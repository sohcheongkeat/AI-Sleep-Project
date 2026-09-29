import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/export.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _retentionOptions = [7, 14, 30, 90];

  Future<void> _export(BuildContext context, String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: name));
  }

  Future<void> _deleteAll(BuildContext context) async {
    final store = AppScope.of(context).store;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('Every night, report and snore clip will be permanently removed '
            'from this phone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete everything')),
        ],
      ),
    );
    if (ok == true) await store.deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.settings;
    final store = scope.store;
    return ListenableBuilder(
      listenable: Listenable.merge([s, store]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const _Header('Snore recordings'),
          SwitchListTile(
            title: const Text('Save snore clips'),
            subtitle: const Text('Up to 30 short clips per night, kept only on this phone'),
            value: s.saveClips,
            onChanged: (v) => s.update((s) => s.saveClips = v),
          ),
          ListTile(
            title: const Text('Delete clips after'),
            trailing: DropdownButton<int>(
              value: _retentionOptions.contains(s.clipRetentionDays) ? s.clipRetentionDays : 30,
              items: [
                for (final d in _retentionOptions) DropdownMenuItem(value: d, child: Text('$d days')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await s.update((s) => s.clipRetentionDays = v);
                await store.repository.pruneClips(days: v);
                await store.reload();
              },
            ),
          ),
          const _Header('Your data'),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export nightly summary (CSV)'),
            enabled: store.nights.isNotEmpty,
            onTap: () => _export(context, 'ai_sleep_nights.csv', exportNightsCsv(store.nights)),
          ),
          ListTile(
            leading: const Icon(Icons.grid_on),
            title: const Text('Export 30-second detail (CSV)'),
            enabled: store.nights.isNotEmpty,
            onTap: () => _export(context, 'ai_sleep_epochs.csv', exportEpochsCsv(store.nights)),
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Export everything (JSON)'),
            enabled: store.nights.isNotEmpty,
            onTap: () => _export(context, 'ai_sleep_export.json', exportJson(store.nights)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Delete all data'),
            onTap: () => _deleteAll(context),
          ),
          if (Platform.isAndroid) ...[
            const _Header('Reliability'),
            ListTile(
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('Allow running overnight'),
              subtitle: const Text('Stops battery saving from pausing tracking'),
              onTap: FlutterForegroundTask.requestIgnoreBatteryOptimization,
            ),
          ],
          const _Header('About'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$wellnessDisclaimer\n\n'
              'Privacy: sound is analysed on your phone as it is recorded and is not '
              'stored, except short snore clips if you turn them on. Nothing is sent '
              'to any server. Exports go only where you choose to share them.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      );
}
