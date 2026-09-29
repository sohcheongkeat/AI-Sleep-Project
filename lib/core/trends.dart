import 'night_record.dart';

/// Tags users can attach to a night to see what affects their sleep.
const defaultTags = [
  'Alcohol',
  'Caffeine late',
  'Late meal',
  'Exercise',
  'Stress',
  'Screen before bed',
  'Blocked nose',
  'Nap',
];

/// Averages over a set of nights.
class TrendSummary {
  const TrendSummary({
    required this.nights,
    required this.avgScore,
    required this.avgSleepMin,
    required this.avgLatencyMin,
    required this.avgSnoresPerHour,
    required this.avgEfficiency,
  });

  final int nights;
  final double avgScore;
  final double avgSleepMin;
  final double avgLatencyMin;
  final double avgSnoresPerHour;
  final double avgEfficiency;

  static TrendSummary? of(Iterable<NightRecord> nights) {
    final list = nights.toList();
    if (list.isEmpty) return null;
    double avg(double Function(NightRecord) f) =>
        list.fold<double>(0, (a, n) => a + f(n)) / list.length;
    return TrendSummary(
      nights: list.length,
      avgScore: avg((n) => n.metrics.score.toDouble()),
      avgSleepMin: avg((n) => n.metrics.totalSleepMin),
      avgLatencyMin: avg((n) => n.metrics.latencyMin ?? 0),
      avgSnoresPerHour: avg((n) => n.metrics.snoresPerHour),
      avgEfficiency: avg((n) => n.metrics.efficiency),
    );
  }
}

/// How nights with a tag compare with nights without it.
class TagEffect {
  const TagEffect({
    required this.tag,
    required this.withTag,
    required this.withoutTag,
  });

  final String tag;
  final TrendSummary withTag;
  final TrendSummary withoutTag;

  double get scoreDelta => withTag.avgScore - withoutTag.avgScore;
  double get snoreDelta => withTag.avgSnoresPerHour - withoutTag.avgSnoresPerHour;
  double get sleepDeltaMin => withTag.avgSleepMin - withoutTag.avgSleepMin;
}

/// Tag comparisons, needing at least [minNights] on each side to be shown.
List<TagEffect> tagEffects(List<NightRecord> nights, {int minNights = 2}) {
  final tags = {for (final n in nights) ...n.tags};
  final effects = <TagEffect>[];
  for (final tag in tags) {
    final withTag = nights.where((n) => n.tags.contains(tag)).toList();
    final without = nights.where((n) => !n.tags.contains(tag)).toList();
    if (withTag.length < minNights || without.length < minNights) continue;
    effects.add(TagEffect(
      tag: tag,
      withTag: TrendSummary.of(withTag)!,
      withoutTag: TrendSummary.of(without)!,
    ));
  }
  effects.sort((a, b) => a.scoreDelta.abs().compareTo(b.scoreDelta.abs()) * -1);
  return effects;
}
