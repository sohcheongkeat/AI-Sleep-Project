import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_sleep/data/night_repository.dart';
import 'package:ai_sleep/services/audio_capture.dart';
import 'package:ai_sleep/services/tracking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlatform implements TrackingPlatform {
  FakePlatform({this.permission = true});

  final bool permission;
  DateTime clock = DateTime(2026, 5, 1, 23);
  void Function(Float64List)? onFrame;
  DateTime? scheduledAt;
  int ringNowCalls = 0;
  bool audioStopped = false;
  final ringing = StreamController<bool>.broadcast();

  @override
  Future<bool> micPermission() async => permission;
  @override
  Future<void> startAudio(void Function(Float64List) cb) async => onFrame = cb;
  @override
  Future<void> stopAudio() async => audioStopped = true;
  @override
  Future<void> startOvernightService() async {}
  @override
  Future<void> stopOvernightService() async {}
  @override
  Future<void> scheduleAlarm(DateTime at) async => scheduledAt = at;
  @override
  Future<void> ringAlarmNow() async => ringNowCalls++;
  @override
  Future<void> stopAlarm() async {}
  @override
  Stream<bool> get alarmRinging => ringing.stream;
  @override
  DateTime now() => clock;

  final _rng = math.Random(7);

  /// Feeds [seconds] of audio: faint noise, plus a 1.2 s 150 Hz snore every
  /// 4 s when [snoring].
  void feed(double seconds, {bool snoring = false}) {
    const n = AudioCapture.frameSize;
    const sr = AudioCapture.sampleRate;
    final frames = (seconds * AudioCapture.frameRate).round();
    for (var i = 0; i < frames; i++) {
      final tInCycle = (i % 40) / AudioCapture.frameRate;
      final snore = snoring && tInCycle < 1.2;
      final frame = Float64List(n);
      for (var k = 0; k < n; k++) {
        frame[k] = (_rng.nextDouble() * 2 - 1) * 0.001 +
            (snore ? 0.2 * math.sin(2 * math.pi * 150 * k / sr) : 0);
      }
      clock = clock.add(const Duration(milliseconds: 100));
      onFrame!(frame);
    }
  }
}

void main() {
  late Directory dir;
  late NightRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ai_sleep_ctrl');
    repo = NightRepository(dir);
    await repo.init();
  });
  tearDown(() => dir.delete(recursive: true));

  test('refuses to start without microphone permission', () async {
    final c = TrackingController(repository: repo, platform: FakePlatform(permission: false));
    final r = await c.start();
    expect(r.ok, isFalse);
    expect(c.state, TrackingState.idle);
  });

  test('tracks a short night: snores, a clip, the deadline alarm, and saving', () async {
    final p = FakePlatform();
    final c = TrackingController(repository: repo, platform: p);
    final wakeBy = DateTime(2026, 5, 2, 7);
    expect((await c.start(wakeBy: wakeBy, windowMinutes: 20)).ok, isTrue);
    expect(p.scheduledAt, wakeBy, reason: 'OS alarm is the safety net');
    expect(c.state, TrackingState.tracking);

    p.feed(30);
    p.feed(60, snoring: true);
    p.feed(30.5);
    expect(c.snoreCount, closeTo(15, 2));

    final night = (await c.finish())!;
    expect(p.audioStopped, isTrue);
    expect(night.epochs, hasLength(4));
    expect(night.snoreOffsetsS.length, closeTo(15, 2));
    expect(night.clips, hasLength(1), reason: 'at most one clip per 5 minutes');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final clip = File('${repo.clipsDir.path}/${night.clips.single.file}');
    expect(await clip.exists(), isTrue);
    expect(await clip.length(), greaterThan(44));

    final saved = await repo.loadAll();
    expect(saved.single.id, night.id);
    expect(saved.single.wakeBy, wakeBy);
  });

  test('goes to ringing when the OS deadline alarm fires', () async {
    final p = FakePlatform();
    final c = TrackingController(repository: repo, platform: p);
    await c.start(wakeBy: DateTime(2026, 5, 2, 7));
    p.ringing.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, TrackingState.ringing);
    expect(c.alarmReason, 'Wake-up time reached');
  });

  test('a night stopped within 30 seconds is discarded', () async {
    final p = FakePlatform();
    final c = TrackingController(repository: repo, platform: p);
    await c.start(saveClips: false);
    p.feed(10);
    expect(await c.finish(), isNull);
    expect(await repo.loadAll(), isEmpty);
  });
}
