import 'breathing.dart';
import 'burst_detectors.dart';
import 'features.dart';
import 'smart_alarm.dart';
import 'stager.dart';

/// One classified 30 s epoch.
class Epoch {
  const Epoch({
    required this.index,
    required this.stage,
    required this.movement,
    required this.snores,
    this.breathRate,
    this.regularity,
  });

  final int index;
  final Stage stage;
  final double movement;
  final int snores;
  final double? breathRate;
  final double? regularity;

  Map<String, Object?> toJson() => {
        's': stage.name,
        'm': double.parse(movement.toStringAsFixed(3)),
        'n': snores,
        if (breathRate != null) 'br': double.parse(breathRate!.toStringAsFixed(1)),
        if (regularity != null) 'rg': double.parse(regularity!.toStringAsFixed(2)),
      };

  factory Epoch.fromJson(int index, Map<String, Object?> j) => Epoch(
        index: index,
        stage: Stage.values.byName(j['s']! as String),
        movement: (j['m']! as num).toDouble(),
        snores: j['n']! as int,
        breathRate: (j['br'] as num?)?.toDouble(),
        regularity: (j['rg'] as num?)?.toDouble(),
      );
}

/// Ties the detectors together for one night. Feed it audio frame features
/// (~10/s). Every 30 s it closes an epoch, estimates the stage and consults
/// the smart alarm. Time is passed in, so a whole night can be simulated.
class SleepSession {
  SleepSession({
    required this.start,
    this.alarm,
    this.frameRate = 10,
    StagerConfig stagerConfig = const StagerConfig(),
    this.onEpoch,
    this.onSnore,
    this.onAlarm,
  }) : _stager = SleepStager(stagerConfig);

  final DateTime start;
  final SmartAlarm? alarm;
  final double frameRate;
  final void Function(Epoch)? onEpoch;
  final void Function(SoundEvent)? onSnore;
  final void Function(String reason, DateTime at)? onAlarm;

  final SleepStager _stager;
  final _snoreDetector = SnoreDetector();
  final _movementDetector = MovementDetector();

  final List<Epoch> epochs = [];
  final List<SoundEvent> snores = [];
  final List<SoundEvent> movements = [];

  double _epochStart = 0;
  List<double> _envelope = [];
  List<double> _prevEnvelope = [];
  int _epochSnores = 0;
  double _epochMovementS = 0;

  /// [t] is seconds since [start].
  void addFrame(double t, FrameFeatures f) {
    while (t - _epochStart >= epochSeconds) {
      _closeEpoch();
    }
    _envelope.add(f.breathDb);

    final snore = _snoreDetector.push(t, f);
    if (snore != null) {
      snores.add(snore);
      _epochSnores++;
      onSnore?.call(snore);
    }
    final move = _movementDetector.push(t, f);
    if (move != null) {
      movements.add(move);
      _epochMovementS += move.duration;
    }
  }

  void _closeEpoch({bool checkAlarm = true}) {
    // Estimate breathing over the last 60 s so slow rhythms span enough cycles.
    final breathing = estimateBreathing([..._prevEnvelope, ..._envelope], frameRate);
    final input = EpochInput(
      movement: (_epochMovementS / epochSeconds).clamp(0.0, 1.0),
      snores: _epochSnores,
      breathing: breathing,
    );
    final result = _stager.classify(input);
    final epoch = Epoch(
      index: epochs.length,
      stage: result.stage,
      movement: input.movement,
      snores: input.snores,
      breathRate: breathing?.rateBpm,
      regularity: breathing?.regularity,
    );
    epochs.add(epoch);
    onEpoch?.call(epoch);

    _epochStart += epochSeconds;
    _prevEnvelope = _envelope;
    _envelope = [];
    _epochSnores = 0;
    _epochMovementS = 0;

    final a = alarm;
    if (a != null && checkAlarm) {
      final now = start.add(Duration(seconds: _epochStart.round()));
      final reason = a.update(now, result.stage);
      if (reason != null) onAlarm?.call(reason, now);
    }
  }

  /// Closes the unfinished last epoch when tracking stops, so its snores and
  /// stage are counted. Less than 10 s of sound is dropped as too little to judge.
  void finish() {
    if (_envelope.length >= frameRate * 10) _closeEpoch(checkAlarm: false);
  }

  Stage? get currentStage => epochs.isEmpty ? null : epochs.last.stage;
}
