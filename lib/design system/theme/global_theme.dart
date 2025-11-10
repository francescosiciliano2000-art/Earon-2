// shadcn_themes.dart
import 'package:flutter/material.dart';
import 'themes.dart';
import 'oklch.dart';

// ThemeExtensions minime per far funzionare i preset
class ShadcnExtra extends ThemeExtension<ShadcnExtra> {
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarRing;

  const ShadcnExtra({
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarRing,
  });

  @override
  ShadcnExtra copyWith({
    Color? sidebarPrimary,
    Color? sidebarPrimaryForeground,
    Color? sidebarRing,
  }) {
    return ShadcnExtra(
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarPrimaryForeground:
          sidebarPrimaryForeground ?? this.sidebarPrimaryForeground,
      sidebarRing: sidebarRing ?? this.sidebarRing,
    );
  }

  @override
  ThemeExtension<ShadcnExtra> lerp(ThemeExtension<ShadcnExtra>? other, double t) {
    if (other is! ShadcnExtra) return this;
    return ShadcnExtra(
      sidebarPrimary:
          Color.lerp(sidebarPrimary, other.sidebarPrimary, t) ?? sidebarPrimary,
      sidebarPrimaryForeground: Color.lerp(
              sidebarPrimaryForeground, other.sidebarPrimaryForeground, t) ??
          sidebarPrimaryForeground,
      sidebarRing: Color.lerp(sidebarRing, other.sidebarRing, t) ?? sidebarRing,
    );
  }
}

class _ShadcnFonts extends ThemeExtension<_ShadcnFonts> {
  final String? sans;
  final String? mono;
  const _ShadcnFonts({this.sans, this.mono});

  @override
  _ShadcnFonts copyWith({String? sans, String? mono}) {
    return _ShadcnFonts(sans: sans ?? this.sans, mono: mono ?? this.mono);
  }

  @override
  ThemeExtension<_ShadcnFonts> lerp(
      ThemeExtension<_ShadcnFonts>? other, double t) {
    return other is _ShadcnFonts ? other : this;
  }
}

class _ShadcnCharts extends ThemeExtension<_ShadcnCharts> {
  final List<Color> charts;
  const _ShadcnCharts(this.charts);

  @override
  _ShadcnCharts copyWith({List<Color>? charts}) {
    return _ShadcnCharts(charts ?? this.charts);
  }

  @override
  ThemeExtension<_ShadcnCharts> lerp(
      ThemeExtension<_ShadcnCharts>? other, double t) {
    return other is _ShadcnCharts ? other : this;
  }
}

/// Theme neutrals di base (prima di DefaultTheme.apply)
class GlobalTheme {
  static ThemeData lightNeutrals() {
    // Partiamo dal seed e sovrascriviamo con i valori OKLCH del CSS "Default (neutral)"
    final seed = ColorScheme.fromSeed(
      seedColor: const Color(0xFF64748B),
      brightness: Brightness.light,
    );
    final cs = seed.copyWith(
      // Neutrals base (evitiamo campi deprecati: background/onBackground/surfaceVariant)
      surface: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      onSurface: const Color.fromRGBO(10, 10, 10, 1.0), // neutral-950
      surfaceContainerHighest: const Color.fromRGBO(245, 245, 245, 1.0), // neutral-100
      onSurfaceVariant: const Color.fromRGBO(115, 115, 115, 1.0), // neutral-500 (text-muted-foreground)
      // Primary/Secondary/Accent
      primary: const Color.fromRGBO(23, 23, 23, 1.0), // neutral-900
      onPrimary: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      secondary: const Color.fromRGBO(245, 245, 245, 1.0), // neutral-100 (bg-secondary)
      onSecondary: const Color.fromRGBO(23, 23, 23, 1.0), // neutral-900
      tertiary: const Color.fromRGBO(245, 245, 245, 1.0), // neutral-100 (bg-accent)
      onTertiary: const Color.fromRGBO(23, 23, 23, 1.0), // neutral-900
      // Error/Destructive
      error: oklch(0.577, 0.245, 27.325),
      onError: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      // Borders/Input/Ring
      outline: const Color.fromRGBO(229, 229, 229, 1.0), // neutral-200 (border)
      outlineVariant: const Color.fromRGBO(229, 229, 229, 1.0), // neutral-200 (input)
      // Inverse
      inverseSurface: const Color.fromRGBO(10, 10, 10, 1.0), // neutral-950
      onInverseSurface: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      inversePrimary: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      // Container per varianti secondarie (usate da Button secondary)
      secondaryContainer: const Color.fromRGBO(245, 245, 245, 1.0), // neutral-100
      onSecondaryContainer: const Color.fromRGBO(23, 23, 23, 1.0), // neutral-900
    );

    final base = ThemeData(useMaterial3: true, colorScheme: cs);
    return base.copyWith(extensions: _defaultExtensions(base));
  }

