import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';

// Design System
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/components/app_data_table.dart';
import '../../../design system/components/switch.dart';
import '../../../design system/components/pagination.dart';
import '../../../design system/theme/themes.dart';
// theme_builder non utilizzato in questa pagina
import '../../../design system/theme/typography.dart';
import '../../../design system/components/alert_dialog.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/date_picker.dart';
import 'package:gestionale_desktop/features/agenda/presentation/task_edit_dialog.dart';
import 'package:gestionale_desktop/features/agenda/presentation/task_create_dialog.dart';
// Per stampa su web

/// Vista elenco/tabellare per Agenda (Tasks)
class TasksListPage extends StatefulWidget {
  const TasksListPage({super.key});

  @override
  State<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends State<TasksListPage> {
  late final SupabaseClient _sb;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _tasks = const [];

  // Filtri + ordinamento
  String? _filterMatterId;
  String? _filterAssigneeId;
  String? _filterPriority; // (verrà sostituito da filtro tipo)
  String? _filterType; // scrivere | onere
  DateTime? _filterDueDate; // singola data per filtro scadenza
  bool _showCompleted = false;
  String _orderBy = 'due_at'; // due_at, title, type, priority, assignee, matter
  bool _asc = true;

  // Label cache per chip/tag
  Map<String, String> _matterLabels = {};
  Map<String, String> _assigneeLabels = {};

  // Selezione tabella
  final Set<String> _selectedIds = {};

  // Paginazione
  int _page = 0;
  final int _pageSize = 20;
  // Modalità stampa: mostra tutte le righe e un header dedicato, poi invoca window.print()
  final bool _printMode = false;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _init();
  }

  Future<void> _init() async {
    // Avvia SUBITO il caricamento delle task, in parallelo al caricamento
    // delle etichette dei filtri, così l'utente vede immediatamente il progresso.
    // (Niente attese artificiali prima dell'avvio del fetch delle task)
    // Nota: non aspettiamo _loadTasks qui.
    // ignore: unawaited_futures
    _loadTasks();
    await _loadFilterOptions();
  }

