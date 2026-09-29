import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_sleep/core/night_record.dart';
import 'package:ai_sleep/core/session.dart';
import 'package:ai_sleep/data/night_repository.dart';
import 'package:ai_sleep/services/night_store.dart';
import 'package:ai_sleep/services/settings.dart';
import 'package:ai_sleep/services/tracking_controller.dart';
import 'package:ai_sleep/ui/app.dart';
import 'package:ai_sleep/ui/app_scope.dart';
import 'package:ai_sleep/ui/screens/report_screen.dart';
import 'package:ai_sleep/ui/screens/trends_screen.dart';
import 'package:ai_sleep/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/synthetic_night.dart';

/// Smoke tests that every screen renders without layout errors at phone
/// size. Set SCREENSHOT_DIR to also write PNGs (with real fonts) for review.
final _shotDir = Platform.environment['SCREENSHOT_DIR'];

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) return;
  final fonts = '$sdk/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Light.ttf', 'Roboto-Thin.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

NightRecord _simNight(DateTime start, List<(Phase, double)> script, {Set<String>? tags, int seed = 1}) {
  final s = SleepSession(start: start);
  for (final (t, f) in SyntheticNight(script, seed: seed).frames()) {
    s.addFrame(t, f);
  }
  return NightRecord(
    id: '${start.millisecondsSinceEpoch}',
    start: start,
    end: start.add(Duration(seconds: s.epochs.length * 30)),
    epochs: s.epochs,
    snoreOffsetsS: [for (final e in s.snores) e.start],
    wakeBy: start.add(const Duration(hours: 7, minutes: 30)),
    windowMinutes: 30,
    alarmAt: start.add(const Duration(hours: 7, minutes: 12)),
    alarmReason: 'Woke you in light sleep (N1)',
    clips: const [SnoreClip(file: 'a.wav', offsetS: 5400), SnoreClip(file: 'b.wav', offsetS: 9000)],
    tags: tags,
  );
}

List<(Phase, double)> _script(double snoreMin, double wakeMin) => [
      (Phase.awake, wakeMin),
      (Phase.drifting, 6),
      (Phase.regular, 70),
      (Phase.snoring, snoreMin),
      (Phase.regular, 150 - snoreMin / 2),
      (Phase.stir, 3),
      (Phase.regular, 120),
      (Phase.awake, 3),
      (Phase.regular, 60),
      (Phase.stir, 2),
    ];

Future<void> _shot(WidgetTester tester, String name) async {
  final out = _shotDir;
  if (out == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  late Directory dir;
  late NightStore store;
  late Settings settings;

  setUpAll(_loadFonts);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ai_sleep_ui');
    final repo = NightRepository(dir);
    await repo.init();
    store = NightStore(repo);
    settings = Settings(File('${dir.path}/settings.json'));
    final base = DateTime(2026, 9, 20, 23, 10);
    for (var i = 0; i < 8; i++) {
      final alcohol = i.isEven;
      await repo.save(_simNight(
        base.add(Duration(days: i)),
        _script(alcohol ? 120 : 20, 8 + i * 3),
        tags: alcohol ? {'Alcohol'} : {'Exercise'},
        seed: i,
      ));
    }
    await store.reload();
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope(
      settings: settings,
      store: store,
      tracking: TrackingController(repository: store.repository),
      child: MaterialApp(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: const Key('shot'), child: home),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Tonight screen', (tester) async {
    await pump(tester, const HomeShell());
    expect(find.text('Start sleep tracking'), findsOneWidget);
    expect(find.textContaining('Rings at the first light sleep'), findsOneWidget);
    await _shot(tester, '1_tonight');
  });

  testWidgets('Report screen', (tester) async {
    await pump(tester, ReportScreen(night: store.nights.first));
    expect(find.text('Sleep stages (estimated)'), findsOneWidget);
    await _shot(tester, '2_report_top');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await _shot(tester, '3_report_snoring');
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await _shot(tester, '4_report_tips_tags');
  });

  testWidgets('History screen', (tester) async {
    await pump(tester, const HomeShell());
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(8));
    await _shot(tester, '5_history');
  });

  testWidgets('Trends screen shows tag effects', (tester) async {
    await pump(tester, const Scaffold(body: SafeArea(child: TrendsScreen())));
    await _shot(tester, '6_trends');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Alcohol'), findsOneWidget);
    await _shot(tester, '7_trends_tags');
  });

  testWidgets('Settings screen', (tester) async {
    await pump(tester, const HomeShell());
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Export nightly summary (CSV)'), findsOneWidget);
    await _shot(tester, '8_settings');
  });
}
