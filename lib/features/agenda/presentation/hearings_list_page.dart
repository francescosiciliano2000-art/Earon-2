// lib/features/agenda/presentation/hearings_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/components/input_group.dart';
import '../../../design system/components/pagination.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/app_data_table.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_edit_dialog.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_create_dialog.dart';
// import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/alert_dialog.dart';
import '../../courtroom/data/courtroom_repo.dart';

class HearingsListPage extends StatefulWidget {
  const HearingsListPage({super.key});

  @override
  State<HearingsListPage> createState() => _HearingsListPageState();
}

class _HearingsListPageState extends State<HearingsListPage> {
  late final SupabaseClient _sb;
  // Removed MatterRepo (not used here)

  bool _loading = false;
  String? _error;

  // Filters
  final _searchCtl = TextEditingController();

  String? _matterId;
  // Matter text input + suggestions not used in list page

  // Client-side quick filters (Selects per Tribunale e Giudice)
  String? _courtFilter; // selected court value
  String? _judgeFilter; // selected judge value

  // Opzioni Tribunale raggruppate per regione dal file courtroom.json
  List<ComboboxGroupData> _courtGroups = const [];
  StreamSubscription<List<ComboboxGroupData>>? _courtGroupsSub;

  // Data
  List<Map<String, dynamic>> _hearings = const [];
  Map<String, Map<String, dynamic>> _mattersById = const {};

  // Ordinamento + selezione tabella
  // Ordina per data udienza (ends_at) di default
  String _orderBy = 'ends_at';
  // Ordinamento iniziale: dal più recente al meno recente
  bool _asc = false;
  final Set<String> _selectedIds = {};

