import 'package:flutter/material.dart';
import 'chart_config.dart';

@immutable
class LegendEntry {
  final String key; // chiave della serie in ChartConfig o dataKey
  final String? label; // se non presente, prova a pescare da ChartConfig
  final Color? color; // se non presente, prova a pescare da ChartConfig
  final IconData? icon;
  final String? type; // "none" per nascondere (parità API)

  const LegendEntry({
    required this.key,
    this.label,
    this.color,
    this.icon,
    this.type,
  });
}

/// Legenda orizzontale stile shadcn.
/// Sorgente dei dati:
/// - Puoi passarla esplicitamente con `payload`.
/// - Oppure solo le chiavi e lasciare che prenda label/color da ChartConfigProvider.
class ChartLegendContent extends StatelessWidget {
  final List<LegendEntry> payload;
  final bool hideIcon;
  final MainAxisAlignment alignment;
  final EdgeInsetsGeometry padding;

  const ChartLegendContent({
    super.key,
    required this.payload,
    this.hideIcon = false,
    this.alignment = MainAxisAlignment.center,
    this.padding = const EdgeInsets.only(top: 12),
  });

  @override
  Widget build(BuildContext context) {
    if (payload.isEmpty) return const SizedBox.shrink();
    final cfg = _maybeConfig(context);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: alignment,
        children: payload.where((e) => e.type != 'none').map((item) {
          final fromCfg = cfg?[item.key];
          final label = item.label ?? fromCfg?.label ?? item.key;
          final color = item.color ??
              fromCfg?.resolveColor(Theme.of(context).brightness) ??
              Theme.of(context).colorScheme.primary;
          final icon = item.icon ?? fromCfg?.icon;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hideIcon && icon != null)
                  Icon(icon, size: 12, color: Theme.of(context).hintColor)
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  ChartConfig? _maybeConfig(BuildContext context) {
    try {
      return useChartConfig(context);
    } catch (_) {
      return null;
    }
  }
}
