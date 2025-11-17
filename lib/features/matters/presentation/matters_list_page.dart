// lib/features/matters/presentation/matters_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../design system/components/button.dart';
import '../../../design system/components/input_group.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/multiselect.dart';
import '../../../design system/components/pagination.dart';
import '../../../design system/components/app_data_table.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/alert_dialog.dart';
import '../../../design system/components/sheet.dart';
import '../../courtroom/data/courtroom_repo.dart';

import '../../matters/data/matter_model.dart';
import '../../matters/data/matter_repo.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
// import 'matter_create_sheet.dart';
import 'matter_detail_sheet.dart';
import 'new_matter_dialog.dart';
import '../../firms/presentation/select_firm_placeholder.dart';

class MattersListPage extends StatefulWidget {
  const MattersListPage({super.key});

  @override
  State<MattersListPage> createState() => _MattersListPageState();
}

class _MattersListPageState extends State<MattersListPage> {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;

  bool _loading = true;
  String? _error;
  String? _firmId; // firm selezionata
  // ignore: prefer_final_fields
bool _firmResolving = true;
  List<Matter> _rows = [];
  // Selezione righe + ordinamento
  final Set<String> _selectedIds = <String>{};
  String _orderBy = 'created_at';
  bool _asc = false; // default: creato desc

  // Filtri
  final Set<String> _statusSelected = {};
  // Suggerimenti stato non utilizzati nella UI: rimossi per pulizia warning
  String _openFilter = 'all';

  String? _selectedCourt; // court è text nello schema
  // Gruppi tribunali (Foro) da courtroom.json
  List<ComboboxGroupData> _courtGroups = const [];
  StreamSubscription<List<ComboboxGroupData>>? _courtGroupsSub;

  final _searchCtl = TextEditingController();

  // paginazione semplice
  int _page = 0; // 0-based UI
  int _pageSize = 20;
  int _total = 0;

  // SharedPrefs keys per persistenza minima
  static const _prefsKeySearch = 'matters_search';
  static const _prefsKeyPageSize = 'matters_page_size';
  static const _kColsVisibleKey = 'matters_visible_cols';

