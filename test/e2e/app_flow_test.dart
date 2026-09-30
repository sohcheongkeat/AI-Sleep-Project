import 'dart:io';

import 'package:ai_sleep/data/night_repository.dart';
import 'package:ai_sleep/services/night_store.dart';
import 'package:ai_sleep/services/settings.dart';
import 'package:ai_sleep/services/tracking_controller.dart';
import 'package:ai_sleep/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/audio_platform.dart';
import '../helpers/synthetic_audio.dart';

/// Drives the real app like a user: set the alarm, start the night, the
/// alarm rings, "I'm up", read the report, then find it in History.
void main() {
  testWidgets('a night from the Tonight screen to the morning report', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    late Directory dir;
    late NightStore store;
    late Settings settings;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('sleep_coach_flow');
      final repo = NightRepository(dir);
      await repo.init();
      store = NightStore(repo);
      settings = Settings(File('${dir.path}/settings.json'));
    });
    addTearDown(() => dir.deleteSync(recursive: true));

    // Created on the real clock (not the test's fake one) so the controller's
    // save queue runs with the real file I/O.
    final platform = AudioPlatform(DateTime(2026, 9, 29, 23, 0));
    late TrackingController tracking;
    await tester.runAsync(() async {
      tracking = TrackingController(repository: store.repository, platform: platform);
    });
    await tester.pumpWidget(AiSleepApp(settings: settings, store: store, tracking: tracking));
    await tester.pumpAndSettle();

    // Tonight: default 07:00 alarm with a 30-minute window.
    expect(find.text('Tonight'), findsWidgets);
    expect(find.text('30 min'), findsOneWidget);

    // Narrow the window to 20 minutes by dragging the slider left.
    await tester.drag(find.byType(Slider), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(settings.windowMinutes, lessThan(30));
    expect(settings.windowMinutes, greaterThanOrEqualTo(10));

    // Start: the one-time disclaimer, then tracking.
    await tester.runAsync(() async {
      await tester.tap(find.text('Start sleep tracking'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('I understand'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(settings.acceptedDisclaimer, isTrue);
    expect(tracking.state, TrackingState.tracking);
    expect(find.text('End night'), findsOneWidget);
    expect(find.textContaining('Alarm window'), findsOneWidget);
    expect(platform.scheduled, isNotNull, reason: 'OS alarm registered');

    // Two minutes of sound: settling in, then snoring.
    platform.play(SyntheticAudio([(Scene.awake, 1), (Scene.snoring, 1)]));
    await tester.pump();
    expect(tracking.snoreCount, closeTo(13, 2));
    expect(find.textContaining('${tracking.snoreCount} snores'), findsOneWidget);

    // The OS alarm rings (e.g. the wake-up time was reached).
    await tester.runAsync(() async {
      platform.ring();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text("I'm up — stop alarm"), findsOneWidget);
    expect(find.text('Wake-up time reached'), findsOneWidget);

    // I'm up: tracking ends and the report opens.
    await tester.runAsync(() async {
      await tester.tap(find.text("I'm up — stop alarm"));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(tracking.state, TrackingState.idle);
    expect(find.text('Sleep stages (estimated)'), findsOneWidget);
    expect(find.text('Sleep score'), findsOneWidget);

    // Tag the night, then go back and find it in History.
    await tester.scrollUntilVisible(find.text('Alcohol'), 300, scrollable: find.byType(Scrollable).first);
    await tester.runAsync(() async {
      await tester.tap(find.text('Alcohol'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(store.nights.single.tags, {'Alcohol'});

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alcohol'), findsOneWidget);
    final saved = store.nights.single;
    expect(saved.metrics.snoreCount, closeTo(13, 2));
    expect(find.textContaining('${saved.metrics.snoreCount} snores'), findsOneWidget);
  });
}
