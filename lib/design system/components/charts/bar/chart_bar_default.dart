import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/bar_base.dart';
import '../shared/chart_colors.dart';
import '../shared/bar_utils.dart';
import '../shared/bar_datasets.dart';

class ChartBarDefault extends StatelessWidget {
  const ChartBarDefault({super.key, this.colors, this.showContainer = true});
  final ChartColors? colors;
  final bool showContainer; // nuovo: consente di rimuovere bg/border

  @override
  Widget build(BuildContext context) {
    final c = colors ?? ChartColors.fallback(context);

    final groups = List<BarChartGroupData>.generate(barDataMonthly.length, (i) {
      final v = (barDataMonthly[i]['desktop'] as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v,
            width: 26, // barre più larghe per seguire lo style delle screenshot
            borderRadius: BorderRadius.circular(8),
            color: c.colorDesktop,
          ),
        ],
      );
    });

    return BarChartBase(
      colors: c,
      groups: groups,
      showHorizontalGrid: true,
      alignment: BarChartAlignment.spaceBetween,
      showContainer: showContainer,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= barDataMonthly.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                month3(barDataMonthly[i]['month'] as String),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
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
