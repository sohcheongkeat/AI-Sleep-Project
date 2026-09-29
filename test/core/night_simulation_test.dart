import 'package:ai_sleep/core/advice.dart';
import 'package:ai_sleep/core/night_record.dart';
import 'package:ai_sleep/core/session.dart';
import 'package:ai_sleep/core/smart_alarm.dart';
import 'package:ai_sleep/core/stager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/synthetic_night.dart';

void main() {
  final start = DateTime(2026, 3, 1, 23, 0);

  SleepSession run(List<(Phase, double)> script, {SmartAlarm? alarm, List<(String, DateTime)>? fired}) {
    final s = SleepSession(
        start: start, alarm: alarm, onAlarm: fired == null ? null : (r, at) => fired.add((r, at)));
    for (final (t, f) in SyntheticNight(script).frames()) {
      s.addFrame(t, f);
    }
    return s;
  }

  test('a simulated night: stages, snoring and a smart alarm in light sleep', () {
    // Wake-up by 07:00 (480 min), window 30 min => 06:30–07:00.
    final alarm = SmartAlarm(wakeBy: start.add(const Duration(minutes: 480)));
    final fired = <(String, DateTime)>[];
    final session = run([
      (Phase.awake, 10),
      (Phase.drifting, 6),
      (Phase.regular, 60),
      (Phase.snoring, 90),
      (Phase.regular, 150),
      (Phase.stir, 3), // 316–319 min: lightening, but outside the window
      (Phase.regular, 125), // until 444 min (06:24)
      (Phase.snoring, 8), // 06:24–06:32, window opens 06:30 but still snoring
      (Phase.stir, 2), // 06:32: light sleep => alarm
      (Phase.regular, 20),
    ], alarm: alarm, fired: fired);

    final stages = session.epochs.map((e) => e.stage).toList();
    Stage at(double min) => stages[(min * 2).floor()];

    expect(at(5), Stage.wake);
    expect(at(13), Stage.n1, reason: 'drifting off');
    expect(at(40), anyOf(Stage.n2, Stage.n3));
    expect(at(120), anyOf(Stage.n2, Stage.n3), reason: 'snoring phase');
    expect(at(317), Stage.n1, reason: 'stirring phase');
    expect(at(451), Stage.n3, reason: 'snoring in the window does not wake you');

    expect(fired, hasLength(1));
    expect(fired.single.$1, 'Woke you in light sleep (N1)');
    final firedAtMin = fired.single.$2.difference(start).inMinutes;
    expect(firedAtMin, inInclusiveRange(452, 454), reason: 'during the 06:32 stir');

    // Snoring: ~13/min for 90 + 8 minutes.
    expect(session.snores.length, closeTo(13 * 98, 13 * 98 * 0.1));
  });

  test('metrics and summary for a simulated night', () {
    final session = run([
      (Phase.awake, 10),
      (Phase.drifting, 6),
      (Phase.regular, 200),
      (Phase.snoring, 60),
      (Phase.regular, 200),
      (Phase.awake, 4),
    ]);
    final night = NightRecord(
      id: 'n1',
      start: start,
      end: start.add(const Duration(minutes: 480)),
      epochs: session.epochs,
      snoreOffsetsS: [for (final s in session.snores) s.start],
    );
    final m = night.metrics;
    expect(m.timeInBedMin, closeTo(480, 1));
    expect(m.latencyMin, closeTo(10, 1.5));
    expect(m.totalSleepMin, greaterThan(450));
    expect(m.efficiency, greaterThan(0.93));
    expect(m.awakenings, 0);
    expect(m.score, greaterThanOrEqualTo(80));

    final summary = summarize(night);
    expect(summary.headline, contains('score ${m.score}'));

    // Survives a JSON round-trip.
    final back = NightRecord.fromJson(night.toJson());
    expect(back.stages, night.stages);
    expect(back.metrics.score, m.score);
  });

  test('no alarm is created when tracking without one', () {
    final session = run([(Phase.awake, 2)]);
    expect(session.alarm, isNull);
    expect(session.epochs.length, 3); // last partial epoch not yet closed
  });
}