  // Gestione colonne personalizzabili
  late Map<String, ({String label, double? width})> _columnsMeta;
  List<String> _visibleCols = [];

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _initColumnsMeta();
    _bootstrap();
    // Osserva courtroom.json e aggiorna gruppi foro
    _courtGroupsSub = CourtroomRepo().watchGroups().listen((groups) {
      if (!mounted) return;
      setState(() => _courtGroups = groups);
    });
  }

  void _initColumnsMeta() {
    _columnsMeta = {
      'code': (label: 'Codice', width: null),
      'title': (label: 'Oggetto', width: 280.0),
      'client': (label: 'Cliente', width: 220.0),
      'status': (label: 'Stato', width: 140.0),
      'area': (label: 'Area', width: 160.0),
      'court': (label: 'Foro', width: 160.0),
      'judge': (label: 'Giudice', width: 160.0),
      'counterparty_name': (label: 'Controparte', width: 200.0),
      'rg_number': (label: 'RG', width: 140.0),
      'description': (label: 'Descrizione', width: 240.0),
      // rimosse dalle opzioni: created_at / opened_at / closed_at
    };
    _visibleCols = ['code', 'title', 'client', 'status'];
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _courtGroupsSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadPrefs();
      final fid = await getCurrentFirmId();
      _firmId = fid;
      if (fid == null || fid.isEmpty) {
        // Gate: nessuno studio selezionato → non caricare lista, mostra placeholder in build
        return;
      }
      if (mounted) {
        setState(() {
        });
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        toastError(context, 'Errore: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    // rimosso: preferenza kanban
    _searchCtl.text = sp.getString(_prefsKeySearch) ?? _searchCtl.text;
    _pageSize = sp.getInt(_prefsKeyPageSize) ?? _pageSize;
    
    // Carica colonne visibili
    final savedCols = sp.getStringList(_kColsVisibleKey);
    if (savedCols != null && savedCols.isNotEmpty) {
      _visibleCols = savedCols.where(_columnsMeta.containsKey).toList();
      if (_visibleCols.isEmpty) {
        _visibleCols = ['code', 'title', 'client', 'status'];
      }
    }
  }


  Future<void> _savePrefsSearch() async {
    final sp = await SharedPreferences.getInstance();
    final s = _searchCtl.text.trim();
    if (s.isEmpty) {
      await sp.remove(_prefsKeySearch);
    } else {
      await sp.setString(_prefsKeySearch, s);
    }
  }


  Future<void> _persistVisible() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kColsVisibleKey, _visibleCols);
  }


  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statusList =
          _openFilter == 'all' ? const <String>[] : <String>[_openFilter];
      final rowsF = _repo.list(
        status: statusList,
        courtId: _selectedCourt,
        search: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim(),
        searchFields: const ['code', 'rg_number', 'client'],
        page: _page + 1,
        pageSize: _pageSize,
        orderBy: _orderBy,
        asc: _asc,
      );
      final countF = _repo.count(
        status: statusList,
        courtId: _selectedCourt,
        search: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim(),
        searchFields: const ['code', 'rg_number', 'client'],
      );
      final results = await Future.wait([rowsF, countF]);
      final rows = results[0] as List<Matter>;
      final total = results[1] as int;
      setState(() {
        _rows = rows;
        _total = total;
      });
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        toastError(context, 'Errore caricamento pratiche: $e');
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toggleSort(String field) {
    setState(() {
      if (_orderBy == field) {
        _asc = !_asc;
      } else {
        _orderBy = field;
        _asc = true;
      }
      _page = 0;
    });
    _load();
  }

  Future<void> _confirmDeleteMatter(String matterId) async {
    await AppAlertDialog.show<void>(
      context,
      title: 'Elimina pratica',
      description: 'Confermi l’eliminazione di questa pratica?\nL’operazione non può essere annullata.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        final toaster = AppToaster.of(context);
        toaster.loading('Eliminazione pratica…');
        try {
          await _repo.delete(matterId);
          _selectedIds.remove(matterId);
          if (!mounted) return;
          toaster.success('Pratica eliminata');
          await _load();
        } catch (e) {
          if (!mounted) return;
          toaster.error('Pratica non eliminata correttamente', description: '$e');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double su =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final fid = _firmId ?? '';
    final gate = _firmResolving
        ? null
        : (fid.isEmpty ? const SelectFirmPlaceholder() : null);
    return Scaffold(
      // rimosso TopBar: titolo, cerca, aggiorna, utente
      body: Padding(
        padding: EdgeInsets.all(su * 3),
        child: gate ?? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header con pulsante Nuova in alto a destra (come Clienti)
            Row(
              children: [
                const Spacer(),
                AppButton(
                  variant: AppButtonVariant.default_,
                  onPressed: _openNewMatter,
                  leading: const Icon(AppIcons.folderAdd),
                  label: 'Nuova',
                ),
              ],
            ),
            SizedBox(height: su * 2),

            // Toolbar: layout identico a Clienti (search espansa + open + foro + importa)
            Padding(
              padding: EdgeInsets.all(su * 2),
              child: _toolbar(),
            ),

            // Loader lineare come in Agenda/Udienze
            if (_loading) const AppProgressBar(),

            // Tabella
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : _error != null
                  ? Center(child: Text('Errore: $_error'))
                  : _rows.isEmpty
                      ? _buildEmptyState()
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: su),
                          child: _buildTable(),
                        ),
            ),

            // Footer: paginazione (senza select per righe per pagina)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: su * 2, vertical: su),
              child: Row(
                children: [
                  Text('$_total pratiche totali'),
                  const Spacer(),
                  Pagination(
                    child: PaginationContent(
                      children: [
                        PaginationPrevious(
                          onPressed: _page > 0
                              ? () {
                                  setState(() => _page -= 1);
                                  _load();
                                }
                              : null,
                          label: 'Precedente',
                        ),
                        PaginationItem(
                          child: PaginationLink(
                            isActive: true,
                            child: Text('${_page + 1}'),
                          ),
                        ),
                        PaginationNext(
                          onPressed: ((_page + 1) * _pageSize < _total)
                              ? () {
                                  setState(() => _page += 1);
                                  _load();
                                }
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
    );
  }

  Widget _toolbar() {
    final double su =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return Row(
      children: [
        // Cerca con larghezza fissa (coerente con altre pagine)
        SizedBox(
          width: su * 35,
          child: AppInputGroup(
            controller: _searchCtl,
            hintText: 'Cerca per codice, RG o cliente…',
            leading: const Icon(AppIcons.search),
            onSubmitted: (_) {
              setState(() => _page = 0);
              _savePrefsSearch();
              _load();
            },
            onChanged: (_) {
              setState(() => _page = 0);
              _load();
            },
          ),
        ),
        SizedBox(width: su * 2),

        // Filtro Open (Tutte/Aperte/Chiuse)
        AppSelect(
          value: _openFilter,
          placeholder: 'Stato',
          onChanged: (v) {
            setState(() {
              _openFilter = v.isEmpty ? 'all' : v;
              _page = 0;
            });
            _load();
          },
          groups: const [
            SelectGroupData(
              label: 'Stato',
              items: [
                SelectItemData(value: 'all', label: 'Tutte'),
                SelectItemData(value: 'open', label: 'Aperte'),
                SelectItemData(value: 'closed', label: 'Chiuse'),
              ],
            ),
          ],
        ),
        SizedBox(width: su * 2),

        // Combobox Foro di fianco al filtro Open, sulla sinistra
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCombobox(
              value: _selectedCourt,
              placeholder: 'Foro',
              groups: _courtGroups,
              popoverMatchWidestRow: true,
              items: const [],
              onChanged: (v) {
                setState(() {
                  _selectedCourt = (v == null || v.isEmpty) ? null : v;
                  _page = 0;
                });
                _load();
              },
            ),
            if ((_selectedCourt ?? '').isNotEmpty) ...[
              SizedBox(width: su * 2),
              AppButton(
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.icon,
                onPressed: () {
                  setState(() {
                    _selectedCourt = null;
                    _page = 0;
                  });
                  _load();
                },
                child: const Icon(AppIcons.clear, size: 16),
              ),
            ],
          ],
        ),
        SizedBox(width: su * 2),
        const Spacer(),
        // A destra: selettore colonne seguito dal pulsante Importa
        AppMultiSelect(
          values: _visibleCols,
          placeholder: 'Colonne',
          onChanged: (newCols) {
            setState(() {
              _visibleCols = newCols;
            });
            _persistVisible();
          },
          groups: [
            MultiSelectGroupData(
              label: 'Colonne visibili',
              items: _columnsMeta.entries
                  .map((e) => MultiSelectItemData(
                        value: e.key,
                        label: e.value.label,
                      ))
                  .toList(),
            ),
          ],
        ),
        SizedBox(width: su * 2),
        AppButton(
          variant: AppButtonVariant.outline,
          leading: const Icon(AppIcons.uploadFile),
          onPressed: () {
            toastInfo(
                context, 'Importa pratiche: funzione non ancora disponibile');
          },
          label: 'Importa',
        ),
      ],
    );
  }

   List<AppDataColumn> _buildColumns() {
     return _visibleCols.map((colKey) {
       final meta = _columnsMeta[colKey]!;
       // Mappa il campo di ordinamento reale quando differisce dalla chiave visibile
       final String sortField = switch (colKey) {
         // Al momento il nome cliente non è joinato: usiamo client_id per ordinare
       'client' => 'client_id',
        'counterparty_name' => 'counterparty_name',
        'rg_number' => 'rg_number',
        // Altri campi corrispondono direttamente alle colonne del DB
        _ => colKey,
      };
      return AppDataColumn(
        label: meta.label,
        width: meta.width,
        onLabelTap: () => _toggleSort(sortField),
        sortAscending: _orderBy == sortField ? _asc : null,
      );
    }).toList();
  }

  List<Widget> _buildCells(Matter m) {
    return _visibleCols.map((colKey) {
      switch (colKey) {
        case 'code':
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(m.code, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        case 'title':
          return Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis);
        case 'client':
          return Text(m.clientDisplayName ?? '—',
              maxLines: 1, overflow: TextOverflow.ellipsis);
        case 'status':
          return Text(m.status ?? '—');
        case 'area':
          return Text(m.area ?? '—');
        case 'court':
          return Text(m.court ?? '—');
        case 'judge':
          return Text(m.judge ?? '—');
        case 'counterparty_name':
          return Text(m.counterpartyName ?? '—',
              maxLines: 1, overflow: TextOverflow.ellipsis);
        case 'rg_number':
          return Text(m.rgNumber ?? '—');
        case 'description':
          return Text(m.description ?? '—',
              maxLines: 1, overflow: TextOverflow.ellipsis);
        default:
          return const Text('—');
      }
    }).toList();
  }

  Widget _buildTable() {
    return AppDataTable(
      selectionInFirstCell: true,
      selectable: true,
      allSelected: _rows.isNotEmpty &&
          _rows.every((m) => _selectedIds.contains(m.matterId)),
      onToggleAll: () {
        setState(() {
          final all = _rows.isNotEmpty &&
              _rows.every((m) => _selectedIds.contains(m.matterId));
          if (all) {
            _selectedIds.clear();
          } else {
            _selectedIds.addAll(_rows.map((m) => m.matterId));
          }
        });
      },
      selectedRows: [
        for (final m in _rows) _selectedIds.contains(m.matterId),
      ],
      onToggleRow: (i, v) {
        final id = _rows[i].matterId;
        setState(() {
          if (v) {
            _selectedIds.add(id);
          } else {
            _selectedIds.remove(id);
          }
        });
      },
      columns: _buildColumns(),
      rows: [
        for (final m in _rows)
          AppDataRow(
            onTap: () {
              showSheet<void>(
                context,
                builder: (_) => MatterDetailSheet(matterId: m.matterId.toString()),
                side: SheetSide.right,
                maxWidth: 537,
                widthFraction: 0.70,
              );
            },
            cells: _buildCells(m),
            rowMenu: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.iconSm,
                  circular: true,
                  child: const Icon(AppIcons.edit),
                  onPressed: () async {
                    final updated = await AppDialog.show<Matter>(
                      context,
                      builder: (_) => NewMatterDialog(editing: m),
                    );
                    if (updated != null) {
                      setState(() {
                        _page = 0;
                      });
                      _load();
                    }
                  },
                ),
                SizedBox(
                    width: (Theme.of(context)
                            .extension<DefaultTokens>()
                            ?.spacingUnit ??
                        8.0)),
                AppButton(
                  variant: AppButtonVariant.destructive,
                  size: AppButtonSize.iconSm,
                  circular: true,
                  child: const Icon(AppIcons.delete),
                  onPressed: () => _confirmDeleteMatter(m.matterId),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Kanban view rimossa: non utilizzata nella pagina elenco

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.inbox,
              size: 48, color: Theme.of(context).colorScheme.outline),
          SizedBox(
              height:
                  (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ??
                      8.0)),
          const Text('Nessuna pratica presente.'),
          SizedBox(
              height:
                  (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ??
                          8.0) *
                      2),
          AppButton(
            variant: AppButtonVariant.secondary,
            onPressed: () {
              setState(() {
                _statusSelected.clear();
                _selectedCourt = null;
                _searchCtl.clear();
                _page = 0;
              });
              _load();
            },
            child: const Text('Azzera filtri'),
          ),
        ],
      ),
    );
  }

  // Formatter data non utilizzato: rimosso

  Future<void> _openNewMatter() async {
    final created = await AppDialog.show<Matter>(
      context,
      builder: (_) => const NewMatterDialog(),
    );
    if (created != null) {
      setState(() {
        _page = 0;
      });
      _load();
    }
  }
}

class ClientOption {
  final String id;
  final String label;
  const ClientOption({required this.id, required this.label});
  @override
  String toString() => label;
}
