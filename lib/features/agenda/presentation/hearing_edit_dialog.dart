// lib/features/agenda/presentation/hearing_edit_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/textarea.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/alert.dart';

import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import 'package:gestionale_desktop/features/matters/data/matter_model.dart';
import 'package:gestionale_desktop/components/date_picker.dart';
import '../../../design system/components/alert_dialog.dart';
// rimosso: AppSearchSelect (in modifica la pratica è read-only)
import '../../../design system/components/time_numeric_input.dart';

class HearingEditDialog extends StatefulWidget {
  final String hearingId;
  const HearingEditDialog({super.key, required this.hearingId});

  @override
  State<HearingEditDialog> createState() => _HearingEditDialogState();
}

class _HearingEditDialogState extends State<HearingEditDialog> {
  late final SupabaseClient _sb;
  late final MatterRepo _matterRepo;

  // Form controllers
  final _typeCtl = TextEditingController();
  final _courtroomCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  // Derived (read-only visual) fields
  final _matterCourtCtl = TextEditingController();
  final _matterJudgeCtl = TextEditingController();

  // Matter autocomplete
  final _matterCtl = TextEditingController();
  String? _matterId;
  String _matterCourt = '';
  String _matterJudge = '';

  // Required fields (mappati su ends_at per la data e time per l'ora)
  DateTime? _startsDate; // solo data (derivata da ends_at)
  TimeOfDay? _startsTime; // ora/minuto (derivata da field `time`)

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _matterRepo = MatterRepo(_sb);
    _bootstrap();
  }

  // Costruisce la label pratica richiesta:
  // CODE — Cognome Nome (se person) o Nome company_type (se company) / Nome controparte
  String _buildMatterLabel(Matter m) {
    final code = (m.code).trim();
    final client = (m.clientDisplayName ?? '').trim();
    final counter = (m.counterpartyName ?? '').trim();
    String right = '';
    if (client.isNotEmpty) right = client;
    if (counter.isNotEmpty) right = right.isNotEmpty ? '$right / $counter' : counter;
    if (right.isEmpty) {
      // fallback: usa il titolo della pratica
      right = (m.title).trim();
    }
    return '$code — $right';
  }

  @override
  void dispose() {
    _typeCtl.dispose();
    _courtroomCtl.dispose();
    _notesCtl.dispose();
    _matterCourtCtl.dispose();
    _matterJudgeCtl.dispose();
    _matterCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final row = await _sb
          .from('hearings')
          .select('hearing_id, matter_id, type, ends_at, time, courtroom, notes')
          .eq('hearing_id', widget.hearingId)
          .maybeSingle();
      if (row == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Udienza non trovata';
          _loading = false;
        });
        return;
      }
      _matterId = row['matter_id']?.toString();
      _typeCtl.text = row['type']?.toString() ?? '';
      _courtroomCtl.text = row['courtroom']?.toString() ?? '';
      _notesCtl.text = row['notes']?.toString() ?? '';
      // Data da ends_at
      final ends = row['ends_at'];
      if (ends != null && ends.toString().isNotEmpty) {
        final dt = DateTime.tryParse(ends.toString())?.toLocal();
        if (dt != null) {
          _startsDate = DateTime(dt.year, dt.month, dt.day);
        }
      }
      // Ora dal campo `time` (stringa "HH:MM" o "HH:MM:SS")
      final timeStr = row['time']?.toString();
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        final hh = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        final mi = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        _startsTime = TimeOfDay(hour: hh, minute: mi);
      }
      // Matter label + details
      if (_matterId != null && _matterId!.isNotEmpty) {
        final m = await _matterRepo.get(_matterId!);
        if (m != null) {
          _matterCtl.text = _buildMatterLabel(m);
          _matterCourt = m.court ?? '';
          _matterJudge = m.judge ?? '';
          _matterCourtCtl.text = _matterCourt.isEmpty ? '—' : _matterCourt;
          _matterJudgeCtl.text = _matterJudge.isEmpty ? '—' : _matterJudge;
        }
      }
      // Orario già impostato in _startsTime; le stringhe derivate non sono necessarie
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // In modifica la pratica è bloccata: niente autocomplete/ricerca

  // Selettori data/ora gestiti tramite AppDatePickerInput e AppTimeNumericInput nel build

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final type = _typeCtl.text.trim();
    final courtroom = _courtroomCtl.text.trim();
    final notes = _notesCtl.text.trim();

    if (_matterId == null || _matterId!.isEmpty) {
      setState(() => _error = 'Pratica obbligatoria');
      return;
    }
    if (_startsDate == null) {
      setState(() => _error = 'Data udienza obbligatoria');
      return;
    }
    if (_startsTime == null) {
      setState(() => _error = 'Ora udienza obbligatoria');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final endsAt = _combineDateTime(_startsDate!, _startsTime!);
      final hh = _startsTime!.hour.toString().padLeft(2, '0');
      final mi = _startsTime!.minute.toString().padLeft(2, '0');
      final payload = {
        'matter_id': _matterId,
        'type': type.isEmpty ? null : type,
        'ends_at': endsAt.toIso8601String(),
        'time': '$hh:$mi:00',
        'courtroom': courtroom.isEmpty ? null : courtroom,
        'notes': notes.isEmpty ? null : notes,
      };
      final updated = await _sb
          .from('hearings')
          .update(payload)
          .eq('hearing_id', widget.hearingId)
          .select('hearing_id')
          .maybeSingle();
      if (!mounted) return;
      AppToaster.of(context).success('Udienza aggiornata');
      Navigator.of(context).pop(updated);
    } catch (e) {
      AppToaster.of(context).error('Errore aggiornamento udienza: ${e.toString()}');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    await AppAlertDialog.show<void>(
      context,
      title: 'Elimina udienza',
      description: 'Confermi l\'eliminazione di questa udienza?\nL\'operazione non può essere annullata.',
      cancelText: 'Annulla',
      confirmText: 'Elimina',
      destructive: true,
      barrierDismissible: false,
      onConfirm: () async {
        try {
          await _sb.from('hearings').delete().eq('hearing_id', widget.hearingId);
          if (!mounted) return;
          AppToaster.of(context).success('Udienza eliminata');
          Navigator.of(context).pop({'deleted': true});
        } catch (e) {
          if (!mounted) return;
          AppToaster.of(context).error('Errore eliminazione: ${e.toString()}');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Modifica udienza'),
          description: AppDialogDescription(
            'Aggiorna i dettagli e gestisci la pratica associata all’udienza.',
          ),
        ),
        SizedBox(height: spacing * 2),
        SizedBox(
          width: 620,
          child: _loading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(spacing * 3),
                    child: Spinner(),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pratica'),
                      SizedBox(height: spacing * 0.5),
                      Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: AppInput(
                                    controller: _matterCtl,
                                    enabled: false,
                                    hintText: '—',
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tribunale (derivato dalla pratica)'),
                                const SizedBox(height: 6),
                                AppInput(
                                  controller: _matterCourtCtl,
                                  enabled: false,
                                  hintText: '—',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Giudice (derivato dalla pratica)'),
                                const SizedBox(height: 6),
                                AppInput(
                                  controller: _matterJudgeCtl,
                                  enabled: false,
                                  hintText: '—',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Tipo udienza'),
                      const SizedBox(height: 6),
                      AppInput(
                        controller: _typeCtl,
                        hintText: 'Esempio: Prima udienza, Comparizione…',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data udienza'),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 200,
                                  child: AppDatePickerInput(
                                    initialDate: _startsDate,
                                    firstDate: DateTime(2000, 1, 1),
                                    lastDate: DateTime(2100, 12, 31),
                                    onDateSubmitted: (d) => setState(() => _startsDate = d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ora udienza'),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 200,
                                  child: AppTimeNumericInput(
                                    initialTime: _startsTime,
                                    onTimeSubmitted: (t) => setState(() => _startsTime = t),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Aula'),
                      const SizedBox(height: 6),
                      AppInput(
                        controller: _courtroomCtl,
                        hintText: 'Es. Aula 12',
                      ),
                      const SizedBox(height: 16),
                      const Text('Note'),
                      const SizedBox(height: 6),
                      AppTextarea(
                        controller: _notesCtl,
                        minLines: 3,
                        hintText: 'Informazioni aggiuntive',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Alert(
                          variant: AlertVariant.destructive,
                          child: AlertDescription(Text(_error!)),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        AppDialogFooter(
          children: [
            AppButton(
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            AppButton(
              variant: AppButtonVariant.destructive,
              onPressed: _loading ? null : _delete,
              child: const Text('Elimina'),
            ),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: _saving || _loading ? null : _submit,
              child: _saving ? Spinner(size: 18) : const Text('Salva'),
            ),
          ],
        ),
      ],
    );
  }

}
// (nessuna opzione pratica in modifica: il campo è read-only)
