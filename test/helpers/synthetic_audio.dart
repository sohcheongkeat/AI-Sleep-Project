import 'dart:math' as math;
import 'dart:typed_data';

/// What is happening in the bedroom during a stretch of a simulated night.
enum Scene {
  /// Tossing and turning: frequent rustles, uneven breathing.
  awake,

  /// Drifting off: still, shallow uneven breathing.
  drifting,

  /// Steady, audible breathing (~14/min).
  breathing,

  /// Snoring on every breath (~13/min).
  snoring,

  /// Light sleep: a short shift in position every 30 s, uneven breathing.
  stir,
}

/// Generates raw 16 kHz mono audio for a scripted night, frame by frame,
/// standing in for the phone's microphone. Unlike [SyntheticNight] this
/// exercises the whole pipeline, including the FFT feature extraction.
class SyntheticAudio {
  SyntheticAudio(this.script, {this.fan = false, int seed = 1}) : _rng = math.Random(seed);

  /// (scene, minutes) segments, in order.
  final List<(Scene, double)> script;

  /// Adds a steady fan (low rumble + 100 Hz hum), which must not count as snoring.
  final bool fan;

  static const sampleRate = 16000;
  static const frameSize = 1600;

  final math.Random _rng;
  int _n = 0; // sample index
  double _lp = 0, _lp2 = 0, _prevW = 0, _fanLp = 0, _snorePhase = 0;

  // Breath cycle state.
  double _cycleStart = 0, _cycleLen = 4.3, _cycleAmp = 1;
  // Rustle state.
  double _rustleUntil = -1;
  double _nextRustle = 0;

  int get totalFrames {
    final minutes = script.fold<double>(0, (a, s) => a + s.$2);
    return (minutes * 60 * sampleRate / frameSize).round();
  }

  Scene _sceneAt(double t) {
    var end = 0.0;
    for (final (scene, min) in script) {
      end += min * 60;
      if (t < end) return scene;
    }
    return script.last.$1;
  }

  double _white() => _rng.nextDouble() * 2 - 1;

  /// Noise shaped to roughly 200–1500 Hz, like airflow (differentiator for
  /// the low cut, two one-pole low-passes for a 12 dB/octave roll-off).
  double _breathNoise() {
    final w = _white();
    final hp = w - _prevW;
    _prevW = w;
    _lp += 0.4 * (hp - _lp);
    _lp2 += 0.4 * (_lp - _lp2);
    return _lp2 * 2;
  }

  Float64List nextFrame() {
    final out = Float64List(frameSize);
    for (var i = 0; i < frameSize; i++, _n++) {
      final t = _n / sampleRate;
      final scene = _sceneAt(t);
      final regular = scene == Scene.breathing || scene == Scene.snoring;

      // Start a new breath when the previous one ends.
      if (t - _cycleStart >= _cycleLen) {
        _cycleStart = t;
        if (regular) {
          _cycleLen = 60 / (scene == Scene.snoring ? 13 : 14);
          _cycleAmp = 1;
        } else {
          _cycleLen = 2.5 + _rng.nextDouble() * 4.5;
          _cycleAmp = 0.2 + _rng.nextDouble() * 0.8;
        }
      }
      final phase = t - _cycleStart;
      // Inhale (first 40%) louder than exhale.
      final inhale = phase < _cycleLen * 0.4;
      final shape = math.sin(math.pi * (inhale ? phase / (_cycleLen * 0.4) : (phase - _cycleLen * 0.4) / (_cycleLen * 0.6)));
      final breathAmp = (inhale ? 0.004 : 0.0025) * _cycleAmp * shape * shape;

      var s = 0.0008 * _white(); // room noise floor (~-62 dBFS)
      s += breathAmp * _breathNoise() * 3;

      if (scene == Scene.snoring && inhale && phase < 1.2) {
        // Buzz at ~95 Hz with harmonics, jittered, fading in and out.
        final env = math.sin(math.pi * phase / 1.2);
        final f0 = 95 + 5 * math.sin(t * 3);
        _snorePhase += 2 * math.pi * f0 / sampleRate; // accumulate: no drift
        for (var h = 1; h <= 5; h++) {
          s += 0.05 * env / h * math.sin(h * _snorePhase);
        }
      }

      if (scene == Scene.awake || scene == Scene.stir) {
        if (t >= _nextRustle && t > _rustleUntil) {
          final len = scene == Scene.awake ? 3 + _rng.nextDouble() * 4 : 1.5 + _rng.nextDouble();
          _rustleUntil = t + len;
          _nextRustle = t + (scene == Scene.awake ? 12 + _rng.nextDouble() * 6 : 30);
        }
      }
      if (t < _rustleUntil) s += 0.03 * _white();

      if (fan) {
        _fanLp += 0.02 * (_white() - _fanLp);
        s += 0.02 * _fanLp + 0.002 * math.sin(2 * math.pi * 100 * t);
      }
      out[i] = s.clamp(-1.0, 1.0);
    }
    return out;
  }
}
