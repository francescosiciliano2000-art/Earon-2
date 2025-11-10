// lib/features/matters/presentation/matter_create_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/design system/components/button.dart';
import 'package:gestionale_desktop/design system/components/input.dart';
import 'package:gestionale_desktop/design system/components/select.dart';
import 'package:gestionale_desktop/design system/components/search_select.dart';
import 'package:gestionale_desktop/design system/components/textarea.dart';
import 'package:gestionale_desktop/design system/components/date_picker.dart';
import 'package:gestionale_desktop/design system/theme/themes.dart';

import '../data/matter_repo.dart';
import '../data/matter_model.dart';
import '../../clienti/data/cliente_repo.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'matters_list_page.dart' show ClientOption; // riuso tipo semplice
import '../../../design system/icons/app_icons.dart';

/// Bottom sheet per creare una nuova pratica.
/// Validazioni: client obbligatorio, subject obbligatorio; court/responsible opzionali.
class MatterCreateSheet extends StatefulWidget {
  final String? presetClientId;
  const MatterCreateSheet({super.key, this.presetClientId});

  @override
  State<MatterCreateSheet> createState() => _MatterCreateSheetState();
}

class _MatterCreateSheetState extends State<MatterCreateSheet> {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;
  late final ClienteRepo _clientsRepo;

  final _subjectCtl = TextEditingController();
  final _statusCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  final _courtCtl = TextEditingController();
  final _judgeCtl = TextEditingController();
  final _counterpartyCtl = TextEditingController();
  final _rgCtl = TextEditingController();
  // Responsabile rimosso: non presente nello schema, campo non più visualizzato
  final _notesCtl = TextEditingController();

  final _clientCtl = TextEditingController();
  String? _clientId;
  List<ClientOption> _clientOptions = const [];
  Timer? _clientDebounce;

