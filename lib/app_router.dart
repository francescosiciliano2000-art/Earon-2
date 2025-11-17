// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_state_notifier.dart';

import 'shell/adaptive_shell.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/clienti/presentation/clienti_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/forgot_password_page.dart';
import 'features/auth/presentation/select_firm_page.dart';
// import 'features/auth/presentation/onboarding_checklist_page.dart'; // disabilitato temporaneamente
import 'features/matters/presentation/matters_list_page.dart';
import 'features/matters/presentation/matter_detail_page.dart';
// import 'features/agenda/presentation/agenda_page.dart';
import 'features/expenses/presentation/spese_page.dart';
import 'features/invoices/presentation/fatture_page.dart';
import 'features/notifications/presentation/notifiche_page.dart';
import 'features/account/presentation/profile_page.dart';
import 'features/account/presentation/preferences_page.dart';
import 'features/agenda/presentation/tasks_page.dart';
import 'features/agenda/presentation/tasks_list_page.dart';
// import 'features/agenda/presentation/task_edit_page.dart'; // rimosso: edit ora via dialog
import 'features/agenda/presentation/hearings_list_page.dart';
import 'features/agenda/presentation/hearings_calendar_page.dart';
// import 'features/agenda/presentation/ui_test_page.dart'; // temporaneamente disabilitato – file non esistente
// import 'features/agenda/presentation/hearing_edit_page.dart'; // rimosso: edit ora via dialog

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: '/clienti',
  refreshListenable: authStateNotifier,
  // Redirect minimale: se non autenticato vai a /auth/login
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loggingIn = state.matchedLocation.startsWith('/auth');

    if (session == null) {
      // Non autenticato → consenti solo rotte /auth/*
      return loggingIn ? null : '/auth/login';
    }

    // Se autenticato, evita di restare sulle pagine di login/forgot
    if (loggingIn && state.matchedLocation != '/auth/select_firm') {
      return '/clienti';
    }

    // Redirect di default: la pagina Udienze apre la vista Calendario
    if (state.matchedLocation == '/agenda/udienze') {
      return '/agenda/udienze/calendar';
    }

    return null; // nessun redirect
  },
  routes: [
    // ---- AUTH (fuori dallo shell) ----
    GoRoute(
      path: '/auth/login',
      name: 'login',
      pageBuilder: (ctx, st) => const MaterialPage(child: LoginPage()),
    ),
    GoRoute(
      path: '/auth/forgot',
      name: 'forgot',
      pageBuilder: (ctx, st) => const MaterialPage(child: ForgotPasswordPage()),
    ),
    GoRoute(
      path: '/auth/select_firm',
      name: 'select_firm',
      pageBuilder: (ctx, st) => const MaterialPage(child: SelectFirmPage()),
    ),
    // GoRoute(
    //   path: '/onboarding/checklist',
    //   name: 'onboarding_checklist',
    //   pageBuilder: (ctx, st) =>
    //       const MaterialPage(child: OnboardingChecklistPage()),
    // ),

    // ---- APP SHELL + rotte annidate ----
    ShellRoute(
      builder: (context, state, child) => AdaptiveShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          pageBuilder: (ctx, st) => const MaterialPage(child: DashboardPage()),
        ),
        // ---- MATTERS ----
        GoRoute(
          path: '/matters/list',
          name: 'matters_list',
          pageBuilder: (ctx, st) =>
              const MaterialPage(child: MattersListPage()),
        ),
        GoRoute(
          path: '/matters/detail/:id',
          name: 'matter_detail',
          pageBuilder: (ctx, st) {
            final id = st.pathParameters['id'] ?? '';
            return MaterialPage(child: MatterDetailPage(matterId: id));
          },
        ),
        GoRoute(
          path: '/clienti',
          name: 'clienti',
          pageBuilder: (ctx, st) => const MaterialPage(child: ClientiPage()),
        ),
        // ---- MAIN SECTIONS ----
        GoRoute(
          path: '/agenda',
          name: 'agenda',
          pageBuilder: (ctx, st) => const MaterialPage(child: TasksPage()),
        ),
        // ---- AGENDA SUB-MODULES ----
        GoRoute(
          path: '/agenda/tasks',
          name: 'agenda_tasks',
          pageBuilder: (ctx, st) => const MaterialPage(child: TasksPage()),
        ),
        GoRoute(
          path: '/agenda/tasks/list',
          name: 'agenda_tasks_list',
          pageBuilder: (ctx, st) => const MaterialPage(child: TasksListPage()),
        ),
        // Route rimossa: edit task gestito via dialog

        GoRoute(
          path: '/agenda/udienze',
          name: 'agenda_udienze',
          pageBuilder: (ctx, st) => const MaterialPage(child: HearingsListPage()),
        ),
        // Alias esplicito per l'elenco (serve a bypassare il redirect di default verso il calendario)
        GoRoute(
          path: '/agenda/udienze/list',
          name: 'agenda_udienze_list',
          pageBuilder: (ctx, st) => const MaterialPage(child: HearingsListPage()),
        ),
        GoRoute(
          path: '/agenda/udienze/calendar',
          name: 'agenda_udienze_calendar',
          pageBuilder: (ctx, st) => const MaterialPage(child: HearingsCalendarPage()),
        ),
        // Percorso di test rimosso
        // Route rimossa: edit udienza gestito via dialog


        GoRoute(
          path: '/spese',
          name: 'spese',
          pageBuilder: (ctx, st) => const MaterialPage(child: SpesePage()),
        ),
        GoRoute(
          path: '/fatture',
          name: 'fatture',
          pageBuilder: (ctx, st) => const MaterialPage(child: FatturePage()),
        ),
        GoRoute(
          path: '/notifiche',
          name: 'notifiche',
          pageBuilder: (ctx, st) => const MaterialPage(child: NotifichePage()),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (ctx, st) =>
              const MaterialPage(child: PreferencesPage()),
        ),
        // ---- ACCOUNT PAGES ----
        GoRoute(
          path: '/account/profile',
          name: 'account_profile',
          pageBuilder: (ctx, st) => const MaterialPage(child: ProfilePage()),
        ),
        GoRoute(
          path: '/account/preferences',
          name: 'account_preferences',
          pageBuilder: (ctx, st) =>
              const MaterialPage(child: PreferencesPage()),
        ),
      ],
    ),
  ],
  errorPageBuilder: (context, state) => MaterialPage(
    child: Scaffold(
      body: Center(child: Text('Errore di routing: ${state.error}')),
    ),
  ),
);
