import 'dart:convert';

import '../core/night_record.dart';
import '../core/stager.dart';

/// Full data for all nights, for backup or analysis elsewhere.
String exportJson(List<NightRecord> nights) => const JsonEncoder.withIndent('  ')
    .convert({'nights': [for (final n in nights) n.toJson()]});

String _csvCell(Object? v) {
  final s = v?.toString() ?? '';
  return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _csv(List<List<Object?>> rows) =>
    rows.map((r) => r.map(_csvCell).join(',')).join('\n');

/// One row per night with the sleep-quality metrics.
String exportNightsCsv(List<NightRecord> nights) => _csv([
      [
        'date', 'start', 'end', 'score', 'time_in_bed_min', 'total_sleep_min',
        'latency_min', 'efficiency_pct', 'awakenings', 'waso_min',
        'wake_min', 'n1_min', 'n2_min', 'n3_min',
        'snores', 'snores_per_hour', 'snoring_pct', 'alarm_at', 'alarm_reason', 'tags',
      ],
      for (final n in nights)
        [
          n.start.toIso8601String().substring(0, 10),
          n.start.toIso8601String(),
          n.end.toIso8601String(),
          n.metrics.score,
          n.metrics.timeInBedMin.toStringAsFixed(1),
          n.metrics.totalSleepMin.toStringAsFixed(1),
          n.metrics.latencyMin?.toStringAsFixed(1),
          (n.metrics.efficiency * 100).toStringAsFixed(1),
          n.metrics.awakenings,
          n.metrics.wasoMin.toStringAsFixed(1),
          for (final s in Stage.values) n.metrics.stageMinutes[s]!.toStringAsFixed(1),
          n.metrics.snoreCount,
          n.metrics.snoresPerHour.toStringAsFixed(1),
          n.metrics.snoringPercent.toStringAsFixed(1),
          n.alarmAt?.toIso8601String(),
          n.alarmReason,
          (n.tags.toList()..sort()).join(';'),
        ],
    ]);

/// One row per 30 s epoch across all nights.
String exportEpochsCsv(List<NightRecord> nights) => _csv([
      ['night_id', 'time', 'stage', 'movement', 'snores', 'breath_rate_bpm', 'regularity'],
      for (final n in nights)
        for (final e in n.epochs)
          [
            n.id,
            n.start.add(Duration(seconds: e.index * epochSeconds)).toIso8601String(),
            e.stage.name,
            e.movement.toStringAsFixed(3),
            e.snores,
            e.breathRate?.toStringAsFixed(1),
            e.regularity?.toStringAsFixed(2),
          ],
    ]);