  Future<void> _openCreateTask() async {
    final ctx = context;
    final res = await AppDialog.show(ctx, builder: (_) => const TaskCreateDialog());
    if (!ctx.mounted) return;
    if (res != null) {
      AppToaster.of(ctx).success('Task creata');
    }
    await _loadTasks();
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
      // Matters: etichetta "CODE — Cliente / Controparte" (fallback a title)
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
          label = right.isNotEmpty ? '$code — $right' : [code, m.title.trim()].where((s) => s.isNotEmpty).join(' — ');
        } else {
          label = [m.title.trim(), right].where((s) => s.isNotEmpty).join(' — ');
        }
        if (id.isNotEmpty) mLabels[id] = label.isNotEmpty ? label : id;
      }
      setState(() {
        _assigneeLabels = aLabels;
        _matterLabels = mLabels;
      });
    } catch (_) {}
  }

  Future<void> _loadMissingLabelsFromTasks(List<Map<String, dynamic>> list) async {
    final Set<String> missingMatter = {};
    final Set<String> missingAssign = {};
    for (final t in list) {
      final mid = '${t['matter_id'] ?? ''}';
      if (mid.isNotEmpty && !_matterLabels.containsKey(mid)) missingMatter.add(mid);
      final uid = '${t['assigned_to'] ?? ''}';
      if (uid.isNotEmpty && !_assigneeLabels.containsKey(uid)) missingAssign.add(uid);
    }
    if (missingMatter.isNotEmpty) {
      try {
        final res = await _sb
            .from('matters')
            .select([
              'matter_id',
              'code',
              'title',
              'counterparty_name',
              'client:clients(client_id,name,surname,kind,company_type)',
            ].join(','))
            .inFilter('matter_id', missingMatter.toList());
        for (final m in (res as List).cast<Map<String, dynamic>>()) {
          final id = (m['matter_id']).toString();
          final code = (m['code'] ?? '').toString();
          final title = (m['title'] ?? '').toString();
          final counter = (m['counterparty_name'] ?? '').toString().trim();
          String clientName() {
            final c = m['client'];
            if (c is Map) {
              final kind = '${c['kind'] ?? ''}';
              if (kind == 'person') {
                final name = '${c['name'] ?? ''}'.trim();
                final surname = '${c['surname'] ?? ''}'.trim();
                return [name, surname].where((e) => e.isNotEmpty).join(' ');
              } else if (kind == 'company') {
                final companyName = '${c['name'] ?? ''}'.trim();
                final companyType = '${c['company_type'] ?? ''}'.trim();
                return [companyName, companyType].where((e) => e.isNotEmpty).join(' ');
              }
            }
            return '';
          }
          final client = clientName();
          final right = [client, counter].where((s) => s.isNotEmpty).join(' / ');
          final label = code.isNotEmpty
              ? (right.isNotEmpty ? '$code — $right' : [code, title].where((s) => s.isNotEmpty).join(' — '))
              : [title, right].where((s) => s.isNotEmpty).join(' — ');
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
      if (fid == null || fid.isEmpty) throw Exception('Nessuno studio selezionato.');
      var qb = _sb
          .from('tasks')
          .select('task_id, title, start_at, due_at, done, priority, assigned_to, matter_id, type')
          .eq('firm_id', fid);
      if ((_filterMatterId ?? '').isNotEmpty) qb = qb.eq('matter_id', _filterMatterId!);
      if ((_filterAssigneeId ?? '').isNotEmpty) qb = qb.eq('assigned_to', _filterAssigneeId!);
      // Filtro tipo (scrivere/onere)
      if ((_filterType ?? '').isNotEmpty) qb = qb.eq('type', _filterType!);
      // Filtro scadenza (singola data) – considera tutto il giorno locale
      if (_filterDueDate != null) {
        final d = _filterDueDate!;
        final startLocal = DateTime(d.year, d.month, d.day);
        final endLocal = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
        final startUtc = startLocal.toUtc().toIso8601String();
        final endUtc = endLocal.toUtc().toIso8601String();
        qb = qb.gte('due_at', startUtc).lte('due_at', endUtc);
      }
      // (Legacy) Supporto al vecchio filtro priorità se ancora presente: manteniamo per compatibilità
      if ((_filterPriority ?? '').isNotEmpty) {
        qb = qb.eq('priority', _priorityToInt(_filterPriority) ?? _filterPriority!);
      }
      if (!_showCompleted) qb = qb.eq('done', false);
      final rows = await qb.order('due_at', ascending: true, nullsFirst: true);
      final list = (rows as List).cast<Map<String, dynamic>>();
      list.sort(_taskComparator);
      await _loadMissingLabelsFromTasks(list);
      setState(() => _tasks = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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
    if (da == null) return 1;
    if (db == null) return -1;
    try {
      final ta = DateTime.parse('$da').toUtc();
      final tb = DateTime.parse('$db').toUtc();
      return ta.compareTo(tb);
    } catch (_) {
      return 0;
    }
  }

  /// Costruisce il badge "Tipo" (onere/scrivere) con colori richiesti:
  /// - onere → blu
  /// - scrivere → arancione
  /// Allinea lo stile a quello usato nella vista principale.
  Widget _buildTypeBadge(BuildContext context, String type, {bool done = false}) {
    final ty = Theme.of(context).extension<ShadcnTypography>() ?? ShadcnTypography.defaults();
    final String label = switch (type.toLowerCase()) {
      'scrivere' => 'Scrivere',
      'onere' => 'Onere',
      _ => type,
    };
    final Color fgBase = Colors.white;
    final Color fg = done ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : fgBase;
    final Color bg = switch (type.toLowerCase()) {
      'scrivere' => Colors.orange.shade600,
      'onere' => Colors.blue.shade600,
      _ => Theme.of(context).colorScheme.secondary,
    };
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

  int _taskComparator(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (_orderBy) {
      case 'priority':
        return _priorityWeight(b['priority']) - _priorityWeight(a['priority']);
      case 'title':
        return ((a['title'] ?? '').toString()).toLowerCase().compareTo(((b['title'] ?? '').toString()).toLowerCase());
      case 'due_at':
      default:
        return _compareDueAsc(a, b);
    }
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

  // Prepara righe stampabili per PDF desktop (macOS/Windows/Linux)
  List<Map<String, String>> _toPrintableRows(List<Map<String, dynamic>> src) {
    return src.map((t) {
      final typeRaw = (t['type'] ?? '').toString();
      final type = switch (typeRaw.toLowerCase()) {
        'writing' => 'Scrivere',
        'scrivere' => 'Scrivere',
        'onere' => 'Onere',
        _ => typeRaw,
      };
      final title = (t['title'] ?? '').toString();
      final dueIso = t['due_at'];
      String due = '';
      if (dueIso != null) {
        try {
          final d = DateTime.parse('$dueIso').toLocal();
          final dd = d.day.toString().padLeft(2, '0');
          final mm = d.month.toString().padLeft(2, '0');
          due = '$dd-$mm-${d.year}';
        } catch (_) {}
      }
      final assigneeId = (t['assigned_to'] ?? '').toString();
      final matterId = (t['matter_id'] ?? '').toString();
      final assignee = assigneeId.isNotEmpty ? (_assigneeLabels[assigneeId] ?? '') : '';
      final matter = matterId.isNotEmpty ? (_matterLabels[matterId] ?? '') : '';
      final done = ((t['done'] ?? false) == true).toString();
      return {
        'type': type,
        'title': title,
        'due': due,
        'matter': matter,
        'assignee': assignee,
        'done': done,
      };
    }).toList();
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

  // toggleDone non utilizzato nella vista tabellare; rimosso per pulizia.

  Future<void> _deleteTask(Map<String, dynamic> t) async {
    final id = (t['task_id'] ?? '').toString();
    if (id.isEmpty) return;
    final ctx = context;
    await AppAlertDialog.show<void>(
      ctx,
      title: 'Elimina task',
      description: 'Confermi l\'eliminazione di questa task?\nL\'operazione non può essere annullata.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        final toaster = AppToaster.of(ctx);
        toaster.loading('Eliminazione task…');
        try {
          await _sb.from('tasks').delete().eq('task_id', id);
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
    final ctx = context;
    final res = await AppDialog.show(ctx, builder: (_) => TaskEditDialog(taskId: (t['task_id']).toString()));
    if (!ctx.mounted) return;
    if (res != null) {
      AppToaster.of(ctx).success('Task aggiornata');
    }
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final dt = Theme.of(context).extension<DefaultTokens>();
    final spacing = dt?.spacingUnit ?? 8.0;

    final rows = List<Map<String, dynamic>>.from(_tasks);
    rows.sort(_taskComparator);
    final total = rows.length;
    final start = (_page * _pageSize).clamp(0, total);
    final end = ((start + _pageSize) > total) ? total : (start + _pageSize);
    final visibleRows = _printMode ? rows : rows.sublist(start, end);

    return Padding(
      padding: EdgeInsets.all(spacing * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Riga superiore: azioni principali (Nuovo)
          Row(
            children: [
              const Spacer(),
              AppButton(
                variant: AppButtonVariant.default_,
                leading: const Icon(AppIcons.add),
                onPressed: _openCreateTask,
                label: 'Nuovo',
              ),
            ],
          ),
          SizedBox(height: spacing * 2),
          // Toolbar
          Row(
            children: [
              // Filtri su una sola riga con scroll orizzontale se non ci sta
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppCombobox(
                        width: 208,
                        value: _filterMatterId,
                        placeholder: 'Pratica…',
                        popoverWidthFactor: 1.6,
                        popoverMatchWidestRow: true,
                        items: [
                          const ComboboxItem(value: '', label: 'Tutte'),
                          ..._matterLabels.entries.map((e) => ComboboxItem(value: e.key, label: e.value)),
                        ],
                        onChanged: (v) {
                          setState(() => _filterMatterId = (v == null || v.isEmpty) ? null : v);
                          _loadTasks();
                        },
                      ),
                      SizedBox(width: spacing),
                      AppSelect(
                        placeholder: 'Assegnatario',
                        width: 220,
                        value: _filterAssigneeId,
                        groups: [
                          SelectGroupData(
                            label: 'Assegnatario',
                            items: [
                              const SelectItemData(value: '', label: 'Tutti'),
                              ..._assigneeLabels.entries.map(
                                (e) => SelectItemData(value: e.key, label: e.value),
                              ),
                            ],
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _filterAssigneeId = v.isEmpty ? null : v);
                          _loadTasks();
                        },
                      ),
                      SizedBox(width: spacing),
                      // Sostituisce il filtro "Priorità" con il filtro "Tipo"
                      AppSelect(
                        placeholder: 'Tipo',
                        width: 160,
                        value: _filterType,
                        groups: const [
                          SelectGroupData(
                            label: 'Tipo',
                            items: [
                              SelectItemData(value: '', label: 'Tutti'),
                              SelectItemData(value: 'scrivere', label: 'Scrivere'),
                              SelectItemData(value: 'onere', label: 'Onere'),
                            ],
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _filterType = v.isEmpty ? null : v);
                          _loadTasks();
                        },
                      ),
                      SizedBox(width: spacing),
                      // Filtro data (scadenza) – usa AppDatePickerInput del DS
                      SizedBox(
                        width: 180,
                        child: AppDatePickerInput(
                          initialDate: _filterDueDate,
                          firstDate: DateTime(2000, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                          onDateSubmitted: (d) {
                            setState(() {
                              if (d == null) {
                                _filterDueDate = null;
                              } else if (_filterDueDate != null &&
                                  _filterDueDate!.year == d.year &&
                                  _filterDueDate!.month == d.month &&
                                  _filterDueDate!.day == d.day) {
                                // Riclick sulla stessa data → svuota filtro
                                _filterDueDate = null;
                              } else {
                                _filterDueDate = d;
                              }
                            });
                            _loadTasks();
                          },
                        ),
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
                          Text('Mostra completati', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: spacing),
              AppButton(
                variant: AppButtonVariant.secondary,
                leading: const Icon(AppIcons.calendar),
                onPressed: () => context.go('/agenda/tasks'),
                label: 'Calendario',
              ),
              SizedBox(width: spacing),
              // Pulsante Stampa temporaneamente nascosto su richiesta
              // (il flusso di stampa verrà ripristinato in una fase successiva)
            ],
          ),

          SizedBox(height: spacing),
          if (_loading) const AppProgressBar(),
          if (_error != null) ...[
            SizedBox(height: spacing),
            Text('Errore: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],

          if (_printMode) ...[
            SizedBox(height: spacing),
            Center(
              child: Builder(builder: (ctx) {
                final DateTime ref = _filterDueDate ?? DateTime.now();
                final String dd = ref.day.toString().padLeft(2, '0');
                final String mm = ref.month.toString().padLeft(2, '0');
                final String yyyy = ref.year.toString();
                return Text(
                  'Agenda del $dd-$mm-$yyyy',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                );
              }),
            ),
          ],

          SizedBox(height: spacing),
          // Tabella elenco (Design System)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing),
              child: (!_loading && _error == null)
                  ? AppDataTable(
                      selectionInFirstCell: !_printMode,
                      selectable: !_printMode,
                      allSelected: visibleRows.isNotEmpty &&
                          visibleRows.every((t) => _selectedIds.contains('${t['task_id'] ?? ''}')),
                      onToggleAll: () {
                        setState(() {
                          final all = visibleRows.isNotEmpty &&
                              visibleRows.every((t) => _selectedIds.contains('${t['task_id'] ?? ''}'));
                          if (all) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(visibleRows
                                .map((t) => '${t['task_id'] ?? ''}')
                                .where((id) => id.isNotEmpty));
                          }
                        });
                      },
                      selectedRows: [
                        for (final t in visibleRows) _selectedIds.contains('${t['task_id'] ?? ''}')
                      ],
                      onToggleRow: (i, v) {
                        final id = '${visibleRows[i]['task_id'] ?? ''}';
                        setState(() {
                          if (v) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                      columns: [
                        // 1. Tipo
                        AppDataColumn(label: 'Tipo', width: 120),
                        // 2. Titolo
                        AppDataColumn(
                          label: 'Titolo',
                          width: 280,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'title') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'title';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'title' ? _asc : null,
                        ),
                        // 3. Scadenza
                        AppDataColumn(
                          label: 'Scadenza',
                          width: 140,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'due_at') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'due_at';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'due_at' ? _asc : null,
                        ),
                        // 4. Pratica
                        AppDataColumn(label: 'Pratica', width: 300),
                        // 5. Assegnatario
                        AppDataColumn(label: 'Assegnatario', width: 220),
                      ],
                      rows: visibleRows.map((t) {
                        final id = '${t['task_id'] ?? ''}';
                        final due = _fmtDate(t['due_at']);
                        final title = (t['title'] ?? '').toString();
                        final type = (t['type'] ?? '').toString();
                        final assigneeId = (t['assigned_to'] ?? '').toString();
                        final matterId = (t['matter_id'] ?? '').toString();
                        final assigneeLabel = assigneeId.isNotEmpty ? (_assigneeLabels[assigneeId] ?? '') : '';
                        final matterLabel = matterId.isNotEmpty ? (_matterLabels[matterId] ?? '') : '';
                        final done = (t['done'] ?? false) == true;
                        final TextStyle strike = TextStyle(
                          decoration: done ? TextDecoration.lineThrough : null,
                        );
                        return AppDataRow(
                          onTap: id.isEmpty ? null : () => _openEditTask(t),
                          cells: [
                            // Tipo badge
                            type.isEmpty
                                ? const Text('—')
                                : _buildTypeBadge(context, type, done: done),
                            // Titolo
                            Text(title.isEmpty ? '—' : title, overflow: TextOverflow.ellipsis, style: strike),
                            // Scadenza
                            Text(due, style: strike),
                            // Pratica
                            Text(
                              matterLabel.isEmpty ? '—' : matterLabel,
                              overflow: TextOverflow.ellipsis,
                              style: strike,
                            ),
                            // Assegnatario
                            Text(assigneeLabel.isEmpty ? '—' : assigneeLabel, style: strike),
                          ],
                          rowMenu: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                variant: AppButtonVariant.outline,
                                size: AppButtonSize.iconSm,
                                circular: true,
                                onPressed: id.isEmpty ? null : () => _openEditTask(t),
                                child: const Icon(AppIcons.edit),
                              ),
                              SizedBox(width: spacing),
                              AppButton(
                                variant: AppButtonVariant.destructive,
                                size: AppButtonSize.iconSm,
                                circular: true,
                                onPressed: id.isEmpty ? null : () => _deleteTask(t),
                                child: const Icon(AppIcons.delete),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          if (!_printMode)
            // Footer: paginazione
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing * 2, vertical: spacing),
              child: Row(
                children: [
                  Text('$total task totali'),
                  const Spacer(),
                  Pagination(
                    child: PaginationContent(
                      children: [
                        PaginationPrevious(
                          onPressed: _page > 0 ? () => setState(() => _page -= 1) : null,
                          label: 'Precedente',
                        ),
                        PaginationItem(
                          child: PaginationLink(isActive: true, child: Text('${_page + 1}')),
                        ),
                        PaginationNext(
                          onPressed: ((_page + 1) * _pageSize < total) ? () => setState(() => _page += 1) : null,
                          label: 'Successiva',
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
}