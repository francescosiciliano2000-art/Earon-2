// lib/features/agenda/presentation/hearing_edit_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/textarea.dart';
import 'package:gestionale_desktop/components/date_picker.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/alert_dialog.dart';

class HearingEditPage extends StatefulWidget {
  final String hearingId;
  const HearingEditPage({super.key, required this.hearingId});

  @override
  State<HearingEditPage> createState() => _HearingEditPageState();
}

class _HearingEditPageState extends State<HearingEditPage> {
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

  // Required fields
  DateTime? _startsDate;

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
          .select('hearing_id, matter_id, type, starts_at, courtroom, notes')
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
      final s = row['starts_at'];
      if (s != null && s.toString().isNotEmpty) {
        _startsDate = DateTime.tryParse(s.toString());
      }
      // Matter label
      if (_matterId != null && _matterId!.isNotEmpty) {
        final m = await _matterRepo.get(_matterId!);
        if (m != null) {
          _matterCtl.text = '${m.code} — ${m.title}';
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
          .map((m) => _MatterOption(id: m.matterId, label: '${m.code} — ${m.title}'))
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

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'matter_id': _matterId,
        'type': type.isEmpty ? null : type,
        'starts_at': _startsDate!.toIso8601String(),
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
        if (!mounted) return;
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
    final dt = Theme.of(context).extension<DefaultTokens>();
    final spacing = dt?.spacingUnit ?? 8.0;
    return Padding(
      padding: EdgeInsets.all(spacing * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.event),
              SizedBox(width: spacing),
              Text('Modifica udienza', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _saving ? null : _delete,
                leading: const Icon(AppIcons.delete),
                child: const Text('Elimina'),
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
            onSelected: (o) {
              setState(() {
                _matterId = o.id;
                _matterCtl.text = o.label;
              });
            },
            fieldViewBuilder: (ctx, ctl, focus, onSubmit) {
              ctl.removeListener(_onMatterTextChanged);
              ctl.addListener(() {
                _matterCtl.value = ctl.value;
                _onMatterTextChanged();
              });
              return SizedBox(
                height: 36,
                child: TextField(
                  controller: ctl,
                  focusNode: focus,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: 'Cerca pratica…',
                    border: const OutlineInputBorder(),
                    suffixIcon: _matterId != null
                        ? IconButton(
                            tooltip: 'Pulisci',
                            icon: const Icon(AppIcons.clear),
                            onPressed: () {
                              setState(() {
                                _matterId = null;
                                ctl.clear();
                              });
                            },
                          )
                        : null,
                  ),
                ),
              );
            },
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
                child: AppInput(
                  controller: _typeCtl,
                  hintText: 'Tipo (opzionale)',
                ),
              ),
            ],
          ),

          SizedBox(height: spacing * 2),
          AppInput(
            controller: _courtroomCtl,
            hintText: 'Aula (opzionale)',
          ),
          SizedBox(height: spacing * 2),
          AppTextarea(
            controller: _notesCtl,
            hintText: 'Note (opzionale)',
            minLines: 3,
          ),

          if (_error != null) ...[
            SizedBox(height: spacing * 2),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],

          SizedBox(height: spacing * 4),
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
    );
  }

  String _fmtDate(DateTime d) {
    final dt = d.toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }
}

class _MatterOption {
  final String id;
  final String label;
  const _MatterOption({required this.id, required this.label});
  @override
  String toString() => label;
}