  static ThemeData dark() {
    // Partiamo dal seed e sovrascriviamo con i valori della palette NEUTRAL RGB
    final seed = ColorScheme.fromSeed(
      seedColor: const Color(0xFF64748B),
      brightness: Brightness.dark,
    );
    final cs = seed.copyWith(
      // Neutrals base
      surface: const Color.fromRGBO(10, 10, 10, 1.0), // neutral-950
      onSurface: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      surfaceContainerHighest: const Color.fromRGBO(38, 38, 38, 1.0), // neutral-800
      onSurfaceVariant: const Color.fromRGBO(163, 163, 163, 1.0), // neutral-400 (text-muted-foreground)
      // Primary/Secondary/Accent
      primary: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      onPrimary: const Color.fromRGBO(23, 23, 23, 1.0), // neutral-900
      secondary: const Color.fromRGBO(38, 38, 38, 1.0), // neutral-800
      onSecondary: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      tertiary: const Color.fromRGBO(38, 38, 38, 1.0), // neutral-800 (bg-accent)
      onTertiary: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      // Error/Destructive
      error: oklch(0.704, 0.191, 22.216),
      onError: const Color.fromRGBO(250, 250, 250, 1.0),
      // Borders/Input
      outline: const Color.fromRGBO(38, 38, 38, 1.0), // neutral-800 (border)
      outlineVariant: const Color.fromRGBO(38, 38, 38, 1.0), // neutral-800 (input)
      // Inverse
      inverseSurface: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
      onInverseSurface: const Color.fromRGBO(10, 10, 10, 1.0), // neutral-950
      inversePrimary: const Color.fromRGBO(23, 23, 23, 1.0), // neutral-900
      // Container per varianti secondarie
      secondaryContainer: const Color.fromRGBO(38, 38, 38, 1.0), // neutral-800
      onSecondaryContainer: const Color.fromRGBO(250, 250, 250, 1.0), // neutral-50
    );

    final base = ThemeData(useMaterial3: true, colorScheme: cs);
    return base.copyWith(extensions: _defaultExtensions(base));
  }

  static List<ThemeExtension<dynamic>> _defaultExtensions(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;

    // Valori extra e charts allineati al CSS neutral (light/dark)
    final extra = ShadcnExtra(
      sidebarPrimary: isDark
          ? oklch(0.488, 0.243, 264.376)
          : oklch(0.205, 0.0, 0.0),
      sidebarPrimaryForeground: oklch(0.985, 0.0, 0.0),
      sidebarRing: isDark ? oklch(0.556, 0.0, 0.0) : oklch(0.708, 0.0, 0.0),
    );

    // Radius base; se serve, possiamo derivare da --radius
    const radii = ShadcnRadii(
      xs: BorderRadius.all(Radius.circular(4)),
      sm: BorderRadius.all(Radius.circular(6)),
      md: BorderRadius.all(Radius.circular(8)),
      lg: BorderRadius.all(Radius.circular(12)),
      xl: BorderRadius.all(Radius.circular(16)),
    );

    final charts = _ShadcnCharts(isDark
        ? [
            oklch(0.488, 0.243, 264.376),
            oklch(0.696, 0.170, 162.480),
            oklch(0.769, 0.188, 70.080),
            oklch(0.627, 0.265, 303.900),
            oklch(0.645, 0.246, 16.439),
          ]
        : [
            oklch(0.646, 0.222, 41.116),
            oklch(0.600, 0.118, 184.704),
            oklch(0.398, 0.070, 227.392),
            oklch(0.828, 0.189, 84.429),
            oklch(0.769, 0.188, 70.080),
          ]);

    final fonts = _ShadcnFonts(
      sans: base.textTheme.bodyMedium?.fontFamily,
      mono: 'monospace',
    );
    return [extra, radii, charts, fonts];
  }
}

