import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

double powerToDb(double p) => 10 * math.log(math.max(p, 1e-12)) / math.ln10;

/// Acoustic features of one ~100 ms audio frame.
class FrameFeatures {
  const FrameFeatures({
    required this.levelDb,
    required this.lowRatio,
    required this.highRatio,
    required this.breathDb,
  });

  /// Overall loudness in dBFS.
  final double levelDb;

  /// Share of 50–7500 Hz energy in the 60–500 Hz snore band.
  final double lowRatio;

  /// Share of 50–7500 Hz energy in the 2–7.5 kHz band (rustling, movement).
  final double highRatio;

  /// Loudness of the 100–1500 Hz band, where breath noise lives.
  final double breathDb;
}

/// Converts little-endian 16-bit PCM bytes to samples in [-1, 1].
Float64List pcm16ToFloat(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final out = Float64List(bytes.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

class FeatureExtractor {
  FeatureExtractor({required this.sampleRate, required this.frameSize})
      : fftSize = nextPowerOfTwo(frameSize),
        _window = Float64List.fromList(List.generate(
            frameSize, (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (frameSize - 1))));

  final int sampleRate;
  final int frameSize;
  final int fftSize;
  final Float64List _window;

  FrameFeatures compute(Float64List samples) {
    assert(samples.length == frameSize);
    var sumSq = 0.0;
    final re = Float64List(fftSize);
    final im = Float64List(fftSize);
    for (var i = 0; i < frameSize; i++) {
      sumSq += samples[i] * samples[i];
      re[i] = samples[i] * _window[i];
    }
    fft(re, im);

    final binHz = sampleRate / fftSize;
    final power = Float64List(fftSize ~/ 2);
    for (var i = 0; i < power.length; i++) {
      power[i] = re[i] * re[i] + im[i] * im[i];
    }
    double band(double lo, double hi) {
      final start = math.max(0, (lo / binHz).floor());
      final end = math.min(power.length - 1, (hi / binHz).ceil());
      var s = 0.0;
      for (var i = start; i <= end; i++) {
        s += power[i];
      }
      return s;
    }

    final total = band(50, 7500);
    return FrameFeatures(
      levelDb: powerToDb(sumSq / frameSize),
      lowRatio: total > 0 ? band(60, 500) / total : 0,
      highRatio: total > 0 ? band(2000, 7500) / total : 0,
      breathDb: powerToDb(band(100, 1500) / fftSize),
    );
  }
}
