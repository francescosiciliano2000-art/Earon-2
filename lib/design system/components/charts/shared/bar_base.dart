import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'chart_colors.dart';

class BarTooltipPayload {
  final String title; // es. "Apr 01"
  final List<(Color color, String label, String value)> items;
  const BarTooltipPayload({required this.title, required this.items});
}

// NOTA: niente BarTouchedSpot (che ha ctor diverso e non serve).
typedef TooltipPayloadBuilder = BarTooltipPayload Function(
  BuildContext context,
  BarChartGroupData group,
  int groupIndex,
  BarChartRodData rod,
  int rodIndex,
  ChartColors colors,
);

class BarChartBase extends StatelessWidget {
  const BarChartBase({
    super.key,
    required this.groups,
    this.colors,
    this.height = 250,
    this.showHorizontalGrid = true,
    this.showVerticalGrid = false,
    this.bottomTitles,
    this.leftTitles =
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    this.tooltipPayloadBuilder,
    this.alignment = BarChartAlignment.spaceBetween,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 12),
    this.showContainer = true, // nuovo: consente di rimuovere bg/border
  });

  final List<BarChartGroupData> groups;
  final ChartColors? colors;
  final double height;
  final bool showHorizontalGrid;
  final bool showVerticalGrid;
  final AxisTitles? bottomTitles;
  final AxisTitles leftTitles;
  final TooltipPayloadBuilder? tooltipPayloadBuilder;
  final BarChartAlignment alignment;
  final EdgeInsets padding;
  final bool showContainer;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? ChartColors.fallback(context);

    final chart = SizedBox(
      height: height,
      child: Padding(
        padding: padding,
        child: BarChart(
          BarChartData(
            alignment: alignment,
            barGroups: groups,
            gridData: FlGridData(
              drawVerticalLine: showVerticalGrid,
              drawHorizontalLine: showHorizontalGrid,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: c.grid, strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  FlLine(color: c.grid, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: leftTitles,
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: bottomTitles ??
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: tooltipPayloadBuilder != null,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tooltipMargin: 8,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  if (tooltipPayloadBuilder == null) {
                    return BarTooltipItem('', const TextStyle());
                  }
                  final payload = tooltipPayloadBuilder!(
                    context,
                    group,
                    groupIndex,
                    rod,
                    rodIndex,
                    c,
                  );

                  final base = DefaultTextStyle.of(context).style.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      );
                  final title = base.copyWith(fontWeight: FontWeight.w600);

                  final spans = <TextSpan>[
                    TextSpan(text: '${payload.title}\n', style: title),
                  ];

                  for (final (color, label, value) in payload.items) {
                    spans.add(TextSpan(
                        text: '■ ', style: base.copyWith(color: color)));
                    spans.add(TextSpan(text: '$label  ', style: base));
                    spans.add(TextSpan(
                      text: '$value\n',
                      style: base.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ));
                  }

                  return BarTooltipItem('', base, children: spans);
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (!showContainer) return chart;

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: chart,
    );
  }
}
