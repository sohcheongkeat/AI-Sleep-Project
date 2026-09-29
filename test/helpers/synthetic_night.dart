import 'dart:math' as math;

import 'package:ai_sleep/core/features.dart';

/// What the room sounds like during one stretch of a simulated night.
enum Phase { awake, drifting, regular, snoring, stir, silent }

/// Produces per-frame features (10 Hz) for a scripted night, standing in for
/// real microphone audio.
class SyntheticNight {
  SyntheticNight(this.script, {int seed = 1}) : _rng = math.Random(seed);

  /// (phase, minutes) segments, in order.
  final List<(Phase, double)> script;
  final math.Random _rng;

  static const frameRate = 10.0;
  static const _floorDb = -60.0;

  Iterable<(double, FrameFeatures)> frames() sync* {
    var t = 0.0;
    for (final (phase, minutes) in script) {
      final end = t + minutes * 60;
      for (; t < end; t += 1 / frameRate) {
        yield (t, _frame(phase, t));
      }
    }
  }

  double _noise(double amp) => (_rng.nextDouble() * 2 - 1) * amp;

  FrameFeatures _quiet(double breathDb) => FrameFeatures(
        levelDb: _floorDb + _noise(1),
        lowRatio: 0.3,
        highRatio: 0.1,
        breathDb: breathDb,
      );

  FrameFeatures _frame(Phase p, double t) {
    switch (p) {
      case Phase.silent:
        return _quiet(-70 + _noise(0.1));
      case Phase.regular:
        // Steady 14 breaths/min.
        return _quiet(-70 + 3 * math.sin(2 * math.pi * t * 14 / 60) + _noise(0.3));
      case Phase.drifting:
        // Uneven, shallow breathing: random-walk loudness, no clear rhythm.
        return _quiet(-70 + 3 * math.sin(2 * math.pi * t / 37) * math.cos(t / 3.1) + _noise(2));
      case Phase.snoring:
        final cycle = t % (60 / 13);
        final breath = -70 + 3 * math.sin(2 * math.pi * t * 13 / 60) + _noise(0.3);
        if (cycle < 1.2) {
          return FrameFeatures(
              levelDb: _floorDb + 20 + _noise(1), lowRatio: 0.8, highRatio: 0.05, breathDb: breath);
        }
        return _quiet(breath);
      case Phase.awake:
        // Rustling for 6 s out of every 15 s.
        if (t % 15 < 6) {
          return FrameFeatures(
              levelDb: _floorDb + 15 + _noise(2), lowRatio: 0.2, highRatio: 0.5, breathDb: -65 + _noise(2));
        }
        return _quiet(-70 + _noise(2));
      case Phase.stir:
        // One 2 s shift in position per 30 s, breathing otherwise shallow.
        if (t % 30 < 2) {
          return FrameFeatures(
              levelDb: _floorDb + 14 + _noise(1), lowRatio: 0.2, highRatio: 0.45, breathDb: -66);
        }
        return _quiet(-70 + _noise(2));
    }
  }
}