  // Paginazione client-side (come Clienti/Pratiche)
  int _page = 0;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    // Osserva courtroom.json e aggiorna gruppi tribunali
    _courtGroupsSub = CourtroomRepo().watchGroups().listen((groups) {
      if (!mounted) return;
      setState(() => _courtGroups = groups);
    });
    _loadHearings();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _courtGroupsSub?.cancel();
    super.dispose();
  }

  // Removed unused matter suggestions helpers

  Future<void> _loadHearings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }

      final qb = _sb
          .from('hearings')
          .select('hearing_id, type, ends_at, time, courtroom, notes, matter_id, status')
          .eq('firm_id', fid)
          .eq('status', 'active')
          .order('ends_at', ascending: false, nullsFirst: false)
          .order('time', ascending: false, nullsFirst: false)
          .range(0, 499);
      final rows = await qb;
      var list = (rows as List).cast<Map<String, dynamic>>();

      // Precarica dettagli pratica (tribunale/giudice/codice + dati cliente/controparte)
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
              'title',
              'court',
              'judge',
              // aggiungi controparte e join cliente per la label
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

      // Filtri client-side: ricerca testo (incl. dettagli pratica), data da/a, pratica
      final search = _searchCtl.text.trim().toLowerCase();
      if (search.isNotEmpty) {
        list = list.where((h) {
          final type = ('${h['type'] ?? ''}').toLowerCase();
          final notes = ('${h['notes'] ?? ''}').toLowerCase();
          final room = ('${h['courtroom'] ?? ''}').toLowerCase();
          final mid = '${h['matter_id'] ?? ''}';
          final m = mattersMap[mid];
          final court = ('${m?['court'] ?? ''}').toLowerCase();
          final judge = ('${m?['judge'] ?? ''}').toLowerCase();
          final code = ('${m?['code'] ?? ''}').toLowerCase();
          final title = ('${m?['title'] ?? ''}').toLowerCase();
          return type.contains(search) ||
              notes.contains(search) ||
              room.contains(search) ||
              court.contains(search) ||
              judge.contains(search) ||
              code.contains(search) ||
              title.contains(search);
        }).toList();
      }

      if (_matterId != null && _matterId!.isNotEmpty) {
        list =
            list.where((h) => '${h['matter_id'] ?? ''}' == _matterId!).toList();
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

  Future<void> _openCreateHearing() async {
    final created = await AppDialog.show(
      context,
      builder: (ctx) => const HearingCreateDialog(),
    );
    if (!mounted) return;
    if (created != null) await _loadHearings();
  }

  Future<void> _openEdit(String hearingId) async {
    final res = await AppDialog.show(
      context,
      builder: (ctx) => HearingEditDialog(hearingId: hearingId),
    );
    if (!mounted) return;
    await _loadHearings();
    if (!mounted) return;
    final toaster = AppToaster.of(context);
    if (res is Map && res['deleted'] == true) {
      toaster.success('Udienza eliminata');
    } else if (res != null) {
      toaster.success('Udienza aggiornata');
    }
  }

  Future<void> _deleteHearing(String hearingId) async {
    await AppAlertDialog.show<void>(
      context,
      title: 'Elimina udienza',
      description:
          'Confermi l’eliminazione di questa udienza?\nL’operazione non può essere annullata.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        if (!mounted) return;
        final toaster = AppToaster.of(context);
        toaster.loading('Eliminazione udienza…');
        try {
          await _sb.from('hearings').delete().eq('hearing_id', hearingId);
          if (!mounted) return;
          toaster.success('Udienza eliminata');
          await _loadHearings();
        } catch (e) {
          if (!mounted) return;
          toaster.error('Udienza non eliminata correttamente',
              description: e.toString());
        }
      },
    );
  }

  // Toolbar, filtri e messaggi di stato (loading/errore)
  Widget _buildTopControls(BuildContext context, List<String> courtOptions, List<String> judgeOptions, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar: padding uniforme e spaziatura coerente
        Padding(
          padding: EdgeInsets.all(spacing * 2),
          child: Row(
            children: [
              // Cerca con larghezza fissa coerente
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
              // Pratica (facoltativa)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCombobox(
                    width: 190,
                    value: _matterId,
                    placeholder: 'Pratica…',
                    popoverWidthFactor: 1.6,
                    // La lista si adatta alla riga più lunga
                    popoverMatchWidestRow: true,
                    items: [
                      // Opzione di reset
                      const ComboboxItem(value: '', label: 'Tutte'),
                      for (final m in _mattersById.values)
                        if ('${m['code'] ?? ''}'.isNotEmpty)
                          ComboboxItem(
                            value: '${m['matter_id'] ?? ''}',
                            label: _buildMatterLabel(m),
                          ),
                    ],
                    onChanged: (v) {
                      setState(() => _matterId = (v == null || v.isEmpty) ? '' : v);
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
                    value: (_courtFilter == null || _courtFilter!.isEmpty) ? null : _courtFilter,
                    placeholder: 'Tribunale…',
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
                    value: (_judgeFilter == null || _judgeFilter!.isEmpty) ? null : _judgeFilter,
                    placeholder: 'Giudice…',
                    groups: [
                      SelectGroupData(
                        label: 'Giudici',
                        items: [
                          for (final o in judgeOptions) SelectItemData(value: o, label: o),
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
                    onPressed: () => toastInfo(
                        context, 'Import udienze: funzione non ancora disponibile'),
                    leading: const Icon(AppIcons.uploadFile),
                    label: 'Importa',
                  ),
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go('/agenda/udienze/calendar'),
                    leading: const Icon(AppIcons.calendar),
                    label: 'Calendario',
                  ),
                ],
              ),
            ],
          ),
        ),
        // Fine toolbar
        SizedBox(height: spacing),
        SizedBox(height: spacing),
        if (_loading) const AppProgressBar(),
        // Messaggio errore
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(top: spacing),
            child: Text(
              'Errore: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredClientSide {
    final cf = (_courtFilter ?? '').trim();
    final jf = (_judgeFilter ?? '').trim();
    return _hearings.where((h) {
      final mid = '${h['matter_id'] ?? ''}';
      final m = _mattersById[mid];
      final court = '${m?['court'] ?? ''}';
      final judge = '${m?['judge'] ?? ''}';
      final okCourt = cf.isEmpty || court == cf;
      final okJudge = jf.isEmpty || judge == jf;
      return okCourt && okJudge;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = List<Map<String, dynamic>>.from(_filteredClientSide);
    rows.sort((a, b) {
      int compare;
      switch (_orderBy) {
        case 'ends_at':
          final da = _composeDateTimeFromEndsAndTime(a['ends_at'], a['time']);
          final db = _composeDateTimeFromEndsAndTime(b['ends_at'], b['time']);
          final ca = da?.millisecondsSinceEpoch ?? -1;
          final cb = db?.millisecondsSinceEpoch ?? -1;
          compare = ca.compareTo(cb);
          break;
        case 'court':
          final ma = _mattersById['${a['matter_id'] ?? ''}'];
          final mb = _mattersById['${b['matter_id'] ?? ''}'];
          compare =
              ('${ma?['court'] ?? ''}').compareTo('${mb?['court'] ?? ''}');
          break;
        case 'judge':
          final ma = _mattersById['${a['matter_id'] ?? ''}'];
          final mb = _mattersById['${b['matter_id'] ?? ''}'];
          compare =
              ('${ma?['judge'] ?? ''}').compareTo('${mb?['judge'] ?? ''}');
          break;
        case 'courtroom':
          compare =
              ('${a['courtroom'] ?? ''}').compareTo('${b['courtroom'] ?? ''}');
          break;
        case 'matter':
          final ma = _mattersById['${a['matter_id'] ?? ''}'];
          final mb = _mattersById['${b['matter_id'] ?? ''}'];
          final sa = '${ma?['code'] ?? ''} ${ma?['title'] ?? ''}';
          final sb = '${mb?['code'] ?? ''} ${mb?['title'] ?? ''}';
          compare = sa.compareTo(sb);
          break;
        default:
          compare = 0;
      }
      return _asc ? compare : -compare;
    });
    final total = rows.length;
    final start = (_page * _pageSize).clamp(0, total);
    final end = ((start + _pageSize) > total) ? total : (start + _pageSize);
    final visibleRows = rows.sublist(start, end);
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

    return Padding(
      padding: EdgeInsets.all(spacing * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              AppButton(
                variant: AppButtonVariant.default_,
                onPressed: _openCreateHearing,
                leading: const Icon(AppIcons.add),
                label: 'Nuova',
              ),
            ],
          ),
          SizedBox(height: spacing * 2),
          // Card espanso: fornisce vincoli di altezza finiti al contenuto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopControls(context, courtOptions, judgeOptions, spacing),
                // Tabella dentro Expanded + scroll verticale per vincoli stabili
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing),
                    child: (!_loading && _error == null)
                        ? AppDataTable(
                      selectionInFirstCell: true,
                      selectable: true,
                      allSelected: visibleRows.isNotEmpty &&
                          visibleRows.every((h) => _selectedIds
                              .contains('${h['hearing_id'] ?? ''}')),
                      onToggleAll: () {
                        setState(() {
                          final all = visibleRows.isNotEmpty &&
                              visibleRows.every((h) => _selectedIds
                                  .contains('${h['hearing_id'] ?? ''}'));
                          if (all) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(visibleRows
                                .map((h) => '${h['hearing_id'] ?? ''}')
                                .where((id) => id.isNotEmpty));
                          }
                        });
                      },
                      selectedRows: [
                        for (final h in visibleRows)
                          _selectedIds.contains('${h['hearing_id'] ?? ''}')
                      ],
                      onToggleRow: (i, v) {
                        final id = '${visibleRows[i]['hearing_id'] ?? ''}';
                        setState(() {
                          if (v) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                      columns: [
                        AppDataColumn(
                          label: 'Data',
                          width: 160,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'ends_at') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'ends_at';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'ends_at' ? _asc : null,
                        ),
                        AppDataColumn(
                          label: 'Tribunale',
                          width: 180,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'court') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'court';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'court' ? _asc : null,
                        ),
                        AppDataColumn(
                          label: 'Giudice',
                          width: 180,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'judge') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'judge';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'judge' ? _asc : null,
                        ),
                        AppDataColumn(
                          label: 'Sala',
                          width: 120,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'courtroom') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'courtroom';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'courtroom' ? _asc : null,
                        ),
                        AppDataColumn(
                          label: 'Pratica',
                          width: 280,
                          onLabelTap: () {
                            setState(() {
                              if (_orderBy == 'matter') {
                                _asc = !_asc;
                              } else {
                                _orderBy = 'matter';
                                _asc = true;
                              }
                            });
                          },
                          sortAscending: _orderBy == 'matter' ? _asc : null,
                        ),
                        // Nessuna colonna "Azioni": le azioni vanno nel rowMenu come in Pratiche/Clienti
                      ],
                      rows: visibleRows.map((h) {
                        final id = '${h['hearing_id'] ?? ''}';
                        final starts = _fmtEndsAndTime(h['ends_at'], h['time']);
                        final room = '${h['courtroom'] ?? ''}';
                        final mid = '${h['matter_id'] ?? ''}';
                        final m = _mattersById[mid];
                        final court = '${m?['court'] ?? ''}';
                        final judge = '${m?['judge'] ?? ''}';
                        final matterLabel = _buildMatterLabel(m);
                        return AppDataRow(
                          onTap: id.isEmpty ? null : () => _openEdit(id),
                          cells: [
                            Text(starts),
                            Text(court.isEmpty ? '—' : court),
                            Text(judge.isEmpty ? '—' : judge),
                            Text(room.isEmpty ? '—' : room),
                            Text(matterLabel, overflow: TextOverflow.ellipsis),
                          ],
                          rowMenu: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                variant: AppButtonVariant.outline,
                                size: AppButtonSize.iconSm,
                                circular: true,
                                onPressed:
                                    id.isEmpty ? null : () => _openEdit(id),
                                child: const Icon(AppIcons.edit),
                              ),
                              SizedBox(width: spacing),
                              AppButton(
                                variant: AppButtonVariant.destructive,
                                size: AppButtonSize.iconSm,
                                circular: true,
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _deleteHearing(id),
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
                // Footer: paginazione sotto la tabella
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: spacing * 2, vertical: spacing),
                  child: Row(
                    children: [
                      Text('$total udienze totali'),
                      const Spacer(),
                      Pagination(
                        child: PaginationContent(
                          children: [
                            PaginationPrevious(
                              onPressed:
                                  _page > 0 ? () => setState(() => _page -= 1) : null,
                              label: 'Precedente',
                            ),
                            PaginationItem(
                              child: PaginationLink(
                                isActive: true,
                                child: Text('${_page + 1}'),
                              ),
                            ),
                            PaginationNext(
                              onPressed: ((_page + 1) * _pageSize < total)
                                  ? () => setState(() => _page += 1)
                                  : null,
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
          ),
        ],
      ),
    );
  }

  /// Combina la data di ends_at (solo giorno/mese/anno) con l'ora dal campo `time`.
  /// Supporta time in formato "HH:MM" o "HH:MM:SS".
  String _fmtEndsAndTime(dynamic endsAt, dynamic time) {
    if (endsAt == null) return '—';
    DateTime? d;
    try {
      d = DateTime.parse('$endsAt').toLocal();
    } catch (_) {
      d = null;
    }
    if (d == null) return '—';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    String hh = '00';
    String mi = '00';
    if (time != null) {
      final ts = '$time';
      final parts = ts.split(':');
      if (parts.isNotEmpty) hh = parts[0].padLeft(2, '0');
      if (parts.length > 1) mi = parts[1].padLeft(2, '0');
    }
    return '$dd/$mm/${d.year} $hh:$mi';
  }

  /// Costruisce un DateTime combinando la data di `ends_at` e la stringa `time`.
  /// Utile per l'ordinamento client-side.
  DateTime? _composeDateTimeFromEndsAndTime(dynamic endsAt, dynamic time) {
    try {
      final d = DateTime.parse('$endsAt').toLocal();
      int hh = 0;
      int mi = 0;
      if (time != null) {
        final ts = '$time';
        final parts = ts.split(':');
        if (parts.isNotEmpty) hh = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1) mi = int.tryParse(parts[1]) ?? 0;
      }
      return DateTime(d.year, d.month, d.day, hh, mi);
    } catch (_) {
      return null;
    }
  }

  /// Costruisce la label pratica "CODICE — Cliente / Controparte".
  /// Usa il join `client:clients(...)` quando disponibile; gestisce persona/azienda.
  String _buildMatterLabel(Map<String, dynamic>? m) {
    if (m == null) return '—';
    final code = '${m['code'] ?? ''}'.trim();
    final counterparty = '${m['counterparty_name'] ?? ''}'.trim();
    String client = '';
    final c = m['client'];
    if (c is Map) {
      final kind = '${c['kind'] ?? ''}';
      if (kind == 'person') {
        final name = '${c['name'] ?? ''}'.trim();
        final surname = '${c['surname'] ?? ''}'.trim();
        client = [name, surname].where((e) => e.isNotEmpty).join(' ');
      } else if (kind == 'company') {
        final companyName = '${c['name'] ?? ''}'.trim();
        final companyType = '${c['company_type'] ?? ''}'.trim();
        client = [companyName, companyType].where((e) => e.isNotEmpty).join(' ');
      }
    }
    final right = [client, counterparty].where((e) => e.isNotEmpty).join(' / ');
    final parts = <String>[
      if (code.isNotEmpty) code,
      if (right.isNotEmpty) right,
    ];
    return parts.where((e) => e.isNotEmpty).join(' — ');
  }
}

// Rimosso _MatterOption inutilizzato