/// Preset/varianti equivalenti a themes.css:
/// - theme-default (implicito)
/// - theme-mono (font mono, ring/siderbar tweaks)
/// - theme-scaled (radius/typography/spacing su viewport >= lg)
/// - Rounded: none/small/medium/large/full
/// - Font families: inter, notoSans, nunitoSans, figtree
/// - Accents: blue, green, amber, rose, purple, orange, teal, red, yellow, violet
enum ShadcnRounded { none, small, medium, large, full }

enum ShadcnAccent {
  blue,
  green,
  amber,
  rose,
  purple,
  orange,
  teal,
  red,
  yellow,
  violet,
}

enum ShadcnFont { inter, notoSans, nunitoSans, figtree, system }

enum ShadcnMode { light, dark }

class ShadcnThemePresets {
  /// Applica i preset su un ThemeData generato da ShadcnTheme.light/dark.
  static ThemeData apply({
    required ThemeData base,
    ShadcnMode mode = ShadcnMode.light,
    bool mono = false, // theme-mono
    bool scaled =
        false, // theme-scaled (lg+ in CSS, qui applichiamo sempre o a discrezione)
    ShadcnRounded rounded = ShadcnRounded.medium,
    ShadcnFont font = ShadcnFont.system,
    ShadcnAccent?
    accent, // theme-blue/green/… (override primary/sidebar/ring + chart)
  }) {
    final extra = base.extension<ShadcnExtra>()!;
    final radii = base.extension<ShadcnRadii>()!;
    final fonts = base.extension<_ShadcnFonts>()!;
    final charts = base.extension<_ShadcnCharts>()!;

    // 1) Font family preset
    String? fontFamilySans = switch (font) {
      ShadcnFont.inter => 'Inter',
      ShadcnFont.notoSans => 'Noto Sans',
      ShadcnFont.nunitoSans => 'Nunito Sans',
      ShadcnFont.figtree => 'Figtree',
      ShadcnFont.system => base.textTheme.bodyMedium?.fontFamily,
    };

    // 2) theme-mono → usa mono everywhere + vari override
    final isDark = base.brightness == Brightness.dark;
    final monoPrimary = isDark
        ? const Color(0xFF78716C)
        : const Color(0xFF57534E); // stone-500/600
    final monoOnPrimary = const Color(0xFFFAFAFA);
    final monoSidebarRing = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFA8A29E); // stone-900/400

