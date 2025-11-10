// lib/features/matters/presentation/matter_edit_sheet.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/design system/components/button.dart';
import 'package:gestionale_desktop/design system/components/input.dart';
import 'package:gestionale_desktop/design system/components/textarea.dart';
import 'package:gestionale_desktop/design system/components/select.dart';
import 'package:gestionale_desktop/design system/components/date_picker.dart';
import 'package:gestionale_desktop/design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';

import '../data/matter_repo.dart';
import '../data/matter_model.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';

/// Bottom sheet per modificare una pratica esistente.
/// Validazioni: subject obbligatorio; court/responsible opzionali.
class MatterEditSheet extends StatefulWidget {
  final Matter matter;
  const MatterEditSheet({super.key, required this.matter});

  @override
  State<MatterEditSheet> createState() => _MatterEditSheetState();
}

class _MatterEditSheetState extends State<MatterEditSheet> {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;

  final _subjectCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _statusCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  final _courtCtl = TextEditingController();
  final _judgeCtl = TextEditingController();
  final _counterpartyCtl = TextEditingController();
  final _rgCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  bool _saving = false;
  String? _error;
  List<String> _statusSuggestions = const [];
  List<String> _courtSuggestions = const [];
  DateTime? _openedAt;
  DateTime? _closedAt;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _codeCtl.text = widget.matter.code;
    _subjectCtl.text = widget.matter.title;
    _statusCtl.text = widget.matter.status ?? '';
    _areaCtl.text = widget.matter.area ?? '';
    _courtCtl.text = widget.matter.court ?? '';
    _judgeCtl.text = widget.matter.judge ?? '';
    _counterpartyCtl.text = widget.matter.counterpartyName ?? '';
    _rgCtl.text = widget.matter.rgNumber ?? '';
    _notesCtl.text = widget.matter.description ?? '';
    _openedAt = widget.matter.openedAt;
    _closedAt = widget.matter.closedAt;
    _bootstrap();
  }

  @override
  void dispose() {
    _codeCtl.dispose();
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
    try {
      final fid = await getCurrentFirmId();
      if (fid == null) return;
      final statuses = await _loadDistinctValues('status');
      final courts = await _loadDistinctValues('court');
      setState(() {
        _statusSuggestions = statuses.isEmpty
            ? const ['open', 'in_progress', 'closed']
            : statuses;
        _courtSuggestions = courts;
      });
    } catch (_) {}
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

  Future<void> _submit() async {
    final subject = _subjectCtl.text.trim();
    final code = _codeCtl.text.trim();
    final status = _statusCtl.text.trim();
    final area = _areaCtl.text.trim();
    final court = _courtCtl.text.trim();
    final judge = _judgeCtl.text.trim();
    final counterparty = _counterpartyCtl.text.trim();
    final rgNumber = _rgCtl.text.trim();
    final notes = _notesCtl.text.trim();

    if (subject.isEmpty) {
      setState(() => _error = 'Oggetto obbligatorio');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _repo.update(
        widget.matter.matterId,
        code: code.isEmpty ? null : code,
        subject: subject,
        status: status.isEmpty ? null : status,
        area: area.isEmpty ? null : area,
        courtId: court.isEmpty ? null : court,
        judge: judge.isEmpty ? null : judge,
        notes: notes.isEmpty ? null : notes,
        counterpartyName: counterparty.isEmpty ? null : counterparty,
        rgNumber: rgNumber.isEmpty ? null : rgNumber,
        openedAt: _openedAt,
        closedAt: _closedAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Spacing Design System
    final spacing = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing * 2, spacing * 2, spacing * 2, spacing * 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(AppIcons.edit),
                SizedBox(width: spacing),
                Text('Modifica pratica',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                AppButton(
                  variant: AppButtonVariant.ghost,
                  leading: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Chiudi'),
                )
              ],
            ),
            SizedBox(height: spacing * 2),
            // Codice pratica
            AppInput(
              controller: _codeCtl,
              hintText: 'Codice pratica',
            ),
            SizedBox(height: spacing * 2),
            AppInput(
              controller: _subjectCtl,
              hintText: 'Oggetto (obbligatorio)',
            ),
            SizedBox(height: spacing * 2),
            AppSelect(
              value: _statusSuggestions.contains(_statusCtl.text)
                  ? _statusCtl.text
                  : null,
              placeholder: 'Stato (opzionale)',
              width: double.infinity,
              groups: [
                SelectGroupData(
                  label: 'Stato (opzionale)',
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
            AppInput(
              controller: _areaCtl,
              hintText: 'Area (opzionale)',
            ),
            SizedBox(height: spacing * 2),
            AppSelect(
              value: _courtSuggestions.contains(_courtCtl.text)
                  ? _courtCtl.text
                  : null,
              placeholder: 'Foro (opzionale)',
              width: double.infinity,
              groups: [
                SelectGroupData(
                  label: 'Foro (opzionale)',
                  items: [
                    const SelectItemData(value: '', label: '—'),
                    ..._courtSuggestions.map(
                      (c) => SelectItemData(value: c, label: c),
                    ),
                  ],
                ),
              ],
              onChanged: (v) => setState(() => _courtCtl.text = v.isEmpty ? '' : v),
            ),
            SizedBox(height: spacing * 2),
            AppInput(
              controller: _judgeCtl,
              hintText: 'Giudice (opzionale)',
            ),
            SizedBox(height: spacing * 2),
            AppInput(
              controller: _counterpartyCtl,
              hintText: 'Controparte (opzionale)',
            ),
            SizedBox(height: spacing * 2),
            AppInput(
              controller: _rgCtl,
              hintText: 'Numero RG (opzionale)',
            ),
            SizedBox(height: spacing * 2),
            // Date apertura/chiusura
            Row(
              children: [
                Expanded(
                  child: AppDatePickerInput(
                    initialDate: _openedAt ?? DateTime.now(),
                    firstDate: DateTime(1970, 1, 1),
                    lastDate: DateTime(2100, 12, 31),
                    onDateSubmitted: (d) => setState(() => _openedAt = d),
                    label: 'Data apertura',
                  ),
                ),
                SizedBox(width: spacing * 2),
                Expanded(
                  child: AppDatePickerInput(
                    initialDate: _closedAt ?? (_openedAt ?? DateTime.now()),
                    firstDate: DateTime(1970, 1, 1),
                    lastDate: DateTime(2100, 12, 31),
                    onDateSubmitted: (d) => setState(() => _closedAt = d),
                    label: 'Data chiusura',
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing * 2),
            AppTextarea(
              controller: _notesCtl,
              minLines: 3,
              hintText: 'Note (opzionale)',
            ),
            if (_error != null) ...[
              SizedBox(height: spacing * 2),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: spacing * 3),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                variant: AppButtonVariant.default_,
                onPressed: _saving ? null : _submit,
                leading: const Icon(AppIcons.save),
                child: const Text('Salva modifiche'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
