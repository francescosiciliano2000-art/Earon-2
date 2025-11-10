// lib/features/matters/presentation/matter_detail_page.dart
import 'package:flutter/material.dart';
import '../../../design system/components/top_bar.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/list_tile.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../data/matter_repo.dart';
import '../data/matter_model.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';

import 'matter_edit_sheet.dart';
import 'change_client_dialog.dart';
import '../../agenda/presentation/task_create_dialog.dart';
import '../../agenda/presentation/hearing_create_dialog.dart';
import '../../../design system/components/alert_dialog.dart';

class MatterDetailPage extends StatefulWidget {
  final String matterId;
  const MatterDetailPage({super.key, required this.matterId});

  @override
  State<MatterDetailPage> createState() => _MatterDetailPageState();
}

class _MatterDetailPageState extends State<MatterDetailPage>
    with SingleTickerProviderStateMixin {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;

  // Helper per accedere ai token del tema
  double get _spacing => Theme.of(context).extension<DefaultTokens>()!.spacingUnit;

  Matter? _matter;
  bool _loading = true;
  String? _error;

  // editable
  final _statusCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  List<String> _statusSuggestions = const [];

  // controparte riassunto (placeholder)
  String _counterpartySummary = '—';
  // final _fmtDate = DateFormat('dd/MM/yyyy'); // rimosso: non utilizzato

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _bootstrap();
  }

  @override
  void dispose() {
    _statusCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _repo.get(widget.matterId);
      if (m == null) {
        throw Exception('Pratica non trovata.');
      }
      _statusCtl.text = m.status ?? '';
      _notesCtl.text = m.description ?? '';
      final statuses = await _loadDistinctValues('status');
      final cp = await _loadCounterpartySummary();
      setState(() {
        _matter = m;
        _statusSuggestions = statuses.isEmpty
            ? const ['open', 'in_progress', 'closed']
            : statuses;
        _counterpartySummary = cp;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<String>> _loadDistinctValues(String col) async {
    final fid = await getCurrentFirmId();
    if (fid == null) {
      return const [];
    }
    try {
      final res = await _sb
          .from('matters')
          .select(col)
          .eq(Matter.colFirmId, fid)
          .limit(1000);
      final list = List<Map<String, dynamic>>.from(res as List);
      final vals = list
          .map((e) => '${e[col] ?? ''}'.trim())
          .where((v) => v.isNotEmpty)
          .toSet();
      final out = vals.toList();
      out.sort();
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<String> _loadCounterpartySummary() async {
    try {
      final res = await _sb
          .from('matter_parties')
          .select('role,name')
          .eq('matter_id', widget.matterId)
          .limit(20);
      final list = List<Map<String, dynamic>>.from(res as List);
      if (list.isEmpty) {
        return '—';
      }
      final items =
          list.map((e) => '${e['role'] ?? ''}: ${e['name'] ?? ''}').toList();
      return items.join(' • ');
    } catch (_) {
      return '—';
    }
  }

  Future<void> _saveOverview() async {
    if (_matter == null) {
      return;
    }
    try {
      final updated = await _repo.update(
        _matter!.matterId,
        status: _statusCtl.text.trim().isEmpty ? null : _statusCtl.text.trim(),
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );
      setState(() => _matter = updated);
      if (!mounted) {
        return;
      }
      toastSuccess(context, 'Salvato');
    } catch (e) {
      if (!mounted) {
        return;
      }
      toastError(context, 'Errore salvataggio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: TopBar(
          leading: Text(_matter == null ? 'Pratica' : _matter!.title),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Parti'),
              Tab(text: 'Documenti'),
              Tab(text: 'Ore'),
              Tab(text: 'Spese'),
              Tab(text: 'Agenda'),
              Tab(text: 'Fatturazione'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: Spinner())
            : _error != null
                ? Center(child: Text('Errore: $_error'))
                : TabBarView(
                    children: [
                      _buildOverviewTab(),
                      _buildPartiesTab(),
                      _buildDocumentsTab(),
                      _buildHoursTab(),
                      _buildExpensesTab(),
                      _buildAgendaTab(),
                      _buildBillingTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final m = _matter;
    if (m == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: EdgeInsets.all(_spacing * 2),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(_spacing * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.code, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: _spacing * 0.5),
                Text(
                    'Creato: ${_safeDate(m.createdAt)} • Stato: ${m.status ?? '—'}'),
                SizedBox(height: _spacing * 3),
                Row(
                  children: [
                    Expanded(
                      child: ShadcnSelect(
                        value: m.status,
                        placeholder: 'Stato (modificabile)',
                        width: double.infinity,
                        groups: [
                          SelectGroupData(
                            label: 'Stato (modificabile)',
                            items: [
                              ..._statusSuggestions.map((s) => SelectItemData(value: s, label: s)),
                            ],
                          ),
                        ],
                        onChanged: (v) {
                          _statusCtl.text = v;
                        },
                      ),
                    ),
                    SizedBox(width: _spacing * 2),
                    Expanded(
                      child: TextField(
                        controller: _notesCtl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Note',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _spacing * 2),
                // Sezione ‘Responsabili’ rimossa: non supportata nello schema attuale
                SizedBox(height: _spacing * 2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Controparte (riassunto)'),
                    SizedBox(height: _spacing),
                    Text(_counterpartySummary),
                  ],
                ),
                SizedBox(height: _spacing * 3),
                Wrap(
                  spacing: _spacing,
                  runSpacing: _spacing,
                  children: [
                    AppButton(variant: AppButtonVariant.secondary, 
                      leading: Icon(AppIcons.edit),
                      child: const Text('Modifica'),
                      onPressed: () => _openEditSheet(m),
                    ),
                    AppButton(variant: AppButtonVariant.secondary, 
                      leading: Icon(AppIcons.switchAccount),
                      child: const Text('Cambia cliente'),
                      onPressed: () => _openChangeClientDialog(),
                    ),
                    AppButton(variant: AppButtonVariant.default_, 
                      leading: Icon(AppIcons.checkCircle),
                      child: const Text('Chiudi pratica'),
                      onPressed: () => _confirmClose(),
                    ),
                    AppButton(variant: AppButtonVariant.default_, 
                      leading: Icon(AppIcons.restart),
                      child: const Text('Riapri'),
                      onPressed: () => _confirmReopen(),
                    ),
                    AppButton(variant: AppButtonVariant.destructive, 
                      leading: Icon(AppIcons.delete),
                      child: const Text('Elimina'),
                      onPressed: () => _confirmDelete(),
                    ),
                  ],
                ),
                SizedBox(height: _spacing),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(variant: AppButtonVariant.default_, 
                    onPressed: _saveOverview,
                    leading: Icon(AppIcons.save),
                    child: const Text('Salva'),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // (placeholder tab rimosso: non utilizzato)

  String _safeDate(DateTime? d) {
    if (d == null) {
      return '—';
    }
    final dt = d.toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  // Recupera firmId dalla pratica già caricata.
  // Se non disponibile, solleva un errore per evitare query inconsistenti.
  Future<String> _getFirmId(SupabaseClient sb) async {
    final fid = _matter?.firmId;
    if (fid != null && fid.isNotEmpty) {
      return fid;
    }
    throw StateError('firmId non disponibile per la pratica');
  }

  Future<void> _openEditSheet(Matter m) async {
    final updated = await showModalBottomSheet<Matter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: MatterEditSheet(matter: m),
      ),
    );
    if (!mounted) {
      return;
    }
    if (updated != null) {
      setState(() => _matter = updated);
      toastSuccess(context, 'Pratica aggiornata');
    }
  }

  Future<void> _openChangeClientDialog() async {
    final m = _matter;
    if (m == null) {
      return;
    }
    final newClientId = await showDialog<String>(
      context: context,
      builder: (_) => ChangeClientDialog(matterId: m.matterId),
    );
    if (newClientId != null && newClientId.isNotEmpty) {
      await _bootstrap(); // refresh per coerenza
      if (!mounted) {
        return;
      }
      toastSuccess(context, 'Cliente aggiornato');
    }
  }

  Future<void> _confirmClose() async {
    final ok = await AppDialog.show<bool>(
      context,
      builder: (ctx) => AppDialogContent(
        children: [
          const AppDialogHeader(
            title: AppDialogTitle('Chiudere pratica?'),
            description: AppDialogDescription('Confermi la chiusura della pratica?'),
          ),
          AppDialogFooter(
            children: [
              AppButton(
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              AppButton(
                variant: AppButtonVariant.default_,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _repo.close(widget.matterId);
      await _bootstrap();
      if (!mounted) {
        return;
      }
      toastSuccess(context, 'Pratica chiusa');
    } catch (e) {
      if (!mounted) {
        return;
      }
      toastError(context, 'Errore chiusura: $e');
    }
  }

  Future<void> _confirmReopen() async {
    final ok = await AppDialog.show<bool>(
      context,
      builder: (ctx) => AppDialogContent(
        children: [
          const AppDialogHeader(
            title: AppDialogTitle('Riaprire pratica?'),
            description: AppDialogDescription('Confermi la riapertura della pratica?'),
          ),
          AppDialogFooter(
            children: [
              AppButton(
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              AppButton(
                variant: AppButtonVariant.default_,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Riapri'),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _repo.reopen(widget.matterId);
      await _bootstrap();
      if (!mounted) {
        return;
      }
      toastSuccess(context, 'Pratica riaperta');
    } catch (e) {
      if (!mounted) {
        return;
      }
      toastError(context, 'Errore riapertura: $e');
    }
  }

  Future<void> _confirmDelete() async {
    await AppAlertDialog.show<void>(
      context,
      title: 'Eliminare pratica?',
      description: 'L\'operazione non è reversibile.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        try {
          await _repo.delete(widget.matterId);
          if (!mounted) return;
          toastSuccess(context, 'Pratica eliminata');
          context.go('/matters/list');
        } catch (e) {
          if (!mounted) return;
          final msg = '$e';
          final text = msg.contains('righe fattura')
              ? 'Impossibile eliminare: esistono righe fattura collegate'
              : msg;
          toastError(context, text);
        }
      },
    );
  }

  // -------- PARTIES TAB --------
  Widget _buildPartiesTab() {
    final mId = widget.matterId;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchParties(mId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) {
          return Center(child: Text('Errore parti: ${snap.error}'));
        }
        final rows = snap.data ?? const [];
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final r in rows) {
          final role = (r['role'] ?? 'altro').toString();
          grouped.putIfAbsent(role, () => []);
          grouped[role]!.add(r);
        }
        return Padding(
          padding: EdgeInsets.all(_spacing * 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Parti', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  AppButton(variant: AppButtonVariant.secondary, 
                    onPressed: _openAddPartyDialog,
                    leading: Icon(AppIcons.personAdd),
                    child: const Text('Nuova parte'),
                  ),
                ],
              ),
              SizedBox(height: _spacing * 2),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in grouped.entries)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(_spacing * 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_labelForRole(entry.key),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              SizedBox(height: _spacing),
                              for (final r in entry.value)
                                AppListTile(
                                  leading:
                                      const Icon(AppIcons.accountCircle),
                                  title: Text(r['name'] ?? ''),
                                  subtitle: Text([
                                    r['tax_code'],
                                    r['vat_number']
                                  ]
                                      .where((e) =>
                                          (e ?? '').toString().isNotEmpty)
                                      .join(' • ')),
                                  trailing:
                                      Wrap(spacing: _spacing, children: [
                                    AppButton(size: AppButtonSize.icon, 
                                      leading: Icon(AppIcons.edit),
                                      onPressed: () => _openEditPartyDialog(r),
                                    ),
                                    AppButton(size: AppButtonSize.icon, 
                                      leading: Icon(AppIcons.delete),
                                      onPressed: () => _confirmDeleteParty(r),
                                    ),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchParties(String matterId) async {
    try {
      final sb = Supabase.instance.client;
      final firmId = await _getFirmId(sb);
      final res = await sb
          .from('matter_parties')
          .select('party_id, name, role, tax_code, vat_number')
          .eq('firm_id', firmId)
          .eq('matter_id', matterId)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return Future.error(e);
    }
  }

  String _labelForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('attor') || r.contains('actor') || r == 'actor') {
      return 'Attori';
    }
    if (r.contains('contro') || r.contains('counter') || r == 'counterparty') {
      return 'Controparti';
    }
    if (r.contains('terz') || r == 'third') {
      return 'Terzi';
    }
    return role[0].toUpperCase() + role.substring(1);
  }

  Future<void> _openAddPartyDialog() async {
    final nameCtrl = TextEditingController();
    String role = 'actor';
    final confirmed = await AppDialog.show<bool>(
      context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AppDialogContent(
          children: [
            const AppDialogHeader(
              title: AppDialogTitle('Nuova parte'),
              description: AppDialogDescription('Crea una nuova parte associata alla pratica.'),
            ),
            SizedBox(height: _spacing),
            AppInput(
              controller: nameCtrl,
              hintText: 'Nome',
            ),
            SizedBox(height: _spacing),
            ShadcnSelect(
              value: role,
              placeholder: 'Ruolo',
              width: double.infinity,
              groups: const [
                SelectGroupData(
                  label: 'Ruolo',
                  items: [
                    SelectItemData(value: 'actor', label: 'Attore'),
                    SelectItemData(value: 'counterparty', label: 'Controparte'),
                    SelectItemData(value: 'third', label: 'Terzo'),
                  ],
                ),
              ],
              onChanged: (v) => setStateDialog(() => role = v.isEmpty ? role : v),
            ),
            AppDialogFooter(
              children: [
                AppButton(
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annulla'),
                ),
                AppButton(
                  variant: AppButtonVariant.default_,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Crea'),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ?? false;
    if (confirmed) {
      // TODO: inserimento reale nel repository
      _refreshTab(() {});
    }
    nameCtrl.dispose();
  }

  Future<void> _openEditPartyDialog(Map<String, dynamic> party) async {
    final nameCtrl = TextEditingController(text: party['name'] ?? '');
    String role = (party['role'] ?? 'actor').toString();
    final confirmed = await AppDialog.show<bool>(
      context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AppDialogContent(
          children: [
            const AppDialogHeader(
              title: AppDialogTitle('Modifica parte'),
              description: AppDialogDescription('Aggiorna le informazioni della parte selezionata.'),
            ),
            SizedBox(height: _spacing),
            AppInput(
              controller: nameCtrl,
              hintText: 'Nome',
            ),
            SizedBox(height: _spacing),
            ShadcnSelect(
              value: role,
              placeholder: 'Ruolo',
              width: double.infinity,
              groups: const [
                SelectGroupData(
                  label: 'Ruolo',
                  items: [
                    SelectItemData(value: 'actor', label: 'Attore'),
                    SelectItemData(value: 'counterparty', label: 'Controparte'),
                    SelectItemData(value: 'third', label: 'Terzo'),
                  ],
                ),
              ],
              onChanged: (v) => setStateDialog(() => role = v.isEmpty ? role : v),
            ),
            AppDialogFooter(
              children: [
                AppButton(
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annulla'),
                ),
                AppButton(
                  variant: AppButtonVariant.default_,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ?? false;
    if (confirmed) {
      // TODO: aggiornamento reale nel repository
      _refreshTab(() {});
    }
    nameCtrl.dispose();
  }

  Future<void> _confirmDeleteParty(Map<String, dynamic> party) async {
    await AppAlertDialog.show<void>(
      context,
      title: 'Eliminare parte?',
      description: 'Sei sicuro di voler eliminare "${party['name'] ?? ''}"?',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        // NOTE: repo/DB call: delete from matter_parties where party_id
        _refreshTab(() {});
      },
    );
  }

  void _refreshTab(VoidCallback cb) {
    setState(cb);
  }

  // -------- DOCUMENTS TAB --------
  Widget _buildDocumentsTab() {
    final firmId = _matter?.firmId; // fallback se già caricato in matter
    final mId = widget.matterId;
    final basePath = firmId == null ? '' : '/firms/$firmId/matters/$mId/docs/';
    return Padding(
      padding: EdgeInsets.all(_spacing * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Documenti', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              AppButton(variant: AppButtonVariant.secondary, 
                onPressed: null,
                leading: Icon(AppIcons.upload),
                child: const Text('Carica'),
              ),
            ],
          ),
          SizedBox(height: _spacing * 2),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: Theme.of(context).extension<ShadcnRadii>()!.md,
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: EdgeInsets.all(_spacing * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Percorso: $basePath'),
                  SizedBox(height: _spacing),
                  const SizedBox.shrink(),
                  SizedBox(height: _spacing),
                  AppListTile(
                    leading: const Icon(AppIcons.insertDriveFile),
                    title: const Text('Esempio.pdf'),
                    subtitle: const Text('placeholder'),
                    trailing: Wrap(spacing: _spacing, children: [
                      AppButton(size: AppButtonSize.icon, 
                        leading: Icon(AppIcons.driveFileRename),
                        onPressed: null,
                      ),
                      AppButton(size: AppButtonSize.icon, 
                        leading: Icon(AppIcons.delete),
                        onPressed: null,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  

  // -------- HOURS TAB --------
  Widget _buildHoursTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchTimeEntries(widget.matterId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) {
          return Center(child: Text('Errore ore: ${snap.error}'));
        }
        final data =
            snap.data ?? {'rows': <Map<String, dynamic>>[], 'sumMin': 0};
        final rows = List<Map<String, dynamic>>.from(data['rows'] as List);
        final sumMin = (data['sumMin'] ?? 0) as int;
        final sumHours = (sumMin / 60.0);
        return Padding(
          padding: EdgeInsets.all(_spacing * 3),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Totale ore: ${sumHours.toStringAsFixed(2)}'),
                  const Spacer(),
                  AppButton(variant: AppButtonVariant.secondary, 
                    onPressed: null, // disabilitato finché la feature non è disponibile
                    leading: Icon(AppIcons.addAlarm),
                    child: const Text('Aggiungi'),
                  ),
                ],
              ),
              SizedBox(height: _spacing),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    final desc = (r['description'] ?? '') as String;
                    final minutes = (r['minutes'] ?? 0) as int;
                    final started = r['started_at'];
                    final dateStr = started == null
                        ? '—'
                        : _safeDate(DateTime.parse(started.toString()));
                    return AppListTile(
                      leading: const Icon(AppIcons.schedule),
                      title: Text(
                          '$dateStr • ${(minutes / 60.0).toStringAsFixed(2)} h'),
                      subtitle:
                          Text(desc.isEmpty ? '(senza descrizione)' : desc),
                      trailing: (r['billable'] == true)
                          ? const Chip(label: Text('Billable'))
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchTimeEntries(String matterId) async {
    try {
      final sb = Supabase.instance.client;
      final firmId = await _getFirmId(sb);
      final res = await sb
          .from('time_entries')
          .select('time_id, started_at, minutes, description, billable')
          .eq('firm_id', firmId)
          .eq('matter_id', matterId)
          .order('started_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(res as List);
      final sumMin =
          rows.fold<int>(0, (acc, r) => acc + ((r['minutes'] ?? 0) as int));
      return {'rows': rows, 'sumMin': sumMin};
    } catch (e) {
      return Future.error(e);
    }
  }


  // -------- EXPENSES TAB --------
  Widget _buildExpensesTab() {
    return FutureBuilder<Map<String, num>>(
      future: _sumExpenses(widget.matterId),
      builder: (context, sumSnap) {
        final header = sumSnap.hasData
            ? 'Totale: € ${sumSnap.data!['net']!.toStringAsFixed(2)} (+ IVA: € ${sumSnap.data!['vat']!.toStringAsFixed(2)})'
            : 'Totale: —';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(_spacing * 3),
              child: Row(
                children: [
                  Text(header),
                  const Spacer(),
                  AppButton(variant: AppButtonVariant.secondary, 
                    onPressed: null, // disabilitato finché la feature non è disponibile
                    leading: Icon(AppIcons.addCircle),
                    child: const Text('Aggiungi'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchExpenses(widget.matterId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: Spinner());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Errore spese: ${snap.error}'));
                  }
                  final rows = snap.data ?? const [];
                  if (rows.isEmpty) {
                    return const Center(child: Text('Nessuna spesa'));
                  }
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      final amount = (r['amount'] ?? 0) as num;
                      final vatRate = (r['vat_rate'] ?? 0) as num;
                      final date = r['date'];
                      final dateStr = date == null
                          ? '—'
                          : _safeDate(DateTime.parse(date.toString()));
                      return AppListTile(
                        leading: const Icon(AppIcons.receiptLong),
                        title: Text(
                            '${r['type'] ?? 'spesa'} • € ${amount.toStringAsFixed(2)}'),
                        subtitle: Text(
                            '${r['description'] ?? ''}\n$dateStr • IVA ${vatRate.toString()}%'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchExpenses(String matterId) async {
    try {
      final sb = Supabase.instance.client;
      final firmId = await _getFirmId(sb);
      final res = await sb
          .from('expenses')
          .select(
              'expense_id, type, description, amount, vat_rate, date, billable')
          .eq('firm_id', firmId)
          .eq('matter_id', matterId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<Map<String, num>> _sumExpenses(String matterId) async {
    final rows = await _fetchExpenses(matterId);
    num net = 0;
    num vat = 0;
    for (final r in rows) {
      final amount = (r['amount'] ?? 0) as num;
      final vatRate = (r['vat_rate'] ?? 0) as num;
      net += amount;
      vat += amount * (vatRate / 100.0);
    }
    return {'net': net, 'vat': vat};
  }

  // -------- AGENDA TAB --------
  Widget _buildAgendaTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Tasks'), Tab(text: 'Udienze')]),
          Expanded(
            child: TabBarView(
              children: [
                _buildTasksSubtab(),
                _buildHearingsSubtab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSubtab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_spacing),
          child: Row(
            children: [
              const Spacer(),
              AppButton(variant: AppButtonVariant.secondary, 
                onPressed: _openNewTaskModal,
                leading: Icon(AppIcons.addTask),
                child: const Text('Nuova task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchTasks(widget.matterId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Spinner());
              }
              if (snap.hasError) {
                return Center(child: Text('Errore tasks: ${snap.error}'));
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return const Center(child: Text('Nessuna task'));
              }
              return ListView(
                children: [
                  for (final r in rows)
                    AppListTile(
                      leading: const Icon(AppIcons.checklist),
                      title: Text(r['title'] ?? ''),
                      subtitle: Text(_taskSubtitle(r)),
                      trailing: (r['done'] == true)
                          ? Icon(AppIcons.checkCircle,
                              color: Theme.of(context).colorScheme.primary)
                          : const Icon(AppIcons.radioUnchecked),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _taskSubtitle(Map<String, dynamic> r) {
    final due = r['due_at'];
    final dueStr =
        due == null ? '—' : _safeDate(DateTime.parse(due.toString()));
    final prio = r['priority'];
    return 'Scadenza: $dueStr • Priorità: ${prio ?? '-'}';
  }

  Future<List<Map<String, dynamic>>> _fetchTasks(String matterId) async {
    try {
      final sb = Supabase.instance.client;
      final firmId = await _getFirmId(sb);
      final res = await sb
          .from('tasks')
          .select('task_id, title, due_at, done, priority')
          .eq('firm_id', firmId)
          .eq('matter_id', matterId)
          .order('due_at', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return Future.error(e);
    }
  }

  Widget _buildHearingsSubtab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_spacing),
          child: Row(
            children: [
              const Spacer(),
              AppButton(variant: AppButtonVariant.secondary, 
                onPressed: _openNewHearingModal,
                leading: Icon(AppIcons.event),
                child: const Text('Nuova udienza'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchHearings(widget.matterId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Spinner());
              }
              if (snap.hasError) {
                return Center(child: Text('Errore udienze: ${snap.error}'));
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return const Center(child: Text('Nessuna udienza'));
              }
              return ListView(
                children: [
                  for (final r in rows)
                    AppListTile(
                      leading: const Icon(AppIcons.gavel),
                      title: Text('${r['type'] ?? ''} • ${_hearingDate(r)}'),
                      subtitle: Text(r['courtroom'] ?? ''),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _hearingDate(Map<String, dynamic> r) {
    final start = r['starts_at'];
    final end = r['ends_at'];
    final sStr =
        start == null ? '—' : _safeDate(DateTime.parse(start.toString()));
    final eStr =
        end == null ? '' : ' → ${_safeDate(DateTime.parse(end.toString()))}';
    return '$sStr$eStr';
  }

  Future<List<Map<String, dynamic>>> _fetchHearings(String matterId) async {
    try {
      final sb = Supabase.instance.client;
      final firmId = await _getFirmId(sb);
      final res = await sb
          .from('hearings')
          .select('hearing_id, type, starts_at, ends_at, courtroom, notes')
          .eq('firm_id', firmId)
          .eq('matter_id', matterId)
          .order('starts_at', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<void> _openNewTaskModal() async {
    // Apri il dialog di creazione task con prefill della pratica corrente
    final created = await AppDialog.show(
      context,
      builder: (ctx) => TaskCreateDialog(presetMatterId: widget.matterId),
    );
    if (!mounted) return;
    // Se una task è stata creata, forza il refresh delle liste correlate
    if (created != null) setState(() {});
  }

  Future<void> _openNewHearingModal() async {
    // Apri il dialog di creazione udienza con prefill della pratica corrente
    final created = await AppDialog.show(
      context,
      builder: (ctx) => HearingCreateDialog(presetMatterId: widget.matterId),
    );
    if (!mounted) return;
    // Se un’udienza è stata creata, forza il refresh delle liste correlate
    if (created != null) setState(() {});
  }

  // -------- BILLING TAB --------
  Widget _buildBillingTab() {
    return Padding(
      padding: EdgeInsets.all(_spacing * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Righe fatturabili',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              AppButton(variant: AppButtonVariant.secondary, 
                onPressed: null, // disabilitato finché la feature non è disponibile
                leading: Icon(AppIcons.playlistAdd),
                child: const Text('Aggiungi a fattura'),
              ),
            ],
          ),
          SizedBox(height: _spacing * 2),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchInvoiceLines(widget.matterId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Spinner());
                }
                if (snap.hasError) {
                  return Center(
                      child: Text('Errore fatturazione: ${snap.error}'));
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('Nessuna riga'));
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    final tot = (r['total_ex_vat'] ?? 0) as num;
                    final inv = r['invoices'] as Map<String, dynamic>?;
                    final invNum = inv?['number'] ?? '-';
                    final invStatus = inv?['status'] ?? '-';
                    return AppListTile(
                      leading: const Icon(AppIcons.receiptLong),
                      title: Text('${r['description'] ?? ''}'),
                      subtitle: Text('Fattura: $invNum • Stato: $invStatus'),
                      trailing: Text('€ ${tot.toStringAsFixed(2)}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchInvoiceLines(String matterId) async {
    try {
      final sb = Supabase.instance.client;
      final firmId = await _getFirmId(sb);
      // Applica i filtri prima delle trasformazioni (es. order) per evitare di chiamare filtri sul builder di trasformazione.
      final res = await sb
          .from('invoice_lines')
          .select(
              'line_id, description, qty, unit_price, total_ex_vat, created_at, invoices!inner(invoice_id, number, status)')
          // Il campo firm_id non appartiene a invoice_lines: filtriamo sulla tabella correlata invoices
          .eq('invoices.firm_id', firmId)
          .eq('matter_id', matterId)
          // Filtra su fatture non finalizzate (evita enum non validi come "unbilled").
          // Valori consentiti per invoice_status: draft, issued, sent, paid, partially_paid, void
          // Qui escludiamo soltanto gli stati finali/chiusi: paid e void
          .not('invoices.status', 'in', '(paid,void)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return Future.error(e);
    }
  }

}
