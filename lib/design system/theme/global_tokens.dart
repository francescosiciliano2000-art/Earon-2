import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

/// GlobalTokens: gestisce tutti i colori semantici del design system
/// Carica i mapping da neutral_inline.json e neutral_rgb.json
/// per garantire coerenza con i token React shadcn/ui
class GlobalTokens extends ThemeExtension<GlobalTokens> {
  // Colori semantici principali
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;

  const GlobalTokens({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
  });

  /// Carica i token per la modalità light
  static Future<GlobalTokens> loadLight() async {
    final colorMap = await _loadColorMappings();
    return _createTokensFromMap(colorMap, 'light');
  }

  /// Carica i token per la modalità dark
  static Future<GlobalTokens> loadDark() async {
    final colorMap = await _loadColorMappings();
    return _createTokensFromMap(colorMap, 'dark');
  }

  /// Carica i mapping dei colori dai file JSON
  static Future<Map<String, dynamic>> _loadColorMappings() async {
    try {
      // Carica neutral_inline.json (mapping semantico)
      final inlineJson = await rootBundle.loadString('lib/design system/theme/colors/neutral_inline.json');
      final inlineData = json.decode(inlineJson) as Map<String, dynamic>;

      // Carica neutral_rgb.json (valori RGB)
      final rgbJson = await rootBundle.loadString('lib/design system/theme/colors/neutral_rgb.json');
      final rgbData = json.decode(rgbJson) as Map<String, dynamic>;

      return {
        'inline': inlineData,
        'rgb': rgbData,
      };
    } catch (e) {
      throw Exception('Errore nel caricamento dei file colori: $e');
    }
  }

  /// Crea i token da una mappa di colori per una modalità specifica
  static GlobalTokens _createTokensFromMap(Map<String, dynamic> colorMap, String mode) {
    final inlineData = colorMap['inline'] as Map<String, dynamic>;
    final rgbData = colorMap['rgb'] as Map<String, dynamic>;
    final modeData = inlineData[mode] as Map<String, dynamic>;

    return GlobalTokens(
      background: _parseColor(modeData['background'], rgbData),
      foreground: _parseColor(modeData['foreground'], rgbData),
      card: _parseColor(modeData['card'], rgbData),
      cardForeground: _parseColor(modeData['card-foreground'], rgbData),
      popover: _parseColor(modeData['popover'], rgbData),
      popoverForeground: _parseColor(modeData['popover-foreground'], rgbData),
      primary: _parseColor(modeData['primary'], rgbData),
      primaryForeground: _parseColor(modeData['primary-foreground'], rgbData),
      secondary: _parseColor(modeData['secondary'], rgbData),
      secondaryForeground: _parseColor(modeData['secondary-foreground'], rgbData),
      muted: _parseColor(modeData['muted'], rgbData),
      mutedForeground: _parseColor(modeData['muted-foreground'], rgbData),
      accent: _parseColor(modeData['accent'], rgbData),
      accentForeground: _parseColor(modeData['accent-foreground'], rgbData),
      destructive: _parseColor(modeData['destructive'], rgbData),
      destructiveForeground: _parseColor(modeData['destructive-foreground'], rgbData),
      border: _parseColor(modeData['border'], rgbData),
      input: _parseColor(modeData['input'], rgbData),
      ring: _parseColor(modeData['ring'], rgbData),
    );
  }

  /// Converte un valore colore (stringa) in Color Flutter
  static Color _parseColor(String colorValue, Map<String, dynamic> rgbData) {
    // Se è "white", restituisce bianco
    if (colorValue == 'white') {
      return Colors.white;
    }

    // Se è un colore neutral-xxx, cerca nei dati RGB
    if (colorValue.startsWith('neutral-')) {
      final rgbString = rgbData[colorValue] as String?;
      if (rgbString != null) {
        return _parseRgbString(rgbString);
      }
    }

    // Se è red-xxx, usa i colori predefiniti
    if (colorValue.startsWith('red-')) {
      return _parseRedColor(colorValue);
    }

    // Fallback: nero
    return Colors.black;
  }

  /// Converte una stringa RGB "r g b" in Color
  static Color _parseRgbString(String rgbString) {
    final parts = rgbString.split(' ');
    if (parts.length == 3) {
      final r = int.tryParse(parts[0]) ?? 0;
      final g = int.tryParse(parts[1]) ?? 0;
      final b = int.tryParse(parts[2]) ?? 0;
      return Color.fromRGBO(r, g, b, 1.0);
    }
    return Colors.black;
  }

  /// Gestisce i colori red-xxx per destructive
  static Color _parseRedColor(String colorValue) {
    switch (colorValue) {
      case 'red-500':
        return const Color(0xFFEF4444); // red-500
      case 'red-900':
        return const Color(0xFF7F1D1D); // red-900
      default:
        return const Color(0xFFEF4444); // fallback red-500
    }
  }

  @override
  GlobalTokens copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? border,
    Color? input,
    Color? ring,
  }) {
    return GlobalTokens(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground: destructiveForeground ?? this.destructiveForeground,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
    );
  }

  @override
  ThemeExtension<GlobalTokens> lerp(ThemeExtension<GlobalTokens>? other, double t) {
    if (other is! GlobalTokens) return this;
    return GlobalTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      foreground: Color.lerp(foreground, other.foreground, t) ?? foreground,
      card: Color.lerp(card, other.card, t) ?? card,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t) ?? cardForeground,
      popover: Color.lerp(popover, other.popover, t) ?? popover,
      popoverForeground: Color.lerp(popoverForeground, other.popoverForeground, t) ?? popoverForeground,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryForeground: Color.lerp(primaryForeground, other.primaryForeground, t) ?? primaryForeground,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      secondaryForeground: Color.lerp(secondaryForeground, other.secondaryForeground, t) ?? secondaryForeground,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t) ?? mutedForeground,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t) ?? accentForeground,
      destructive: Color.lerp(destructive, other.destructive, t) ?? destructive,
      destructiveForeground: Color.lerp(destructiveForeground, other.destructiveForeground, t) ?? destructiveForeground,
      border: Color.lerp(border, other.border, t) ?? border,
      input: Color.lerp(input, other.input, t) ?? input,
      ring: Color.lerp(ring, other.ring, t) ?? ring,
    );
  }
}

/// Extension per accedere facilmente ai GlobalTokens dal BuildContext
extension GlobalTokensExtension on BuildContext {
  GlobalTokens get globalTokens {
    final tokens = Theme.of(this).extension<GlobalTokens>();
    if (tokens == null) {
      throw Exception('GlobalTokens non trovati nel tema. Assicurati di averli aggiunti al ThemeData.');
    }
    return tokens;
  }
}