import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; // <— per LogicalKeyboardKey e SingleActivator
import '../design system/components/top_bar.dart';
import '../design system/components/app_sidebar.dart';
import '../features/dashboard/widgets/status_banner.dart';
import '../features/search/data/global_search_repo.dart';
import '../design system/components/input_group.dart';
import '../design system/components/button.dart';
import '../design system/components/dialog.dart';
import '../design system/components/list_tile.dart';
import '../design system/components/spinner.dart';

import '../core/supa_helpers.dart';
import '../core/responsive.dart';
import '../core/firm_selection_service.dart';
import '../design system/theme/themes.dart';
import '../design system/components/topbar_styles.dart';
import '../design system/icons/app_icons.dart';
import '../design system/components/sonner.dart';
import 'dart:async' show unawaited;
import '../core/audit/audit_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasFirm = false;

  // Genera dinamicamente gli items in base alla firm selezionata
  List<_NavItem> _navItems() {
    final items = <_NavItem>[
      const _NavItem(
          index: 0,
          label: 'Clienti',
          route: '/clienti',
          icon: AppIcons.clients),
    ];
    if (_hasFirm) {
      items.add(const _NavItem(
          index: 1,
          label: 'Pratiche',
          route: '/matters/list',
          icon: AppIcons.matters));
    }
    return items;
  }

  int _indexFromLocation(String location) {
    final items = _navItems();
    final match = items.indexWhere((e) => location.startsWith(e.route));
    return match >= 0 ? match : 0;
  }

  @override
  void initState() {
    super.initState();
    // aspetta il primo frame per avere un context “valido”
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureFirmSelected(context).then((_) => _reloadFirmPresence());
    });
    // Prova subito a caricare la firm salvata
    _reloadFirmPresence();
  }

  Future<void> _reloadFirmPresence() async {
    final svc = FirmSelectionService();
    final firm = await svc.loadCurrentFirm();
    debugPrint(
        '[Nav] reloadFirmPresence: hasFirm=${firm != null} firmId=${firm?.id ?? 'null'}');
    if (mounted) setState(() => _hasFirm = firm != null);
  }

  void _onDestinationSelected(int index) {
    final item = _navItems()[index];
    if (GoRouterState.of(context).matchedLocation != item.route) {
      context.go(item.route);
    }
  }

  void _openSearch() {
    AppDialog.show(context, builder: (_) => const _GlobalSearchDialog());
  }

  void _openNotifications() {
    // Mostra Sonner info al click su Notifiche (anziché aprire il pannello)
    toastInfo(context, 'Funzionalità in fase di sviluppo, arriverà presto');
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const ActivateIntent(), // Cmd+K (mac)
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const ActivateIntent(), // Ctrl+K (win/linux)
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(onInvoke: (_) {
            _openSearch();
            return null;
          }),
        },
        child: Scaffold(
          key: _scaffoldKey,
          body: Row(
            children: [
              if (isDisplayDesktop(context))
                AppSidebar(
                  items: [
                    for (final it in _navItems())
                      AppSidebarItem(
                        icon: it.icon,
                        label: it.label,
                        onTap: () => _onDestinationSelected(it.index),
                      ),
                  ],
                  selectedIndex: _indexFromLocation(
                      GoRouterState.of(context).matchedLocation),
                  onSearch: (_) => _openSearch(),
                  // Al click su Impostazioni: non navigare, mostra Sonner info
                  onSettings: () => toastInfo(
                    context,
                    'Funzionalità in fasi di sviluppo, arriverà presto',
                  ),
                  onProfile: () => context.go('/account/profile'),
                  onLogout: () async {
                    await removeCurrentFirmId();
                    await Supabase.instance.client.auth.signOut();
                    // Audit: logout
                    unawaited(AuditService.logEvent(entity: 'auth', action: 'LOGOUT'));
                  },
                ),
              if (isDisplayDesktop(context)) const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    SafeArea(
                      top: true,
                      bottom: false,
                      child: Column(
                        children: [
                          const StatusBanner(), // Banner di stato: SEMPRE sopra la topbar
                          TopBar(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  _navItems()[_indexFromLocation(
                                          GoRouterState.of(context)
                                              .matchedLocation)]
                                      .icon,
                                ),
                                SizedBox(
                                    width: Theme.of(context)
                                            .extension<AppTopBarStyles>()
                                            ?.leadingGap ??
                                        8),
                                Text(
                                  _navItems()[_indexFromLocation(
                                          GoRouterState.of(context)
                                              .matchedLocation)]
                                      .label,
                                  style: Theme.of(context)
                                      .appBarTheme
                                      .titleTextStyle,
                                ),
                              ],
                            ),
                            showNotifications:
                                false, // icona notifiche già gestita negli actions
                            actions: [
                              IconButton(
                                tooltip: 'Notifiche',
                                icon: const Icon(AppIcons.notifications),
                                onPressed: _openNotifications,
                              ),
                            ],
                            // Rimosso menu utente con popup; icona profilo spostata nella Sidebar
                            userMenu: const SizedBox.shrink(),
                          ),
                          // (divider sotto la TopBar rimosso temporaneamente per ripristinare layout)
                        ],
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDisplayDesktop(context)
              ? null
              : NavigationBar(
                  selectedIndex: _indexFromLocation(
                      GoRouterState.of(context).matchedLocation),
                  onDestinationSelected: _onDestinationSelected,
                  destinations: [
                    for (final it in _navItems())
                      NavigationDestination(
                          icon: Icon(it.icon), label: it.label),
                  ],
                ),
        ),
      ),
    );
  }
}

