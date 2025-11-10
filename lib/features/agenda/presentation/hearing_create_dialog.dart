// lib/features/agenda/presentation/hearing_create_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/textarea.dart';
import '../../../design system/components/sonner.dart';

import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import 'package:gestionale_desktop/features/matters/data/matter_model.dart';
import 'package:gestionale_desktop/components/date_picker.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/time_numeric_input.dart';

class HearingCreateDialog extends StatefulWidget {
  final String? presetMatterId;
  final DateTime? presetDate;
  const HearingCreateDialog({super.key, this.presetMatterId, this.presetDate});

  @override
  State<HearingCreateDialog> createState() => _HearingCreateDialogState();
}

class _HearingCreateDialogState extends State<HearingCreateDialog> {
  late final SupabaseClient _sb;
  late final MatterRepo _matterRepo;

  // Form controllers
  final _typeCtl = TextEditingController();
  final _courtroomCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  // Matter autocomplete
  final _matterCtl = TextEditingController();
  String? _matterId;
  // Items per la combobox pratica (in‑memory, filtrati dal componente)
  List<ComboboxItem> _matterItems = const [];
  // Visualizzazione derivata da pratica
  String _matterCourt = '';
  String _matterJudge = '';

  // Required fields
  DateTime? _startsDate; // solo data
  TimeOfDay? _startsTime; // ora/minuto

