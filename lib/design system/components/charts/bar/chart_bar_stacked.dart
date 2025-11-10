import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/bar_base.dart';
import '../shared/chart_colors.dart';
import '../shared/bar_utils.dart';
import '../shared/bar_datasets.dart';

class ChartBarStacked extends StatelessWidget {
  const ChartBarStacked({super.key, this.colors});
  final ChartColors? colors;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? ChartColors.fallback(context);

    final groups =
        List<BarChartGroupData>.generate(barDataMonthlyMulti.length, (i) {
      final d = (barDataMonthlyMulti[i]['desktop'] as num).toDouble();
      final m = (barDataMonthlyMulti[i]['mobile'] as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: d + m,
            width: 22,
            borderRadius: BorderRadius.zero,
            rodStackItems: [
              // In fl_chart 0.68.x questi item NON supportano borderRadius.
              BarChartRodStackItem(0, d, c.colorDesktop),
              BarChartRodStackItem(d, d + m, c.colorMobile),
            ],
          ),
        ],
      );
    });

    Widget legendDot(Color col, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: col, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(label),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 16,
            children: [
              legendDot(c.colorDesktop, 'Desktop'),
              legendDot(c.colorMobile, 'Mobile'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BarChartBase(
          colors: c,
          groups: groups,
          showHorizontalGrid: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= barDataMonthlyMulti.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    month3(barDataMonthlyMulti[i]['month'] as String),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          tooltipPayloadBuilder:
              (context, group, groupIndex, rod, rodIndex, c) {
            final i = group.x.toInt();
            final d = (barDataMonthlyMulti[i]['desktop'] as int);
            final m = (barDataMonthlyMulti[i]['mobile'] as int);
            return BarTooltipPayload(
              title: month3(barDataMonthlyMulti[i]['month'] as String),
              items: [
                (c.colorDesktop, 'Desktop', d.toString()),
                (c.colorMobile, 'Mobile', m.toString()),
              ],
            );
          },
        ),
      ],
    );
  }
}