  bool _saving = false;
  String? _error;
  DateTime? _openedAt;
  List<String> _courtSuggestions = const [];
  List<String> _statusSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _clientsRepo = ClienteRepo(_sb);
    _bootstrap();
    // Precarica i primi 20 clienti all’apertura per evitare elenco vuoto
    scheduleMicrotask(() => _searchClients(''));
  }

  @override
  void dispose() {
    _clientDebounce?.cancel();
    _clientCtl.dispose();
    _subjectCtl.dispose();
    _statusCtl.dispose();
    _areaCtl.dispose();
    _courtCtl.dispose();
    _judgeCtl.dispose();
    _counterpartyCtl.dispose();
    _rgCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _error = null);
    try {
      if (widget.presetClientId != null && widget.presetClientId!.isNotEmpty) {
        _clientId = widget.presetClientId;
      }
      final statuses = await _loadDistinctValues('status');
      final courts = await _loadDistinctValues('court');
      setState(() {
        _statusSuggestions = statuses.isEmpty
            ? const ['open', 'in_progress', 'closed']
            : statuses;
        _courtSuggestions = courts;
      });
    } catch (e) {
      setState(() => _error = e.toString());
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
      final opts = rows
          .map((r) => ClientOption(
                id: '${r['client_id']}',
                label: '${r['name'] ?? ''}',
              ))
          .toList();
      if (!mounted) return;
      setState(() => _clientOptions = opts);
    } catch (_) {}
  }


  void _onClientTextChanged() {
    _clientDebounce?.cancel();
    _clientDebounce = Timer(const Duration(milliseconds: 300), () async {
      final text = _clientCtl.text.trim();
      await _searchClients(text);
    });
  }

  

  Future<void> _submit() async {
    final subject = _subjectCtl.text.trim();
    final status = _statusCtl.text.trim();
    final area = _areaCtl.text.trim();
    final court = _courtCtl.text.trim();
    final judge = _judgeCtl.text.trim();
    final counterparty = _counterpartyCtl.text.trim();
    final rgNumber = _rgCtl.text.trim();
    final notes = _notesCtl.text.trim();

    if (_clientId == null || _clientId!.isEmpty) {
      setState(() => _error = 'Cliente obbligatorio');
      return;
    }
    if (subject.isEmpty) {
      setState(() => _error = 'Oggetto obbligatorio');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await _repo.create(
        clientId: _clientId!,
        subject: subject,
        status: status.isEmpty ? null : status,
        area: area.isEmpty ? null : area,
        courtId: court.isEmpty ? null : court,
        judge: judge.isEmpty ? null : judge,
        counterpartyName: counterparty.isEmpty ? null : counterparty,
        rgNumber: rgNumber.isEmpty ? null : rgNumber,
        openedAt: _openedAt,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DefaultTokens>();
    final spacing = tokens?.spacingUnit ?? 8.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing * 3, spacing * 3, spacing * 3, spacing * 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(AppIcons.gavel),
                SizedBox(width: spacing * 1.5),
                Text('Nuova pratica',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Tooltip(
                  message: 'Chiudi',
                  child: AppButton(
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.icon,
                    onPressed: () => Navigator.of(context).pop(),
                    leading: const Icon(AppIcons.close),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing * 2),

            const Text('Cliente (obbligatorio)'),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: AppSearchSelect(
                    width: double.infinity,
                    controller: _clientCtl,
                    placeholder: 'Cerca cliente…',
                    groups: [
                      SelectGroupData(
                        label: 'Clienti',
                        items: _clientOptions
                            .map((o) => SelectItemData(
                                  value: o.id,
                                  label: o.label,
                                ))
                            .toList(),
                      ),
                    ],
                    onQueryChanged: (q) {
                      _clientCtl.value = TextEditingValue(
                        text: q,
                        selection: TextSelection.collapsed(offset: q.length),
                      );
                      _onClientTextChanged();
                    },
                    onChanged: (value) {
                      final opt = _clientOptions.firstWhere(
                        (o) => o.id == value,
                        orElse: () => ClientOption(id: value, label: value),
                      );
                      setState(() {
                        _clientId = opt.id;
                        _clientCtl.text = opt.label;
                      });
                    },
                  ),
                ),
                if (_clientId != null)
                  Padding(
                    padding: EdgeInsets.only(left: spacing),
                    child: AppButton(
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.icon,
                      onPressed: () {
                        setState(() {
                          _clientId = null;
                          _clientCtl.clear();
                          _clientOptions = const [];
                        });
                      },
                      child: const Icon(AppIcons.clear, size: 16),
                    ),
                  ),
              ],
            ),

            SizedBox(height: spacing * 2),
            // Oggetto (obbligatorio)
            const Text('Oggetto (obbligatorio)'),
            SizedBox(height: spacing),
            AppInput(
              controller: _subjectCtl,
              hintText: 'Oggetto…',
            ),

            SizedBox(height: spacing * 2),
            // Stato (opzionale)
            AppSelect(
              placeholder: 'Stato (opzionale)',
              width: double.infinity,
              value: _statusSuggestions.contains(_statusCtl.text)
                  ? _statusCtl.text
                  : null,
              groups: [
                SelectGroupData(
                  label: 'Stato',
                  items: [
                    const SelectItemData(value: '', label: '—'),
                    ..._statusSuggestions.map(
                      (s) => SelectItemData(value: s, label: s),
                    ),
                  ],
                ),
              ],
              onChanged: (v) => setState(() => _statusCtl.text = v.isEmpty ? '' : v),
            ),

            SizedBox(height: spacing * 2),
            // Area (opzionale)
            AppInput(
              controller: _areaCtl,
              hintText: 'Area (opzionale)',
            ),

            SizedBox(height: spacing * 2),
            // Court (opzionale)
            AppSelect(
              placeholder: 'Foro (opzionale)',
              width: double.infinity,
              value: _courtSuggestions.contains(_courtCtl.text)
                  ? _courtCtl.text
                  : null,
              groups: [
                SelectGroupData(
                  label: 'Foro',
                  items: [
                    const SelectItemData(value: '', label: '—'),
                    ..._courtSuggestions.map(
                      (c) => SelectItemData(value: c, label: c),
                    ),
                  ],
                ),
              ],
              onChanged: (v) {
                setState(() => _courtCtl.text = v.isEmpty ? '' : v);
              },
            ),

            SizedBox(height: spacing * 2),
            // Giudice (opzionale)
            AppInput(
              controller: _judgeCtl,
              hintText: 'Giudice (opzionale)',
            ),

            SizedBox(height: spacing * 2),
            // Controparte (opzionale)
            AppInput(
              controller: _counterpartyCtl,
              hintText: 'Controparte (opzionale)',
            ),

            SizedBox(height: spacing * 2),
            // Numero RG (opzionale)
            AppInput(
              controller: _rgCtl,
              hintText: 'Numero RG (opzionale)',
            ),

            SizedBox(height: spacing * 2),
            // Data apertura (default: oggi)
            AppDatePickerInput(
              initialDate: _openedAt ?? DateTime.now(),
              firstDate: DateTime(1970, 1, 1),
              lastDate: DateTime(2100, 12, 31),
              onDateSubmitted: (d) => setState(() => _openedAt = d),
              label: 'Data apertura',
            ),

            // Responsabile rimosso (placeholder non supportato nel DB)
            SizedBox(height: spacing * 2),
            const Text('Note (opzionale)'),
            SizedBox(height: spacing),
            AppTextarea(
              controller: _notesCtl,
              hintText: 'Note…',
              minLines: 3,
              maxLines: 6,
            ),

            if (_error != null) ...[
              SizedBox(height: spacing * 2),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],

            SizedBox(height: spacing * 3),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                variant: AppButtonVariant.default_,
                onPressed: _saving ? null : _submit,
                leading: const Icon(AppIcons.save),
                child: const Text('Crea pratica'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
