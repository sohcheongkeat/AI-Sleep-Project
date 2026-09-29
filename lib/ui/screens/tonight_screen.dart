import 'package:flutter/material.dart';

import '../../core/smart_alarm.dart';
import '../../services/overnight_service.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Set the alarm and start tracking.
class TonightScreen extends StatefulWidget {
  const TonightScreen({super.key});

  @override
  State<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends State<TonightScreen> {
  bool _starting = false;

  String _fmt(TimeOfDay t) => MaterialLocalizations.of(context).formatTimeOfDay(t);

  TimeOfDay _minus(TimeOfDay t, int minutes) {
    final total = (t.hour * 60 + t.minute - minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  Future<bool> _ensureDisclaimer() async {
    final settings = AppScope.of(context).settings;
    if (settings.acceptedDisclaimer) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Before you start'),
        content: const Text('$wellnessDisclaimer\n\n'
            'Sound is analysed on your phone. Only short snore clips are kept, '
            'and only on this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I understand')),
        ],
      ),
    );
    if (ok != true) return false;
    await settings.update((s) => s.acceptedDisclaimer = true);
    return true;
  }

  Future<void> _start() async {
    if (!await _ensureDisclaimer() || !mounted) return;
    final scope = AppScope.of(context);
    final s = scope.settings;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    try {
      await OvernightService.requestPermissions();
      final result = await scope.tracking.start(
        wakeBy: s.alarmEnabled ? s.nextWakeTime(DateTime.now()) : null,
        windowMinutes: s.windowMinutes,
        saveClips: s.saveClips,
      );
      if (!result.ok) messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tonight', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              SwitchListTile(
                title: const Text('Smart alarm'),
                subtitle: const Text('Wake me in light sleep'),
                value: s.alarmEnabled,
                onChanged: (v) => s.update((s) => s.alarmEnabled = v),
              ),
              if (s.alarmEnabled) ...[
                ListTile(
                  title: const Text('Wake me up by'),
                  trailing: Text(_fmt(s.wakeTime),
                      style: Theme.of(context).textTheme.headlineSmall),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: s.wakeTime);
                    if (t != null) await s.update((s) => s.wakeTime = t);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Text('Wake-up window'),
                    const Spacer(),
                    Text('${s.windowMinutes} min'),
                  ]),
                ),
                Slider(
                  value: s.windowMinutes.toDouble(),
                  min: minWindowMinutes.toDouble(),
                  max: maxWindowMinutes.toDouble(),
                  divisions: (maxWindowMinutes - minWindowMinutes) ~/ 5,
                  label: '${s.windowMinutes} min',
                  onChanged: (v) => s.update((s) => s.windowMinutes = v.round()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Rings at the first light sleep between '
                    '${_fmt(_minus(s.wakeTime, s.windowMinutes))} and ${_fmt(s.wakeTime)}, '
                    'and at ${_fmt(s.wakeTime)} at the latest.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('For best results'),
                SizedBox(height: 8),
                Text(
                  '• Put the phone on your bedside table, within about 1\u00A0m of your head.\n'
                  '• Keep it plugged in to charge.\n'
                  '• Turn the volume up so you can hear the alarm.\n'
                  '• If someone sleeps next to you, their sounds may be counted too.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: const Icon(Icons.bedtime),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_starting ? 'Starting…' : 'Start sleep tracking'),
            ),
          ),
        ],
      ),
    );
  }
}