  bool _saving = false;
  bool _showValidation = false;

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
    if (counter.isNotEmpty) {
      right = right.isNotEmpty ? '$right / $counter' : counter;
    }
    if (right.isEmpty) {
      // fallback: usa il titolo della pratica
      right = (m.title).trim();
    }
    return '$code — $right';
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.presetMatterId != null && widget.presetMatterId!.isNotEmpty) {
        _matterId = widget.presetMatterId;
        final m = await _matterRepo.get(widget.presetMatterId!);
        if (m != null) {
          setState(() {
            _matterCtl.text = _buildMatterLabel(m);
            _matterCourt = m.court ?? '';
            _matterJudge = m.judge ?? '';
            // Pre-popola con la pratica corrente per migliorare UX
            _matterItems = [
              ComboboxItem(value: m.matterId, label: _buildMatterLabel(m)),
            ];
          });
        }
      }
      // Se non c'è una pratica preimpostata, carica le prime 20 per il primo click
      final rows = await _matterRepo.list(search: '', page: 1, pageSize: 50);
      final baseItems = rows
          .map((m) =>
              ComboboxItem(value: m.matterId, label: _buildMatterLabel(m)))
          .toList();
      // Se c'è un preset, assicurati che sia incluso e al primo posto
      setState(() {
        if ((_matterId ?? '').isNotEmpty) {
          // Evita duplicati
          final presetIdx = baseItems.indexWhere((it) => it.value == _matterId);
          if (presetIdx == -1) {
            _matterItems = [
              ComboboxItem(
                value: _matterId!,
                label: _matterCtl.text.isNotEmpty
                    ? _matterCtl.text
                    : 'Pratica predefinita',
              ),
              ...baseItems,
            ];
          } else {
            _matterItems = baseItems;
          }
        } else {
          _matterItems = baseItems;
        }
      });
      if (widget.presetDate != null) {
        setState(() => _startsDate = widget.presetDate);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _typeCtl.dispose();
    _courtroomCtl.dispose();
    _notesCtl.dispose();
    _matterCtl.dispose();
    super.dispose();
  }

  // Selettore data gestito tramite AppDatePickerInput direttamente nel build

  // Time picking is handled inline by AppTimeNumericInput

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final type = _typeCtl.text.trim();
    final courtroom = _courtroomCtl.text.trim();
    final notes = _notesCtl.text.trim();

    if (_matterId == null || _matterId!.isEmpty) {
      setState(() => _showValidation = true);
      AppToaster.of(context).warning('Pratica obbligatoria');
      return;
    }
    if (_startsDate == null) {
      setState(() => _showValidation = true);
      AppToaster.of(context).warning('Data udienza obbligatoria');
      return;
    }
    if (_startsTime == null) {
      setState(() => _showValidation = true);
      AppToaster.of(context).warning('Ora udienza obbligatoria');
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }
      final endsAt = _combineDateTime(_startsDate!, _startsTime!);
      final hh = _startsTime!.hour.toString().padLeft(2, '0');
      final mi = _startsTime!.minute.toString().padLeft(2, '0');
      final payload = {
        'firm_id': fid,
        'matter_id': _matterId,
        'type': type.isEmpty ? null : type,
        'ends_at': endsAt.toIso8601String(),
        'time': '$hh:$mi:00',
        'courtroom': courtroom.isEmpty ? null : courtroom,
        'notes': notes.isEmpty ? null : notes,
      };
      final created = await _sb
          .from('hearings')
          .insert(payload)
          .select('hearing_id, type, ends_at, time, courtroom, notes')
          .maybeSingle();
      if (!mounted) return;
      AppToaster.of(context).success('Udienza creata');
      Navigator.of(context).pop(created);
    } catch (e) {
      AppToaster.of(context).error('Errore creazione udienza: ${e.toString()}');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()!.spacingUnit;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Nuova udienza'),
          description: AppDialogDescription(
            'Compila i dettagli per programmare una nuova udienza.',
          ),
        ),
        SizedBox(height: su * 2),
        SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pratica'),
                SizedBox(height: su * 0.5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AppCombobox(
                      items: _matterItems,
                      value: (_matterId == null || _matterId!.isEmpty)
                          ? null
                          : _matterId,
                      placeholder: 'Seleziona pratica…',
                      width: constraints.maxWidth, // piena larghezza
                      buttonVariant: AppButtonVariant.outline,
                      // La lista si adatta alla riga più lunga
                      popoverMatchWidestRow: true,
                      emptyLabel: 'Nessun risultato',
                      onChanged: (v) async {
                        setState(() => _matterId = v);
                        try {
                          if (v == null || v.isEmpty) {
                            setState(() {
                              _matterCourt = '';
                              _matterJudge = '';
                            });
                          } else {
                            final m = await _matterRepo.get(v);
                            if (!mounted) return;
                            setState(() {
                              _matterCourt = m?.court ?? '';
                              _matterJudge = m?.judge ?? '';
                            });
                          }
                        } catch (_) {}
                      },
                    );
                  },
                ),
                if (_showValidation &&
                    (_matterId == null || _matterId!.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Pratica obbligatoria',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                SizedBox(height: su * 1.5),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Data udienza'),
                          SizedBox(height: su * 0.5),
                          SizedBox(
                            width: 200,
                            child: AppDatePickerInput(
                              initialDate: _startsDate,
                              firstDate: DateTime(2000, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                              onDateSubmitted: (d) =>
                                  setState(() => _startsDate = d),
                            ),
                          ),
                          if (_showValidation && _startsDate == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Data obbligatoria',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: su * 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ora udienza'),
                          SizedBox(height: su * 0.5),
                          SizedBox(
                            width: 200,
                            child: AppTimeNumericInput(
                              initialTime: _startsTime,
                              onTimeSubmitted: (t) {
                                setState(() {
                                  _startsTime = t;
                                });
                              },
                            ),
                          ),
                          if (_showValidation && _startsTime == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Ora obbligatoria',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: su * 1.5),
                const Text('Tipo udienza'),
                SizedBox(height: su * 0.5),
                AppInput(
                  controller: _typeCtl,
                  hintText: '',
                ),
                SizedBox(height: su * 1.5),
                const Text('Aula'),
                SizedBox(height: su * 0.5),
                AppInput(
                  controller: _courtroomCtl,
                  hintText: '',
                ),
                SizedBox(height: su * 1.5),
                const Text('Note'),
                SizedBox(height: su * 0.5),
                AppTextarea(
                  controller: _notesCtl,
                  minLines: 3,
                  hintText: 'Informazioni aggiuntive',
                ),
                if (_matterCourt.isNotEmpty || _matterJudge.isNotEmpty) ...[
                  SizedBox(height: su * 1.5),
                  const Text('Informazioni dalla pratica'),
                  if (_matterCourt.isNotEmpty)
                    Text('Tribunale: $_matterCourt',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (_matterJudge.isNotEmpty)
                    Text('Giudice: $_matterJudge',
                        style: Theme.of(context).textTheme.bodySmall),
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
              variant: AppButtonVariant.default_,
              onPressed: _saving ? null : _submit,
              leading: const Icon(AppIcons.save),
              child: _saving
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Text('Crea udienza'),
            ),
          ],
        ),
      ],
    );
  }

  // Formattazione data non utilizzata: rimossa
}

class MatterOption {
  final String id;
  final String label;
  const MatterOption({required this.id, required this.label});
  @override
  String toString() => label;
}
