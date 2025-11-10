import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/bar_base.dart';
import '../shared/chart_colors.dart';
import '../shared/bar_utils.dart';
import '../shared/bar_datasets.dart';

class ChartBarInteractive extends StatefulWidget {
  const ChartBarInteractive({super.key, this.colors});
  final ChartColors? colors;

  @override
  State<ChartBarInteractive> createState() => _ChartBarInteractiveState();
}

class _ChartBarInteractiveState extends State<ChartBarInteractive> {
  String active = 'desktop';

  @override
  Widget build(BuildContext context) {
    final c = widget.colors ?? ChartColors.fallback(context);

    int sum(String key) =>
        barDataDaily.fold(0, (acc, e) => acc + (e[key] as int));
    final totalDesktop = sum('desktop');
    final totalMobile = sum('mobile');

    Widget totalBtn(String key, String label, int total) {
      final isActive = active == key;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => active = key),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
                left: key == 'mobile'
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant)
                    : BorderSide.none,
              ),
              color: isActive
                  ? Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color!
                          .withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedColor = active == 'desktop' ? c.colorDesktop : c.colorMobile;

    final groups = List<BarChartGroupData>.generate(barDataDaily.length, (i) {
      final v = (barDataDaily[i][active] as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v,
            width: 14,
            borderRadius: BorderRadius.circular(8),
            color: selectedColor,
          ),
        ],
      );
    });

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bar Chart - Interactive',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Showing total visitors for the last 3 months',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color!
                              .withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 480,
              child: Row(
                children: [
                  totalBtn('desktop', 'Desktop', totalDesktop),
                  totalBtn('mobile', 'Mobile', totalMobile),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BarChartBase(
          colors: c,
          groups: groups,
          showHorizontalGrid: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 3,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= barDataDaily.length) {
                  return const SizedBox.shrink();
                }
                final d = DateTime.parse(barDataDaily[i]['date'] as String);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmtDateLabel(d),
                      style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ),
          ),
          tooltipPayloadBuilder:
              (context, group, groupIndex, rod, rodIndex, c) {
            final i = group.x.toInt();
            final d = DateTime.parse(barDataDaily[i]['date'] as String);
            final shown = active == 'desktop'
                ? rod.toY.toInt()
                : (barDataDaily[i]['desktop']
                    as int); // come negli esempi React
            return BarTooltipPayload(
              title: fmtDateFull(d),
              items: [(c.colorDesktop, 'Page Views', '$shown')],
            );
          },
        ),
      ],
    );
  }
}
