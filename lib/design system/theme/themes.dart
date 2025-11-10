import 'package:flutter/material.dart';
import 'typography.dart';

/// DefaultTokens consolidati: contengono gli stessi valori usati dal progetto
/// (ring, chart, spacing, radius, durata, curve, sidebar colors) e replicano
/// la semantica dei file React.
class DefaultTokens extends ThemeExtension<DefaultTokens> {
  final Color ring;
  final List<Color> chart;
  final double spacingUnit;
  final BorderRadius radiusXs;
  final BorderRadius radiusSm;
  final BorderRadius radiusMd;
  final Duration durationBase;
  final Curve curveEaseOut;
  final Color sidebarPrimary;
  final Color sidebarOnPrimary;

  const DefaultTokens({
    required this.ring,
    required this.chart,
    required this.spacingUnit,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.durationBase,
    required this.curveEaseOut,
    required this.sidebarPrimary,
    required this.sidebarOnPrimary,
  });

  factory DefaultTokens.light({
    required Color ring,
    required Color sidebarPrimary,
    required Color sidebarOnPrimary,
  }) {
    return DefaultTokens(
      ring: ring,
      chart: const [
        Color(0xFF93C5FD), // blue-300
        Color(0xFF3B82F6), // blue-500
        Color(0xFF2563EB), // blue-600
        Color(0xFF1D4ED8), // blue-700
        Color(0xFF1E40AF), // blue-800
      ],
      spacingUnit: 8.0,
      radiusXs: BorderRadius.circular(4),
      radiusSm: BorderRadius.circular(6),
      radiusMd: BorderRadius.circular(8),
      durationBase: const Duration(milliseconds: 160),
      curveEaseOut: Curves.easeOut,
      sidebarPrimary: sidebarPrimary,
      sidebarOnPrimary: sidebarOnPrimary,
    );
  }

  factory DefaultTokens.dark({
    required Color ring,
    required Color sidebarPrimary,
    required Color sidebarOnPrimary,
  }) {
    return DefaultTokens(
      ring: ring,
      chart: const [
        Color(0xFF60A5FA), // blue-400
        Color(0xFF2563EB), // blue-600
        Color(0xFF1D4ED8), // blue-700
        Color(0xFF1E40AF), // blue-800
        Color(0xFF1D3A7A), // custom dark variant
      ],
      spacingUnit: 8.0,
      radiusXs: BorderRadius.circular(4),
      radiusSm: BorderRadius.circular(6),
      radiusMd: BorderRadius.circular(8),
      durationBase: const Duration(milliseconds: 160),
      curveEaseOut: Curves.easeOut,
      sidebarPrimary: sidebarPrimary,
      sidebarOnPrimary: sidebarOnPrimary,
    );
  }

  @override
  ThemeExtension<DefaultTokens> copyWith({
    Color? ring,
    List<Color>? chart,
    double? spacingUnit,
    BorderRadius? radiusXs,
    BorderRadius? radiusSm,
    BorderRadius? radiusMd,
    Duration? durationBase,
    Curve? curveEaseOut,
    Color? sidebarPrimary,
    Color? sidebarOnPrimary,
  }) {
    return DefaultTokens(
      ring: ring ?? this.ring,
      chart: chart ?? this.chart,
      spacingUnit: spacingUnit ?? this.spacingUnit,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      durationBase: durationBase ?? this.durationBase,
      curveEaseOut: curveEaseOut ?? this.curveEaseOut,
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarOnPrimary: sidebarOnPrimary ?? this.sidebarOnPrimary,
    );
  }

