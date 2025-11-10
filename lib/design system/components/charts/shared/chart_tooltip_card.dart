import 'package:flutter/material.dart';

/// Tooltip “card” stile shadcn da usare come OVERLAY sopra il chart.
/// Non sostituisce il tooltip testuale interno di fl_chart.
class DsChartTooltipCard extends StatelessWidget {
  const DsChartTooltipCard({
    super.key,
    required this.title,
    required this.items,
    this.minWidth = 128,
  });

  /// Titolo (es. "Apr 1, 2024" o "Jan").
  final String title;

  /// Righe del tooltip: (colore dot, label, valore)
  final List<(Color color, String label, String value)> items;

  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8), // fallback neutro
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: kElevationToShadow[4],
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.bodySmall!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodySmall!
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...items.map((e) {
                final (color, label, value) = e;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                      Text(
                        value,
                        style: theme.textTheme.labelSmall!.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────────────────────────
   ESEMPIO D’USO (overlay sopra un BarChartBase)
   ───────────────────────────────────────────────────────────────────────────
   class ChartWithOverlayTooltip extends StatefulWidget { ... }
   class _ChartWithOverlayTooltipState extends State<ChartWithOverlayTooltip> {
     Offset? anchor; BarTooltipPayload? payload;

     @override
     Widget build(BuildContext context) {
       return Stack(
         children: [
           BarChartBase(
             // ...
             // puoi esporre un onTouch in BarChartBase (touchCallback) per ottenere l'anchor
           ),
           if (anchor != null && payload != null)
             Positioned(
               left: anchor!.dx,
               top:  anchor!.dy,
               child: DsChartTooltipCard(
                 title: payload!.title,
                 items: payload!.items,
               ),
             ),
         ],
       );
     }
   }
*/
