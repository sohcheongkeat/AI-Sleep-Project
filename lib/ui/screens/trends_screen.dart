import 'package:flutter/material.dart';

import '../../core/advice.dart';
import '../../core/trends.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  String _signed(double v, String unit) => '${v >= 0 ? '+' : '−'}${v.abs().round()}$unit';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final nights = store.nights;
        if (nights.length < 2) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Trends appear after two tracked nights.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        final week = TrendSummary.of(nights.take(7))!;
        final month = TrendSummary.of(nights.take(30))!;
        final effects = tagEffects(nights.take(90).toList());

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Trends', style: Theme.of(context).textTheme.headlineMedium),
            SectionTitle('Sleep score, last ${nights.take(30).length} nights'),
            ScoreTrend(nights: nights.take(30).toList()),
            SectionTitle('Last ${week.nights} nights (average)'),
            StatGrid(children: [
              StatTile(label: 'Sleep score', value: '${week.avgScore.round()}',
                  detail: '30-night avg ${month.avgScore.round()}'),
              StatTile(label: 'Asleep', value: formatMinutes(week.avgSleepMin),
                  detail: '30-night avg ${formatMinutes(month.avgSleepMin)}'),
              StatTile(label: 'Fell asleep in', value: formatMinutes(week.avgLatencyMin),
                  detail: '30-night avg ${formatMinutes(month.avgLatencyMin)}'),
              StatTile(label: 'Snoring', value: '${week.avgSnoresPerHour.round()}/h',
                  detail: '30-night avg ${month.avgSnoresPerHour.round()}/h'),
            ]),
            const SectionTitle('What affects your sleep'),
            if (effects.isEmpty)
              const Text(
                'Tag your nights in the morning report. Once a tag has been used on at '
                'least 2 nights (and not used on 2 others), its effect shows here.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              for (final e in effects)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.tag),
                    subtitle: Text(
                      'Score ${_signed(e.scoreDelta, '')} · '
                      'Sleep ${_signed(e.sleepDeltaMin, ' min')} · '
                      'Snoring ${_signed(e.snoreDelta, '/h')}\n'
                      '${e.withTag.nights} nights with, ${e.withoutTag.nights} without',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    isThreeLine: true,
                  ),
                ),
            const SizedBox(height: 8),
            const Text('Comparisons show patterns, not proof of cause.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        );
      },
    );
  }
}
