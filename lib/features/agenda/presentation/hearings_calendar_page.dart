// lib/features/agenda/presentation/hearings_calendar_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/components/calendar.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/progress.dart';
// import '../../../design system/components/input.dart';

import '../../../design system/components/sonner.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/input_group.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/theme/themes.dart';
import '../../courtroom/data/courtroom_repo.dart';
// import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_create_dialog.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_edit_dialog.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_disposition_dialog.dart';
// import 'package:gestionale_desktop/components/date_picker.dart';
import '../../../design system/components/dialog.dart';

class HearingsCalendarPage extends StatefulWidget {
  const HearingsCalendarPage({super.key});

  @override
  State<HearingsCalendarPage> createState() => _HearingsCalendarPageState();
}

class _HearingsCalendarPageState extends State<HearingsCalendarPage> {
  late final SupabaseClient _sb;
  late final ScrollController _eventsScrollCtl;
  // Removed MatterRepo (not used here)

  bool _loading = false;
  String? _error;

  // Filters
  final _searchCtl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _matterId;
  // Removed matter text input and suggestions (unused)
  // Client-side quick filters (Selects per Tribunale e Giudice)
  String? _courtFilter; // selected court value
  String? _judgeFilter; // selected judge value
  // Gruppi tribunali da courtroom.json
  List<ComboboxGroupData> _courtGroups = const [];
  StreamSubscription<List<ComboboxGroupData>>? _courtGroupsSub;

  // Calendar state
  // Calendar state (DS)
  DateTime _selectedDay = DateTime.now();

