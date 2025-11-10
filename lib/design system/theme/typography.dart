import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
// Importiamo lerpDouble da dart:ui per l'interpolazione dei double

/// ShadcnTypography mirrors Tailwind CSS defaults used in the React app,
/// converted for Flutter with Inter as the only font family.
///
/// It provides:
/// - Font sizes for text-[...]
/// - Letter-spacing values for tracking-[...]
/// - Line-height multipliers for leading-[...]
/// - Helpers to derive TextTheme and letterSpacing in px from em
class ShadcnTypography extends ThemeExtension<ShadcnTypography> {
  // Font sizes in logical pixels (Tailwind default scale)
  final double textXs; // 12px
  final double textSm; // 14px
  final double textBase; // 16px
  final double textLg; // 18px
  final double textXl; // 20px
  final double text2xl; // 24px
  final double text3xl; // 30px
  final double text4xl; // 36px
  final double text5xl; // 48px
  final double text6xl; // 60px

  // Line-height multipliers (Tailwind default)
  final double leadingNone; // 1.0
  final double leadingTight; // 1.25
  final double leadingSnug; // 1.375
  final double leadingNormal; // 1.5
  final double leadingRelaxed; // 1.625
  final double leadingLoose; // 2.0

  // Letter-spacing values in em (Tailwind default)
  final double trackingTighterEm; // -0.05em
  final double trackingTightEm; // -0.025em
  final double trackingNormalEm; // 0
  final double trackingWideEm; // 0.025em
  final double trackingWiderEm; // 0.05em
  final double trackingWidestEm; // 0.1em

  const ShadcnTypography({
    required this.textXs,
    required this.textSm,
    required this.textBase,
    required this.textLg,
    required this.textXl,
    required this.text2xl,
    required this.text3xl,
    required this.text4xl,
    required this.text5xl,
    required this.text6xl,
    required this.leadingNone,
    required this.leadingTight,
    required this.leadingSnug,
    required this.leadingNormal,
    required this.leadingRelaxed,
    required this.leadingLoose,
    required this.trackingTighterEm,
    required this.trackingTightEm,
    required this.trackingNormalEm,
    required this.trackingWideEm,
    required this.trackingWiderEm,
    required this.trackingWidestEm,
  });

  factory ShadcnTypography.defaults() => const ShadcnTypography(
        textXs: 12,
        textSm: 14,
        textBase: 16,
        textLg: 18,
        textXl: 20,
        text2xl: 24,
        text3xl: 30,
        text4xl: 36,
        text5xl: 48,
        text6xl: 60,
        leadingNone: 1.0,
        leadingTight: 1.25,
        leadingSnug: 1.375,
        leadingNormal: 1.5,
        leadingRelaxed: 1.625,
        leadingLoose: 2.0,
        trackingTighterEm: -0.05,
        trackingTightEm: -0.025,
        trackingNormalEm: 0.0,
        trackingWideEm: 0.025,
        trackingWiderEm: 0.05,
        trackingWidestEm: 0.1,
      );

  // Convert em letter-spacing to logical pixels based on font size
  double letterSpacingPx({required double fontSize, required double em}) {
    return fontSize * em;
  }

  // Convenience getters for common letter-spacing px at specific sizes
  double trackingTightPxSm() => letterSpacingPx(fontSize: textSm, em: trackingTightEm);
  double trackingTightPxBase() => letterSpacingPx(fontSize: textBase, em: trackingTightEm);

