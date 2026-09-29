import 'package:flutter/material.dart';

import '../../core/advice.dart';
import '../app_scope.dart';
import '../theme.dart';
import 'report_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final loc = MaterialLocalizations.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.nights.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No nights yet. Start tracking tonight and your report will appear here.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('History', style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: 8),
            for (final n in store.nights)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceRaised,
                  child: Text('${n.metrics.score}', style: const TextStyle(color: AppColors.textPrimary)),
                ),
                title: Text(loc.formatMediumDate(n.start)),
                subtitle: Text(
                  '${formatMinutes(n.metrics.totalSleepMin)} asleep · '
                  '${n.metrics.snoreCount} snores'
                  '${n.tags.isEmpty ? '' : ' · ${n.tags.join(', ')}'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ReportScreen(night: n))),
              ),
          ],
        );
      },
    );
  }
}
