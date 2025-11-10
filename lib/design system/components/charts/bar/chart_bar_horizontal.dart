import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/bar_base.dart';
import '../shared/chart_colors.dart';
import '../shared/bar_utils.dart';
import '../shared/bar_datasets.dart';

class ChartBarHorizontal extends StatelessWidget {
  const ChartBarHorizontal({super.key, this.colors});
  final ChartColors? colors;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? ChartColors.fallback(context);

    final groups = List<BarChartGroupData>.generate(barDataMonthly.length, (i) {
      final v = (barDataMonthly[i]['desktop'] as num).toDouble();
      return BarChartGroupData(
        x: i,
        groupVertically: true,
        barRods: [
          BarChartRodData(
            toY: v,
            width: 20,
            borderRadius: BorderRadius.circular(5),
            color: c.colorDesktop,
          ),
        ],
      );
    });

    return BarChartBase(
      colors: c,
      groups: groups,
      showHorizontalGrid: false,
      showVerticalGrid: true,
      alignment: BarChartAlignment.spaceBetween,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= barDataMonthly.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                month3(barDataMonthly[i]['month'] as String),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      ),
      bottomTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      tooltipPayloadBuilder: (context, group, groupIndex, rod, rodIndex, c) {
        final i = group.x.toInt();
        return BarTooltipPayload(
          title: month3(barDataMonthly[i]['month'] as String),
          items: [(c.colorDesktop, 'Desktop', rod.toY.toInt().toString())],
        );
      },
    );
  }
}
