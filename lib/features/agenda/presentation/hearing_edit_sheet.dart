// lib/features/agenda/presentation/hearing_edit_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/textarea.dart';

import '../../../design system/components/sonner.dart';
import '../../../design system/components/alert_dialog.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import 'package:gestionale_desktop/features/matters/data/matter_model.dart';
import '../../../design system/components/spinner.dart';
import 'package:gestionale_desktop/components/date_picker.dart';

class HearingEditSheet extends StatefulWidget {
  final String hearingId;
  const HearingEditSheet({super.key, required this.hearingId});

  @override
  State<HearingEditSheet> createState() => _HearingEditSheetState();
}

class _HearingEditSheetState extends State<HearingEditSheet> {
  late final SupabaseClient _sb;
  late final MatterRepo _matterRepo;

  // Form controllers
  final _typeCtl = TextEditingController();
  final _courtroomCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  // Matter autocomplete
  final _matterCtl = TextEditingController();
  String? _matterId;
  List<_MatterOption> _matterOptions = const [];
  Timer? _matterDebounce;
  String _matterCourt = '';
  String _matterJudge = '';

  // Required fields (mappati su ends_at per la data e time per l'ora)
  DateTime? _startsDate; // solo data
  TimeOfDay? _startsTime; // ora/minuto

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

