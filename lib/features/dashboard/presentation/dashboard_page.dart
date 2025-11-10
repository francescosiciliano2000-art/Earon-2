import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supa_helpers.dart';
import '../data/dashboard_repo.dart';
import '../widgets/kpi_cards.dart';
import '../../../core/responsive.dart';

// import '../widgets/quick_filters.dart'; // Filtri globali rimossi dalla dashboard
import '../../../design system/components/tabs.dart';
import '../../../design system/icons/app_icons.dart';
import 'package:gestionale_desktop/features/agenda/presentation/task_edit_dialog.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_edit_dialog.dart';
// import 'package:gestionale_desktop/theme/tokens.dart'; // legacy; sostituito da DefaultTokens in themes.dart
// Design System imports
import '../../../design system/components/button.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/components/switch.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/card.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/components/list_tile.dart';
import '../../../design system/components/dialog.dart';
// import '../widgets/onboarding_banner.dart'; // temporaneamente disabilitato (banner onboarding nascosto)
import '../../../design system/theme/theme_builder.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final _repo = DashboardRepo(Supabase.instance.client);

  bool onlyMine = false;
  int rangeDays = 7;
  // Filtri locali per il blocco Memorandum (scoperti solo sulla lista memorandum)
  bool memoOnlyMine = false;
  int memoRangeDays = 7;
  bool _showCompletedDue = false; // switch Memorandum: mostra completate
  bool _loadingDue = false; // mini caricamento solo dentro la card Memorandum
  
  bool loading = true;
  String? error;

  // Data
  Map<String, num> kpis = {
    'billable_hours': 0,
    'invoices_issued_month': 0,
    'receivables_open': 0
  };
  List<Map<String, dynamic>> hearings = [];
  List<Map<String, dynamic>> due = [];
  Map<DateTime, List<Map<String, dynamic>>> calendarItems = {};
  // Serie mensile per grafico "Da incassare"
  List<Map<String, dynamic>> receivablesMonthly = [];
  // Label cache per chips nelle tile Memorandum
  final Map<String, String> _assigneeLabels = {};
  final Map<String, String> _matterLabels = {};
  final Map<String, String> _matterTitles = {};

  // bool onboardingIncomplete =
  //     true; // placeholder: collegheremo a DB/SharedPrefs (disabilitato temporaneamente)

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // 1) Prova a prendere la firm
      String? fid = await getCurrentFirmId();

      // 2) Se manca, prova ad auto-fixare (SelectFirm o auto-selezione)
      if (fid == null || fid.isEmpty) {
        if (mounted) await ensureFirmSelected(context);
        fid = await getCurrentFirmId();
      }

      // 3) Se ancora manca → stato “no_firm” (gestito nel build)
      if (fid == null || fid.isEmpty) {
        setState(() {
          loading = false;
          error = 'NO_FIRM';
        });
        return;
      }

      // 4) Ora abbiamo un firmId NON NULL
      final firmId = fid;

      final res = await Future.wait([
        _repo.fetchKpis(firmId),
        _repo.nextHearings(firmId, days: rangeDays, limit: 5),
        // Memorandum usa i filtri locali
        _repo.dueTasks(firmId, days: memoRangeDays, onlyMine: memoOnlyMine, includeDone: _showCompletedDue),
        _repo.calendar(firmId, days: rangeDays, onlyMine: onlyMine),
        _repo.receivablesMonthlySeries(firmId, months: 6),
      ]);
      kpis = res[0] as Map<String, num>;
      hearings = List<Map<String, dynamic>>.from(res[1] as List);
      due = List<Map<String, dynamic>>.from(res[2] as List);
      calendarItems =
          Map<DateTime, List<Map<String, dynamic>>>.from(res[3] as Map);
      receivablesMonthly = List<Map<String, dynamic>>.from(res[4] as List);

      // Prepara etichette per assegnatario e pratica nelle tile Memorandum
      await _loadLabelsForDue(due);
    } catch (e) {
      // debug: stampa l’errore reale
      debugPrint('[DashboardPage] load error -> $e');
      error = 'LOAD_ERROR';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadLabelsForDue(List<Map<String, dynamic>> list) async {
    try {
      final Set<String> missMatter = {};
      final Set<String> missAssign = {};
      for (final t in list) {
        final mid = '${t['matter_id'] ?? ''}';
        if (mid.isNotEmpty && !_matterLabels.containsKey(mid)) missMatter.add(mid);
        final uid = '${t['assignee_id'] ?? ''}';
        if (uid.isNotEmpty && !_assigneeLabels.containsKey(uid)) missAssign.add(uid);
      }
      if (missMatter.isNotEmpty) {
        final res = await _repo.sb
            .from('matters')
            .select('matter_id, code, title')
            .inFilter('matter_id', missMatter.toList());
        for (final m in (res as List).cast<Map<String, dynamic>>()) {
          final id = (m['matter_id']).toString();
          final code = (m['code'] ?? '').toString();
          final title = (m['title'] ?? '').toString();
          final label = [code, title].where((s) => s.isNotEmpty).join(' — ');
          if (id.isNotEmpty) {
            _matterLabels[id] = label.isNotEmpty ? label : id;
            _matterTitles[id] = title.isNotEmpty ? title : id;
          }
        }
      }
      if (missAssign.isNotEmpty) {
        final res = await _repo.sb
            .from('profiles')
            .select('user_id, full_name')
            .inFilter('user_id', missAssign.toList());
        for (final p in (res as List).cast<Map<String, dynamic>>()) {
          final id = (p['user_id']).toString();
          final name = (p['full_name'] ?? '').toString();
          if (id.isNotEmpty) _assigneeLabels[id] = name.isNotEmpty ? name : id;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // silent
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Removed unused methods: _updateOnlyMine, _updateRange

  // --- Filtri locali Memorandum ---
  void _updateMemoOnlyMine(bool v) async {
    setState(() => memoOnlyMine = v);
    await _loadDueOnly();
  }

  void _updateMemoRange(int d) async {
    setState(() => memoRangeDays = d);
    await _loadDueOnly();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: Spinner(size: 24));
    }

    // Se non c'è ancora una firm selezionata, mostra una CTA chiara
    if (error == 'NO_FIRM') {
      final double gap = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleziona uno studio per continuare'),
            SizedBox(height: gap),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: () => context.go('/auth/select_firm'),
              child: const Text('Scegli studio'),
            ),
          ],
        ),
      );
    }

    if (error == 'LOAD_ERROR') {
      return Center(
          child: Text(
        'Impossibile caricare la dashboard.',
        style: Theme.of(context)
            .textTheme
            .bodySmall!
            .copyWith(color: Theme.of(context).colorScheme.error),
      ));
    }

    // Layout: top -> banner + kpi; bottom -> udienze/memorandum
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // OnboardingBanner(show: onboardingIncomplete), // temporaneamente nascosto
            Padding(
              padding: EdgeInsets.only(
                top: unit * 2,
                left: unit * 2,
                right: unit * 2,
              ),
              child: KpiCards(
                kpis: kpis,
                isWide: isDisplayDesktop(context),
                receivablesMonthly: receivablesMonthly,
              ),
            ),
            SizedBox(height: unit * 0.75),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: unit * 2).copyWith(
                  top: unit * 0.75,
                  bottom: unit * 0.75,
                ),
                child: _twoCols(
                  leftBuilder: (h) => _hearingsCard(height: h - unit),
                  rightBuilder: (h) => _memorandumCard(height: h - unit),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  // Header in stile KPI (icona + titolo, scala +20%)
  Widget _metricTitleRow(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 18 * 1.2),
        SizedBox(width: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 0.5),
        Builder(
          builder: (_) {
            final base = theme.textTheme.labelLarge;
            final fs = base?.fontSize;
            return Text(
              title,
              style: base?.copyWith(fontSize: fs != null ? fs * 1.2 : null),
            );
          },
        ),
      ],
    );
  }

  // Formatter date coerenti con Agenda
  String _fmtDate(dynamic iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  String _fmtDateTime(dynamic iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse('$iso').toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year} $hh:$mi';
    } catch (_) {
      return '—';
    }
  }


  Color? _priorityColor(dynamic p) {
    final s = '$p'.toLowerCase().trim();
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case 'high':
      case '2':
        return cs.error;
      case 'normal':
      case '1':
        return cs.primary;
      case 'low':
      case '0':
        return cs.secondary;
      default:
        return cs.secondary;
    }
  }

  // Tile udienza in stile Agenda
  Widget _hearingAppListTile(Map<String, dynamic> h) {
    final date = _fmtDateTime(h['date']);
    final courtroom = h['court'] != null && '${h['court']}'.isNotEmpty
        ? 'Aula: ${h['court']}'
        : null;
    return AppListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0)),
      leading: const Icon(AppIcons.gavel),
      title: Text('${h['subject'] ?? 'Udienza'}'),
      subtitle: Text(courtroom != null ? '$date • $courtroom' : date),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () {
        final id = '${h['id'] ?? ''}';
        if (id.isEmpty) return;
        AppDialog.show(
          context,
          builder: (ctx) => HearingEditDialog(hearingId: id),
        );
      },
    );
  }

  Future<void> _toggleDone(Map<String, dynamic> t, bool done) async {
    final id = '${t['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await _repo.sb.from('tasks').update({'done': done}).eq('task_id', id);
      if (!mounted) return;
      setState(() {
        // Rimuovi dalla lista dei "due" se completata
        if (done) {
          due.removeWhere((e) => '${e['id']}' == id);
        }
      });
    } catch (e) {
      debugPrint('[DashboardPage] toggle done error: $e');
    }
  }

  // Tile task in stile Agenda (senza checkbox selezione, senza modifica/elimina)
  Widget _taskAppListTile(Map<String, dynamic> t) {
    final title = '${t['title'] ?? ''}';
    final dueDate = _fmtDate(t['due_date']);
    final pr = t['priority'];
    final done = '${t['status']}' == 'done';
    final Color prColor = _priorityColor(pr) ?? Theme.of(context).colorScheme.secondary;
    final gt = context.tokens;
    final Color barColor = done ? gt.muted : prColor;
    final assigneeId = '${t['assignee_id'] ?? ''}';
    final matterId = '${t['matter_id'] ?? ''}';
    final assigneeLabel = assigneeId.isNotEmpty
        ? (_assigneeLabels[assigneeId] ?? assigneeId)
        : '';
    final matterLabel = matterId.isNotEmpty
        ? (_matterLabels[matterId] ?? matterId)
        : '';
    final matterTitleOnly = matterId.isNotEmpty
        ? (_matterTitles[matterId] ?? matterLabel)
        : '';
    

    // Barra priorità: 70% altezza, centrata verticalmente, più spessa e arrotondata
    const double barWidth = 6.0; // più spessa rispetto a prima
    const double barRadius = 4.0; // angoli leggermente arrotondati
    final double unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final double barInset = unit * 1.5; // spaziatura dal bordo sinistro della card
    final double leftPad = barInset + barWidth + 8.0 + unit; // padding contenuto a sinistra evitando sovrapposizione

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Theme.of(context).extension<DefaultTokens>()?.radiusSm ?? BorderRadius.circular(6),
        side: BorderSide(color: gt.border),
      ),
      color: done ? gt.muted : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () {
          final id = '${t['id'] ?? ''}';
          if (id.isEmpty) return;
          AppDialog.show(
            context,
            builder: (_) => TaskEditDialog(taskId: id),
          );
        },
        child: IntrinsicHeight(
          child: Stack(
            children: [
              // Contenuto della riga con padding maggiorato a sinistra
              Padding(
                padding: EdgeInsets.fromLTRB(leftPad, unit, unit, unit),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: done ? gt.mutedForeground : Theme.of(context).colorScheme.onSurface,
                                    decoration: done ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.schedule, size: 16, color: done ? gt.mutedForeground : null),
                                  const SizedBox(width: 4),
                                  Text(
                                    dueDate,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: done ? gt.mutedForeground : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (assigneeLabel.isNotEmpty)
                                Chip(
                                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                                  avatar: Icon(AppIcons.person, size: 16, color: Theme.of(context).colorScheme.onTertiary),
                                  label: Text(
                                    assigneeLabel,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onTertiary,
                                    ),
                                  ),
                                ),
                              if (matterTitleOnly.isNotEmpty)
                                Tooltip(
                                  message: matterTitleOnly,
                                  child: Chip(
                                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                                    avatar: Icon(AppIcons.folder, size: 16, color: Theme.of(context).colorScheme.onTertiary),
                                    label: Text(
                                      matterTitleOnly,
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: done ? 'Segna come da fare' : 'Completa',
                          icon: Icon(
                            AppIcons.checklist,
                          ),
                          color: done ? gt.mutedForeground : Theme.of(context).colorScheme.primary,
                          onPressed: () => _toggleDone(t, !done),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Barra priorità a sinistra: 70% dell'altezza della riga, centrata e distanziata dal bordo
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 1.5),
                  child: FractionallySizedBox(
                    heightFactor: 0.7,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: barWidth,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(barRadius),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card Udienze (ex "In scadenza")
  Widget _hearingsCard({double? height}) {
    final double cardHeight = height ?? _sectionCardHeight(context);
    final radii = Theme.of(context).extension<ShadcnRadii>()?.lg ?? BorderRadius.circular(12);
    return SizedBox(
      height: cardHeight,
      child: AppCard(
        header: AppCardHeader(
          title: AppCardTitle(_metricTitleRow(context, AppIcons.gavel, 'Udienze')),
        ),
        content: Expanded(
          child: AppCardContent(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 1.0),
              Expanded(
                child: ClipRRect(
                  borderRadius: radii,
                  child: hearings.isEmpty
                      ? _buildCardEmptyState(
                          context,
                          message: 'Nessuna udienza imminente',
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: hearings.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _hearingAppListTile(hearings[i]),
                        ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  // Card Memorandum (tasks imminenti)
  Widget _memorandumCard({double? height}) {
    final double cardHeight = height ?? _sectionCardHeight(context);
    final radii = Theme.of(context).extension<ShadcnRadii>()?.lg ?? BorderRadius.circular(12);
    return SizedBox(
      height: cardHeight,
      child: AppCard(
        header: AppCardHeader(
          title: AppCardTitle(_metricTitleRow(context, AppIcons.lightbulb, 'Memorandum')),
          action: Row(
            children: [
              const Text('Mostra completate'),
              SizedBox(width: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0)),
              AppSwitch(
                value: _showCompletedDue,
                onChanged: (v) async {
                  setState(() => _showCompletedDue = v);
                  await _loadDueOnly();
                },
              ),
            ],
          ),
        ),
        content: Expanded(
          child: AppCardContent(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingDue) const AppProgressBar(minHeight: 2),
              SizedBox(height: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0)),
              // Filtri locali per Memorandum: "Solo mie" + tabs 7gg/30gg
              Row(
                children: [
                  FilterChip(
                    label: const Text('Solo mie'),
                    selected: memoOnlyMine,
                    onSelected: (v) => _updateMemoOnlyMine(v),
                  ),
                  SizedBox(width: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0)),
                  Tabs(
                    axis: Axis.horizontal,
                    value: '$memoRangeDays',
                    onValueChange: (v) {
                      final next = int.tryParse(v) ?? 7;
                      _updateMemoRange(next);
                    },
                    child: TabsList(
                      children: const [
                        TabsTrigger(value: '7', child: Text('7gg')),
                        TabsTrigger(value: '30', child: Text('30gg')),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0)),
              Expanded(
                child: ClipRRect(
                  borderRadius: radii,
                  child: due.isEmpty
                      ? _buildCardEmptyState(
                          context,
                          message: 'Nessun memorandum imminente',
                          onReset: () {
                            _updateMemoOnlyMine(false);
                            _updateMemoRange(7);
                          },
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: due.length,
                          itemBuilder: (_, i) => _taskAppListTile(due[i]),
                          separatorBuilder: (_, __) => SizedBox(
                            height: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 1.5,
                          ),
                        ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadDueOnly() async {
    setState(() => _loadingDue = true);
    try {
      String? fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        if (mounted) await ensureFirmSelected(context);
        fid = await getCurrentFirmId();
      }
      if (fid == null || fid.isEmpty) {
        if (mounted) setState(() => _loadingDue = false);
        return;
      }
      final firmId = fid;
      final res = await _repo.dueTasks(
        firmId,
        // Usa esclusivamente i filtri locali del Memorandum
        days: memoRangeDays,
        onlyMine: memoOnlyMine,
        includeDone: _showCompletedDue,
      );
      setState(() {
        due = List<Map<String, dynamic>>.from(res);
      });
      await _loadLabelsForDue(due);
    } catch (e) {
      debugPrint('[DashboardPage] load due-only error -> $e');
    } finally {
      if (mounted) setState(() => _loadingDue = false);
    }
  }
  Widget _twoCols({required Widget Function(double availableHeight) leftBuilder, required Widget Function(double availableHeight) rightBuilder}) {
    return LayoutBuilder(
      builder: (context, c) {
        final unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
        // Tablet e mobile: layout a colonna; Desktop: due colonne.
        if (!isDisplayDesktop(context)) {
          final h = _sectionCardHeight(context);
          return Column(
            children: [
              leftBuilder(h),
              SizedBox(height: unit * 1.5),
              rightBuilder(h),
            ],
          );
        }
        final h = c.maxHeight;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leftBuilder(h)),
            SizedBox(width: unit * 1.5),
            Expanded(child: rightBuilder(h)),
          ],
        );
      },
    );
  }

  // Altezza fissa per i blocchi Udienze/Memorandum con scroll interno.
  double _sectionCardHeight(BuildContext context) {
    if (isDisplayDesktop(context)) return 420; // desktop: ottimo per far entrare la pagina
    if (isDisplayTablet(context)) return 360;  // tablet: leggermente ridotto
    return 320;                                // mobile: compatto
  }

  // Empty state coerente con liste/tabelle (icona inbox + messaggio + opzionale azzera filtri)
  Widget _buildCardEmptyState(BuildContext context,
      {required String message, VoidCallback? onReset}) {
    final unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.inbox, size: 48, color: Theme.of(context).colorScheme.outline),
          SizedBox(height: unit),
          Text(message),
          if (onReset != null) ...[
            SizedBox(height: unit * 2),
            AppButton(
              variant: AppButtonVariant.secondary,
              onPressed: onReset,
              child: const Text('Azzera filtri'),
            ),
          ],
        ],
      ),
    );
  }
}
