import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'package:gestionale_desktop/features/agenda/presentation/task_create_dialog.dart';
import 'package:gestionale_desktop/features/agenda/presentation/task_edit_dialog.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';

// Design System
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/switch.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/theme/typography.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/theme/theme_builder.dart';
import '../../../design system/components/alert_dialog.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final SupabaseClient _sb;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _tasks = const [];
  bool _showCompleted = false;
  // Filtri + ordinamento
  String? _filterMatterId;
  String? _filterAssigneeId;
  String? _filterPriority;
  final String _sortKey = 'due_asc';
  // Label cache per chip/tag
  Map<String, String> _matterLabels = {};
  Map<String, String> _assigneeLabels = {};
  // Selezione multipla
  final Set<String> _selectedIds = {};
  // Scroll per sezioni indipendenti
  final ScrollController _scrivereScroll = ScrollController();
  final ScrollController _onereScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _loadFilterOptions(); // preload: team + matters per dropdown
    _loadTasks();
  }

  @override
  void dispose() {
    _scrivereScroll.dispose();
    _onereScroll.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) return;
      // Team (assignees)
      final profs = await _sb
          .from('profiles')
          .select('user_id, full_name')
          .eq('firm_id', fid)
          .order('full_name', ascending: true);
      final team = (profs as List).cast<Map<String, dynamic>>();
      final Map<String, String> aLabels = {};
      for (final p in team) {
        final uid = (p['user_id'] ?? '').toString();
        final name = (p['full_name'] ?? '').toString();
        if (uid.isNotEmpty) aLabels[uid] = name.isNotEmpty ? name : uid;
      }
      // Matters: usa etichetta "CODE — Cliente / Controparte" (fallback a title)
      final mr = MatterRepo(_sb);
      final matters = await mr.list(page: 1, pageSize: 100);
      final Map<String, String> mLabels = {};
      for (final m in matters) {
        final id = m.matterId;
        final code = m.code;
        final client = (m.clientDisplayName ?? '').trim();
        final counter = (m.counterpartyName ?? '').trim();
        final right = [client, counter].where((s) => s.isNotEmpty).join(' / ');
        String label;
        if (code.isNotEmpty) {
          if (right.isNotEmpty) {
            label = '$code — $right';
          } else {
            // m.title è non-nullabile nel modello: rimuovi null-coalescing ridondante
            final title = m.title.trim();
            label = [code, title].where((s) => s.isNotEmpty).join(' — ');
          }
        } else {
          // m.title è non-nullabile nel modello: rimuovi null-coalescing ridondante
          final title = m.title.trim();
          label = [title, right].where((s) => s.isNotEmpty).join(' — ');
        }
        if (id.isNotEmpty) mLabels[id] = label.isNotEmpty ? label : id;
      }
      // Unisci senza sovrascrivere: evita race con _loadTasks/_loadMissingLabelsFromTasks
      // che potrebbero aver già arricchito _matterLabels.
      setState(() {
        _assigneeLabels = aLabels;
        _matterLabels = {
          ..._matterLabels,
          ...mLabels,
        };
      });
    } catch (_) {
      // silent
    }
  }

  Future<void> _loadMissingLabelsFromTasks(
      List<Map<String, dynamic>> list) async {
    final Set<String> missingMatter = {};
    final Set<String> missingAssign = {};
    for (final t in list) {
      final mid = '${t['matter_id'] ?? ''}';
      if (mid.isNotEmpty && !_matterLabels.containsKey(mid)) {
        missingMatter.add(mid);
      }
      final uid = '${t['assigned_to'] ?? ''}';
      if (uid.isNotEmpty && !_assigneeLabels.containsKey(uid)) {
        missingAssign.add(uid);
      }
    }
    if (missingMatter.isNotEmpty) {
      try {
        final res = await _sb
            .from('matters')
            .select([
              'matter_id',
              'code',
              'title',
              // join cliente + controparte per etichetta
              'counterparty_name',
              'client:clients(client_id,name,surname,kind,company_type)',
            ].join(','))
            .inFilter('matter_id', missingMatter.toList());
        for (final m in (res as List).cast<Map<String, dynamic>>()) {
          final id = (m['matter_id']).toString();
          String buildLabel(Map<String, dynamic> mm) {
            final code = (mm['code'] ?? '').toString();
            final title = (mm['title'] ?? '').toString();
            final counter = (mm['counterparty_name'] ?? '').toString().trim();
            String clientName() {
              final c = mm['client'];
              if (c is Map) {
                final kind = '${c['kind'] ?? ''}';
                if (kind == 'person') {
                  final name = '${c['name'] ?? ''}'.trim();
                  final surname = '${c['surname'] ?? ''}'.trim();
                  return [name, surname].where((e) => e.isNotEmpty).join(' ');
                } else if (kind == 'company') {
                  final companyName = '${c['name'] ?? ''}'.trim();
                  final companyType = '${c['company_type'] ?? ''}'.trim();
                  return [companyName, companyType]
                      .where((e) => e.isNotEmpty)
                      .join(' ');
                }
              }
              return '';
            }

            final client = clientName();
            final right =
                [client, counter].where((s) => s.isNotEmpty).join(' / ');
            String label;
            if (code.isNotEmpty) {
              label = right.isNotEmpty
                  ? '$code — $right'
                  : [code, title].where((s) => s.isNotEmpty).join(' — ');
            } else {
              label = [title, right].where((s) => s.isNotEmpty).join(' — ');
            }
            return label;
          }

          final label = buildLabel(m);
          if (id.isNotEmpty) _matterLabels[id] = label.isNotEmpty ? label : id;
        }
      } catch (_) {}
    }
    if (missingAssign.isNotEmpty) {
      try {
        final res = await _sb
            .from('profiles')
            .select('user_id, full_name')
            .inFilter('user_id', missingAssign.toList());
        for (final p in (res as List).cast<Map<String, dynamic>>()) {
          final id = (p['user_id']).toString();
          final name = (p['full_name'] ?? '').toString();
          if (id.isNotEmpty) _assigneeLabels[id] = name.isNotEmpty ? name : id;
        }
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }
      final base = _sb
          .from('tasks')
          .select(
              'task_id, title, start_at, due_at, done, priority, assigned_to, matter_id, type')
          .eq('firm_id', fid);
      var qb = base;
      // Regole di visibilità (calendario):
      // 1) Mostra tutte le task per cui OGGI (intero giorno locale) interseca l'intervallo [start_at..due_at]
      //    → start_at <= fine_giornata && due_at >= inizio_giornata
      // 2) Mostra tutte le task con due_at nel passato e done = FALSE (overdue non completate)
      final nowLocal = DateTime.now();
      final startOfTodayLocal =
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final endOfTodayLocal = DateTime(
          nowLocal.year, nowLocal.month, nowLocal.day, 23, 59, 59, 999);
      final startIso = startOfTodayLocal.toUtc().toIso8601String();
      final endIso = endOfTodayLocal.toUtc().toIso8601String();
      // Limiti locali (senza conversione a UTC) — usati per done_at per evitare mismatch di timezone
      final startIsoLocal = startOfTodayLocal.toIso8601String();
      final endIsoLocal = endOfTodayLocal.toIso8601String();
      final nowIso = nowLocal.toUtc().toIso8601String();
      // Logica originale: visibilità basata su intersezione con oggi e overdue non completate.
      // Se il toggle "Mostra completati" è ON, non filtriamo done=false ma NON includiamo
      // tutte le completate fuori finestra.
      qb = qb.or(
          'and(start_at.lte.$endIso,due_at.gte.$startIso),and(due_at.lt.$nowIso,done.eq.false)');
      if (!_showCompleted) {
        qb = qb.eq('done', false);
      }
      if ((_filterMatterId ?? '').isNotEmpty) {
        qb = qb.eq('matter_id', _filterMatterId!);
      }
      if ((_filterAssigneeId ?? '').isNotEmpty) {
        qb = qb.eq('assigned_to', _filterAssigneeId!);
      }
      if ((_filterPriority ?? '').isNotEmpty) {
        final pv = _priorityToInt(_filterPriority);
        qb = qb.eq('priority', pv ?? _filterPriority!);
      }
      // Ordine DB preliminare: by due_at asc (per ridurre sforzo di sort client)
      final ordered = qb.order('due_at', ascending: true, nullsFirst: true);
      final rows = await ordered; // dynamic
      List<Map<String, dynamic>> list =
          (rows as List).cast<Map<String, dynamic>>();
      // Se mostra completati, includi anche le task completate OGGI (done_at nel giorno locale)
      if (_showCompleted) {
        final List<Map<String, dynamic>> extras = [];
        // done_at in [oggi]
        try {
          var extrasQb = _sb
              .from('tasks')
              .select(
                  'task_id, title, start_at, due_at, done, priority, assigned_to, matter_id, type, done_at')
              .eq('firm_id', fid)
              .eq('done', true)
              .gte('done_at', startIsoLocal)
              .lte('done_at', endIsoLocal);
          // Applica gli stessi filtri opzionali di matter/assignee/priority
          if ((_filterMatterId ?? '').isNotEmpty) {
            extrasQb = extrasQb.eq('matter_id', _filterMatterId!);
          }
          if ((_filterAssigneeId ?? '').isNotEmpty) {
            extrasQb = extrasQb.eq('assigned_to', _filterAssigneeId!);
          }
          if ((_filterPriority ?? '').isNotEmpty) {
            final pv = _priorityToInt(_filterPriority);
            extrasQb = extrasQb.eq('priority', pv ?? _filterPriority!);
          }
          final extra2 = await extrasQb;
          extras.addAll(
              ((extra2 as List?) ?? const []).cast<Map<String, dynamic>>());
        } catch (_) {}
        // Unisci evitando duplicati su task_id
        final existingIds =
            list.map((e) => (e['task_id'] ?? '').toString()).toSet();
        for (final e in extras) {
          final id = (e['task_id'] ?? '').toString();
          if (id.isEmpty) continue;
          if (!existingIds.contains(id)) {
            list.add(e);
            existingIds.add(id);
          }
        }
      }
      // Ordinamento client: prima le task scadute (overdue e non completate),
      // poi le altre. All'interno dei gruppi, rispetta lo _sortKey selezionato.
      list.sort(_taskComparator);
      await _loadMissingLabelsFromTasks(list);
      setState(() => _tasks = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleDone(Map<String, dynamic> t, bool value) async {
    try {
      final id = t['task_id'];
      await _sb.from('tasks').update({'done': value}).eq('task_id', id);
      await _loadTasks();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> t) async {
    final id = (t['task_id'] ?? '').toString();
    if (id.isEmpty) return;
    final ctx = context;
    await AppAlertDialog.show<void>(
      ctx,
      title: 'Elimina task',
      description:
          'Confermi l\'eliminazione di questa task?\nL\'operazione non può essere annullata.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        final toaster = AppToaster.of(ctx);
        toaster.loading('Eliminazione task…');
        try {
          await _sb.from('tasks').delete().eq('task_id', id);
          _selectedIds.remove(id);
          if (!ctx.mounted) return;
          toaster.success('Task eliminata');
          await _loadTasks();
        } catch (e) {
          if (!ctx.mounted) return;
          toaster.error('Task non eliminata correttamente', description: '$e');
        }
      },
    );
  }

  Future<void> _openEditTask(Map<String, dynamic> t) async {
    final id = (t['task_id'] ?? '').toString();
    if (id.isEmpty) return;
    final ctx = context;
    final res = await AppDialog.show(
      ctx,
      builder: (_) => TaskEditDialog(taskId: id),
    );
    if (!ctx.mounted) return;
    if (res != null) {
      AppToaster.of(ctx).success('Task aggiornata');
      await _loadTasks();
    } else {
      await _loadTasks();
    }
  }

  // Tile in stile DS come in Dashboard (_taskAppListTile), adattato al modello Agenda
  Widget _taskAppListTile(Map<String, dynamic> t) {
    final title = (t['title'] ?? '').toString();
    final dueDate = _fmtDate(t['due_at']);
    final type = (t['type'] ?? '').toString();
    final pr = t['priority'];
    final done = t['done'] == true;
    final overdue = _isOverdue(t);
    final Color prColor =
        _priorityColor(pr) ?? Theme.of(context).colorScheme.secondary;
    // Tokens DS (border, muted, ecc.)
    final gt = context.tokens;
    // Logica colore barra priorità:
    // - Se task completata: usa colore attenuato (muted)
    // - Se scaduta e non completata: rosso scurissimo
    // - Altrimenti: colore della priorità
    final Color barColor =
        done ? gt.muted : (overdue ? Colors.red.shade900 : prColor);
    final assigneeId = (t['assigned_to'] ?? '').toString();
    final matterId = (t['matter_id'] ?? '').toString();
    final assigneeLabel = assigneeId.isNotEmpty
        ? (_assigneeLabels[assigneeId] ?? assigneeId)
        : '';
    final matterLabel =
        matterId.isNotEmpty ? (_matterLabels[matterId] ?? matterId) : '';

    // Barra priorità: 70% altezza, centrata verticalmente
    const double barWidth = 6.0;
    const double barRadius = 4.0;
    final double unit =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final double barInset = unit * 1.5;
    final double leftPad = barInset + barWidth + 8.0 + unit;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Theme.of(context).extension<DefaultTokens>()?.radiusSm ??
            BorderRadius.circular(6),
        side: BorderSide(color: gt.border),
      ),
      color: done ? gt.muted : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => _openEditTask(t),
        child: IntrinsicHeight(
          child: Stack(
            children: [
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: done
                                            ? gt.mutedForeground
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
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
                                  Icon(AppIcons.schedule,
                                      size: 16,
                                      color: done ? gt.mutedForeground : null),
                                  const SizedBox(width: 4),
                                  Text(
                                    dueDate,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color:
                                              done ? gt.mutedForeground : null,
                                        ),
                                  ),
                                ],
                              ),
                              if (type.isNotEmpty)
                                _buildTypeBadge(type, done: done),
                              if (assigneeLabel.isNotEmpty)
                                Chip(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.tertiary,
                                  avatar: Icon(AppIcons.person,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiary),
                                  label: Text(
                                    assigneeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiary,
                                        ),
                                  ),
                                ),
                              if (matterLabel.isNotEmpty)
                                Chip(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.tertiary,
                                  avatar: Icon(AppIcons.folder,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiary),
                                  label: Text(
                                    matterLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiary,
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
                          icon: const Icon(AppIcons.checklist),
                          color: done
                              ? gt.mutedForeground
                              : Theme.of(context).colorScheme.primary,
                          onPressed: () => _toggleDone(t, !done),
                        ),
                        SizedBox(width: unit),
                        AppButton(
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.iconSm,
                          circular: true,
                          child: const Icon(AppIcons.edit),
                          onPressed: () => _openEditTask(t),
                        ),
                        SizedBox(width: unit),
                        AppButton(
                          variant: AppButtonVariant.destructive,
                          size: AppButtonSize.iconSm,
                          circular: true,
                          child: const Icon(AppIcons.delete),
                          onPressed: () => _deleteTask(t),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: barInset),
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

  @override
  Widget build(BuildContext context) {
    // Spacing DS
    final spacing =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    // Dividi le task in due sezioni per type: scrivere (sopra) e onere (sotto)
    final List<Map<String, dynamic>> scrivere = _tasks
        .where((t) => _typeCanonical(t['type']) == 'scrivere')
        .toList()
      ..sort(_taskComparator);
    final List<Map<String, dynamic>> onere = _tasks
        .where((t) => _typeCanonical(t['type']) == 'onere')
        .toList()
      ..sort(_taskComparator);
    return Padding(
      padding: EdgeInsets.all(spacing * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar superiore identica alle Udienze: solo pulsante "Nuovo" a destra
          Row(
            children: [
              const Spacer(),
              AppButton(
                variant: AppButtonVariant.default_,
                leading: const Icon(AppIcons.add),
                onPressed: _openCreateTask,
                child: const Text('Nuovo'),
              ),
            ],
          ),
          SizedBox(height: spacing * 2),
          // Contenuti senza Card: allineati al DS come nelle altre pagine
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtri + ordinamento con azioni a destra (Elenco), come pagina Udienze
                Row(
                  children: [
                    // Filtri su una sola riga; se non c'è spazio, abilita scroll orizzontale
                    Expanded(
                      child: Row(
                        children: [
                          AppCombobox(
                            width: 190,
                            value: _filterMatterId,
                            placeholder: 'Pratica',
                            popoverWidthFactor: 1.6,
                            popoverMatchWidestRow: true,
                            items: [
                              const ComboboxItem(value: '', label: 'Tutte'),
                              ..._matterLabels.entries.map(
                                (e) =>
                                    ComboboxItem(value: e.key, label: e.value),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => _filterMatterId =
                                  (v == null || v.isEmpty) ? null : v);
                              _loadTasks();
                            },
                          ),
                          SizedBox(width: spacing),
                          AppSelect(
                            placeholder: 'Assegnatario',
                            width: 200,
                            value: _filterAssigneeId,
                            groups: [
                              SelectGroupData(
                                label: 'Assegnatario',
                                items: [
                                  const SelectItemData(
                                      value: '', label: 'Tutti'),
                                  ..._assigneeLabels.entries.map(
                                    (e) => SelectItemData(
                                        value: e.key, label: e.value),
                                  ),
                                ],
                              ),
                            ],
                            onChanged: (v) {
                              setState(() =>
                                  _filterAssigneeId = v.isEmpty ? null : v);
                              _loadTasks();
                            },
                          ),
                          SizedBox(width: spacing),
                          AppSelect(
                            placeholder: 'Priorità',
                            width: 140,
                            value: _filterPriority,
                            groups: const [
                              SelectGroupData(
                                label: 'Priorità',
                                items: [
                                  SelectItemData(value: '', label: 'Tutte'),
                                  SelectItemData(value: 'high', label: 'Alta'),
                                  SelectItemData(
                                      value: 'normal', label: 'Normale'),
                                  SelectItemData(value: 'low', label: 'Bassa'),
                                ],
                              ),
                            ],
                            onChanged: (v) {
                              setState(
                                  () => _filterPriority = v.isEmpty ? null : v);
                              _loadTasks();
                            },
                          ),
                          SizedBox(width: spacing),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppSwitch(
                                value: _showCompleted,
                                onChanged: (value) {
                                  setState(() => _showCompleted = value);
                                  _loadTasks();
                                },
                              ),
                              const SizedBox(width: 8),
                              Text('Completati',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing),
                    // Azioni a destra: pulsante "Elenco" come in Udienze
                    Wrap(
                      spacing: spacing * 2,
                      children: [
                        AppButton(
                          variant: AppButtonVariant.secondary,
                          leading: const Icon(AppIcons.tableChart),
                          onPressed: () => context.go('/agenda/tasks/list'),
                          child: const Text('Elenco'),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                if (_loading) const AppProgressBar(),
                if (_error != null) ...[
                  SizedBox(height: spacing),
                  Text('Errore: $_error',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                // (Diagnostica rimossa su richiesta)
                // Due sezioni con altezza fissa ciascuna a metà dello spazio disponibile,
                // ognuna con scroll interno indipendente.
                Expanded(
                  child: Column(
                    children: [
                      // Sezione: Scrivere (metà superiore)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('Scrivere'),
                            _sectionSeparator(),
                            Expanded(
                              child: Scrollbar(
                                controller: _scrivereScroll,
                                thumbVisibility: true,
                                child: (scrivere.isEmpty &&
                                        !_loading &&
                                        _error == null)
                                    ? _buildSectionEmptyState(spacing)
                                    : ListView.separated(
                                        controller: _scrivereScroll,
                                        itemCount: scrivere.length,
                                        separatorBuilder: (_, __) =>
                                            SizedBox(height: spacing * 1.5),
                                        itemBuilder: (_, i) =>
                                            _taskAppListTile(scrivere[i]),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: spacing * 3),

                      // Sezione: Onere (metà inferiore)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('Onere'),
                            _sectionSeparator(),
                            Expanded(
                              child: Scrollbar(
                                controller: _onereScroll,
                                thumbVisibility: true,
                                child: (onere.isEmpty &&
                                        !_loading &&
                                        _error == null)
                                    ? _buildSectionEmptyState(spacing)
                                    : ListView.separated(
                                        controller: _onereScroll,
                                        itemCount: onere.length,
                                        separatorBuilder: (_, __) =>
                                            SizedBox(height: spacing * 1.5),
                                        itemBuilder: (_, i) =>
                                            _taskAppListTile(onere[i]),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final base = Theme.of(context).textTheme.titleMedium;
    final increasedSize = (base?.fontSize ?? 16.0) + 2.0; // leggero incremento
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        title,
        style: base?.copyWith(
          fontSize: increasedSize,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // Empty state per sezioni (Scrivere/Onere), allineato a tabelle Clienti/Pratiche
  Widget _buildSectionEmptyState(double spacing) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.inbox, size: 48, color: cs.outline),
          SizedBox(height: spacing * 2),
          const Text('Nessuna task'),
        ],
      ),
    );
  }

  // (Sezione diagnostica rimossa su richiesta)

  Widget _sectionSeparator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      height: 1,
      color: context.tokens.border,
    );
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse('$iso').toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  int _priorityWeight(dynamic p) {
    if (p == null) return 0;
    if (p is int) return p; // 0=bassa, 1=normale, 2=alta
    final s = p.toString().toLowerCase().trim();
    switch (s) {
      case 'high':
        return 2;
      case 'normal':
        return 1;
      case 'low':
        return 0;
      default:
        final n = int.tryParse(s);
        return n ?? 0;
    }
  }

  int _compareDueAsc(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = a['due_at'];
    final db = b['due_at'];
    if (da == null && db == null) return 0;
    if (da == null) return 1; // nulls last
    if (db == null) return -1;
    try {
      final ta = DateTime.parse('$da').toUtc();
      final tb = DateTime.parse('$db').toUtc();
      return ta.compareTo(tb);
    } catch (_) {
      return 0;
    }
  }

  int _compareDueDesc(Map<String, dynamic> a, Map<String, dynamic> b) =>
      -_compareDueAsc(a, b);

  int _taskComparator(Map<String, dynamic> a, Map<String, dynamic> b) {
    // Quando "Mostra completati" è attivo, metti per primi i completati
    // che sono nell'intervallo odierno [start_at..due_at].
    // Poi le overdue non completate, poi le altre.
    int groupA;
    int groupB;
    if (_showCompleted && (a['done'] == true || b['done'] == true)) {
      final aDoneWindow = a['done'] == true && _isInWindow(a);
      final bDoneWindow = b['done'] == true && _isInWindow(b);
      final aDoneToday = a['done'] == true && _isCompletedToday(a);
      final bDoneToday = b['done'] == true && _isCompletedToday(b);
      groupA = (aDoneWindow || aDoneToday) ? 0 : (_isOverdue(a) ? 1 : 2);
      groupB = (bDoneWindow || bDoneToday) ? 0 : (_isOverdue(b) ? 1 : 2);
    } else {
      groupA = _isOverdue(a) ? 1 : 2;
      groupB = _isOverdue(b) ? 1 : 2;
    }
    if (groupA != groupB) return groupA - groupB;
    // Ordinamento secondario secondo sortKey scelto
    switch (_sortKey) {
      case 'priority_desc':
        return _priorityWeight(b['priority']) - _priorityWeight(a['priority']);
      case 'title_asc':
        return ((a['title'] ?? '').toString())
            .toLowerCase()
            .compareTo(((b['title'] ?? '').toString()).toLowerCase());
      case 'due_desc':
        return _compareDueDesc(a, b);
      case 'due_asc':
      default:
        return _compareDueAsc(a, b);
    }
  }

  // Determina se la task è stata completata OGGI (locale) usando done_at
  bool _isCompletedToday(Map<String, dynamic> t) {
    try {
      final nowLocal = DateTime.now();
      final startOfTodayLocal =
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final endOfTodayLocal = DateTime(
          nowLocal.year, nowLocal.month, nowLocal.day, 23, 59, 59, 999);
      DateTime? comp;
      final c2 = t['done_at'];
      if (c2 != null) {
        comp = DateTime.tryParse('$c2');
      }
      if (comp == null) return false;
      final lc = comp.toLocal();
      return !lc.isBefore(startOfTodayLocal) && !lc.isAfter(endOfTodayLocal);
    } catch (_) {
      return false;
    }
  }

  // Canonicalizza il campo type per evitare mismatch dovuti a spazi/casing
  String _typeCanonical(dynamic v) {
    return (v ?? '').toString().trim().toLowerCase();
  }

  int? _priorityToInt(String? p) {
    if (p == null) return null; // 0=bassa, 1=normale, 2=alta
    switch (p) {
      case 'low':
        return 0;
      case 'normal':
        return 1;
      case 'high':
        return 2;
      default:
        return int.tryParse(p);
    }
  }

  /// Ritorna true se la task è scaduta (due_at < now) e non è completata (done=false).
  bool _isOverdue(Map<String, dynamic> t) {
    try {
      if (t['done'] == true) return false;
      final due = t['due_at'];
      if (due == null) return false;
      final d = DateTime.parse('$due').toUtc();
      return DateTime.now().toUtc().isAfter(d);
    } catch (_) {
      return false;
    }
  }

  /// True se la giornata odierna (intero giorno locale) interseca l'intervallo [start_at..due_at].
  bool _isInWindow(Map<String, dynamic> t) {
    try {
      final start = t['start_at'];
      final due = t['due_at'];
      if (start == null || due == null) return false;
      final sLocal = DateTime.parse('$start').toLocal();
      final dLocal = DateTime.parse('$due').toLocal();
      final nowLocal = DateTime.now();
      final todayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final todayEnd = DateTime(
          nowLocal.year, nowLocal.month, nowLocal.day, 23, 59, 59, 999);
      // Intersezione tra [sLocal..dLocal] e [todayStart..todayEnd]
      final intersects = (sLocal.isBefore(todayEnd) ||
              sLocal.isAtSameMomentAs(todayEnd)) &&
          (dLocal.isAfter(todayStart) || dLocal.isAtSameMomentAs(todayStart));
      return intersects;
    } catch (_) {
      return false;
    }
  }

  Color? _priorityColor(dynamic p) {
    final s = p.toString().toLowerCase().trim();
    switch (s) {
      case 'high':
      case '2':
        return Colors.red.shade300;
      case 'normal':
      case '1':
        return Colors.orange.shade300;
      case 'low':
      case '0':
        return Colors.green.shade300;
      default:
        return null;
    }
  }

  /// Costruisce il badge "Tipo" (onere/scrivere) con colori richiesti:
  /// - onere → blu
  /// - scrivere → arancione
  /// Mantiene lo stile compatto del DS (px-2.5 py-0.5, rounded-md, text-xs, semibold)
  Widget _buildTypeBadge(String type, {bool done = false}) {
    final ty = Theme.of(context).extension<ShadcnTypography>() ??
        ShadcnTypography.defaults();
    final String label = switch (type.toLowerCase()) {
      'scrivere' => 'Scrivere',
      'onere' => 'Onere',
      _ => type,
    };
    // Colori: foreground bianco; se task "done", attenua foreground
    final Color fgBase = Colors.white;
    final Color fg = done
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
        : fgBase;
    final Color bg = switch (type.toLowerCase()) {
      'scrivere' => Colors.orange.shade600,
      'onere' => Colors.blue.shade600,
      _ => Theme.of(context).colorScheme.secondary,
    };
    // Se done, attenua anche lo sfondo
    final Color bgAttenuated = done ? bg.withValues(alpha: 0.6) : bg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgAttenuated,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ty.textXs,
            fontWeight: FontWeight.w600,
            color: fg,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateTask() async {
    final ctx = context;
    final res = await AppDialog.show(
      ctx,
      builder: (_) => const TaskCreateDialog(),
    );
    if (!ctx.mounted) return;
    if (res != null) {
      AppToaster.of(ctx).success('Task creata');
    }
    await _loadTasks();
  }
}
