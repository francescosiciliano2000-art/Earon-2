import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../shared/bar_base.dart';
import '../shared/chart_colors.dart';
import '../shared/bar_utils.dart';
import '../shared/bar_datasets.dart';

class ChartBarActive extends StatelessWidget {
  const ChartBarActive({super.key, this.colors, this.activeIndex = 2});
  final ChartColors? colors;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? ChartColors.fallback(context);

    Color pick(String key) => switch (key) {
          'chrome' => c.colorChrome,
          'safari' => c.colorSafari,
          'firefox' => c.colorFirefox,
          'edge' => c.colorEdge,
          _ => c.colorOther,
        };

    final groups =
        List<BarChartGroupData>.generate(barDataBrowsers.length, (i) {
      final v = (barDataBrowsers[i]['visitors'] as num).toDouble();
      final key = barDataBrowsers[i]['browser'] as String;
      final isActive = i == activeIndex;
      final base = pick(key);
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v,
            width: 20,
            borderRadius: BorderRadius.circular(8),
            color: base.withValues(alpha: isActive ? 0.8 : 1.0),
            borderSide:
                isActive ? BorderSide(color: base, width: 2) : BorderSide.none,
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
            if (i < 0 || i >= barDataBrowsers.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                browserLabel(barDataBrowsers[i]['browser'] as String),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      ),
      // Nessun tooltip custom in questa variante.
    );
  }
}
