// lib/core/supa_env.dart
// Wrapper per leggere le variabili di ambiente a COMPILE-TIME
// senza mai stampare valori sensibili.
// Usa le chiavi SUPABASE_URL / SUPABASE_ANON_KEY oppure
// le alternative corte SB_URL / SB_ANON se presenti.

class SupaEnv {
  static String get url => const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: String.fromEnvironment('SB_URL', defaultValue: ''),
      );

  static String get anonKey => const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: String.fromEnvironment('SB_ANON', defaultValue: ''),
      );
}
