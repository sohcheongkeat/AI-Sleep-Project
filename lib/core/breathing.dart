import 'dart:math' as math;

/// Breathing rhythm estimated from a loudness envelope.
class BreathingEstimate {
  const BreathingEstimate({required this.rateBpm, required this.regularity});

  final double rateBpm;

  /// 0..1: strength of the periodic component. Regular breathing (N2/N3)
  /// scores high; the uneven breathing of N1 and wake scores low.
  final double regularity;
}

const _minBpm = 8.0;
const _maxBpm = 30.0;

/// Autocorrelation-based estimate. [envelope] is breath-band loudness in dB
/// sampled at [frameRate] Hz. Returns null if the signal is too short or too
/// flat to tell (e.g. breathing is inaudible from where the phone lies).
BreathingEstimate? estimateBreathing(List<double> envelope, double frameRate) {
  final n = envelope.length;
  if (n < frameRate * 15) return null;

  final mean = envelope.reduce((a, b) => a + b) / n;
  final x = [for (final v in envelope) v - mean];
  final energy = x.fold<double>(0, (a, v) => a + v * v);
  if (energy / n < 0.05) return null;

  final minLag = (60 / _maxBpm * frameRate).floor();
  final maxLag = math.min(n - 1, (60 / _minBpm * frameRate).ceil());
  final ac = List<double>.filled(maxLag + 2, 0);
  for (var lag = minLag; lag <= maxLag; lag++) {
    var s = 0.0;
    for (var i = 0; i + lag < n; i++) {
      s += x[i] * x[i + lag];
    }
    ac[lag] = (s / (n - lag)) / (energy / n);
  }

  // Prefer the first clear local maximum (the fundamental period) over the
  // global one, so a 2x-period harmonic isn't mistaken for the rate.
  var bestLag = -1;
  var best = double.negativeInfinity;
  for (var lag = minLag + 1; lag < maxLag; lag++) {
    if (ac[lag] > ac[lag - 1] && ac[lag] >= ac[lag + 1] && ac[lag] > 0.2) {
      bestLag = lag;
      best = ac[lag];
      break;
    }
  }
  if (bestLag < 0) {
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (ac[lag] > best) {
        best = ac[lag];
        bestLag = lag;
      }
    }
  }

  return BreathingEstimate(
    rateBpm: 60 * frameRate / bestLag,
    regularity: best.clamp(0.0, 1.0),
  );
}