  @override
  void dispose() {
    _typeCtl.dispose();
    _courtroomCtl.dispose();
    _notesCtl.dispose();
    _matterCtl.dispose();
    _matterDebounce?.cancel();
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
      _typeCtl.text = '${row['type'] ?? ''}';
      _courtroomCtl.text = '${row['courtroom'] ?? ''}';
      _notesCtl.text = '${row['notes'] ?? ''}';
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
        }
      }
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

  Future<void> _searchMatters(String q) async {
    try {
      final rows = await _matterRepo.list(search: q, page: 1, pageSize: 50);
      final opts = rows
          .map((m) => _MatterOption(id: m.matterId, label: _buildMatterLabel(m)))
          .toList();
      if (!mounted) return;
      setState(() => _matterOptions = opts);
    } catch (_) {}
  }

  void _onMatterTextChanged() {
    _matterDebounce?.cancel();
    _matterDebounce = Timer(const Duration(milliseconds: 300), () async {
      final text = _matterCtl.text.trim();
      if (text.isEmpty) {
        setState(() => _matterOptions = const []);
        return;
      }
      await _searchMatters(text);
    });
  }

  Future<void> _pickStartsDate() async {
    final picked = await AppDatePicker.show(
      context,
      initialDate: _startsDate ?? DateTime.now(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) setState(() => _startsDate = picked);
  }

  Future<void> _pickStartsTime() async {
    final initial = _startsTime ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) setState(() => _startsTime = picked);
  }

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
        final toaster = AppToaster.of(context);
        toaster.loading('Eliminazione udienza…');
        try {
          await _sb.from('hearings').delete().eq('hearing_id', widget.hearingId);
          if (!mounted) return;
          toaster.success('Udienza eliminata');
          Navigator.of(context).pop({'deleted': true});
        } catch (e) {
          if (!mounted) return;
          toaster.error('Udienza non eliminata correttamente', description: e.toString());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Spinner());
    }
    final spacing = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing * 4, spacing * 4, spacing * 4, spacing * 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(AppIcons.event),
                SizedBox(width: spacing),
                Text('Modifica udienza',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : _delete,
                  leading: const Icon(AppIcons.delete),
                  child: const Text('Elimina'),
                ),
                SizedBox(width: spacing),
                AppButton(
                  size: AppButtonSize.icon,
                  variant: AppButtonVariant.ghost,
                  leading: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: spacing * 2),
            const Text('Pratica (obbligatoria)'),
            SizedBox(height: spacing * 0.5),
            Autocomplete<_MatterOption>(
              displayStringForOption: (o) => o.label,
              optionsBuilder: (text) {
                final q = text.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<_MatterOption>.empty();
                return _matterOptions
                    .where((o) => o.label.toLowerCase().contains(q));
              },
              onSelected: (o) async {
                setState(() {
                  _matterId = o.id;
                  _matterCtl.text = o.label;
                });
                try {
                  final m = await _matterRepo.get(o.id);
                  if (!mounted) return;
                  setState(() {
                    _matterCourt = m?.court ?? '';
                    _matterJudge = m?.judge ?? '';
                  });
                } catch (_) {}
              },
              fieldViewBuilder: (ctx, ctl, focus, onSubmit) {
                ctl.removeListener(_onMatterTextChanged);
                ctl.addListener(() {
                  _matterCtl.value = ctl.value;
                  _onMatterTextChanged();
                });
                return TextField(
                  controller: ctl,
                  focusNode: focus,
                  decoration: InputDecoration(
                    hintText: 'Cerca pratica…',
                    suffixIcon: _matterId != null
                        ? IconButton(
                            tooltip: 'Pulisci',
                            icon: const Icon(AppIcons.clear),
                            onPressed: () {
                              setState(() {
                                _matterId = null;
                                _matterCourt = '';
                                _matterJudge = '';
                                ctl.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => onSubmit(),
                );
              },
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tribunale (derivato dalla pratica)'),
                      SizedBox(height: spacing * 0.5),
                      Text(_matterCourt.isEmpty ? '—' : _matterCourt,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                SizedBox(width: spacing * 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giudice (derivato dalla pratica)'),
                      SizedBox(height: spacing * 0.5),
                      Text(_matterJudge.isEmpty ? '—' : _matterJudge,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing * 2),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Data (obbligatoria)'),
                      SizedBox(height: spacing * 0.5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _startsDate == null
                                  ? '—'
                                  : _fmtDate(_startsDate!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          SizedBox(width: spacing),
                          AppButton(
                            variant: AppButtonVariant.secondary,
                            onPressed: _pickStartsDate,
                            leading: const Icon(AppIcons.event),
                            child: const Text('Scegli data'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing * 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ora (obbligatoria)'),
                      SizedBox(height: spacing * 0.5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _startsTime == null
                                  ? '—'
                                  : _fmtTime(_startsTime!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          SizedBox(width: spacing),
                          AppButton(
                            variant: AppButtonVariant.secondary,
                            onPressed: _pickStartsTime,
                            leading: const Icon(AppIcons.schedule),
                            child: const Text('Scegli ora'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing * 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tipo (opzionale)'),
                SizedBox(height: spacing * 0.5),
                AppInput(
                  controller: _typeCtl,
                ),
              ],
            ),
            SizedBox(height: spacing * 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aula (opzionale)'),
                SizedBox(height: spacing * 0.5),
                AppInput(
                  controller: _courtroomCtl,
                ),
              ],
            ),
            SizedBox(height: spacing * 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note (opzionale)'),
                SizedBox(height: spacing * 0.5),
                AppTextarea(
                  controller: _notesCtl,
                  minLines: 3,
                ),
              ],
            ),
            if (_error != null) ...[
              SizedBox(height: spacing * 2),
              Builder(
                builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.error),
                  );
                },
              ),
            ],
            SizedBox(height: spacing * 4),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
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

  /// Costruisce la label della pratica per il typeahead:
  /// "CODE — Cognome Nome (se person) o Nome company_type (se company) / Nome controparte"
  /// Se i dati cliente/controparte non sono disponibili, ripiega su "CODE — title".
  String _buildMatterLabel(Matter m) {
    final client = (m.clientDisplayName ?? '').trim();
    final counterparty = (m.counterpartyName ?? '').trim();
    final extraParts = <String>[];
    if (client.isNotEmpty) extraParts.add(client);
    if (counterparty.isNotEmpty) extraParts.add(counterparty);
    final suffix = extraParts.isNotEmpty
        ? ' — ${extraParts.join(' / ')}'
        : ' — ${m.title}';
    return '${m.code}$suffix';
  }

  String _fmtDate(DateTime d) {
    final dt = d.toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  String _fmtTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return '$hh:$mi';
  }
}

class _MatterOption {
  final String id;
  final String label;
  const _MatterOption({required this.id, required this.label});
  @override
  String toString() => label;
}