  // Data
  List<Map<String, dynamic>> _hearings = const [];
  Map<String, Map<String, dynamic>> _mattersById = const {};

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _eventsScrollCtl = ScrollController();
    _loadHearings();
    // Osserva courtroom.json e aggiorna gruppi tribunali
    _courtGroupsSub = CourtroomRepo().watchGroups().listen((groups) {
      if (!mounted) return;
      setState(() => _courtGroups = groups);
    });
  }

  // Costruisce toolbar, filtri e azioni superiori come blocco separato
  Widget _buildTopControls(BuildContext context, List<String> courtOptions,
      List<String> judgeOptions) {
    final spacing =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar superiore identica alla lista: pulsante "Nuova" a destra
        Row(
          children: [
            const Spacer(),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: _openCreateQuick,
              leading: const Icon(AppIcons.add),
              label: 'Nuova',
            ),
          ],
        ),
        SizedBox(height: spacing * 2),
        Padding(
          padding: EdgeInsets.all(spacing * 2),
          child: Row(
            children: [
              SizedBox(
                width: spacing * 35,
                child: AppInputGroup(
                  controller: _searchCtl,
                  hintText: 'Cerca udienze…',
                  leading: const Icon(AppIcons.search),
                  onSubmitted: (_) => _loadHearings(),
                  onChanged: (_) => _loadHearings(),
                ),
              ),
              SizedBox(width: spacing * 2),
              // Pratica
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCombobox(
                    width: 190,
                    value: _matterId,
                    placeholder: 'Pratica',
                    popoverWidthFactor: 1.6,
                    // La lista si adatta alla riga più lunga
                    popoverMatchWidestRow: true,
                    items: [
                      const ComboboxItem(value: '', label: 'Tutte'),
                      for (final m in _mattersById.values)
                        if ('${m['code'] ?? ''}'.isNotEmpty)
                          ComboboxItem(
                            value: '${m['matter_id'] ?? ''}',
                            label: _buildMatterLabel(m),
                          ),
                    ],
                    onChanged: (v) {
                      setState(
                          () => _matterId = (v == null || v.isEmpty) ? '' : v);
                      _loadHearings();
                    },
                  ),
                  if ((_matterId ?? '').isNotEmpty) ...[
                    SizedBox(width: spacing * 2),
                    Tooltip(
                      message: 'Pulisci pratica',
                      child: AppButton(
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.icon,
                        onPressed: () {
                          setState(() => _matterId = '');
                          _loadHearings();
                        },
                        child: const Icon(AppIcons.clear),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(width: spacing * 2),
              // Tribunale
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCombobox(
                    width: 140,
                    value: (_courtFilter == null || _courtFilter!.isEmpty)
                        ? null
                        : _courtFilter,
                    placeholder: 'Tribunale',
                    groups: _courtGroups,
                    popoverMatchWidestRow: true,
                    items: const [],
                    onChanged: (v) => setState(() => _courtFilter = v ?? ''),
                  ),
                  if ((_courtFilter ?? '').isNotEmpty) ...[
                    SizedBox(width: spacing * 2),
                    Tooltip(
                      message: 'Pulisci tribunale',
                      child: AppButton(
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.icon,
                        onPressed: () => setState(() => _courtFilter = ''),
                        child: const Icon(AppIcons.clear),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(width: spacing * 2),
              // Giudice
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSelect(
                    width: 140,
                    value: (_judgeFilter == null || _judgeFilter!.isEmpty)
                        ? null
                        : _judgeFilter,
                    placeholder: 'Giudice',
                    groups: [
                      SelectGroupData(
                        label: 'Giudici',
                        items: [
                          for (final o in judgeOptions)
                            SelectItemData(value: o, label: o),
                        ],
                      ),
                    ],
                    onChanged: (v) => setState(() => _judgeFilter = v),
                  ),
                  if ((_judgeFilter ?? '').isNotEmpty) ...[
                    SizedBox(width: spacing * 2),
                    Tooltip(
                      message: 'Pulisci giudice',
                      child: AppButton(
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.icon,
                        onPressed: () => setState(() => _judgeFilter = ''),
                        child: const Icon(AppIcons.clear),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              // Azioni a destra
              Wrap(
                spacing: spacing * 2,
                children: [
                  AppButton(
                    variant: AppButtonVariant.outline,
                    onPressed: () => toastInfo(context,
                        'Import udienze: funzione non ancora disponibile'),
                    leading: const Icon(AppIcons.uploadFile),
                    label: 'Importa',
                  ),
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go('/agenda/udienze/list'),
                    leading: const Icon(AppIcons.tableChart),
                    label: 'Elenco',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: spacing * 2),
        if (_error != null) ...[
          SizedBox(height: spacing),
          Text(
            'Errore: $_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_loading) const AppProgressBar(),
      ],
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _eventsScrollCtl.dispose();
    _courtGroupsSub?.cancel();
    super.dispose();
  }

  // Removed _searchMatters (unused)

  // Note: matter suggestions and date pickers are currently unused in this page's UI.
  // Removed unused date picker helpers to satisfy analyzer.

  Future<void> _loadHearings({DateTime? month}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }

      // Determina il mese da caricare: default al mese visibile (o selezionato)
      final baseMonth = month ?? _selectedDay;
      final start = DateTime(baseMonth.year, baseMonth.month, 1);
      final end = DateTime(baseMonth.year, baseMonth.month + 1, 0);
      // Local helper: format a DateTime to YYYY-MM-DD for date-only filters
      String dateOnly(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final qb = _sb
          .from('hearings')
          .select(
              'hearing_id, type, ends_at, time, courtroom, notes, matter_id, done, status')
          .eq('firm_id', fid)
          .gte('ends_at', dateOnly(start))
          .lte('ends_at', dateOnly(end))
          .eq('status', 'active')
          .order('ends_at', ascending: true)
          .order('time', ascending: true);
      final rows = await qb;
      var list = (rows as List).cast<Map<String, dynamic>>();

      // Filtri client-side
      final search = _searchCtl.text.trim().toLowerCase();
      if (search.isNotEmpty) {
        list = list.where((h) {
          final type = ('${h['type'] ?? ''}').toLowerCase();
          final notes = ('${h['notes'] ?? ''}').toLowerCase();
          final room = ('${h['courtroom'] ?? ''}').toLowerCase();
          return type.contains(search) ||
              notes.contains(search) ||
              room.contains(search);
        }).toList();
      }
      if (_fromDate != null) {
        list = list.where((h) {
          final dtStr = '${h['ends_at'] ?? ''}';
          if (dtStr.isEmpty) return false;
          final dt = DateTime.tryParse(dtStr);
          if (dt == null) return false;
          return !dt.isBefore(_fromDate!);
        }).toList();
      }
      if (_toDate != null) {
        final end =
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        list = list.where((h) {
          final dtStr = '${h['ends_at'] ?? ''}';
          if (dtStr.isEmpty) return false;
          final dt = DateTime.tryParse(dtStr);
          if (dt == null) return false;
          return !dt.isAfter(end);
        }).toList();
      }
      if (_matterId != null && _matterId!.isNotEmpty) {
        list =
            list.where((h) => '${h['matter_id'] ?? ''}' == _matterId!).toList();
      }

      // Precarica dettagli pratica (con join clienti per label e controparte)
      final ids = list
          .map((h) => '${h['matter_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      Map<String, Map<String, dynamic>> mattersMap = {};
      if (ids.isNotEmpty) {
        final mrows = await _sb
            .from('matters')
            .select([
              'matter_id',
              'code',
              'title', // usata nelle opzioni del filtro "Pratica"
              'court',
              'judge',
              // controparte e dati cliente per etichetta card
              'counterparty_name',
              'client:clients(client_id,name,surname,kind,company_type)'
            ].join(','))
            .eq('firm_id', fid)
            .inFilter('matter_id', ids);
        final ml = List<Map<String, dynamic>>.from(mrows as List);
        for (final m in ml) {
          mattersMap['${m['matter_id']}'] = m;
        }
      }

      if (!mounted) return;
      setState(() {
        _hearings = list;
        _mattersById = mattersMap;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final y = day.year, m = day.month, d = day.day;
    return _hearings.where((h) {
      final s = '${h['ends_at'] ?? ''}';
      if (s.isEmpty) return false;
      final dt = DateTime.tryParse(s)?.toLocal();
      if (dt == null) return false;
      return dt.year == y && dt.month == m && dt.day == d;
    }).toList();
  }

  Color _colorFor(Map<String, dynamic> h) {
    // Color by type hash
    final type = '${h['type'] ?? ''}';
    final palette = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
    ];
    final i = type.isEmpty
        ? 0
        : (type.codeUnits.fold<int>(0, (p, c) => p + c) % palette.length);
    return palette[i];
  }

  Future<void> _openEdit(String hearingId) async {
    final res = await AppDialog.show(
      context,
      builder: (ctx) => HearingEditDialog(hearingId: hearingId),
    );
    if (!mounted) return;
    await _loadHearings();
    if (!mounted) return;
    if (res is Map && res['deleted'] == true) {
      AppToaster.of(context).success('Udienza eliminata');
    } else if (res != null) {
      AppToaster.of(context).success('Udienza aggiornata');
    }
  }

  Future<void> _openCreateQuick() async {
    final created = await AppDialog.show(
      context,
      builder: (ctx) => HearingCreateDialog(presetDate: _selectedDay),
    );
    if (!mounted) return;
    if (created != null) {
      AppToaster.of(context).success('Udienza creata');
      await _loadHearings();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Applica filtro per il giorno selezionato
    final selectedEventsRaw = _eventsForDay(_selectedDay);
    final dt = Theme.of(context).extension<DefaultTokens>();
    final spacing = dt?.spacingUnit ?? 8.0;

    // Opzioni per Select tribunale/giudice derivanti dai dati caricati
    final courtOptions = _mattersById.values
        .map((m) => '${m['court'] ?? ''}')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final judgeOptions = _mattersById.values
        .map((m) => '${m['judge'] ?? ''}')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // Applica filtri client-side per Tribunale/Giudice alla lista del giorno
    final filteredSelectedEvents = selectedEventsRaw.where((h) {
      final mid = '${h['matter_id'] ?? ''}';
      final m = _mattersById[mid];
      final court = '${m?['court'] ?? ''}';
      final judge = '${m?['judge'] ?? ''}';
      final okCourt =
          (_courtFilter ?? '').isEmpty || court == (_courtFilter ?? '');
      final okJudge =
          (_judgeFilter ?? '').isEmpty || judge == (_judgeFilter ?? '');
      return okCourt && okJudge;
    }).toList();

    return Padding(
      padding: EdgeInsets.all(spacing * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopControls(context, courtOptions, judgeOptions),
          // Layout a due colonne: sinistra 30% udienze del giorno, destra 70% calendario
          Expanded(
            child: Row(
              children: [
                // Colonna sinistra 70% con Calendario (piena altezza)
                Expanded(
                  flex: 7,
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final h = constraints.maxHeight;
                      const headerScale = 0.5; // dimezza altezza intestazione
                      // Imposta cellSize in base all'altezza disponibile e all'intestazione scalata
                      // Condizione: 7*cell + 48 <= h - 24 - (headerH + 8)
                      // con headerH = headerScale * cell ⇒ cell = (h - 80) / (7 + headerScale)
                      final cell =
                          ((h - 80) / (7 + headerScale)).clamp(24.0, 80.0);
                      return Calendar(
                        initialMonth: _selectedDay,
                        selectionMode: CalendarSelectionMode.single,
                        value: _selectedDay,
                        onDaySelected: (sel) => setState(() {
                          _selectedDay = DateTime(sel.year, sel.month, sel.day);
                        }),
                        onMonthChanged: (m) {
                          // Ricarica dal server le udienze del mese visibile
                          _loadHearings(month: m);
                        },
                        captionLayout: CaptionLayout.dropdown,
                        captionSelectSize: SelectSize.md,
                        navButtonVariant: NavButtonVariant.ghost,
                        showWeekNumbers: false,
                        firstDayOfWeek: DateTime.monday,
                        locale: 'it-IT',
                        cellSize: cell,
                        headerScale: headerScale,
                        dayBadgeCount: (day) {
                          // Conta le udienze del giorno applicando gli stessi filtri client-side
                          final raw = _eventsForDay(day);
                          final filtered = raw.where((h) {
                            final mid = '${h['matter_id'] ?? ''}';
                            final m = _mattersById[mid];
                            final court = '${m?['court'] ?? ''}';
                            final judge = '${m?['judge'] ?? ''}';
                            final okMatter = (_matterId ?? '').isEmpty ||
                                mid == (_matterId ?? '');
                            final okCourt = (_courtFilter ?? '').isEmpty ||
                                court == (_courtFilter ?? '');
                            final okJudge = (_judgeFilter ?? '').isEmpty ||
                                judge == (_judgeFilter ?? '');
                            return okMatter && okCourt && okJudge;
                          }).toList();
                          return filtered.length;
                        },
                      );
                    },
                  ),
                ),
                // Separatore verticale tra calendario ed elenco
                SizedBox(
                  width: spacing * 2,
                  child: Center(
                    child: Container(
                      width: 1,
                      height: double.infinity,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                // Colonna destra 30%: udienze del giorno selezionato
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Udienze del ${_fmtDay(_selectedDay)}',
                          style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: spacing),
                      Expanded(
                        child: Scrollbar(
                          controller: _eventsScrollCtl,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _eventsScrollCtl,
                            itemCount: filteredSelectedEvents.length,
                            itemBuilder: (ctx, i) =>
                                _eventTile(filteredSelectedEvents[i]),
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
    );
  }

  Widget _eventTile(Map<String, dynamic> h) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final id = '${h['hearing_id'] ?? ''}';
    final timeOnly = _fmtTimeOnly(h['time']);
    final mid = '${h['matter_id'] ?? ''}';
    final m = _mattersById[mid];
    final court = '${m?['court'] ?? ''}';
    final judge = '${m?['judge'] ?? ''}';
    final matterLabel = _buildMatterLabel(m);
    final dynamic doneVal = h['done'];
    final bool isDone = (doneVal == true) ||
        (doneVal is String && (doneVal.toLowerCase() == 't' || doneVal.toLowerCase() == 'true')) ||
        (doneVal is int && doneVal != 0);
    return GestureDetector(
      onTap: () { if (isDone) { AppToaster.of(context).warning('Udienza già evasa'); } else { _openDisposition(h); } },
      child: Container(
        // Aumenta leggermente la spaziatura verticale della card
        margin: EdgeInsets.symmetric(vertical: su * 0.75),
        padding: EdgeInsets.all(su),
        decoration: BoxDecoration(
          border: Border.all(color: isDone ? Theme.of(context).colorScheme.outlineVariant : _colorFor(h)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Rimosso il rettangolo verticale colorato (non necessario)
            // Manteniamo solo il contenuto principale senza barra di stato
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1) Pratica in alto: stesso container della lista Agenda (Chip)
                  if (matterLabel.isNotEmpty)
                    Chip(
                      backgroundColor: isDone ? Colors.transparent : Theme.of(context).colorScheme.tertiary,
                      avatar: Icon(
                        AppIcons.folder,
                        size: 16,
                        color: Theme.of(context).colorScheme.onTertiary,
                      ),
                      label: Text(
                        matterLabel,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onTertiary,
                            ),
                      ),
                    ),
                  if (matterLabel.isNotEmpty) SizedBox(height: su * 0.75),
                  // 2) Tribunale
                  Text(court.isEmpty ? '—' : court, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDone ? Theme.of(context).disabledColor : null,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  )),
                  SizedBox(height: su * 0.5),
                  // 3) Giudice
                  Text(judge.isEmpty ? '—' : judge, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDone ? Theme.of(context).disabledColor : null,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  )),
                  SizedBox(height: su * 0.5),
                  // 4) Ora udienza (solo HH:mm)
                  Text(timeOnly, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDone ? Theme.of(context).disabledColor : null,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  )),
                ],
              ),
            ),
            SizedBox(width: su),
            AppButton(
              size: AppButtonSize.icon,
              variant: AppButtonVariant.outline,
              onPressed: id.isEmpty ? null : () => _openEdit(id),
              child: const Icon(AppIcons.edit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDisposition(Map<String, dynamic> hearing) async {
    final res = await AppDialog.show(
      context,
      builder: (ctx) => HearingDispositionDialog(hearing: hearing),
    );
    if (!mounted) return;
    await _loadHearings();
    if (!mounted) return;
    if (res is Map) {
      final msg = (res['message'] ?? '') as String;
      if (msg.isNotEmpty) {
        AppToaster.of(context).success(msg);
      } else if (res['outcome'] != null) {
        // Fallback generico, nel caso la dialog non fornisca il messaggio dettagliato
        final outcome = res['outcome'];
        if (outcome == 'rinviata') {
          AppToaster.of(context).success('Udienza rinviata');
        } else if (outcome == 'in_riserva') {
          AppToaster.of(context)
              .success('Adempimento creato: Verifica Scioglimento');
        } else if (outcome == 'a_sentenza') {
          AppToaster.of(context)
              .success('Adempimento creato: Verifica Provvedimento');
        }
      }
    }
  }

  // Formatta solo l'ora HH:mm partendo da campo time (stringa HH:mm o HH:mm:ss)
  String _fmtTimeOnly(dynamic timeVal) {
    int hh = 0, mi = 0;
    if (timeVal != null) {
      final t = '$timeVal';
      final parts = t.split(':');
      if (parts.length >= 2) {
        hh = int.tryParse(parts[0]) ?? 0;
        mi = int.tryParse(parts[1]) ?? 0;
      }
    }
    final sh = hh.toString().padLeft(2, '0');
    final sm = mi.toString().padLeft(2, '0');
    return '$sh:$sm';
  }

  /// Costruisce l'etichetta pratica: "CODICE — Cliente / Controparte"
  String _buildMatterLabel(Map<String, dynamic>? m) {
    if (m == null) return '—';
    final code = '${m['code'] ?? ''}';
    final counterparty = '${m['counterparty_name'] ?? ''}';
    // Estrai cliente dal join
    String clientName() {
      final c = m['client'];
      if (c is Map) {
        final kind = '${c['kind'] ?? ''}';
        if (kind == 'person') {
          final name = '${c['name'] ?? ''}';
          final surname = '${c['surname'] ?? ''}';
          final s = [name, surname].where((e) => e.trim().isNotEmpty).join(' ');
          return s.trim();
        } else if (kind == 'company') {
          final companyName = '${c['name'] ?? ''}';
          final companyType = '${c['company_type'] ?? ''}';
          final s = [companyName, companyType]
              .where((e) => e.trim().isNotEmpty)
              .join(' ');
          return s.trim();
        }
      }
      return '';
    }

    final client = clientName();
    final parts = <String>[
      if (code.isNotEmpty) code,
      if (client.isNotEmpty || counterparty.isNotEmpty)
        [client, counterparty].where((e) => e.isNotEmpty).join(' / '),
    ];
    return parts.where((e) => e.isNotEmpty).join(' — ');
  }

  String _fmtDay(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

// Rimosso _MatterOption inutilizzato
