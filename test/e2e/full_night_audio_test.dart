import 'dart:io';

import 'package:ai_sleep/core/stager.dart';
import 'package:ai_sleep/data/night_repository.dart';
import 'package:ai_sleep/services/tracking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/audio_platform.dart';
import '../helpers/synthetic_audio.dart';

// A 7.5-hour night in 90-minute-ish cycles. Minutes from bedtime in brackets.
const night = [
  (Scene.awake, 12.0), //       [0]    settling in
  (Scene.drifting, 8.0), //     [12]   falling asleep
  (Scene.breathing, 50.0), //   [20]
  (Scene.snoring, 40.0), //     [70]
  (Scene.breathing, 30.0), //   [110]
  (Scene.stir, 3.0), //         [140]  cycle ends: light sleep, outside window
  (Scene.breathing, 40.0), //   [143]
  (Scene.snoring, 30.0), //     [183]
  (Scene.breathing, 20.0), //   [213]
  (Scene.stir, 3.0), //         [233]
  (Scene.breathing, 60.0), //   [236]
  (Scene.snoring, 20.0), //     [296]
  (Scene.stir, 3.0), //         [316]
  (Scene.breathing, 50.0), //   [319]
  (Scene.awake, 3.0), //        [369]  brief awakening
  (Scene.breathing, 44.0), //   [372]
  (Scene.snoring, 20.0), //     [416]  window opens at 420, still snoring
  (Scene.stir, 3.0), //         [436]  light sleep in the window => alarm
  (Scene.breathing, 14.0), //   [439]  until 453
];
const snoringMinutes = 40 + 30 + 20 + 20;

void main() {
  for (final fan in [false, true]) {
    test('a full night of realistic audio (${fan ? 'with a fan' : 'quiet room'})', () async {
      final dir = await Directory.systemTemp.createTemp('sleep_coach_e2e');
      addTearDown(() => dir.delete(recursive: true));
      final repo = NightRepository(dir);
      await repo.init();

      final start = DateTime(2026, 9, 29, 23, 0);
      final wakeBy = start.add(const Duration(minutes: 450)); // 06:30
      final p = AudioPlatform(start);
      final c = TrackingController(repository: repo, platform: p);
      expect((await c.start(wakeBy: wakeBy, windowMinutes: 30)).ok, isTrue);
      expect(p.scheduled, wakeBy, reason: 'OS alarm registered as the safety net');

      p.play(SyntheticAudio(night, fan: fan, seed: fan ? 2 : 1));

      // Smart alarm: once, in light sleep, during the 06:16 stir.
      expect(c.state, TrackingState.ringing);
      expect(c.alarmReason, 'Woke you in light sleep (N1)');
      expect(p.ringNowAt, hasLength(1));
      final alarmMin = p.ringNowAt.single.difference(start).inMinutes;
      expect(alarmMin, inInclusiveRange(436, 440));

      final record = (await c.finish())!;
      await Future<void>.delayed(const Duration(milliseconds: 200)); // clip writes
      final m = record.metrics;
      Stage at(double min) => record.epochs[(min * 2).floor()].stage;

      // Stages at known moments.
      expect(at(6), Stage.wake, reason: 'settling in');
      expect(at(16), Stage.n1, reason: 'falling asleep');
      expect(at(60), anyOf(Stage.n2, Stage.n3));
      expect(at(90), anyOf(Stage.n2, Stage.n3), reason: 'snoring');
      expect(at(141), Stage.n1, reason: 'stir');
      expect(at(370), Stage.wake, reason: 'brief awakening');

      // Snoring: 13 per minute of snoring.
      expect(m.snoreCount, closeTo(13 * snoringMinutes, 13 * snoringMinutes * 0.1));
      expect(record.clips.length, inInclusiveRange(10, 30));
      for (final clip in record.clips) {
        expect(await File('${repo.clipsDir.path}/${clip.file}').exists(), isTrue);
      }

      // Night-level metrics.
      expect(m.timeInBedMin, closeTo(453, 1));
      expect(m.latencyMin, inInclusiveRange(12, 22));
      expect(m.awakenings, 1);
      expect(m.efficiency, greaterThan(0.9));
      expect(m.stagePercent(Stage.n3), inInclusiveRange(5, 35));
      expect(m.stagePercent(Stage.n1), lessThan(25));

      final saved = await repo.loadAll();
      expect(saved.single.id, record.id);
      expect(saved.single.alarmReason, 'Woke you in light sleep (N1)');

      // ignore: avoid_print
      print('${fan ? 'fan  ' : 'quiet'}: score ${m.score}, asleep ${m.totalSleepMin} min, '
          'latency ${m.latencyMin} min, snores ${m.snoreCount}, clips ${record.clips.length}, '
          'N1 ${m.stagePercent(Stage.n1).round()}% N2 ${m.stagePercent(Stage.n2).round()}% '
          'N3 ${m.stagePercent(Stage.n3).round()}%, alarm at +$alarmMin min');
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
