import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/stager.dart';
import '../../services/tracking_controller.dart';
import '../app_scope.dart';
import '../theme.dart';
import 'report_screen.dart';

/// Shown all night: a dim clock, and the alarm controls when it rings.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final Timer _tick;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _clock(DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t));

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final scope = AppScope.of(context);
    final nav = Navigator.of(context);
    final night = await scope.tracking.finish();
    await scope.store.reload();
    if (night != null) {
      nav.push(MaterialPageRoute<void>(builder: (_) => ReportScreen(night: night)));
    }
  }

  Future<void> _confirmEnd() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End the night?'),
        content: const Text('Tracking will stop and the alarm will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep tracking')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End night')),
        ],
      ),
    );
    if (ok == true) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).tracking;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final ringing = c.state == TrackingState.ringing;
            final elapsed = c.startedAt == null ? Duration.zero : DateTime.now().difference(c.startedAt!);
            final dim = const TextStyle(color: AppColors.textMuted);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Text(_clock(DateTime.now()),
                      style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w200,
                          color: ringing ? AppColors.textPrimary : AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  if (c.wakeBy != null && c.windowMinutes != null)
                    Text(
                        'Alarm window ${_clock(c.wakeBy!.subtract(Duration(minutes: c.windowMinutes!)))}'
                        ' – ${_clock(c.wakeBy!)}',
                        style: dim)
                  else
                    Text('No alarm set', style: dim),
                  const SizedBox(height: 32),
                  if (ringing) ...[
                    Text(c.alarmReason ?? 'Good morning',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 18)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _finishing ? null : _finish,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text("I'm up — stop alarm", style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                        'Tracking for ${elapsed.inHours}h ${elapsed.inMinutes % 60}m · '
                        '${c.snoreCount} snores',
                        style: dim),
                    const SizedBox(height: 4),
                    Text('Now: ${c.currentStage?.label ?? 'listening…'} (estimate)', style: dim),
                  ],
                  const Spacer(),
                  if (!ringing)
                    TextButton(
                      onPressed: _finishing ? null : _confirmEnd,
                      child: const Text('End night'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
