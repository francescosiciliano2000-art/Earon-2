import 'package:flutter/material.dart';
import 'global_theme.dart';
import 'global_tokens.dart';

/// ThemeBuilder: integra GlobalTokens nel sistema tema esistente
/// Fornisce un'interfaccia semplice per creare temi con token globali coerenti
class ThemeBuilder {
  /// Crea un tema light con GlobalTokens integrati
  static Future<ThemeData> createLightTheme() async {
    // Carica i token globali per la modalità light
    final globalTokens = await GlobalTokens.loadLight();
    
    // Ottieni il tema base da GlobalTheme
    final baseTheme = GlobalTheme.lightNeutrals();
    
    // Integra i GlobalTokens nelle extensions esistenti
    final extensions = List<ThemeExtension<dynamic>>.from(baseTheme.extensions.values);
    extensions.add(globalTokens);
    
    return baseTheme.copyWith(extensions: extensions);
  }

  /// Crea un tema dark con GlobalTokens integrati
  static Future<ThemeData> createDarkTheme() async {
    // Carica i token globali per la modalità dark
    final globalTokens = await GlobalTokens.loadDark();
    
    // Ottieni il tema base da GlobalTheme
    final baseTheme = GlobalTheme.dark();
    
    // Integra i GlobalTokens nelle extensions esistenti
    final extensions = List<ThemeExtension<dynamic>>.from(baseTheme.extensions.values);
    extensions.add(globalTokens);
    
    return baseTheme.copyWith(extensions: extensions);
  }

  /// Applica preset al tema con GlobalTokens
  static ThemeData applyPresets({
    required ThemeData themeWithTokens,
    ShadcnMode mode = ShadcnMode.light,
    bool mono = false,
    bool scaled = false,
    ShadcnRounded rounded = ShadcnRounded.medium,
    ShadcnFont font = ShadcnFont.system,
    ShadcnAccent? accent,
  }) {
    return ShadcnThemePresets.apply(
      base: themeWithTokens,
      mode: mode,
      mono: mono,
      scaled: scaled,
      rounded: rounded,
      font: font,
      accent: accent,
    );
  }
}

/// Extension per accesso rapido ai token dal BuildContext
extension ThemeBuilderExtension on BuildContext {
  /// Accesso rapido ai GlobalTokens
  GlobalTokens get tokens => globalTokens;
  
  /// Verifica se il tema corrente è dark
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  /// Accesso rapido ai colori semantici più comuni
  Color get backgroundColor => tokens.background;
  Color get foregroundColor => tokens.foreground;
  Color get primaryColor => tokens.primary;
  Color get secondaryColor => tokens.secondary;
  Color get mutedColor => tokens.muted;
  Color get borderColor => tokens.border;
  Color get ringColor => tokens.ring;
}