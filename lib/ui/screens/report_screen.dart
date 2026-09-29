import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/advice.dart';
import '../../core/night_record.dart';
import '../../core/stager.dart';
import '../../core/trends.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// The morning report for one night.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.night});

  final NightRecord night;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late NightRecord _night = widget.night;
  AudioPlayer? _player; // created on first play
  String? _playing;
  StreamSubscription<void>? _completeSub;

  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;
    final p = _player = AudioPlayer();
    _completeSub = p.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    return p;
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String _clock(DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t));

  Future<void> _toggleClip(SnoreClip clip) async {
    if (_playing == clip.file) {
      await _audio.stop();
      setState(() => _playing = null);
      return;
    }
    final dir = AppScope.of(context).store.repository.clipsDir.path;
    await _audio.play(DeviceFileSource('$dir/${clip.file}'));
    setState(() => _playing = clip.file);
  }

  Future<void> _toggleTag(String tag) async {
    final tags = {..._night.tags};
    if (!tags.remove(tag)) tags.add(tag);
    final updated = _night.copyWith(tags: tags);
    setState(() => _night = updated);
    await AppScope.of(context).store.save(updated);
  }

  Future<void> _addCustomTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'e.g. New pillow'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    final t = tag?.trim();
    if (t != null && t.isNotEmpty && !_night.tags.contains(t)) await _toggleTag(t);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this night?'),
        content: const Text('Its data and snore clips will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    await AppScope.of(context).store.delete(_night);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final n = _night;
    final m = n.metrics;
    final summary = summarize(n, history: store.historyBefore(n));
    final allTags = {...defaultTags, for (final other in store.nights) ...other.tags, ...n.tags};
    final date = MaterialLocalizations.of(context).formatMediumDate(n.start);

    return Scaffold(
      appBar: AppBar(
        title: Text(date),
        actions: [IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Delete night')],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(summary.headline, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${_clock(n.start)} – ${_clock(n.end)}',
              style: const TextStyle(color: AppColors.textSecondary)),
          if (n.alarmAt != null) ...[
            const SizedBox(height: 4),
            Text('Alarm ${_clock(n.alarmAt!)}: ${n.alarmReason ?? ''}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
          const SectionTitle('Sleep stages (estimated)'),
          Hypnogram(night: n),
          const SizedBox(height: 16),
          StatGrid(children: [
            StatTile(label: 'Sleep score', value: '${m.score}', detail: 'out of 100'),
            StatTile(label: 'Asleep', value: formatMinutes(m.totalSleepMin),
                detail: 'of ${formatMinutes(m.timeInBedMin)} in bed'),
            StatTile(label: 'Fell asleep in',
                value: m.latencyMin == null ? '–' : formatMinutes(m.latencyMin!)),
            StatTile(label: 'Efficiency', value: '${(m.efficiency * 100).round()}%'),
            StatTile(label: 'Awakenings', value: '${m.awakenings}',
                detail: '${formatMinutes(m.wasoMin)} awake'),
            StatTile(label: 'Deep sleep', value: '${m.stagePercent(Stage.n3).round()}%',
                detail: formatMinutes(m.stageMinutes[Stage.n3]!)),
            StatTile(label: 'Light sleep', value: '${m.stagePercent(Stage.n1).round()}%',
                detail: formatMinutes(m.stageMinutes[Stage.n1]!)),
            StatTile(label: 'Snoring', value: '${m.snoresPerHour.round()}/h',
                detail: '${m.snoreCount} snores'),
          ]),
          const SectionTitle('Snoring'),
          if (n.snoreOffsetsS.isEmpty)
            const Text('No snoring detected.', style: TextStyle(color: AppColors.textSecondary))
          else
            SnoreTimeline(night: n),
          if (n.clips.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final clip in n.clips)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_playing == clip.file ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                title: Text('Snore at ${_clock(n.start.add(Duration(seconds: clip.offsetS.round())))}'),
                onTap: () => _toggleClip(clip),
              ),
          ],
          const SectionTitle('Suggestions'),
          for (final tip in summary.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $tip', style: const TextStyle(height: 1.4)),
            ),
          const SectionTitle('Tags'),
          const Text('Tag what happened yesterday to see what affects your sleep.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tag in allTags)
              FilterChip(
                label: Text(tag),
                selected: n.tags.contains(tag),
                onSelected: (_) => _toggleTag(tag),
              ),
            ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Custom'), onPressed: _addCustomTag),
          ]),
          const SizedBox(height: 32),
          const Text(wellnessDisclaimer, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
