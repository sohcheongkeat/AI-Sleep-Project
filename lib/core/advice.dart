import 'metrics.dart';
import 'night_record.dart';
import 'stager.dart';
import 'trends.dart';

/// Rule-based, on-device summary and suggestions. Wellness guidance only —
/// no diagnosis.
class NightSummary {
  const NightSummary({required this.headline, required this.tips});

  final String headline;
  final List<String> tips;
}

String formatMinutes(double min) {
  final h = min ~/ 60;
  final m = (min % 60).round();
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
}

NightSummary summarize(NightRecord night, {List<NightRecord> history = const []}) {
  final m = night.metrics;
  if (m.latencyMin == null) {
    return const NightSummary(
      headline: 'Not enough sleep was detected to analyse this night.',
      tips: [
        'Place the phone on your bedside table within about 1 m of your head, '
            'microphone facing you.',
      ],
    );
  }

  final quality = switch (m.score) {
    >= 85 => 'Great night',
    >= 70 => 'Good night',
    >= 50 => 'Fair night',
    _ => 'Rough night',
  };
  final headline = '$quality: ${formatMinutes(m.totalSleepMin)} of sleep, '
      'score ${m.score}/100.';

  final tips = <String>[];
  if (m.totalSleepMin < 7 * 60) {
    tips.add('You slept under 7 hours. Most adults need 7–9 hours; try moving '
        'bedtime earlier by 15–30 minutes.');
  }
  if (m.latencyMin! > 30) {
    tips.add('It took ${formatMinutes(m.latencyMin!)} to fall asleep. A '
        'consistent wind-down routine and dim light in the last hour can help.');
  }
  if (m.efficiency < 0.85 && m.awakenings >= 3) {
    tips.add('You woke ${m.awakenings} times. Keep the room cool, dark and '
        'quiet, and limit fluids and alcohol in the evening.');
  }
  if (m.snoresPerHour >= 30) {
    tips.add('Snoring was frequent (${m.snoresPerHour.round()} per hour). '
        'Sleeping on your side, avoiding alcohol before bed and treating a '
        'blocked nose often reduce snoring.');
  }
  if (m.stagePercent(Stage.n3) < 5 && m.totalSleepMin > 240) {
    tips.add('Little deep sleep was detected. Regular exercise earlier in the '
        'day and a consistent schedule tend to support deeper sleep.');
  }

  // Pattern across history: persistently heavy snoring.
  final recent = [...history.take(14), night];
  final heavy = recent.where((n) => n.metrics.snoresPerHour >= 60).length;
  if (recent.length >= 7 && heavy >= recent.length * 0.7) {
    tips.add('Loud, frequent snoring on most nights can be worth discussing '
        'with a doctor, especially if you feel tired during the day.');
  }

  for (final e in tagEffects([...history, night]).take(2)) {
    if (e.scoreDelta <= -8) {
      tips.add('On "${e.tag}" nights your score averages '
          '${e.scoreDelta.abs().round()} points lower.');
    } else if (e.snoreDelta >= 15) {
      tips.add('On "${e.tag}" nights you snore about '
          '${e.snoreDelta.round()} more times per hour.');
    } else if (e.scoreDelta >= 8) {
      tips.add('On "${e.tag}" nights your score averages '
          '${e.scoreDelta.round()} points higher — keep it up.');
    }
  }

  if (tips.isEmpty) tips.add('Nothing stood out. Keep your routine consistent.');
  return NightSummary(headline: headline, tips: tips);
}

/// Short text description of the metrics, used in exports and the report.
String describeMetrics(NightMetrics m) => [
      'Score ${m.score}',
      'Asleep ${formatMinutes(m.totalSleepMin)}',
      if (m.latencyMin != null) 'Fell asleep in ${formatMinutes(m.latencyMin!)}',
      'Efficiency ${(m.efficiency * 100).round()}%',
      'Snores ${m.snoreCount} (${m.snoresPerHour.round()}/h)',
    ].join(' · ');
