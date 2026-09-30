import 'dart:math' as math;

import 'features.dart';

/// Adaptive estimate of the room's background loudness. Falls quickly with
/// quiet moments and rises slowly, so repeated snores don't become "the floor".
class NoiseFloor {
  NoiseFloor({this.riseDbPerS = 0.05, this.fallAlpha = 0.2});

  final double riseDbPerS;
  final double fallAlpha;
  double? _db;
  double? _lastT;

  double get db => _db ?? -120;

  void update(double t, double levelDb) {
    final dt = _lastT == null ? 0.0 : t - _lastT!;
    _lastT = t;
    final cur = _db;
    if (cur == null) {
      _db = levelDb;
    } else if (levelDb < cur) {
      _db = cur + (levelDb - cur) * fallAlpha;
    } else {
      _db = cur + math.min(levelDb - cur, riseDbPerS * dt);
    }
  }
}

/// A completed burst of sound.
class SoundEvent {
  const SoundEvent({required this.start, required this.end, required this.peakDb});

  final double start;
  final double end;
  final double peakDb;

  double get duration => end - start;
}

class _Burst {
  _Burst(this.start, this.peakDb);
  final double start;
  double peakDb;
  int frames = 0;
  int matchingFrames = 0;
}

/// Tracks loud bursts above the noise floor and reports those whose frames
/// mostly match [frameMatches] and whose duration is within bounds.
class _BurstDetector {
  _BurstDetector({
    required this.level,
    required this.thresholdDb,
    required this.minDurationS,
    required this.maxDurationS,
    required this.frameMatches,
    NoiseFloor? floor,
  }) : floor = floor ?? NoiseFloor();

  /// Which loudness to compare with the noise floor.
  final double Function(FrameFeatures) level;
  final double thresholdDb;
  final double minDurationS;
  final double maxDurationS;
  final bool Function(FrameFeatures) frameMatches;
  final NoiseFloor floor;
  _Burst? _burst;

  SoundEvent? push(double t, FrameFeatures f) {
    final db = level(f);
    floor.update(t, db);
    final loud = db - floor.db >= thresholdDb;
    if (loud) {
      final b = _burst ??= _Burst(t, db);
      b.frames++;
      if (frameMatches(f)) b.matchingFrames++;
      b.peakDb = math.max(b.peakDb, db);
      return null;
    }
    final b = _burst;
    if (b == null) return null;
    _burst = null;
    final duration = t - b.start;
    if (b.matchingFrames / b.frames >= 0.6 &&
        duration >= minDurationS &&
        duration <= maxDurationS) {
      return SoundEvent(start: b.start, end: t, peakDb: b.peakDb);
    }
    return null;
  }
}

/// Snore: a loud burst in the 60–500 Hz band about as long as an inhalation
/// (0.3–3.5 s). Measured in that band only, because audible breathing is
/// itself 10+ dB above a quiet room's floor but carries little low-frequency
/// energy; a snore is 30–40 dB above it.
class SnoreDetector extends _BurstDetector {
  SnoreDetector({super.thresholdDb = 15, double minLowRatio = 0.45})
      : super(
          level: (f) => f.lowDb,
          minDurationS: 0.3,
          maxDurationS: 3.5,
          frameMatches: (f) => f.lowRatio >= minLowRatio,
        );
}

/// Movement: a rustle (bedding, turning over) measured in the 2–7.5 kHz
/// band. Breathing reaches ~+14 dB there in a quiet room, rustling ~+30 dB,
/// hence the 20 dB threshold. Very long sounds (TV, traffic) are ignored.
class MovementDetector extends _BurstDetector {
  MovementDetector({super.thresholdDb = 20, double minHighRatio = 0.2})
      : super(
          level: (f) => f.highDb,
          minDurationS: 0.4,
          maxDurationS: 20,
          frameMatches: (f) => f.highRatio >= minHighRatio,
        );
}
