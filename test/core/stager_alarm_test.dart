import 'package:ai_sleep/core/breathing.dart';
import 'package:ai_sleep/core/smart_alarm.dart';
import 'package:ai_sleep/core/stager.dart';
import 'package:flutter_test/flutter_test.dart';

const regular = BreathingEstimate(rateBpm: 14, regularity: 0.8);
const uneven = BreathingEstimate(rateBpm: 18, regularity: 0.1);

EpochInput still({BreathingEstimate? b, int snores = 0}) =>
    EpochInput(movement: 0, snores: snores, breathing: b);

void main() {
  group('SleepStager', () {
    test('lots of movement is wake', () {
      expect(SleepStager().classify(const EpochInput(movement: 0.3, snores: 0)).stage, Stage.wake);
    });

    test('sleep onset passes through N1 before N2', () {
      final s = SleepStager();
      s.classify(const EpochInput(movement: 0.3, snores: 0));
      expect(s.classify(still(b: regular)).stage, Stage.n1);
      expect(s.classify(still(b: regular)).stage, Stage.n2);
    });

    test('uneven breathing without snoring is N1', () {
      final s = SleepStager();
      s.classify(still(b: regular));
      s.classify(still(b: regular));
      expect(s.classify(still(b: uneven)).stage, Stage.n1);
    });

    test('a brief movement out of deep sleep is N1 (lightening)', () {
      final s = SleepStager();
      for (var i = 0; i < 30; i++) {
        s.classify(still(b: regular));
      }
      expect(s.classify(const EpochInput(movement: 0.05, snores: 0, breathing: regular)).stage,
          Stage.n1);
    });

    test('long regular stillness becomes N3', () {
      final s = SleepStager();
      Stage last = Stage.wake;
      for (var i = 0; i < 25; i++) {
        last = s.classify(still(b: regular)).stage;
      }
      expect(last, Stage.n3);
    });

    test('deep sleep comes in capped blocks that need lightening to repeat', () {
      final s = SleepStager();
      final stages = [for (var i = 0; i < 200; i++) s.classify(still(b: regular)).stage];
      final n3 = stages.where((x) => x == Stage.n3).length;
      expect(n3, 60, reason: 'one 30-minute block, then N2');
      expect(stages.last, Stage.n2);

      s.classify(const EpochInput(movement: 0.05, snores: 0, breathing: regular)); // stir
      final again = [for (var i = 0; i < 40; i++) s.classify(still(b: regular)).stage];
      expect(again, contains(Stage.n3), reason: 'a new block after lightening');
    });

    test('snoring counts as sleep, not N1', () {
      final s = SleepStager();
      s.classify(still(b: regular));
      expect(s.classify(still(b: uneven, snores: 4)).stage, isNot(Stage.n1));
    });

    test('N1 does not persist through a long quiet stretch', () {
      final s = SleepStager();
      s.classify(const EpochInput(movement: 0.3, snores: 0));
      Stage last = Stage.wake;
      for (var i = 0; i < 20; i++) {
        last = s.classify(still()).stage;
      }
      expect(last, Stage.n2);
    });
  });

  group('SmartAlarm', () {
    final t0 = DateTime(2026, 1, 1, 23);
    DateTime at(int min) => t0.add(Duration(minutes: min));

    test('window sizes are limited to 10–60 minutes', () {
      expect(() => SmartAlarm(wakeBy: at(480), windowMinutes: 5), throwsA(isA<AssertionError>()));
      expect(() => SmartAlarm(wakeBy: at(480), windowMinutes: 61), throwsA(isA<AssertionError>()));
    });

    test('fires on N1 inside the window after deeper sleep', () {
      final a = SmartAlarm(wakeBy: at(480), windowMinutes: 30);
      expect(a.update(at(0), Stage.wake), isNull);
      expect(a.update(at(100), Stage.n3), isNull);
      expect(a.update(at(440), Stage.n1), isNull, reason: 'before window');
      expect(a.update(at(455), Stage.n2), isNull);
      expect(a.update(at(460), Stage.n1), contains('N1'));
      expect(a.update(at(461), Stage.n1), isNull, reason: 'fires only once');
    });

    test('ignores sleep-onset N1 even when it falls inside the window', () {
      final a = SmartAlarm(wakeBy: at(40), windowMinutes: 60);
      expect(a.update(at(0), Stage.wake), isNull);
      expect(a.update(at(5), Stage.n1), isNull);
      expect(a.update(at(20), Stage.n2), isNull);
      expect(a.update(at(30), Stage.n1), isNull, reason: 'slept less than an hour');
      expect(a.update(at(40), Stage.n2), 'Wake-up time reached');
    });

    test('always fires at the deadline', () {
      final a = SmartAlarm(wakeBy: at(480), windowMinutes: 30);
      a.update(at(0), Stage.wake);
      expect(a.update(at(470), Stage.n3), isNull);
      expect(a.update(at(480), Stage.n3), 'Wake-up time reached');
    });
  });
}
