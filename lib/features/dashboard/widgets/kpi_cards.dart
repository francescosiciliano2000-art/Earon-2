import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../design system/components/charts/shared/bar_base.dart';
import '../../../design system/components/charts/shared/chart_colors.dart';
import '../../../design system/components/card.dart';
import '../../../design system/icons/app_icons.dart';

class KpiCards extends StatelessWidget {
  const KpiCards({
    super.key,
    required this.kpis,
    required this.isWide,
    this.receivablesMonthly = const [],
  });

  final Map<String, num> kpis;
  final bool isWide;
  final List<Map<String, dynamic>> receivablesMonthly;

  // 3‑letter month from ISO yyyy-MM-dd
  String _m3(String iso) {
    final parts = iso.split('-');
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[(m - 1).clamp(0, 11)];
  }

  String _fmtCurrency(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i - 1;
      b.write(s[idx]);
      if (i % 3 == 2 && idx != 0) b.write('.');
    }
    return '€ ${b.toString().split('').reversed.join()}';
  }

  double? _deltaPercent(num current, num? prev) {
    if (prev == null || prev == 0) return null;
    final d = ((current - prev) / prev) * 100.0;
    return d.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.fallback(context);
    // Garantisce visibilità e previene errori di layout
    final childAspectRatio = isWide ? 2.6 : 1.8;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      children: [
        // Fatture emesse (mese)
        AppCard(
          padding: const EdgeInsets.all(16),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Row(
                children: [
                  const Icon(AppIcons.invoice, size: 20),
                  const SizedBox(width: 8),
                  Text('Fatture emesse (mese)', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 12),
              // Corpo 30% / 70% (senza Expanded per evitare vincoli non limitati)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Sinistra 30%
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _fmtCurrency(kpis['invoices_issued_month'] ?? 0),
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(builder: (_) {
                          final d = _deltaPercent(
                            kpis['invoices_issued_month'] ?? 0,
                            kpis['prev_invoices_issued_month'],
                          );
                          if (d == null) return const SizedBox.shrink();
                          final isUp = d > 0;
                          final color = isUp
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error;
                          return Text(
                            '${isUp ? '+' : ''}${d.toStringAsFixed(1)}% ultimo mese',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Destra 70%: placeholder (altezza fissa per stabilità)
                  const Expanded(
                    flex: 7,
                    child: SizedBox(
                      height: 120,
                      child: SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Da incassare
        _receivablesCard(context, colors),
      ],
    );
  }

  Widget _receivablesCard(BuildContext context, ChartColors colors) {
    final theme = Theme.of(context);
    final open = kpis['receivables_open'] ?? 0;
    final prev = kpis['prev_receivables_open'];
    final d = _deltaPercent(open, prev);

    return AppCard(
      padding: const EdgeInsets.all(16),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            children: [
              const Icon(AppIcons.currencyEur, size: 20),
              const SizedBox(width: 8),
              Text('Da incassare', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          // Corpo 30% / 70% (senza Expanded per prevenire vincoli non limitati)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Sinistra 30%
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _fmtCurrency(open),
                        style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (d != null) ...[
                      Text(
                        '${d > 0 ? '+' : ''}${d.toStringAsFixed(1)}% ultimo mese',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: d > 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Destra 70%: grafico (altezza fissa) a filo del fondo
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 120,
                  child: _receivablesChart(context, colors),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receivablesChart(BuildContext context, ChartColors colors) {
    final theme = Theme.of(context);

    final groups = List.generate(receivablesMonthly.length, (i) {
      final v = (receivablesMonthly[i]['amount'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: v,
            width: 34,
            borderRadius: BorderRadius.circular(8),
            color: colors.colorDesktop,
          ),
        ],
      );
    });

    return BarChartBase(
      colors: colors,
      groups: groups,
      alignment: BarChartAlignment.spaceEvenly,
      showContainer: false,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      showHorizontalGrid: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 20,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= receivablesMonthly.length) {
              return const SizedBox.shrink();
            }
            final label = _m3(receivablesMonthly[i]['month'] as String? ?? '');
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(label, style: theme.textTheme.bodySmall),
            );
          },
        ),
      ),
      tooltipPayloadBuilder: (context, group, groupIndex, rod, rodIndex, c) {
        final monthIso = receivablesMonthly[groupIndex]['month'] as String? ?? '';
        final label = _m3(monthIso);
        return BarTooltipPayload(
          title: label,
          items: [(
            c.colorDesktop,
            'Da incassare',
            _fmtCurrency(rod.toY),
          )],
        );
      },
    );
  }
}
