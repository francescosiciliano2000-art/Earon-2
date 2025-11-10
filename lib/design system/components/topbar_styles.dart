import 'package:flutter/material.dart';

/// ThemeExtension per stili della TopBar (icone/titolo) a livello di UI.
class AppTopBarStyles extends ThemeExtension<AppTopBarStyles> {
  final double leadingIconSize;
  final double leadingGap;

  const AppTopBarStyles({
    required this.leadingIconSize,
    required this.leadingGap,
  });

  /// Variante compatta: icona leggermente ridotta mantenendo l’altezza della TopBar.
  factory AppTopBarStyles.compact() => const AppTopBarStyles(
        leadingIconSize: 20, // default 24 → 20 per compattezza
        leadingGap: 8,
      );

  @override
  AppTopBarStyles copyWith({double? leadingIconSize, double? leadingGap}) {
    return AppTopBarStyles(
      leadingIconSize: leadingIconSize ?? this.leadingIconSize,
      leadingGap: leadingGap ?? this.leadingGap,
    );
  }

  @override
  ThemeExtension<AppTopBarStyles> lerp(
      ThemeExtension<AppTopBarStyles>? other, double t) {
    if (other is! AppTopBarStyles) return this;
    return AppTopBarStyles(
      leadingIconSize: _lerpDouble(leadingIconSize, other.leadingIconSize, t),
      leadingGap: _lerpDouble(leadingGap, other.leadingGap, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
