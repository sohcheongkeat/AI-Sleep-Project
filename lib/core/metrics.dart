import 'dart:math' as math;

import 'stager.dart';

/// Sleep-quality numbers for one night, derived from the epoch stages.
class NightMetrics {
  NightMetrics._({
    required this.timeInBedMin,
    required this.latencyMin,
    required this.totalSleepMin,
    required this.efficiency,
    required this.awakenings,
    required this.wasoMin,
    required this.stageMinutes,
    required this.snoreCount,
    required this.snoresPerHour,
    required this.snoringPercent,
    required this.score,
  });

  final double timeInBedMin;

  /// Minutes until sustained sleep began (null if never).
  final double? latencyMin;
  final double totalSleepMin;

  /// Total sleep / time in bed, 0..1.
  final double efficiency;

  /// Wake periods of >= 1 min between falling asleep and final waking.
  final int awakenings;

  /// Wake after sleep onset, in minutes.
  final double wasoMin;
  final Map<Stage, double> stageMinutes;
  final int snoreCount;
  final double snoresPerHour;

  /// Percent of sleep epochs that contained snoring.
  final double snoringPercent;

  /// 0–100 overall sleep score.
  final int score;

  double stagePercent(Stage s) =>
      totalSleepMin == 0 ? 0 : 100 * (stageMinutes[s] ?? 0) / totalSleepMin;

  static const _epochMin = epochSeconds / 60;

  factory NightMetrics.compute(List<Stage> stages, List<int> snoresPerEpoch) {
    assert(stages.length == snoresPerEpoch.length);
    final n = stages.length;
    final tib = n * _epochMin;

    // Sleep onset: first of 3 consecutive asleep epochs.
    int? onset;
    for (var i = 0; i + 2 < n; i++) {
      if (stages[i].isAsleep && stages[i + 1].isAsleep && stages[i + 2].isAsleep) {
        onset = i;
        break;
      }
    }
    var lastSleep = -1;
    for (var i = n - 1; i >= 0; i--) {
      if (stages[i].isAsleep) {
        lastSleep = i;
        break;
      }
    }

    final stageMinutes = {for (final s in Stage.values) s: 0.0};
    var sleepEpochs = 0;
    var wakeEpochs = 0;
    var awakenings = 0;
    var wakeRun = 0;
    var snoringEpochs = 0;
    var snoresAsleep = 0;
    if (onset != null) {
      for (var i = onset; i <= lastSleep; i++) {
        final s = stages[i];
        if (s.isAsleep) {
          if (wakeRun >= 2) awakenings++;
          wakeRun = 0;
          sleepEpochs++;
          stageMinutes[s] = stageMinutes[s]! + _epochMin;
          if (snoresPerEpoch[i] > 0) snoringEpochs++;
          snoresAsleep += snoresPerEpoch[i];
        } else {
          wakeRun++;
          wakeEpochs++;
        }
      }
    }

    final tst = sleepEpochs * _epochMin;
    final latency = onset == null ? null : onset * _epochMin;
    final waso = wakeEpochs * _epochMin;
    final efficiency = tib == 0 ? 0.0 : tst / tib;
    final snoresPerHour = tst == 0 ? 0.0 : snoresAsleep / (tst / 60);
    final deepPct = tst == 0 ? 0.0 : 100 * stageMinutes[Stage.n3]! / tst;

    return NightMetrics._(
      timeInBedMin: tib,
      latencyMin: latency,
      totalSleepMin: tst,
      efficiency: efficiency,
      awakenings: awakenings,
      wasoMin: waso,
      stageMinutes: stageMinutes,
      snoreCount: snoresPerEpoch.fold(0, (a, b) => a + b),
      snoresPerHour: snoresPerHour,
      snoringPercent: sleepEpochs == 0 ? 0 : 100 * snoringEpochs / sleepEpochs,
      score: _score(
        tstHours: tst / 60,
        efficiency: efficiency,
        latencyMin: latency,
        wasoMin: waso,
        deepPct: deepPct,
        snoresPerHour: snoresPerHour,
      ),
    );
  }

  static int _score({
    required double tstHours,
    required double efficiency,
    required double? latencyMin,
    required double wasoMin,
    required double deepPct,
    required double snoresPerHour,
  }) {
    if (latencyMin == null) return 0;
    // Linear ramp: 1 at `good`, 0 at `bad` (either direction).
    double ramp(double v, double good, double bad) =>
        ((v - bad) / (good - bad)).clamp(0.0, 1.0);

    final duration = tstHours < 7 ? ramp(tstHours, 7, 4) : ramp(tstHours, 9, 11);
    // (component 0..1, weight); weights sum to 100.
    final components = [
      (duration, 30),
      (ramp(efficiency, 0.9, 0.65), 25),
      (ramp(latencyMin, 20, 60), 10),
      (ramp(wasoMin, 20, 90), 15),
      (ramp(deepPct, 15, 0), 10),
      (ramp(snoresPerHour, 10, 120), 10),
    ];
    final total = components.fold<double>(0, (a, c) => a + c.$1 * c.$2);
    return math.max(0, math.min(100, total.round()));
  }
}