  @override
  ThemeExtension<DefaultTokens> lerp(ThemeExtension<DefaultTokens>? other, double t) {
    if (other is! DefaultTokens) return this;
    return DefaultTokens(
      ring: Color.lerp(ring, other.ring, t) ?? ring,
      chart: chart, // non lerpiamo la palette
      spacingUnit: spacingUnit,
      radiusXs: BorderRadius.lerp(radiusXs, other.radiusXs, t) ?? radiusXs,
      radiusSm: BorderRadius.lerp(radiusSm, other.radiusSm, t) ?? radiusSm,
      radiusMd: BorderRadius.lerp(radiusMd, other.radiusMd, t) ?? radiusMd,
      durationBase: Duration(milliseconds:
          (durationBase.inMilliseconds + (other.durationBase.inMilliseconds - durationBase.inMilliseconds) * t).round()),
      curveEaseOut: curveEaseOut,
      sidebarPrimary: Color.lerp(sidebarPrimary, other.sidebarPrimary, t) ?? sidebarPrimary,
      sidebarOnPrimary: Color.lerp(sidebarOnPrimary, other.sidebarOnPrimary, t) ?? sidebarOnPrimary,
    );
  }
}

/// Radii come ThemeExtension per l'accesso semplice (xs/sm/md/lg/xl)
class ShadcnRadii extends ThemeExtension<ShadcnRadii> {
  final BorderRadius xs;
  final BorderRadius sm;
  final BorderRadius md;
  final BorderRadius lg;
  final BorderRadius xl;

  const ShadcnRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  @override
  ShadcnRadii copyWith({
    BorderRadius? xs,
    BorderRadius? sm,
    BorderRadius? md,
    BorderRadius? lg,
    BorderRadius? xl,
  }) {
    return ShadcnRadii(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  ThemeExtension<ShadcnRadii> lerp(ThemeExtension<ShadcnRadii>? other, double t) {
    if (other is! ShadcnRadii) return this;
    return ShadcnRadii(
      xs: BorderRadius.lerp(xs, other.xs, t) ?? xs,
      sm: BorderRadius.lerp(sm, other.sm, t) ?? sm,
      md: BorderRadius.lerp(md, other.md, t) ?? md,
      lg: BorderRadius.lerp(lg, other.lg, t) ?? lg,
      xl: BorderRadius.lerp(xl, other.xl, t) ?? xl,
    );
  }
}

/// DefaultTheme sovrappone DefaultTokens sopra i neutrals del GlobalTheme.
class DefaultTheme {
  static ThemeData apply(ThemeData base) {
    final isDark = base.colorScheme.brightness == Brightness.dark;

    // Deriva ring neutro, come in React neutral theme
    final Color ring = isDark
        ? const Color.fromRGBO(212, 212, 212, 1.0) // neutral-300 (dark)
        : const Color.fromRGBO(10, 10, 10, 1.0);   // neutral-950 (light)

    final sidebarPrimary = base.colorScheme.primary;
    final sidebarOnPrimary = base.colorScheme.onPrimary;

    final tokens = isDark
        ? DefaultTokens.dark(ring: ring, sidebarPrimary: sidebarPrimary, sidebarOnPrimary: sidebarOnPrimary)
        : DefaultTokens.light(ring: ring, sidebarPrimary: sidebarPrimary, sidebarOnPrimary: sidebarOnPrimary);

    final radii = ShadcnRadii(
      xs: tokens.radiusXs,
      sm: tokens.radiusSm,
      md: tokens.radiusMd,
      lg: BorderRadius.circular(12),
      xl: BorderRadius.circular(16),
    );

    // Preserva eventuali ThemeExtensions esistenti (es. GlobalTokens) e aggiungi le nostre
    final List<ThemeExtension<dynamic>> mergedExtensions = [
      if (base.extensions.isNotEmpty) ...base.extensions.values,
      tokens,
      radii,
      ShadcnTypography.defaults(),
    ];

    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: tokens.radiusSm,
          borderSide: BorderSide(color: tokens.ring, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              vertical: tokens.spacingUnit,
              horizontal: tokens.spacingUnit * 3,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: tokens.radiusSm),
          ),
        ),
      ),
      extensions: mergedExtensions,
    );
  }
}