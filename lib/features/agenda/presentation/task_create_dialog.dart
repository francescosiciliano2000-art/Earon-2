// lib/features/agenda/presentation/task_create_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/combobox.dart';
import '../../../design system/components/textarea.dart';
// import '../../../design system/components/switch.dart';
import 'package:gestionale_desktop/components/date_picker.dart';
import '../../../design system/components/alert.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import 'package:gestionale_desktop/features/matters/data/matter_model.dart';
import '../../../design system/icons/app_icons.dart';

class TaskCreateDialog extends StatefulWidget {
  final String? presetMatterId;
  const TaskCreateDialog({super.key, this.presetMatterId});

  @override
  State<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<TaskCreateDialog> {
  late final SupabaseClient _sb;
  late final MatterRepo _matterRepo;

  // Form controllers
  final _titleCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  // Matter autocomplete
  String? _matterId;
  List<MatterOption> _matterOptions = const [];
  Timer? _matterDebounce;

  // Team (assignee)
  List<_AssigneeOption> _assigneeOptions = const [];
  String? _assigneeId;

  // Optional fields
  DateTime? _dueDate;
  DateTime? _startDate;
  String? _priority = 'normal';
  // Nuovo campo: tipo task (onere/scrivere)
  String? _type = 'onere';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _matterRepo = MatterRepo(_sb);
    _bootstrap();
    // Precarica le prime pratiche per evitare overlay vuoto all'apertura
    scheduleMicrotask(() => _onMatterQueryChanged(''));
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

  Future<void> _bootstrap() async {
    try {
      final fid = await getCurrentFirmId();
      if (fid != null && fid.isNotEmpty) {
        // Carica team per assegnatario
        final profs = await _sb
            .from('profiles')
            .select('user_id, full_name')
            .eq('firm_id', fid)
            .order('full_name', ascending: true);
        final opts = (profs as List)
            .map((p) => _AssigneeOption(
                  id: '${p['user_id'] ?? ''}',
                  label: '${p['full_name'] ?? ''}',
                ))
            .where((o) => o.id.isNotEmpty)
            .toList();
        _assigneeOptions = opts;
      }
      if (widget.presetMatterId != null && widget.presetMatterId!.isNotEmpty) {
        _matterId = widget.presetMatterId;
        // Carica label della pratica e garantisci che compaia negli items
        final m = await _matterRepo.get(widget.presetMatterId!);
        if (m != null) {
          final label = _buildMatterLabel(m);
          final exists = _matterOptions.any((o) => o.id == m.matterId);
          if (!exists) {
            _matterOptions = [
              MatterOption(id: m.matterId, label: label),
              ..._matterOptions,
            ];
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _notesCtl.dispose();
    _matterDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchMatters(String q) async {
    try {
      final rows = await _matterRepo.list(
        search: q.isEmpty ? null : q,
        page: 1,
        pageSize: q.isEmpty ? 20 : 50,
      );
      final opts = rows
          .map((m) => MatterOption(id: m.matterId, label: _buildMatterLabel(m)))
          .toList();
      if (!mounted) return;
      setState(() => _matterOptions = opts);
    } catch (_) {}
  }

  void _onMatterQueryChanged(String q) {
    _matterDebounce?.cancel();
    _matterDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _searchMatters(q.trim());
    });
  }


  Future<void> _submit() async {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Titolo obbligatorio');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }
      final payload = {
        'firm_id': fid,
        'matter_id': _matterId,
        'title': title,
        'type': _type,
        // Mappiamo le date sullo schema reale: start_at e due_at (TIMESTAMP WITH TIME ZONE)
        'start_at': _startDate?.toIso8601String(),
        'due_at': _dueDate?.toIso8601String(),
        'priority': _priorityToInt(_priority),
        'assigned_to': _assigneeId,
        'notes': _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      };
      final created = await _sb
          .from('tasks')
          .insert(payload)
          .select('task_id, title, due_at, status, priority')
          .maybeSingle();
      if (!mounted) return;
      // Toast successo
      // ignore: use_build_context_synchronously
      AppToaster.of(context).success('Task creata');
      Navigator.of(context).pop(created);
    } catch (e) {
      // ignore: use_build_context_synchronously
      AppToaster.of(context).error('Errore creazione task: ${e.toString()}');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DefaultTokens>()!;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Nuova task'),
          description: AppDialogDescription(
            'Compila i dettagli per aggiungere un’attività alla agenda.',
          ),
        ),
        SizedBox(height: tokens.spacingUnit * 2),
        SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pratica'),
                SizedBox(height: tokens.spacingUnit * 0.5),
                AppCombobox(
                  width: double.infinity,
                  items: _matterOptions
                      .map((o) => ComboboxItem(value: o.id, label: o.label))
                      .toList(),
                  value: _matterId,
                  placeholder: 'Seleziona pratica…',
                  // La lista si adatta alla riga più lunga
                  popoverMatchWidestRow: true,
                  onQueryChanged: _onMatterQueryChanged,
                  onChanged: (value) {
                    setState(() => _matterId = value);
                  },
                ),
                SizedBox(height: tokens.spacingUnit * 2),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Titolo'),
                          SizedBox(height: tokens.spacingUnit * 0.5),
                          AppInput(controller: _titleCtl),
                        ],
                      ),
                    ),
                    SizedBox(width: tokens.spacingUnit * 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assegnatario'),
                          SizedBox(height: tokens.spacingUnit * 0.5),
                          AppSelect(
                            value: _assigneeId,
                            placeholder: 'Seleziona…',
                            width: double.infinity,
                            groups: [
                              SelectGroupData(
                                label: 'Assegnatario',
                                items: [
                                  const SelectItemData(value: '', label: '—'),
                                  ..._assigneeOptions.map((o) => SelectItemData(
                                        value: o.id,
                                        label: o.label.isEmpty ? o.id : o.label,
                                      )),
                                ],
                              ),
                            ],
                            onChanged: (v) => setState(
                                () => _assigneeId = v.isEmpty ? null : v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacingUnit * 2),
                Row(
                  children: [
                    // Dal
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dal'),
                          SizedBox(height: tokens.spacingUnit * 0.5),
                          AppDatePickerInput(
                            initialDate: _startDate,
                            firstDate: DateTime(2000, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                            onDateSubmitted: (d) => setState(() => _startDate = d),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: tokens.spacingUnit * 2),
                    // Al
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Al'),
                          SizedBox(height: tokens.spacingUnit * 0.5),
                          AppDatePickerInput(
                            initialDate: _dueDate,
                            firstDate: DateTime(2000, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                            onDateSubmitted: (d) => setState(() => _dueDate = d),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: tokens.spacingUnit * 2),
                    // Tipo
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipo'),
                          SizedBox(height: tokens.spacingUnit * 0.5),
                          AppSelect(
                            value: _type,
                            placeholder: 'Tipo',
                            width: double.infinity,
                            groups: const [
                              SelectGroupData(
                                label: 'Tipo',
                                items: [
                                  SelectItemData(value: 'onere', label: 'Onere'),
                                  SelectItemData(value: 'scrivere', label: 'Scrivere'),
                                ],
                              ),
                            ],
                            onChanged: (v) => setState(() => _type = v.isEmpty ? null : v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacingUnit * 2),
                // Priorità (spostata sotto per aggiungere Tipo)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Priorità'),
                          SizedBox(height: tokens.spacingUnit * 0.5),
                          AppSelect(
                            value: _priority,
                            placeholder: 'Priorità',
                            width: double.infinity,
                            groups: const [
                              SelectGroupData(
                                label: 'Priorità',
                                items: [
                                  SelectItemData(value: '', label: '—'),
                                  SelectItemData(value: 'low', label: 'Bassa'),
                                  SelectItemData(value: 'normal', label: 'Normale'),
                                  SelectItemData(value: 'high', label: 'Alta'),
                                ],
                              ),
                            ],
                            onChanged: (v) => setState(() => _priority = v.isEmpty ? null : v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacingUnit * 2),
                // Completata/Eseguito da rimossi per richiesta
                const Text('Note'),
                SizedBox(height: tokens.spacingUnit * 0.5),
                AppTextarea(
                  controller: _notesCtl,
                ),
                SizedBox(height: tokens.spacingUnit * 2),
                if (_error != null)
                  Alert(
                    variant: AlertVariant.destructive,
                    child: AlertDescription(Text(_error!)),
                  ),
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
              onPressed: _saving ? null : _submit,
              leading: Icon(AppIcons.save),
              child: _saving ? const Spinner(size: 18) : const Text('Crea task'),
            ),
          ],
        ),
      ],
    );
  }


  int? _priorityToInt(String? p) {
    if (p == null) return null; // 0=bassa, 1=normale, 2=alta
    switch (p) {
      case 'low':
        return 0;
      case 'normal':
        return 1;
      case 'high':
        return 2;
      default:
        return int.tryParse(p);
    }
  }

}

class MatterOption {
  final String id;
  final String label;
  const MatterOption({required this.id, required this.label});
  @override
  String toString() => label;
}

class _AssigneeOption {
  final String id;
  final String label;
  const _AssigneeOption({required this.id, required this.label});
}
