import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/night_record.dart';
import '../../core/stager.dart';
import '../theme.dart';

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _axisStyle = TextStyle(color: AppColors.textMuted, fontSize: 11);

FlGridData _grid({double? horizontalInterval}) => FlGridData(
      drawVerticalLine: false,
      horizontalInterval: horizontalInterval,
      getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.grid, strokeWidth: 1),
    );

/// Stage over the night as a step line: Awake at the top, deep sleep at the
/// bottom (the usual hypnogram orientation).
class Hypnogram extends StatelessWidget {
  const Hypnogram({super.key, required this.night});

  final NightRecord night;

  static double _y(Stage s) => switch (s) {
        Stage.wake => 3,
        Stage.n1 => 2,
        Stage.n2 => 1,
        Stage.n3 => 0,
      };

  static const _labels = ['Deep', 'Sleep', 'Light', 'Awake'];
  static String _label(double y) => y >= 0 && y <= 3 && y == y.roundToDouble() ? _labels[y.round()] : '';

  @override
  Widget build(BuildContext context) {
    final epochs = night.epochs;
    if (epochs.isEmpty) return const SizedBox.shrink();
    final hours = epochs.length * epochSeconds / 3600;
    final spots = [
      for (final e in epochs) FlSpot(e.index * epochSeconds / 3600, _y(e.stage)),
      FlSpot(hours, _y(epochs.last.stage)),
    ];
    final alarmX = night.alarmAt == null
        ? null
        : night.alarmAt!.difference(night.start).inSeconds / 3600;
    final windowStartX = night.wakeBy == null || night.windowMinutes == null
        ? null
        : night.wakeBy!
                .subtract(Duration(minutes: night.windowMinutes!))
                .difference(night.start)
                .inSeconds /
            3600;

    return Semantics(
      label: 'Sleep stages over the night',
      child: SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          minX: 0,
          maxX: hours,
          minY: -0.2,
          maxY: 3.2,
          gridData: _grid(horizontalInterval: 1),
          borderData: FlBorderData(show: false),
          rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: [
            if (windowStartX != null && windowStartX < hours)
              VerticalRangeAnnotation(
                x1: math.max(0, windowStartX),
                x2: hours,
                color: AppColors.series.withValues(alpha: 0.12),
              ),
          ]),
          extraLinesData: ExtraLinesData(verticalLines: [
            if (alarmX != null && alarmX <= hours)
              VerticalLine(
                x: alarmX,
                color: AppColors.textSecondary,
                strokeWidth: 1,
                dashArray: [4, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  style: _axisStyle,
                  labelResolver: (_) => 'Alarm',
                ),
              ),
          ]),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: 1,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_label(v), style: _axisStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: hours > 6 ? 2 : 1,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                      _clock(night.start.add(Duration(seconds: (v * 3600).round()))),
                      style: _axisStyle),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${_clock(night.start.add(Duration(seconds: (s.x * 3600).round())))}\n'
                    '${_label(s.y)}',
                    const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isStepLineChart: true,
              lineChartStepData:
                  const LineChartStepData(stepDirection: LineChartStepData.stepDirectionForward),
              color: AppColors.series,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        )),
      ),
    );
  }
}

/// Snores per 15-minute block.
class SnoreTimeline extends StatelessWidget {
  const SnoreTimeline({super.key, required this.night});

  final NightRecord night;
  static const _blockMin = 15;

  @override
  Widget build(BuildContext context) {
    final totalMin = night.epochs.length * epochSeconds / 60;
    final blocks = List.filled(math.max(1, (totalMin / _blockMin).ceil()), 0);
    for (final s in night.snoreOffsetsS) {
      final i = (s / 60 / _blockMin).floor();
      if (i < blocks.length) blocks[i]++;
    }
    final maxY = math.max(5, blocks.reduce(math.max)).toDouble();
    String blockLabel(int i) =>
        _clock(night.start.add(Duration(minutes: i * _blockMin)));

    return Semantics(
      label: 'Snores per 15 minutes',
      child: SizedBox(
        height: 140,
        child: BarChart(BarChartData(
          maxY: maxY * 1.1,
          gridData: _grid(),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${blockLabel(group.x)}\n${rod.toY.round()} snores',
                const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : SideTitleWidget(meta: meta, child: Text('${v.round()}', style: _axisStyle)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  // Label every 2 hours.
                  if (i % (120 ~/ _blockMin) != 0) return const SizedBox.shrink();
                  return SideTitleWidget(meta: meta, child: Text(blockLabel(i), style: _axisStyle));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < blocks.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: blocks[i].toDouble(),
                  color: AppColors.series,
                  width: math.max(2, 240 / blocks.length),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        )),
      ),
    );
  }
}

/// Sleep score per night, oldest to newest.
class ScoreTrend extends StatelessWidget {
  const ScoreTrend({super.key, required this.nights});

  /// Newest first, as stored.
  final List<NightRecord> nights;

  @override
  Widget build(BuildContext context) {
    final ordered = nights.reversed.toList();
    String date(NightRecord n) => '${n.start.day}/${n.start.month}';
    return Semantics(
      label: 'Sleep score by night',
      child: SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: math.max(1, ordered.length - 1).toDouble(),
          gridData: _grid(horizontalInterval: 25),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, meta) =>
                    SideTitleWidget(meta: meta, child: Text('${v.round()}', style: _axisStyle)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: math.max(1, (ordered.length / 5).ceil()).toDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= ordered.length) return const SizedBox.shrink();
                  return SideTitleWidget(meta: meta, child: Text(date(ordered[i]), style: _axisStyle));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceRaised,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${date(ordered[s.x.round()])}\nScore ${s.y.round()}',
                    const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < ordered.length; i++)
                  FlSpot(i.toDouble(), ordered[i].metrics.score.toDouble()),
              ],
              color: AppColors.series,
              barWidth: 2,
              dotData: FlDotData(
                show: ordered.length <= 14,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.series,
                  strokeWidth: 2,
                  strokeColor: AppColors.surface,
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }
}
