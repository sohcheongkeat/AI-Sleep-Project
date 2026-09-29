import 'metrics.dart';
import 'session.dart';
import 'stager.dart';

/// A saved snore clip, [offsetS] seconds after the night started.
class SnoreClip {
  const SnoreClip({required this.file, required this.offsetS});

  final String file;
  final double offsetS;

  Map<String, Object?> toJson() => {'file': file, 't': offsetS};

  factory SnoreClip.fromJson(Map<String, Object?> j) =>
      SnoreClip(file: j['file']! as String, offsetS: (j['t']! as num).toDouble());
}

/// Everything stored about one tracked night.
class NightRecord {
  NightRecord({
    required this.id,
    required this.start,
    required this.end,
    required this.epochs,
    required this.snoreOffsetsS,
    this.wakeBy,
    this.windowMinutes,
    this.alarmAt,
    this.alarmReason,
    List<SnoreClip>? clips,
    Set<String>? tags,
  })  : clips = clips ?? [],
        tags = tags ?? {};

  final String id;
  final DateTime start;
  final DateTime end;
  final List<Epoch> epochs;
  final List<double> snoreOffsetsS;
  final DateTime? wakeBy;
  final int? windowMinutes;
  final DateTime? alarmAt;
  final String? alarmReason;
  final List<SnoreClip> clips;
  final Set<String> tags;

  List<Stage> get stages => [for (final e in epochs) e.stage];

  late final NightMetrics metrics =
      NightMetrics.compute(stages, [for (final e in epochs) e.snores]);

  NightRecord copyWith({Set<String>? tags, List<SnoreClip>? clips}) => NightRecord(
        id: id,
        start: start,
        end: end,
        epochs: epochs,
        snoreOffsetsS: snoreOffsetsS,
        wakeBy: wakeBy,
        windowMinutes: windowMinutes,
        alarmAt: alarmAt,
        alarmReason: alarmReason,
        clips: clips ?? this.clips,
        tags: tags ?? this.tags,
      );

  Map<String, Object?> toJson() => {
        'version': 1,
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'wakeBy': wakeBy?.toIso8601String(),
        'windowMinutes': windowMinutes,
        'alarmAt': alarmAt?.toIso8601String(),
        'alarmReason': alarmReason,
        'epochs': [for (final e in epochs) e.toJson()],
        'snores': [for (final s in snoreOffsetsS) double.parse(s.toStringAsFixed(1))],
        'clips': [for (final c in clips) c.toJson()],
        'tags': tags.toList()..sort(),
      };

  factory NightRecord.fromJson(Map<String, Object?> j) {
    DateTime? date(String k) => j[k] == null ? null : DateTime.parse(j[k]! as String);
    final epochs = j['epochs']! as List;
    return NightRecord(
      id: j['id']! as String,
      start: date('start')!,
      end: date('end')!,
      wakeBy: date('wakeBy'),
      windowMinutes: j['windowMinutes'] as int?,
      alarmAt: date('alarmAt'),
      alarmReason: j['alarmReason'] as String?,
      epochs: [
        for (var i = 0; i < epochs.length; i++)
          Epoch.fromJson(i, (epochs[i] as Map).cast<String, Object?>()),
      ],
      snoreOffsetsS: [for (final s in j['snores']! as List) (s as num).toDouble()],
      clips: [
        for (final c in (j['clips'] as List? ?? const []))
          SnoreClip.fromJson((c as Map).cast<String, Object?>()),
      ],
      tags: {for (final t in (j['tags'] as List? ?? const [])) t as String},
    );
  }
}
