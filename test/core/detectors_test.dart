import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_sleep/core/breathing.dart';
import 'package:ai_sleep/core/burst_detectors.dart';
import 'package:ai_sleep/core/features.dart';
import 'package:ai_sleep/core/fft.dart';
import 'package:flutter_test/flutter_test.dart';

Float64List tone(double hz, {double amp = 0.3, int n = 1600, int sr = 16000}) =>
    Float64List.fromList(List.generate(n, (i) => amp * math.sin(2 * math.pi * hz * i / sr)));

FrameFeatures f(double level, {double low = 0.3, double high = 0.1}) =>
    FrameFeatures(levelDb: level, lowRatio: low, highRatio: high, breathDb: -70);

void main() {
  group('fft', () {
    test('puts a pure tone in the right bin', () {
      final re = Float64List(64);
      final im = Float64List(64);
      for (var i = 0; i < 64; i++) {
        re[i] = math.cos(2 * math.pi * 5 * i / 64);
      }
      fft(re, im);
      final mags = [for (var i = 0; i < 32; i++) math.sqrt(re[i] * re[i] + im[i] * im[i])];
      final peak = mags.indexOf(mags.reduce(math.max));
      expect(peak, 5);
    });
  });

  group('FeatureExtractor', () {
    final fx = FeatureExtractor(sampleRate: 16000, frameSize: 1600);

    test('a 150 Hz hum is low-band dominated (snore-like)', () {
      final r = fx.compute(tone(150));
      expect(r.lowRatio, greaterThan(0.9));
      expect(r.highRatio, lessThan(0.05));
    });

    test('a 4 kHz hiss is high-band dominated (rustle-like)', () {
      final r = fx.compute(tone(4000));
      expect(r.highRatio, greaterThan(0.9));
      expect(r.lowRatio, lessThan(0.05));
    });

    test('louder input gives a higher level', () {
      expect(fx.compute(tone(300, amp: 0.5)).levelDb,
          greaterThan(fx.compute(tone(300, amp: 0.05)).levelDb + 15));
    });

    test('pcm16ToFloat decodes little-endian samples', () {
      final bytes = Uint8List.fromList([0x00, 0x40, 0x00, 0xC0]); // 16384, -16384
      expect(pcm16ToFloat(bytes), [0.5, -0.5]);
    });
  });

  group('SnoreDetector', () {
    test('detects a 1.2 s low-frequency burst above the floor', () {
      final d = SnoreDetector();
      SoundEvent? ev;
      var t = 0.0;
      for (; t < 10; t += 0.1) {
        d.push(t, f(-60));
      }
      for (final end = t + 1.2; t < end; t += 0.1) {
        d.push(t, f(-40, low: 0.8));
      }
      ev = d.push(t, f(-60));
      expect(ev, isNotNull);
      expect(ev!.duration, closeTo(1.2, 0.15));
    });

    test('ignores high-frequency bursts and very long sounds', () {
      final d = SnoreDetector();
      var t = 0.0;
      for (; t < 10; t += 0.1) {
        d.push(t, f(-60));
      }
      for (final end = t + 1.0; t < end; t += 0.1) {
        d.push(t, f(-40, low: 0.1, high: 0.6));
      }
      expect(d.push(t, f(-60)), isNull);
      for (final end = t + 8; t < end; t += 0.1) {
        d.push(t, f(-40, low: 0.8));
      }
      expect(d.push(t, f(-60)), isNull);
    });
  });

  group('MovementDetector', () {
    test('detects a broadband rustle, not a snore', () {
      final d = MovementDetector();
      var t = 0.0;
      for (; t < 10; t += 0.1) {
        d.push(t, f(-60));
      }
      for (final end = t + 3; t < end; t += 0.1) {
        d.push(t, f(-45, low: 0.2, high: 0.5));
      }
      expect(d.push(t, f(-60)), isNotNull);
      for (final end = t + 1.2; t < end; t += 0.1) {
        d.push(t, f(-40, low: 0.8, high: 0.05));
      }
      expect(d.push(t, f(-60)), isNull);
    });
  });

  group('estimateBreathing', () {
    test('finds the rate of steady breathing and scores it regular', () {
      final env = [for (var i = 0; i < 600; i++) math.sin(2 * math.pi * (i / 10) * 15 / 60) * 3];
      final b = estimateBreathing(env, 10)!;
      expect(b.rateBpm, closeTo(15, 1));
      expect(b.regularity, greaterThan(0.7));
    });

    test('scores random loudness as irregular', () {
      final rng = math.Random(3);
      final env = [for (var i = 0; i < 600; i++) rng.nextDouble() * 4];
      expect(estimateBreathing(env, 10)!.regularity, lessThan(0.3));
    });

    test('returns null for silence or too little data', () {
      expect(estimateBreathing(List.filled(600, -70.0), 10), isNull);
      expect(estimateBreathing([1, 2, 3], 10), isNull);
    });
  });
}
