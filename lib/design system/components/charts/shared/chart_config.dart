import 'package:flutter/material.dart';

/* ─────────────────────────────────────────────────────────────────────────────
   CONFIG DELLE SERIE (parità API con chart.tsx)
   ─────────────────────────────────────────────────────────────────────────── */

@immutable
class ChartItemConfig {
  final String? label;
  final IconData? icon;

  /// Colore esplicito della serie (alternativo a [theme]).
  final Color? color;

  /// Mappa tema -> colore della serie.
  final Map<Brightness, Color>? theme;

  const ChartItemConfig({this.label, this.icon, this.color, this.theme});

  Color? resolveColor(Brightness b) {
    if (theme != null && theme!.containsKey(b)) return theme![b];
    return color;
  }

  ChartItemConfig copyWith({
    String? label,
    IconData? icon,
    Color? color,
    Map<Brightness, Color>? theme,
  }) {
    return ChartItemConfig(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      theme: theme ?? this.theme,
    );
  }
}

typedef ChartConfig = Map<String, ChartItemConfig>;

class ChartConfigProvider extends InheritedWidget {
  final ChartConfig config;

  const ChartConfigProvider({
    super.key,
    required this.config,
    required super.child,
  });

  static ChartConfig of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ChartConfigProvider>();
    assert(scope != null,
        'useChartConfig() deve essere chiamato dentro ChartConfigProvider');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(covariant ChartConfigProvider oldWidget) =>
      !identical(oldWidget.config, config);
}

ChartConfig useChartConfig(BuildContext context) =>
    ChartConfigProvider.of(context);

/// Normalizza i colori delle serie prendendoli da una palette di fallback
/// ricavata dal ColorScheme (nessuna dipendenza da ThemeExtensions).
ChartConfig normalizeChartConfigColors(
    BuildContext context, ChartConfig input) {
  final theme = Theme.of(context);
  final brightness = theme.brightness;

  final cs = theme.colorScheme;
  final palette = <Color>[
    cs.primary,
    cs.secondary,
    cs.tertiary,
    cs.primaryContainer,
    cs.secondaryContainer,
  ];

  var i = 0;
  final out = <String, ChartItemConfig>{};
  input.forEach((key, cfg) {
    final resolved = cfg.resolveColor(brightness);
    if (resolved != null) {
      out[key] = cfg;
    } else {
      final color = palette[i % palette.length];
      i++;
      out[key] = cfg.copyWith(color: color);
    }
  });
  return out;
}

/* ─────────────────────────────────────────────────────────────────────────────
   Se in futuro vorrai usare i tuoi token (DefaultTokens.chart):
   - assicurati del path corretto dell'import (es. '../../../../theme/themes.dart')
   - aggiungi qui una funzione normalizeChartConfigColorsFromTokens(...) che,
     se trova l'estensione, usa quella palette al posto del fallback.
   ─────────────────────────────────────────────────────────────────────────── */
