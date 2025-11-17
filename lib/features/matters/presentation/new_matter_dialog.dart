// lib/features/matters/presentation/new_matter_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Design System
import '../../../design system/components/dialog.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/textarea.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/label.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import '../../courtroom/data/courtroom_repo.dart';

// Data & helpers
import '../data/matter_repo.dart';
import '../data/matter_model.dart';
import '../../clienti/data/cliente_repo.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';

/// Dialog unico per creazione e modifica Pratica.
/// - Se [editing] è null: flusso a 2 step (Step 1: selezione tipologia/area; Step 2: form dati)
/// - Se [editing] è valorizzato: modifica la pratica (oggetto, stato, area, foro, giudice, note)
class NewMatterDialog extends StatefulWidget {
  final Matter? editing;
  const NewMatterDialog({super.key, this.editing});

  @override
  State<NewMatterDialog> createState() => _NewMatterDialogState();
}

class _NewMatterDialogState extends State<NewMatterDialog> {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;
  late final ClienteRepo _clientsRepo;

  // Stato flusso step
  int _step = 1; // 1 = selezione area; 2 = form
  String? _areaChoice; // area scelta nello step 1

  // campi comuni
  final _subjectCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  // campi creazione
  String? _clientId;
  List<_ClientOption> _clientOptions = const [];
  Timer? _clientDebounce;

  // campi modifica
  final _statusCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  final _courtCtl = TextEditingController();
  final _judgeCtl = TextEditingController();
  final _counterpartyCtl = TextEditingController();
  final _rgCtl = TextEditingController();
  final _courtSectionCtl = TextEditingController();
  final _oppAttorneyCtl = TextEditingController();
  final _subtypeCtl = TextEditingController();

  bool _saving = false;
  String? _error;
  List<String> _statusSuggestions = const [];
  // Gruppi foro da courtroom.json
  List<ComboboxGroupData> _courtGroups = const [];
  StreamSubscription<List<ComboboxGroupData>>? _courtGroupsSub;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _clientsRepo = ClienteRepo(_sb);

    final e = widget.editing;
    if (e != null) {
      _subjectCtl.text = e.title;
      _statusCtl.text = e.status ?? '';
      _areaCtl.text = e.area ?? '';
      _courtCtl.text = e.court ?? '';
      _judgeCtl.text = e.judge ?? '';
      _notesCtl.text = e.description ?? '';
      _counterpartyCtl.text = e.counterpartyName ?? '';
      _rgCtl.text = e.rgNumber ?? '';
      _courtSectionCtl.text = e.courtSection ?? '';
      _oppAttorneyCtl.text = e.opposingAttorneyName ?? '';
      _step = 2; // in modifica salta lo step 1
    } else {
      _step = 1;
    }

    _bootstrap();
    // Osserva courtroom.json e aggiorna gruppi foro
    _courtGroupsSub = CourtroomRepo().watchGroups().listen((groups) {
      if (!mounted) return;
      setState(() => _courtGroups = groups);
    });

