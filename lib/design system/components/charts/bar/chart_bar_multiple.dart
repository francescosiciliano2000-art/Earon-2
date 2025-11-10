import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/bar_base.dart';
import '../shared/chart_colors.dart';
import '../shared/bar_utils.dart';
import '../shared/bar_datasets.dart';

class ChartBarMultiple extends StatelessWidget {
  const ChartBarMultiple({super.key, this.colors});
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
        barsSpace: 6,
        barRods: [
          BarChartRodData(
            toY: d,
            width: 18,
            borderRadius: BorderRadius.circular(4),
            color: c.colorDesktop,
          ),
          BarChartRodData(
            toY: m,
            width: 18,
            borderRadius: BorderRadius.circular(4),
            color: c.colorMobile,
          ),
        ],
      );
    });

    return BarChartBase(
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
      tooltipPayloadBuilder: (context, group, groupIndex, rod, rodIndex, c) {
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
    );
  }
}
