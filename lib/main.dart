import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_router.dart';
// import 'theme/app_theme.dart';
import 'design system/theme/themes.dart';
import 'design system/theme/theme_builder.dart';
import 'design system/components/sonner.dart';
import 'core/supa_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[App] start');

  // 1) Carica .env
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[Config] dotenv loaded from assets .env');
  } catch (e) {
    // Non bloccare l’avvio: useremo i valori di compile-time (SupaEnv)
    debugPrint('[Config] dotenv load failed: $e — fallback to --dart-define (SupaEnv)');
  }

  // Inizializza dati di localizzazione per Intl (mesi/giorni in italiano)
  await initializeDateFormatting('it_IT');
  Intl.defaultLocale = 'it_IT';

  // Assicurati che i font Google siano pre-bundled (offline) e non caricati a runtime
  GoogleFonts.config.allowRuntimeFetching = false;

  // Traccia configurazione (senza stampare valori sensibili)
  final dotenvLoaded = dotenv.isInitialized;
  debugPrint('[Config] dotenv loaded=$dotenvLoaded');

  // Sorgente valori: preferisci dotenv, altrimenti compile-time (SupaEnv)
  final envUrl = dotenvLoaded ? (dotenv.env['SUPABASE_URL']?.trim() ?? '') : '';
  final envAnon = dotenvLoaded ? (dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '') : '';
  final ctUrl = SupaEnv.url.trim();
  final ctAnon = SupaEnv.anonKey.trim();
  final supabaseUrl = envUrl.isNotEmpty ? envUrl : ctUrl;
  final supabaseAnon = envAnon.isNotEmpty ? envAnon : ctAnon;

  debugPrint('[Config] Supabase URL source=${envUrl.isNotEmpty ? 'dotenv:SUPABASE_URL' : 'fromEnvironment:SUPABASE_URL/SB_URL'}');
  debugPrint('[Config] Supabase anon key source=${envAnon.isNotEmpty ? 'dotenv:SUPABASE_ANON_KEY' : 'fromEnvironment:SUPABASE_ANON_KEY/SB_ANON'}');

  if (supabaseUrl.isEmpty || supabaseAnon.isEmpty) {
    throw StateError(
        'Supabase config mancante: assicurati di valorizzare SUPABASE_URL e SUPABASE_ANON_KEY (oppure SB_URL/SB_ANON) via .env o --dart-define.');
  }

  // 2) Inizializza Supabase una sola volta qui
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnon,
    debug: true,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  debugPrint('[Supabase] initialized');

  // Log "sicuro" della sessione
  final session = Supabase.instance.client.auth.currentSession;
  final uid = session?.user.id;
  final email = session?.user.email;
  debugPrint(
      '[Auth] session loaded: uid=${uid ?? 'null'} email=${email ?? 'null'}');

  // 3) Prepara temi con GlobalTokens e avvia app
  final lightWithTokens = await ThemeBuilder.createLightTheme();
  final darkWithTokens = await ThemeBuilder.createDarkTheme();
  final lightTheme = DefaultTheme.apply(lightWithTokens);
  final darkTheme = DefaultTheme.apply(darkWithTokens);
  runApp(GestionaleApp(lightTheme: lightTheme, darkTheme: darkTheme));
}

class GestionaleApp extends StatelessWidget {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  const GestionaleApp({super.key, required this.lightTheme, required this.darkTheme});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gestionale',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter, // GoRouter
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Stack(
        children: [
          child!,
          AppToaster(key: AppToaster.globalKey),
        ],
      ),
    );
  }
}
