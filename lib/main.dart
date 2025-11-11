import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:auto_updater/auto_updater.dart';
import 'package:window_manager/window_manager.dart';

import 'app_router.dart';
// import 'theme/app_theme.dart';
import 'design system/theme/themes.dart';
import 'design system/theme/theme_builder.dart';
import 'design system/components/sonner.dart';
import 'core/supa_env.dart';

Future<void> setupAutoUpdater() async {
  if (!(Platform.isMacOS || Platform.isWindows)) return;

  const feedURLFromEnv =
      String.fromEnvironment('APPCAST_URL', defaultValue: '');
  // Fallback: se il secrets APPCAST_URL non è configurato, usa l’URL raw del repo
  const defaultFeedURL =
      'https://raw.githubusercontent.com/francescosiciliano2000-art/Earon-2/main/updates/appcast.xml';
  final feedURL = feedURLFromEnv.isNotEmpty ? feedURLFromEnv : defaultFeedURL;

  await autoUpdater.setFeedURL(feedURL);
  await autoUpdater.checkForUpdates();
}

/// Prova a caricare automaticamente il file .env in debug da diversi percorsi
/// comuni. Non blocca l'avvio in caso di fallimento.
Future<bool> _loadDotenvAdaptive() async {
  const candidates = [
    '.env', // root progetto (flutter run)
    'assets/.env', // se preferisci mantenerlo in assets
    '../.env', // avvio da sottocartelle
    '../../.env',
  ];
  for (final p in candidates) {
    try {
      await dotenv.load(fileName: p);
      debugPrint('[Config] dotenv loaded from $p');
      return true;
    } catch (_) {
      // tenta prossimo percorso
    }
  }
  debugPrint('[Config] dotenv load failed in all candidates: $candidates');
  return false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  debugPrint('[App] start');

  // Logga le eccezioni in release per evitare schermate bianche silenziose
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
      final st = details.stack?.toString() ?? '';
      if (st.isNotEmpty) debugPrint(st);
    } else {
      FlutterError.presentError(details);
    }
  };

  // 1) Carica .env (in debug, automatico) senza bloccare l'avvio
  final dotenvLoaded = await _loadDotenvAdaptive();

  // Inizializza dati di localizzazione per Intl (mesi/giorni in italiano)
  await initializeDateFormatting('it_IT');
  Intl.defaultLocale = 'it_IT';

  // Assicurati che i font Google siano pre-bundled (offline) e non caricati a runtime
  GoogleFonts.config.allowRuntimeFetching = false;

  // Traccia configurazione (senza stampare valori sensibili)
  debugPrint('[Config] dotenv loaded=${dotenv.isInitialized}');

  // Sorgente valori: preferisci dotenv, altrimenti compile-time (SupaEnv)
  final envUrl = dotenvLoaded ? (dotenv.env['SUPABASE_URL']?.trim() ?? '') : '';
  final envAnon =
      dotenvLoaded ? (dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '') : '';
  final ctUrl = SupaEnv.url.trim();
  final ctAnon = SupaEnv.anonKey.trim();
  final supabaseUrl = envUrl.isNotEmpty ? envUrl : ctUrl;
  final supabaseAnon = envAnon.isNotEmpty ? envAnon : ctAnon;

  debugPrint(
      '[Config] Supabase URL source=${envUrl.isNotEmpty ? 'dotenv:SUPABASE_URL' : 'fromEnvironment:SUPABASE_URL/SB_URL'}');
  debugPrint(
      '[Config] Supabase anon key source=${envAnon.isNotEmpty ? 'dotenv:SUPABASE_ANON_KEY' : 'fromEnvironment:SUPABASE_ANON_KEY/SB_ANON'}');

  if (supabaseUrl.isEmpty || supabaseAnon.isEmpty) {
    // In release o debug: mostra una schermata chiara invece di crashare
    runApp(const ConfigErrorApp());
    // Imposta comunque la finestra per evitare schermo nero
    if (Platform.isMacOS || Platform.isWindows) {
      await windowManager.waitUntilReadyToShow(const WindowOptions(
        size: Size(1024, 700),
        center: true,
        titleBarStyle: TitleBarStyle.normal,
      ), () async {
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      });
    }
    return; // termina main evitando inizializzazione Supabase
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

  // avvia il controllo update senza bloccare la UI
  unawaited(setupAutoUpdater());

  // Imposta massimizzazione all'avvio (macOS/Windows)
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.waitUntilReadyToShow(const WindowOptions(
      // In caso di fallback, imposta dimensione iniziale e centra
      size: Size(1280, 800),
      center: true,
      // Su macOS mantiene la barra del titolo standard; su Windows non influisce
      titleBarStyle: TitleBarStyle.normal,
    ), () async {
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

class GestionaleApp extends StatelessWidget {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  const GestionaleApp(
      {super.key, required this.lightTheme, required this.darkTheme});

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

/// App minimale di errore configurazione per rilasci senza variabili richieste.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configurazione mancante',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Configurazione mancante')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Supabase config mancante',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Assicurati di valorizzare SUPABASE_URL e SUPABASE_ANON_KEY (oppure SB_URL/SB_ANON).',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'In debug: crea/compila un file .env nella root con SUPABASE_URL, SUPABASE_ANON_KEY e (opzionale) APPCAST_URL.\n'
                  'In release: passa i valori via --dart-define nei workflow GitHub Actions.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
