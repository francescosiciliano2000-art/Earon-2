import 'dart:convert';
import 'package:flutter/material.dart';

// Design System
import '../../../design system/components/app_data_table.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/multiselect.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/pagination.dart';
import '../../../design system/components/input_group.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/badge.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supa_helpers.dart';

import 'new_client_dialog.dart';
import 'import_wizard.dart';
import '../../clienti/data/cliente_repo.dart';
import 'cliente_detail_sheet.dart';
import '../../../design system/components/alert_dialog.dart';
import '../../firms/presentation/select_firm_placeholder.dart';

class ClientiPage extends StatefulWidget {
  const ClientiPage({super.key});

  @override
  State<ClientiPage> createState() => _ClientiPageState();
}

class _ClientiPageState extends State<ClientiPage> {
  final _searchCtl = TextEditingController();
  String _kind = 'all';
  int _page = 0;
  final int _pageSize = 10;
  bool _loading = false;
  String? _firmId;
  bool _firmResolving = true;
  late final _repo = ClienteRepo(Supabase.instance.client);
  List<Map<String, dynamic>> _rows = const [];
  int _total = 0;
  final Set<String> _selectedIds = <String>{};
  String _orderBy = 'name';
  bool _asc = true;

  // Preferenze UI
  late SharedPreferences _prefs;
  static const _kColsVisibleKey = 'clienti.columns.visible';

  final Map<String, ({String label, double? width})> _columnsMeta = {
    'name': (label: 'Nome', width: 240),
    'kind': (label: 'Tipo', width: 120),
    'email': (label: 'Email', width: 220),
    'phone': (label: 'Telefono', width: 140),
    'created_at': (label: 'Creato il', width: 140),
    // extra
    'tax_code': (label: 'Cod. Fiscale', width: 180),
    'vat_number': (label: 'P. IVA', width: 160),
    'city': (label: 'Città', width: 140),
    'province': (label: 'Provincia', width: 120),
    'zip': (label: 'CAP', width: 100),
    'country': (label: 'Paese', width: 140),
    'updated_at': (label: 'Aggiornato il', width: 140),
  };

  List<String> _visibleCols = ['name', 'kind', 'email', 'phone', 'created_at'];

  double get su =>
      (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0);

  @override
  void initState() {
    super.initState();
    // Evita il flicker dell'empty state impostando subito il loading
    setState(() => _loading = true);
    _initPrefs().then((_) => _initFirm().then((_) => _load()));
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final visStr = _prefs.getString(_kColsVisibleKey);
    if (visStr != null) {
      final list = List<String>.from(jsonDecode(visStr));
      if (list.isNotEmpty) {
        _visibleCols = list.where(_columnsMeta.containsKey).toList();
      }
    }
  }

  void _persistVisible() {
    _prefs.setString(_kColsVisibleKey, jsonEncode(_visibleCols));
  }