    ThemeData t = base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: mono ? (fonts.mono ?? 'monospace') : fontFamilySans,
      ),
      colorScheme: mono
          ? base.colorScheme.copyWith(
              primary: monoPrimary,
              onPrimary: monoOnPrimary,
            )
          : base.colorScheme,
      extensions: [
        extra.copyWith(
          sidebarPrimary: mono ? monoPrimary : extra.sidebarPrimary,
          sidebarPrimaryForeground:
              mono ? monoOnPrimary : extra.sidebarPrimaryForeground,
          sidebarRing: mono ? monoSidebarRing : extra.sidebarRing,
        ),
        radii,
        charts,
        fonts.copyWith(
            sans: mono ? fonts.mono ?? 'monospace' : fontFamilySans),
      ],
    );

    // 3) theme-scaled → radius e tipografia “compressa” (come in CSS >= lg)
    if (scaled) {
      const scaledRadius = 0.45; // em
      final baseRad = 10.0;
      final r = baseRad * scaledRadius; // ≈4.5px
      final scaledRadii = ShadcnRadii(
        xs: t.extension<ShadcnRadii>()!.xs,
        sm: BorderRadius.zero,
        md: BorderRadius.circular(r * 0.85),
        lg: BorderRadius.circular(r),
        xl: BorderRadius.circular(r * 1.2),
      );
      final textScale = 0.9; // text-base 0.85rem etc.
      t = t.copyWith(
        textTheme: _scaleTextTheme(t.textTheme, textScale),
        extensions: [
          // Preserve existing extensions and replace only the ones we override
          ...t.extensions.values.where((e) =>
              e is! ShadcnExtra && e is! ShadcnRadii && e is! _ShadcnCharts && e is! _ShadcnFonts),
          t.extension<ShadcnExtra>()!,
          scaledRadii,
          charts,
          t.extension<_ShadcnFonts>()!,
        ],
      );
    }

    // 4) Rounded variants
    ShadcnRadii roundedRadii() {
      switch (rounded) {
        case ShadcnRounded.none:
          return const ShadcnRadii(
            xs: BorderRadius.zero,
            sm: BorderRadius.zero,
            md: BorderRadius.zero,
            lg: BorderRadius.zero,
            xl: BorderRadius.zero,
          );
        case ShadcnRounded.small:
          return ShadcnRadii(
            xs: const BorderRadius.all(Radius.circular(2)),
            sm: BorderRadius.circular(4),
            md: BorderRadius.circular(6),
            lg: BorderRadius.circular(8),
            xl: BorderRadius.circular(10),
          );
        case ShadcnRounded.medium:
          return t.extension<ShadcnRadii>()!; // già coerente con globals
        case ShadcnRounded.large:
          return ShadcnRadii(
            xs: const BorderRadius.all(Radius.circular(8)),
            sm: BorderRadius.circular(10),
            md: BorderRadius.circular(14),
            lg: BorderRadius.circular(16),
            xl: BorderRadius.circular(20),
          );
        case ShadcnRounded.full:
          return const ShadcnRadii(
            xs: BorderRadius.all(Radius.circular(999)),
            sm: BorderRadius.all(Radius.circular(999)),
            md: BorderRadius.all(Radius.circular(999)),
            lg: BorderRadius.all(Radius.circular(999)),
            xl: BorderRadius.all(Radius.circular(999)),
          );
      }
    }

    t = t.copyWith(
      extensions: [
        // Preserve existing extensions and replace only the ones we override
        ...t.extensions.values.where((e) =>
            e is! ShadcnExtra && e is! ShadcnRadii && e is! _ShadcnCharts && e is! _ShadcnFonts),
        t.extension<ShadcnExtra>()!,
        roundedRadii(),
        charts,
        t.extension<_ShadcnFonts>()!,
      ],
    );

    // 5) Accents (theme-blue/green/amber/rose/purple/orange/teal/red/yellow/violet)
    if (accent != null) {
      final sets = _accentSet(accent, isDark: isDark);
      final s = t.colorScheme.copyWith(
        primary: sets.primary,
        onPrimary: sets.onPrimary,
        // opzionale: ring come nei css di alcune palette
      );
      t = t.copyWith(
        colorScheme: s,
        extensions: [
          // Preserve existing extensions and replace only the ones we override
          ...t.extensions.values.where((e) =>
              e is! ShadcnExtra && e is! ShadcnRadii && e is! _ShadcnCharts && e is! _ShadcnFonts),
          t.extension<ShadcnExtra>()!.copyWith(
            sidebarPrimary: sets.sidebarPrimary,
            sidebarPrimaryForeground: sets.sidebarPrimaryForeground,
            sidebarRing: sets.sidebarRing,
          ),
          t.extension<ShadcnRadii>()!,
          _ShadcnCharts(sets.charts),
          t.extension<_ShadcnFonts>()!,
        ],
      );
    }

    return t;
  }

  // Helpers

  static TextTheme _scaleTextTheme(TextTheme input, double factor) {
    TextStyle? s(TextStyle? x) => x?.copyWith(fontSize: (x.fontSize ?? 14) * factor);
    return input.copyWith(
      displayLarge: s(input.displayLarge),
      displayMedium: s(input.displayMedium),
      displaySmall: s(input.displaySmall),
      headlineLarge: s(input.headlineLarge),
      headlineMedium: s(input.headlineMedium),
      headlineSmall: s(input.headlineSmall),
      titleLarge: s(input.titleLarge),
      titleMedium: s(input.titleMedium),
      titleSmall: s(input.titleSmall),
      bodyLarge: s(input.bodyLarge),
      bodyMedium: s(input.bodyMedium),
      bodySmall: s(input.bodySmall),
      labelLarge: s(input.labelLarge),
      labelMedium: s(input.labelMedium),
      labelSmall: s(input.labelSmall),
    );
  }
}

