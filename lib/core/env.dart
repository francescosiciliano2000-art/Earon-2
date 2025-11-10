import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static void _ensure() {
    if (!dotenv.isInitialized) {
      throw StateError(
          'dotenv non caricato: verifica dotenv.load(".env") in main().');
    }
  }

  static String get apiBase {
    _ensure();
    var v = dotenv.env['API_BASE_URL']?.trim();
    if (v == null || v.isEmpty) {
      throw StateError('API_BASE_URL mancante nel .env');
    }
    if (!v.endsWith('/')) v = '$v/';
    return v;
  }

  static String get supabaseUrl {
    _ensure();
    final v = dotenv.env['SUPABASE_URL']?.trim();
    if (v == null || v.isEmpty) {
      throw StateError(
          'SUPABASE_URL mancante nel .env (es: https://<ref>.supabase.co)');
    }
    return v;
  }

  static String? get supabaseAnon {
    _ensure();
    return dotenv.env['SUPABASE_ANON_KEY']?.trim();
  }

  static String? get defaultFirmId {
    _ensure();
    return dotenv.env['DEFAULT_FIRM_ID']?.trim();
  }
}