  Future<void> _initFirm() async {
    await ensureFirmSelected(context);
    final id = await getCurrentFirmId();
    setState(() => _firmId = id);
  
    setState(() => _firmResolving = false);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      if (_firmId == null || _firmId!.isEmpty) {
        setState(() {
          _rows = const [];
          _total = 0;
          _loading = false;
        });
        return;
      }

      final query = _searchCtl.text.trim();
      final offset = _page * _pageSize;

      final items = await _repo.list(
        firmId: _firmId!,
        q: query.isEmpty ? null : query,
        kind: _kind == 'all' ? null : _kind,
        orderBy: _orderBy,
        asc: _asc,
        limit: _pageSize,
        offset: offset,
      );

      final total = await _repo.count(
        firmId: _firmId!,
        q: query.isEmpty ? null : query,
        kind: _kind == 'all' ? null : _kind,
      );

      setState(() {
        _rows = items;
        _total = total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
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

  Future<void> _newClient() async {
    final ok = await AppDialog.show<bool>(
      context,
      builder: (_) => const NewClientDialog(),
    );
    if (ok == true) _load();
  }

  Future<void> _deleteClient(String clientId) async {
    await AppAlertDialog.show<void>(
      context,
      title: 'Elimina cliente',
      description:
          'Confermi l’eliminazione di questo cliente?\nL’operazione non può essere annullata.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        final toaster = AppToaster.of(context);
        toaster.loading('Eliminazione cliente…');
        final error = await _repo.safeDelete(clientId);
        if (error != null) {
          toaster.error('Cliente non eliminato correttamente',
              description: error);
        } else {
          toaster.success('Cliente eliminato');
          _load();
        }
      },
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        // Larghezza di ricerca uniformata tra le pagine (≈ 280px)
        SizedBox(
          width: su * 35,
          child: AppInputGroup(
            controller: _searchCtl,
            hintText: 'Cerca clienti…',
            leading: const Icon(AppIcons.search),
            onChanged: (_) {
              setState(() => _page = 0);
              _load();
            },
          ),
        ),
        SizedBox(width: su * 2),
        AppSelect(
          placeholder: 'Tipo cliente',
          value: _kind,
          onChanged: (value) {
            setState(() {
              _kind = value;
              _page = 0;
            });
            _load();
          },
          groups: const [
            SelectGroupData(
              label: 'Tipo',
              items: [
                SelectItemData(value: 'all', label: 'Tutti'),
                SelectItemData(value: 'person', label: 'Privati'),
                SelectItemData(value: 'company', label: 'Aziende'),
              ],
            ),
          ],
        ),
        SizedBox(width: su * 2),
        const Spacer(),
        // A destra: selettore colonne (se presente) seguito dal pulsante Importa
        AppMultiSelect(
          width: 240,
          placeholder: 'Personalizza colonne',
          values: _visibleCols,
          onChanged: (vals) {
            final cleaned = vals.where(_columnsMeta.containsKey).toList();
            setState(
                () => _visibleCols = cleaned.isEmpty ? _visibleCols : cleaned);
            _persistVisible();
          },
          groups: [
            MultiSelectGroupData(
              label: 'Visibilità',
              items: _columnsMeta.entries
                  .map((e) =>
                      MultiSelectItemData(value: e.key, label: e.value.label))
                  .toList(),
            ),
          ],
        ),
        SizedBox(width: su * 2),
        AppButton(
          variant: AppButtonVariant.outline,
          onPressed: _firmId != null
              ? () async {
                  final ok = await AppDialog.show<bool>(
                    context,
                    builder: (_) => ImportClientsWizard(firmId: _firmId!),
                  );
                  if (ok == true) _load();
                }
              : null,
          leading: const Icon(AppIcons.uploadFile),
          label: 'Importa',
        ),
      ],
    );
  }

  Widget _buildKindCell(String? kind) {
    final cs = Theme.of(context).colorScheme;

    // Decidi icona e colore in base al tipo
    final (IconData iconData, Color iconColor, String text) = switch (kind) {
      'person' => (AppIcons.userRectangle, Colors.blueAccent, 'Privato'),
      'company' => (AppIcons.buildingOffice, Colors.green, 'Azienda'),
      _ => (Icons.help_outline, cs.outline, '—'),
    };

    return AppBadge(
      variant: AppBadgeVariant.outline, // sempre outline
      label: text,
      leading: Icon(iconData, color: iconColor, size: 12),
      gap: 6,
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  List<AppDataColumn> _buildColumns() {
    final cols = <AppDataColumn>[];
    for (final key in _visibleCols) {
      final meta = _columnsMeta[key];
      if (meta == null) continue;
      cols.add(AppDataColumn(
        label: meta.label,
        width: meta.width,
        onLabelTap: () => _toggleSort(key),
        sortAscending: _orderBy == key ? _asc : null,
      ));
    }
    return cols;
  }

  List<Widget> _buildCells(Map<String, dynamic> r) {
    final cells = <Widget>[];
    for (final key in _visibleCols) {
      switch (key) {
        case 'name':
          // Composizione dinamica del nome in tabella:
          // - Se tipo è 'person' → "Cognome Nome"
          // - Se tipo è 'company' → "Ragione Sociale FormaGiuridica"
          final kind = (r['kind'] ?? '').toString();
          final name = (r['name'] ?? '').toString().trim();
          String display;
          if (kind == 'person') {
            final surname = (r['surname'] ?? '').toString().trim();
            display = [surname, name].where((s) => s.isNotEmpty).join(' ');
          } else if (kind == 'company') {
            final companyType = (r['company_type'] ?? '').toString().trim();
            display = [name, companyType].where((s) => s.isNotEmpty).join(' ');
          } else {
            // Fallback: usa nome + cognome come prima
            final surname = (r['surname'] ?? '').toString().trim();
            display = [name, surname].where((s) => s.isNotEmpty).join(' ');
          }
          if (display.isEmpty) display = '—';
          cells.add(Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ));
          break;
        case 'kind':
          cells.add(_buildKindCell(r['kind']));
          break;
        case 'email':
        case 'phone':
        case 'tax_code':
        case 'vat_number':
        case 'city':
        case 'province':
        case 'country':
          cells.add(Text('${r[key] ?? '—'}'));
          break;
        case 'zip':
          // Allineamento con DB DEV: il campo è 'zip'
        cells.add(Text('${r['zip'] ?? '—'}'));
          break;
        case 'created_at':
        case 'updated_at':
          cells.add(Text(_formatDate(r[key])));
          break;
      }
    }
    return cells;
  }

  Widget _buildTableBlock() {
    // Durante il loading mostriamo solo la barra lineare sopra (come Agenda/Udienze)
    if (_loading) return const SizedBox.shrink();
    if (_rows.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.inbox,
              size: 48, color: Theme.of(context).colorScheme.outline),
          SizedBox(height: su * 2),
          const Text('Nessun cliente trovato'),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: su),
      child: AppDataTable(
        key: ValueKey(_visibleCols.join(',')), // remount su cambio colonne
        selectionInFirstCell: true,
        selectable: true,
        allSelected: _rows.isNotEmpty &&
            _rows
                .every((r) => _selectedIds.contains('${r['client_id'] ?? ''}')),
        onToggleAll: () {
          setState(() {
            final all = _rows.isNotEmpty &&
                _rows.every(
                    (r) => _selectedIds.contains('${r['client_id'] ?? ''}'));
            if (all) {
              _selectedIds.clear();
            } else {
              _selectedIds.addAll(_rows.map((r) => '${r['client_id'] ?? ''}'));
            }
          });
        },
        selectedRows: [
          for (final r in _rows)
            _selectedIds.contains('${r['client_id'] ?? ''}'),
        ],
        onToggleRow: (i, v) {
          final id = '${_rows[i]['client_id'] ?? ''}';
          setState(() => v ? _selectedIds.add(id) : _selectedIds.remove(id));
        },
        columns: _buildColumns(),
        rows: [
          for (final r in _rows)
            AppDataRow(
              onTap: () {
                final id = '${r['client_id'] ?? ''}';
                if (id.isNotEmpty) {
                  showSheet<void>(
                    context,
                    builder: (_) => ClienteDetailSheet(clientId: id),
                    side: SheetSide.right,
                    maxWidth: 537,
                    widthFraction: 0.70,
                  );
                }
              },
              cells: _buildCells(r),
              rowMenu: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.iconSm,
                    circular: true,
                    child: const Icon(AppIcons.edit),
                    onPressed: () async {
                      final ok = await AppDialog.show<bool>(
                        context,
                        builder: (_) => NewClientDialog(editing: r),
                      );
                      if (ok == true) _load();
                    },
                  ),
                  SizedBox(width: su),
                  AppButton(
                    variant: AppButtonVariant.destructive,
                    size: AppButtonSize.iconSm,
                    circular: true,
                    child: const Icon(AppIcons.delete),
                    onPressed: () {
                      final id = '${r['client_id'] ?? ''}';
                      if (id.isNotEmpty) _deleteClient(id);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget contentColumn() {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: _newClient,
              leading: const Icon(AppIcons.personAdd),
              label: 'Nuovo',
            ),
          ],
        ),
        SizedBox(height: su * 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: EdgeInsets.all(su * 2), child: _toolbar()),
              if (_loading) const AppProgressBar(),
              Expanded(child: _buildTableBlock()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: su * 2, vertical: su),
                child: Row(
                  children: [
                    Text('$_total clienti totali'),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fid = _firmId ?? '';
    final body = _firmResolving
        ? contentColumn()
        : (fid.isEmpty ? const SelectFirmPlaceholder() : contentColumn());
    return Padding(
      padding: EdgeInsets.all(su * 3),
      child: body,
    );
  }
}