  // Build a TextTheme aligned to Tailwind scale using Inter (applied elsewhere)
  TextTheme applyTo(TextTheme base) {
    // Keep weights and colors from base, only adjust sizes and heights where typical
    return base.copyWith(
      bodySmall: base.bodySmall?.copyWith(
        fontSize: textSm,
        height: leadingNormal, // Tailwind default for normal body text
        letterSpacing: letterSpacingPx(fontSize: textSm, em: trackingNormalEm),
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: textBase,
        height: leadingNormal,
        letterSpacing: letterSpacingPx(fontSize: textBase, em: trackingNormalEm),
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: textLg,
        height: leadingNormal,
        letterSpacing: letterSpacingPx(fontSize: textLg, em: trackingNormalEm),
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: textXl,
        height: leadingSnug,
        letterSpacing: letterSpacingPx(fontSize: textXl, em: trackingTightEm),
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: text2xl,
        height: leadingSnug,
        letterSpacing: letterSpacingPx(fontSize: text2xl, em: trackingTightEm),
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: text3xl,
        height: leadingSnug,
        letterSpacing: letterSpacingPx(fontSize: text3xl, em: trackingTightEm),
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: text4xl,
        height: leadingTight,
        letterSpacing: letterSpacingPx(fontSize: text4xl, em: trackingTightEm),
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: text5xl,
        height: leadingTight,
        letterSpacing: letterSpacingPx(fontSize: text5xl, em: trackingTightEm),
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: text6xl,
        height: leadingTight,
        letterSpacing: letterSpacingPx(fontSize: text6xl, em: trackingTightEm),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  @override
  ThemeExtension<ShadcnTypography> copyWith({
    double? textXs,
    double? textSm,
    double? textBase,
    double? textLg,
    double? textXl,
    double? text2xl,
    double? text3xl,
    double? text4xl,
    double? text5xl,
    double? text6xl,
    double? leadingNone,
    double? leadingTight,
    double? leadingSnug,
    double? leadingNormal,
    double? leadingRelaxed,
    double? leadingLoose,
    double? trackingTighterEm,
    double? trackingTightEm,
    double? trackingNormalEm,
    double? trackingWideEm,
    double? trackingWiderEm,
    double? trackingWidestEm,
  }) {
    return ShadcnTypography(
      textXs: textXs ?? this.textXs,
      textSm: textSm ?? this.textSm,
      textBase: textBase ?? this.textBase,
      textLg: textLg ?? this.textLg,
      textXl: textXl ?? this.textXl,
      text2xl: text2xl ?? this.text2xl,
      text3xl: text3xl ?? this.text3xl,
      text4xl: text4xl ?? this.text4xl,
      text5xl: text5xl ?? this.text5xl,
      text6xl: text6xl ?? this.text6xl,
      leadingNone: leadingNone ?? this.leadingNone,
      leadingTight: leadingTight ?? this.leadingTight,
      leadingSnug: leadingSnug ?? this.leadingSnug,
      leadingNormal: leadingNormal ?? this.leadingNormal,
      leadingRelaxed: leadingRelaxed ?? this.leadingRelaxed,
      leadingLoose: leadingLoose ?? this.leadingLoose,
      trackingTighterEm: trackingTighterEm ?? this.trackingTighterEm,
      trackingTightEm: trackingTightEm ?? this.trackingTightEm,
      trackingNormalEm: trackingNormalEm ?? this.trackingNormalEm,
      trackingWideEm: trackingWideEm ?? this.trackingWideEm,
      trackingWiderEm: trackingWiderEm ?? this.trackingWiderEm,
      trackingWidestEm: trackingWidestEm ?? this.trackingWidestEm,
    );
  }

  @override
  ThemeExtension<ShadcnTypography> lerp(ThemeExtension<ShadcnTypography>? other, double t) {
    if (other is! ShadcnTypography) return this;
    return ShadcnTypography(
      textXs: lerpDouble(textXs, other.textXs, t)!,
      textSm: lerpDouble(textSm, other.textSm, t)!,
      textBase: lerpDouble(textBase, other.textBase, t)!,
      textLg: lerpDouble(textLg, other.textLg, t)!,
      textXl: lerpDouble(textXl, other.textXl, t)!,
      text2xl: lerpDouble(text2xl, other.text2xl, t)!,
      text3xl: lerpDouble(text3xl, other.text3xl, t)!,
      text4xl: lerpDouble(text4xl, other.text4xl, t)!,
      text5xl: lerpDouble(text5xl, other.text5xl, t)!,
      text6xl: lerpDouble(text6xl, other.text6xl, t)!,
      leadingNone: lerpDouble(leadingNone, other.leadingNone, t)!,
      leadingTight: lerpDouble(leadingTight, other.leadingTight, t)!,
      leadingSnug: lerpDouble(leadingSnug, other.leadingSnug, t)!,
      leadingNormal: lerpDouble(leadingNormal, other.leadingNormal, t)!,
      leadingRelaxed: lerpDouble(leadingRelaxed, other.leadingRelaxed, t)!,
      leadingLoose: lerpDouble(leadingLoose, other.leadingLoose, t)!,
      trackingTighterEm: lerpDouble(trackingTighterEm, other.trackingTighterEm, t)!,
      trackingTightEm: lerpDouble(trackingTightEm, other.trackingTightEm, t)!,
      trackingNormalEm: lerpDouble(trackingNormalEm, other.trackingNormalEm, t)!,
      trackingWideEm: lerpDouble(trackingWideEm, other.trackingWideEm, t)!,
      trackingWiderEm: lerpDouble(trackingWiderEm, other.trackingWiderEm, t)!,
      trackingWidestEm: lerpDouble(trackingWidestEm, other.trackingWidestEm, t)!,
    );
  }
}