/// --- Global Search dialog (skeleton) ---
class _GlobalSearchDialog extends StatefulWidget {
  const _GlobalSearchDialog();

  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  final _ctl = TextEditingController();
  bool _loading = false;
  Map<String, List<Map<String, dynamic>>> _res = {
    'clients': [],
    'matters': [],
    'invoices': [],
    'documents': []
  };

  Future<void> _run(String q) async {
    setState(() => _loading = true);
    try {
      final fid = await getCurrentFirmId();
      final repo = GlobalSearchRepo(Supabase.instance.client);
      _res = await repo.searchAll(q, fid);
    } catch (_) {
      _res = {'clients': [], 'matters': [], 'invoices': [], 'documents': []};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Cerca'),
          description: AppDialogDescription(
            'Trova rapidamente clienti, pratiche, fatture e documenti.',
          ),
        ),
        SizedBox(height: spacing * 2),
        AppInputGroup(
          controller: _ctl,
          hintText: 'Cerca clienti, pratiche, fatture, documenti…',
          onSubmitted: _run,
          leading: const Icon(AppIcons.search),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Spinner(size: 20),
          )
        else ...[
          SizedBox(height: spacing * 1.5),
          _Section(
            title: 'Clienti',
            items: _res['clients']!,
            onTap: (it) {
              Navigator.of(context).pop();
              context.go('/clienti');
            },
            subtitleKey: 'email',
            titleKey: 'name',
          ),
          _Section(
            title: 'Pratiche',
            items: _res['matters']!,
            onTap: (it) {
              Navigator.of(context).pop();
            },
            subtitleKey: 'code',
            titleKey: 'title',
          ),
          _Section(
            title: 'Fatture',
            items: _res['invoices']!,
            onTap: (it) {
              Navigator.of(context).pop();
            },
            subtitleKey: 'issue_date',
            titleKey: 'number',
          ),
          _Section(
            title: 'Documenti',
            items: _res['documents']!,
            onTap: (it) {
              Navigator.of(context).pop();
            },
            subtitleKey: 'matter_id',
            titleKey: 'filename',
          ),
        ],
        AppDialogFooter(
          children: [
            AppButton(
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onTap;
  final String titleKey;
  final String? subtitleKey;

  const _Section({
    required this.title,
    required this.items,
    required this.onTap,
    required this.titleKey,
    this.subtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...items.map((it) => AppListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${it[titleKey]}'),
              subtitle: subtitleKey != null ? Text('${it[subtitleKey]}') : null,
              onTap: () => onTap(it),
            )),
      ],
    );
  }
}

// Rimosso pannello notifiche non utilizzato per pulizia del codice

class _NavItem {
  final int index;
  final String label;
  final String route;
  final IconData icon;
  const _NavItem({
    required this.index,
    required this.label,
    required this.route,
    required this.icon,
  });
}
