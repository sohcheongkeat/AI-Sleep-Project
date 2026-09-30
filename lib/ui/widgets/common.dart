import 'package:flutter/material.dart';

import '../theme.dart';

/// A single headline number with a label, e.g. "7h 32m / Asleep".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            if (detail != null)
              Text(detail!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Lays out stat tiles two per row.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

const wellnessDisclaimer =
    'Sleep Coach estimates sleep stages from sound. It is not a medical device and '
    'does not diagnose or treat any condition. If you are worried about your '
    'sleep or snoring, talk to a doctor.';
