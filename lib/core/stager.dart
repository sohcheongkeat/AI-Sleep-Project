import 'breathing.dart';

/// Sleep stages as estimated per 30 s epoch.
///
/// This is an estimate from sound only, not polysomnography: clinical N1 is
/// defined by EEG. We use N1's audible correlates instead:
///   - just after wake/movement: still, but breathing not yet regular
///   - uneven breathing with no snoring (snoring is rare in N1)
///   - brief movement sounds out of deeper sleep (sleep lightening)
enum Stage { wake, n1, n2, n3 }

extension StageLabel on Stage {
  String get label => switch (this) {
        Stage.wake => 'Awake',
        Stage.n1 => 'Light (N1)',
        Stage.n2 => 'Sleep (N2)',
        Stage.n3 => 'Deep (N3)',
      };

  bool get isAsleep => this != Stage.wake;
}

const epochSeconds = 30;

class EpochInput {
  const EpochInput({required this.movement, required this.snores, this.breathing});

  /// Fraction of the epoch (0..1) during which movement sounds were heard.
  final double movement;
  final int snores;
  final BreathingEstimate? breathing;
}

class StagerConfig {
  const StagerConfig({
    this.wakeMovement = 0.15,
    this.minorMovement = 0.02,
    this.regularBreathing = 0.5,
    this.irregularBreathing = 0.3,
    this.deepRegularity = 0.7,
    this.deepStillEpochs = 20,
    this.maxN1Epochs = 14,
    this.snoresForSleep = 2,
  });

  final double wakeMovement; // ~4.5 s of rustling in 30 s => awake
  final double minorMovement; // a twitch or position shift
  final double regularBreathing;
  final double irregularBreathing;
  final double deepRegularity;
  final int deepStillEpochs; // 10 min of stillness before N3 is plausible
  final int maxN1Epochs; // N1 rarely lasts > ~7 min
  final int snoresForSleep;
}

class StageResult {
  const StageResult(this.stage, this.reason);
  final Stage stage;
  final String reason;
}

class SleepStager {
  SleepStager([this.config = const StagerConfig()]);

  final StagerConfig config;
  Stage _prev = Stage.wake;
  int _stillEpochs = 0;
  int _n1Run = 0;

  StageResult classify(EpochInput e) {
    final c = config;
    final reg = e.breathing?.regularity;
    _stillEpochs = e.movement >= c.minorMovement ? 0 : _stillEpochs + 1;

    Stage stage;
    String reason;
    if (e.movement >= c.wakeMovement) {
      (stage, reason) = (Stage.wake, 'lots of movement');
    } else if (e.movement >= c.minorMovement) {
      (stage, reason) = (Stage.n1, 'brief movement');
    } else if (e.snores >= c.snoresForSleep) {
      (stage, reason) = (_deepOr(Stage.n2, reg), 'snoring');
    } else if (reg != null && reg >= c.regularBreathing) {
      if (_prev == Stage.wake) {
        // Breathing has settled, but sleep onset always passes through N1.
        (stage, reason) = (Stage.n1, 'settling after wake');
      } else {
        (stage, reason) = (_deepOr(Stage.n2, reg), 'regular breathing');
      }
    } else if (reg != null && reg < c.irregularBreathing) {
      (stage, reason) = (Stage.n1, 'uneven breathing, no snoring');
    } else if (_prev == Stage.wake || _prev == Stage.n1) {
      (stage, reason) = (Stage.n1, 'still, drifting off');
    } else {
      (stage, reason) = (_prev, 'no change');
    }

    // N1 is a short transition; long calm stillness means we've moved on.
    if (stage == Stage.n1) {
      _n1Run++;
      final uneven = reg != null && reg < c.irregularBreathing;
      if (_n1Run > c.maxN1Epochs && _stillEpochs > c.maxN1Epochs && !uneven) {
        (stage, reason) = (Stage.n2, 'still for a long time');
      }
    }
    if (stage != Stage.n1) _n1Run = 0;

    _prev = stage;
    return StageResult(stage, reason);
  }

  Stage _deepOr(Stage fallback, double? reg) {
    if (_stillEpochs >= config.deepStillEpochs && reg != null && reg >= config.deepRegularity) {
      return Stage.n3;
    }
    return fallback;
  }
}
