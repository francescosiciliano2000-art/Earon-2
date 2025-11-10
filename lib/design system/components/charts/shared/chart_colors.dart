import 'package:flutter/material.dart';

class ChartColors {
  final Color chart1, chart2, chart3, chart4, chart5;
  final Color colorDesktop,
      colorMobile,
      colorChrome,
      colorSafari,
      colorFirefox,
      colorEdge,
      colorOther;
  final Color grid, axis, foreground, mutedForeground, cardBg, border;

  const ChartColors({
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.colorDesktop,
    required this.colorMobile,
    required this.colorChrome,
    required this.colorSafari,
    required this.colorFirefox,
    required this.colorEdge,
    required this.colorOther,
    required this.grid,
    required this.axis,
    required this.foreground,
    required this.mutedForeground,
    required this.cardBg,
    required this.border,
  });

  factory ChartColors.fallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = Theme.of(context).textTheme.bodyMedium?.color ?? cs.onSurface;
    return ChartColors(
      chart1: cs.primary,
      chart2: cs.secondary,
      chart3: cs.tertiary,
      chart4: cs.primaryContainer,
      chart5: cs.secondaryContainer,
      colorDesktop: cs.primary,
      colorMobile: cs.secondary,
      colorChrome: cs.primary,
      colorSafari: cs.secondary,
      colorFirefox: cs.tertiary,
      colorEdge: cs.primaryContainer,
      colorOther: cs.secondaryContainer,
      grid: cs.outlineVariant.withValues(alpha: 0.35),
      axis: Colors.transparent,
      foreground: fg,
      mutedForeground: fg.withValues(alpha: 0.7),
      cardBg: cs.surface,
      border: cs.outlineVariant,
    );
  }

  // opzionale: factory fromShadcn(context) se vuoi leggere i tuoi token
}