/// Definizioni palette come in themes.css (Tailwind-like scale).
class _AccentSet {
  final Color primary;
  final Color onPrimary;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarRing;
  final List<Color> charts;
  _AccentSet({
    required this.primary,
    required this.onPrimary,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarRing,
    required this.charts,
  });
}

_AccentSet _accentSet(ShadcnAccent a, {required bool isDark}) {
  // Palettes (300..800) prese dallo scale Tailwind per coerenza con --chart-1..5.
  Map<String, List<Color>> sw = {
    'blue': [
      const Color(0xFF93C5FD),
      const Color(0xFF3B82F6),
      const Color(0xFF2563EB),
      const Color(0xFF1D4ED8),
      const Color(0xFF1E40AF),
    ],
    'green': [
      const Color(0xFF86EFAC),
      const Color(0xFF22C55E),
      const Color(0xFF16A34A),
      const Color(0xFF15803D),
      const Color(0xFF166534),
    ],
    'amber': [
      const Color(0xFFFCD34D),
      const Color(0xFFF59E0B),
      const Color(0xFFD97706),
      const Color(0xFFB45309),
      const Color(0xFF92400E),
    ],
    'rose': [
      const Color(0xFFFDA4AF),
      const Color(0xFFF43F5E),
      const Color(0xFFE11D48),
      const Color(0xFFBE123C),
      const Color(0xFF9F1239),
    ],
    'purple': [
      const Color(0xFFC4B5FD),
      const Color(0xFF8B5CF6),
      const Color(0xFF7C3AED),
      const Color(0xFF6D28D9),
      const Color(0xFF5B21B6),
    ],
    'orange': [
      const Color(0xFFFBBF24),
      const Color(0xFFFB923C),
      const Color(0xFFF97316),
      const Color(0xFFEA580C),
      const Color(0xFFC2410C),
    ],
    'teal': [
      const Color(0xFF5EEAD4),
      const Color(0xFF14B8A6),
      const Color(0xFF0D9488),
      const Color(0xFF0F766E),
      const Color(0xFF115E59),
    ],
    'red': [
      const Color(0xFFFCA5A5),
      const Color(0xFFEF4444),
      const Color(0xFFDC2626),
      const Color(0xFFB91C1C),
      const Color(0xFF991B1B),
    ],
    'yellow': [
      const Color(0xFFFDE047),
      const Color(0xFFEAB308),
      const Color(0xFFCA8A04),
      const Color(0xFFA16207),
      const Color(0xFF854D0E),
    ],
    'violet': [
      const Color(0xFFC4B5FD),
      const Color(0xFF8B5CF6),
      const Color(0xFF7C3AED),
      const Color(0xFF6D28D9),
      const Color(0xFF5B21B6),
    ],
  };

  String key = a.name;
  final charts = sw[key]!;
  late Color primary;
  late Color onPrimary;
  late Color sidebarPrimary;
  late Color sidebarPrimaryForeground;
  late Color sidebarRing;

  switch (a) {
    case ShadcnAccent.blue:
      primary = isDark
          ? const Color(0xFF2563EB)
          : const Color(0xFF1D4ED8); // ~ var(--color-blue-600/700)
      onPrimary = const Color(0xFFFAFAFA);
      sidebarPrimary = isDark
          ? const Color(0xFF3B82F6)
          : const Color(0xFF2563EB);
      sidebarPrimaryForeground = const Color(0xFFFAFAFA);
      sidebarRing = isDark ? const Color(0xFF0B1221) : const Color(0xFF93C5FD);
      break;
    case ShadcnAccent.green:
      primary = const Color(0xFF65A30D); // lime-600
      onPrimary = const Color(0xFFF7FEE7);
      sidebarPrimary = isDark
          ? const Color(0xFF84CC16)
          : const Color(0xFF65A30D);
      sidebarPrimaryForeground = const Color(0xFFF7FEE7);
      sidebarRing = isDark ? const Color(0xFF1A2E05) : const Color(0xFFA3E635);
      break;
    case ShadcnAccent.amber:
      primary = const Color(0xFFD97706);
      onPrimary = const Color(0xFFFFFBEB);
      sidebarPrimary = isDark
          ? const Color(0xFFF59E0B)
          : const Color(0xFFD97706);
      sidebarPrimaryForeground = const Color(0xFFFFFBEB);
      sidebarRing = isDark ? const Color(0xFF451A03) : const Color(0xFFFBBF24);
      break;
    case ShadcnAccent.rose:
      primary = const Color(0xFFE11D48);
      onPrimary = const Color(0xFFFFF1F2);
      sidebarPrimary = isDark
          ? const Color(0xFFF43F5E)
          : const Color(0xFFE11D48);
      sidebarPrimaryForeground = const Color(0xFFFFF1F2);
      sidebarRing = isDark ? const Color(0xFF4C0519) : const Color(0xFFFDA4AF);
      break;
    case ShadcnAccent.purple:
      primary = const Color(0xFF7C3AED);
      onPrimary = const Color(0xFFF5F3FF);
      sidebarPrimary = isDark
          ? const Color(0xFF8B5CF6)
          : const Color(0xFF7C3AED);
      sidebarPrimaryForeground = const Color(0xFFF5F3FF);
      sidebarRing = isDark ? const Color(0xFF2E1065) : const Color(0xFFC4B5FD);
      break;
    case ShadcnAccent.orange:
      primary = const Color(0xFFF97316);
      onPrimary = const Color(0xFFFFEDD5);
      sidebarPrimary = isDark
          ? const Color(0xFFFB923C)
          : const Color(0xFFF97316);
      sidebarPrimaryForeground = const Color(0xFFFFEDD5);
      sidebarRing = isDark ? const Color(0xFF431407) : const Color(0xFFFBBF24);
      break;
    case ShadcnAccent.teal:
      primary = const Color(0xFF0D9488);
      onPrimary = const Color(0xFFF0FDFA);
      sidebarPrimary = isDark
          ? const Color(0xFF14B8A6)
          : const Color(0xFF0D9488);
      sidebarPrimaryForeground = const Color(0xFFF0FDFA);
      sidebarRing = isDark ? const Color(0xFF042F2E) : const Color(0xFF5EEAD4);
      break;
    case ShadcnAccent.red:
      primary = const Color(0xFFDC2626);
      onPrimary = const Color(0xFFFFF1F2);
      sidebarPrimary = isDark
          ? const Color(0xFFEF4444)
          : const Color(0xFFDC2626);
      sidebarPrimaryForeground = const Color(0xFFFFF1F2);
      sidebarRing = isDark ? const Color(0xFF450A0A) : const Color(0xFFFCA5A5);
      break;
    case ShadcnAccent.yellow:
      primary = const Color(0xFFEAB308);
      onPrimary = const Color(0xFF1F2937);
      sidebarPrimary = isDark
          ? const Color(0xFFEAB308)
          : const Color(0xFFEAB308);
      sidebarPrimaryForeground = const Color(0xFF1F2937);
      sidebarRing = isDark ? const Color(0xFF422006) : const Color(0xFFFDE047);
      break;
    case ShadcnAccent.violet:
      primary = const Color(0xFF7C3AED);
      onPrimary = const Color(0xFFF5F3FF);
      sidebarPrimary = isDark
          ? const Color(0xFF8B5CF6)
          : const Color(0xFF7C3AED);
      sidebarPrimaryForeground = const Color(0xFFF5F3FF);
      sidebarRing = isDark ? const Color(0xFF2E1065) : const Color(0xFFC4B5FD);
      break;
  }

  return _AccentSet(
    primary: primary,
    onPrimary: onPrimary,
    sidebarPrimary: sidebarPrimary,
    sidebarPrimaryForeground: sidebarPrimaryForeground,
    sidebarRing: sidebarRing,
    charts: charts,
  );
}