    // Precarica i primi 20 clienti per evitare elenco vuoto all’apertura
    // (solo se in modalità creazione; in modifica il cliente è già definito)
    if (widget.editing == null) {
      scheduleMicrotask(() => _searchClients(''));
    }
  }

  @override
  void dispose() {
    _clientDebounce?.cancel();
    _subjectCtl.dispose();
    _courtCtl.dispose();
    _judgeCtl.dispose();
    _areaCtl.dispose();
    _statusCtl.dispose();
    _notesCtl.dispose();
    _counterpartyCtl.dispose();
    _rgCtl.dispose();
    _courtSectionCtl.dispose();
    _oppAttorneyCtl.dispose();
    _subtypeCtl.dispose();
    _courtGroupsSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _error = null);
    try {
      // carico suggerimenti campi da valori distinti nel DB
      final statuses = await _loadDistinctValues('status');
      setState(() {
        _statusSuggestions = statuses.isEmpty
            ? const ['open', 'in_progress', 'closed']
            : statuses;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<List<String>> _loadDistinctValues(String col) async {
    final fid = await getCurrentFirmId();
    if (fid == null) return const [];
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

  Future<void> _searchClients(String q) async {
    try {
      final fid = await getCurrentFirmId();
      if (fid == null) return;
      final rows = await _clientsRepo.list(
        firmId: fid,
        q: q.isEmpty ? null : q,
        limit: q.isEmpty ? 20 : 50,
        offset: 0,
      );
      final opts = rows.map((r) {
        final kind = '${r['kind'] ?? ''}'.trim();
        final name = '${r['name'] ?? ''}'.trim();
        final surname = '${r['surname'] ?? ''}'.trim();
        final companyType = '${r['company_type'] ?? ''}'.trim();
        String label;
        if (kind == 'person') {
          label = [name, surname].where((s) => s.isNotEmpty).join(' ');
        } else if (kind == 'company') {
          label = [name, companyType].where((s) => s.isNotEmpty).join(' ');
        } else {
          label = [name, surname].where((s) => s.isNotEmpty).join(' ');
        }
        if (label.isEmpty) label = name;
        return _ClientOption(
          id: '${r['client_id']}',
          label: label,
        );
      }).toList();
      if (!mounted) return;
      setState(() => _clientOptions = opts);
    } catch (_) {}
  }

  void _onClientQueryChanged(String q) {
    _clientDebounce?.cancel();
    _clientDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _searchClients(q.trim());
    });
  }

  void _onAreaSelect(String value) {
    setState(() => _areaChoice = value);
  }

  Future<void> _submit() async {
    final isEdit = widget.editing != null;
    final subject = _subjectCtl.text.trim();
    final notes = _notesCtl.text.trim();
    final counterparty = _counterpartyCtl.text.trim();
    final rgNumber = _rgCtl.text.trim();
    final courtSection = _courtSectionCtl.text.trim();
    final oppAttorney = _oppAttorneyCtl.text.trim();

    final canSkipSubject = (!isEdit && (_areaChoice == 'Curatela' || _areaChoice == 'Delega'));
    if (!canSkipSubject && subject.isEmpty) {
      setState(() => _error = 'Oggetto obbligatorio');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (isEdit) {
        final m = widget.editing!;
        final updated = await _repo.update(
          m.matterId,
          subject: subject,
          status:
              _statusCtl.text.trim().isEmpty ? null : _statusCtl.text.trim(),
          area: _areaCtl.text.trim().isEmpty ? null : _areaCtl.text.trim(),
          courtId: _courtCtl.text.trim().isEmpty ? null : _courtCtl.text.trim(),
          judge: _judgeCtl.text.trim().isEmpty ? null : _judgeCtl.text.trim(),
          notes: notes.isEmpty ? null : notes,
          counterpartyName: counterparty.isEmpty ? null : counterparty,
          rgNumber: rgNumber.isEmpty ? null : rgNumber,
          courtSection: courtSection.isEmpty ? null : courtSection,
          opposingAttorneyName: oppAttorney.isEmpty ? null : oppAttorney,
          subtype: ((!isEdit && _areaChoice == 'Groupama') || (isEdit && (_areaCtl.text.trim() == 'Groupama'))) && (_subtypeCtl.text.trim() != '')
              ? _subtypeCtl.text.trim()
              : null,
        );
        if (!mounted) return;
        Navigator.pop<Matter>(context, updated);
      } else {
        if (_clientId == null || _clientId!.isEmpty) {
          setState(() => _error = 'Cliente obbligatorio');
          return;
        }
        final created = await _repo.create(
          clientId: _clientId!,
          subject: subject,
          status: null,
          area: _areaChoice,
          courtId: _courtCtl.text.trim().isEmpty ? null : _courtCtl.text.trim(),
          judge: _judgeCtl.text.trim().isEmpty ? null : _judgeCtl.text.trim(),
          notes: notes.isEmpty ? null : notes,
          counterpartyName: counterparty.isEmpty ? null : counterparty,
          rgNumber: rgNumber.isEmpty ? null : rgNumber,
          courtSection: courtSection.isEmpty ? null : courtSection,
          opposingAttorneyName: oppAttorney.isEmpty ? null : oppAttorney,
          subtype: ((!isEdit && _areaChoice == 'Groupama') || (isEdit && (_areaCtl.text.trim() == 'Groupama'))) && (_subtypeCtl.text.trim() != '')
              ? _subtypeCtl.text.trim()
              : null,
        );
        if (!mounted) return;
        Navigator.pop<Matter>(context, created);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final isCuratelaSelected = (!isEdit && _areaChoice == 'Curatela');
    final isDelegaSelected = (!isEdit && _areaChoice == 'Delega');
    final isGroupamaSelected = ((!isEdit && _areaChoice == 'Groupama') || (isEdit && (_areaCtl.text.trim() == 'Groupama')));


    final headerDescription = isEdit
        ? 'Aggiorna le informazioni della pratica.'
        : (_step == 1
            ? 'Seleziona la tipologia della pratica.'
            : 'Compila i dati per aggiungere una nuova pratica.');

    return AppDialogContent(
      showCloseButton: true,
      children: [
        AppDialogHeader(
          title: AppDialogTitle(isEdit ? 'Modifica pratica' : 'Nuova pratica'),
          description: AppDialogDescription(headerDescription),
        ),
        SizedBox(height: 6),
        SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STEP 1: selezione tipologia/area (solo creazione)
                if (!isEdit && _step == 1) ...[
                  _AreasGrid(
                    selected: _areaChoice,
                    onSelect: _onAreaSelect,
                  ),
                  SizedBox(height: su * 1.25),
                ],

                // STEP 2: form di creazione/modifica
                if (isEdit || _step == 2) ...[
                  if (!isEdit) ...[
                    AppLabel(text: 'Cliente'),
                    SizedBox(height: su * 1.5),
                    Row(
                      children: [
                        Expanded(
                          child: AppCombobox(
                            width: double.infinity,
                            placeholder: 'Seleziona cliente…',
                            items: _clientOptions
                                .map((o) =>
                                    ComboboxItem(value: o.id, label: o.label))
                                .toList(),
                            value: _clientId,
                            // La lista si adatta alla riga più lunga
                            popoverMatchWidestRow: true,
                            onQueryChanged: _onClientQueryChanged,
                            onChanged: (value) =>
                                setState(() => _clientId = value),
                          ),
                        ),
                        if (_clientId != null)
                          Padding(
                            padding: EdgeInsets.only(left: su),
                            child: AppButton(
                              variant: AppButtonVariant.ghost,
                              size: AppButtonSize.icon,
                              onPressed: () {
                                setState(() {
                                  _clientId = null;
                                  _clientOptions = const [];
                                });
                              },
                              child: const Icon(AppIcons.clear, size: 16),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: su * 2),
                  ],  if (!isCuratelaSelected && !isDelegaSelected) ...[
    // Oggetto + Sottocategoria (solo Groupama) sulla stessa riga
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: isGroupamaSelected ? 7 : 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLabel(text: 'Oggetto'),
              SizedBox(height: su * 1.5),
              AppInput(
                controller: _subjectCtl,
                hintText: '',
              ),
            ],
          ),
        ),
        if (isGroupamaSelected) ...[
          SizedBox(width: su * 2),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppLabel(text: 'Sottocategoria'),
                SizedBox(height: su * 1.5),
                AppSelect(
                  value: _subtypeCtl.text.isEmpty ? null : _subtypeCtl.text,
                  placeholder: 'Seleziona…',
                  width: double.infinity,
                  groups: const [
                    SelectGroupData(
                      label: 'Sottocategoria',
                      items: [
                        SelectItemData(value: 'Alto valore', label: 'Alto valore'),
                        SelectItemData(value: 'Anti frode', label: 'Anti frode'),
                      ],
                    ),
                  ],
                  onChanged: (v) => setState(() => _subtypeCtl.text = v.isEmpty ? '' : v),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
    SizedBox(height: su * 2),
                  // Controparte e Avvocato controparte sulla stessa riga
                  if (!isCuratelaSelected) Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Controparte
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppLabel(text: 'Controparte'),
                            SizedBox(height: su * 1.5),
                            AppInput(
                              controller: _counterpartyCtl,
                              hintText: '',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: su * 2),
                      // Avvocato controparte
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppLabel(text: 'Avvocato controparte'),
                            SizedBox(height: su * 1.5),
                            AppInput(
                              controller: _oppAttorneyCtl,
                              hintText: '',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: su * 2),
                  ],
                  // Stato (solo edit)
                  if (isEdit) ...[
                    AppLabel(text: 'Stato'),
                    SizedBox(height: su * 1.5),
                    AppSelect(
                      value: _statusSuggestions.contains(_statusCtl.text)
                          ? _statusCtl.text
                          : null,
                      placeholder: 'Stato',
                      width: double.infinity,
                      groups: [
                        SelectGroupData(
                          label: 'Stato',
                          items: [
                            const SelectItemData(value: '', label: '—'),
                            ..._statusSuggestions
                                .map((s) => SelectItemData(value: s, label: s)),
                          ],
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _statusCtl.text = v.isEmpty ? '' : v),
                    ),
                    SizedBox(height: su * 2),
                    AppLabel(text: 'Area'),
                    SizedBox(height: su * 1.5),
                    AppInput(
                      controller: _areaCtl,
                      hintText: 'Area',
                    ),
                    SizedBox(height: su * 2),
                  ],

                  // Foro, Sezione e Giudice sulla stessa riga
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foro
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppLabel(text: 'Foro'),
                            SizedBox(height: su * 1.5),
                            AppCombobox(
                              value:
                                  _courtCtl.text.isEmpty ? null : _courtCtl.text,
                              placeholder: 'Seleziona foro...',
                              width: double.infinity,
                              groups: _courtGroups,
                              popoverMatchWidestRow: true,
                              items: const [],
                              onChanged: (v) =>
                                  setState(() => _courtCtl.text = v ?? ''),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: su * 2),
                      // Sezione
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppLabel(text: 'Sezione'),
                            SizedBox(height: su * 1.5),
                            AppInput(
                              controller: _courtSectionCtl,
                              hintText: '',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: su * 2),
                      // Giudice
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppLabel(text: 'Giudice'),
                            SizedBox(height: su * 1.5),
                            AppInput(
                              controller: _judgeCtl,
                              hintText: '',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: su * 2),
                  // Numero RG
                  AppLabel(text: 'Numero RG'),
                  SizedBox(height: su * 1.5),
                  AppInput(
                    controller: _rgCtl,
                    hintText: '',
                  ),

                  SizedBox(height: su * 2),

                  AppLabel(text: 'Note'),
                  SizedBox(height: su * 1.5),
                  AppTextarea(
                    controller: _notesCtl,
                    minLines: 3,
                    maxLines: 6,
                    hintText: '',
                  ),
                ],

                if (_error != null) ...[
                  SizedBox(height: su * 2),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: su * 2),
        AppDialogFooter(
          children: [
            // Bottone Indietro (solo step 2 in creazione)
            if (!isEdit && _step == 2)
              AppButton(
                variant: AppButtonVariant.ghost,
                onPressed: () => setState(() => _step = 1),
                child: const Text('Indietro'),
              ),
            AppButton(
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            if (!isEdit && _step == 1)
              AppButton(
                onPressed: (_areaChoice == null)
                    ? null
                    : () => setState(() => _step = 2),
                child: const Text('Avanti'),
              )
            else
              AppButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const Spinner(size: 18)
                    : Text(isEdit ? 'Salva' : 'Crea'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ClientOption {
  final String id;
  final String label;
  const _ClientOption({required this.id, required this.label});
  @override
  String toString() => label;
}

class _AreasGrid extends StatelessWidget {
  final String? selected;
  final void Function(String value) onSelect;
  const _AreasGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final items = <_AreaCardData>[
            _AreaCardData('Curatela', 'Gestione curatele e tutele'),
      _AreaCardData('Custodia', 'Custodie giudiziarie e amministrative'),
      _AreaCardData('Delega', 'Deleghe e incarichi'),
      _AreaCardData('Ordinaria', 'Attività ordinaria civile/penale'),
      _AreaCardData('Groupama', 'Pratiche assicurative Groupama'),
    ];

    final half = (items.length + 1) ~/ 2;
    final left = items.sublist(0, half);
    final right = items.sublist(half);

    Widget buildColumn(List<_AreaCardData> col) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < col.length; i++) ...[
              _AreaVerticalCard(
                title: col[i].title,
                subtitle: col[i].subtitle,
                selected: selected == col[i].title,
                onTap: () => onSelect(col[i].title),
              ),
              if (i != col.length - 1) SizedBox(height: su),
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: buildColumn(left)),
        SizedBox(width: su),
        Expanded(child: buildColumn(right)),
      ],
    );
  }
}


class _AreaCardData {
  final String title;
  final String subtitle;
  const _AreaCardData(this.title, this.subtitle);
}

/// Card verticale con radio bullet a destra (stile simile a HearingDispositionDialog)
class _AreaVerticalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _AreaVerticalCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: su * 2, vertical: su * 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
          color: selected ? cs.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: title),
                  SizedBox(height: su * 0.5),
                  AppDialogDescription(subtitle),
                ],
              ),
            ),
            SizedBox(width: su),
            _RightRadioBullet(selected: selected),
          ],
        ),
      ),
    );
  }
}


class _RightRadioBullet extends StatelessWidget {
  const _RightRadioBullet({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final border = cs.outlineVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      alignment: Alignment.topRight,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: isDark ? cs.surface.withValues(alpha: 0.30) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? primary : border, width: 1.0),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: selected ? 8 : 0,
            height: selected ? 8 : 0,
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

