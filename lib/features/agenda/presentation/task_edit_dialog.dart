// lib/features/agenda/presentation/task_edit_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/search_select.dart';
import '../../../design system/components/textarea.dart';
// import '../../../design system/components/switch.dart';
import 'package:gestionale_desktop/components/date_picker.dart';
import '../../../design system/components/alert.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'package:gestionale_desktop/features/matters/data/matter_repo.dart';
import 'package:gestionale_desktop/features/matters/data/matter_model.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/icons/app_icons.dart';

class TaskEditDialog extends StatefulWidget {
  final String taskId;
  const TaskEditDialog({super.key, required this.taskId});

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  late final SupabaseClient _sb;
  late final MatterRepo _matterRepo;

  // Form controllers
  final _titleCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  // final _performedByCtl = TextEditingController();

  // Matter autocomplete
  final _matterCtl = TextEditingController();
  String? _matterId;
  List<_MatterOption> _matterOptions = const [];
  Timer? _matterDebounce;

  // Team (assignee)
  List<_AssigneeOption> _assigneeOptions = const [];
  String? _assigneeId;

  // Optional fields
  DateTime? _dueDate;
  DateTime? _startDate;
  String? _priority;
  // Nuovo campo tipo (onere/scrivere)
  String? _type;
  // bool _done = false;
  // bool _originalDone = false;
  // DateTime? _doneAt;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _matterRepo = MatterRepo(_sb);
    _bootstrap();
    // Precarica le prime 20 pratiche per evitare overlay vuoto all'apertura
    scheduleMicrotask(() => _onMatterTextChanged());
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
    _titleCtl.dispose();
    _notesCtl.dispose();
    // _performedByCtl.dispose();
    _matterCtl.dispose();
    _matterDebounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // Team
      final fid = await getCurrentFirmId();
      if (fid != null && fid.isNotEmpty) {
        final profs = await _sb
            .from('profiles')
            .select('user_id, full_name')
            .eq('firm_id', fid)
            .order('full_name', ascending: true);
        _assigneeOptions = (profs as List)
            .map((p) => _AssigneeOption(
                  id: '${p['user_id'] ?? ''}',
                  label: '${p['full_name'] ?? ''}',
                ))
            .where((o) => o.id.isNotEmpty)
            .toList();
      }
      // Task data
      final row = await _sb
          .from('tasks')
          .select('task_id, title, due_at, start_at, priority, assigned_to, matter_id, notes, type')
          .eq('task_id', widget.taskId)
          .maybeSingle();
      if (row == null) {
        setState(() {
          _error = 'Task non trovata';
          _loading = false;
        });
        return;
      }
      _titleCtl.text = '${row['title'] ?? ''}';
      final due = row['due_at'];
      if (due != null && due.toString().isNotEmpty) {
        _dueDate = DateTime.tryParse(due.toString());
      }
      final start = row['start_at'];
      if (start != null && start.toString().isNotEmpty) {
        _startDate = DateTime.tryParse(start.toString());
      }
      _priority = _priorityCanonical(row['priority']);
      _assigneeId = row['assigned_to']?.toString();
      _matterId = row['matter_id']?.toString();
      _notesCtl.text = '${row['notes'] ?? ''}';
      _type = row['type']?.toString();
      // Matter label
      if (_matterId != null && _matterId!.isNotEmpty) {
        final m = await _matterRepo.get(_matterId!);
        if (m != null) {
          _matterCtl.text = _buildMatterLabel(m);
        }
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _searchMatters(String q) async {
    try {
      final rows = await _matterRepo.list(
        search: q.isEmpty ? null : q,
        page: 1,
        pageSize: q.isEmpty ? 20 : 50,
      );
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
      await _searchMatters(text);
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
      final payload = {
        'matter_id': _matterId,
        'title': title,
        // Mappiamo le date sullo schema reale: start_at e due_at (TIMESTAMP WITH TIME ZONE)
        'start_at': _startDate?.toIso8601String(),
        'due_at': _dueDate?.toIso8601String(),
        'type': _type,
        'priority': _priorityToInt(_priority),
        'assigned_to': _assigneeId,
        'notes': _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      };
      final updated = await _sb
          .from('tasks')
          .update(payload)
          .eq('task_id', widget.taskId)
          .select('task_id, title, due_at, status, priority')
          .maybeSingle();
      if (!mounted) return;
      AppToaster.of(context).success('Task aggiornata');
      Navigator.of(context).pop(updated);
    } catch (e) {
      AppToaster.of(context).error('Errore aggiornamento task: ${e.toString()}');
      setState(() => _error = e.toString());
     } finally {
       setState(() => _saving = false);
     }
   }

  @override
  Widget build(BuildContext context) {
    final dt = Theme.of(context).extension<DefaultTokens>();
    final spacing = dt?.spacingUnit ?? 8.0;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Modifica task'),
          description: AppDialogDescription(
            'Aggiorna i dettagli dell’attività selezionata.',
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
                      AppSearchSelect(
                        width: double.infinity,
                        controller: _matterCtl,
                        placeholder: 'Cerca pratica…',
                        groups: [
                          SelectGroupData(
                            label: 'Pratiche',
                            items: _matterOptions
                                .map((o) => SelectItemData(
                                      value: o.id,
                                      label: o.label,
                                    ))
                                .toList(),
                          ),
                        ],
                        onQueryChanged: (q) {
                          _matterCtl.value = TextEditingValue(
                            text: q,
                            selection: TextSelection.collapsed(offset: q.length),
                          );
                          _onMatterTextChanged();
                        },
                        onChanged: (value) {
                          final opt = _matterOptions.firstWhere(
                            (o) => o.id == value,
                            orElse: () => _MatterOption(id: value, label: value),
                          );
                          setState(() {
                            _matterId = opt.id;
                            _matterCtl.text = opt.label;
                          });
                        },
                      ),
                      SizedBox(height: spacing * 2),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Titolo'),
                                SizedBox(height: spacing * 0.5),
                                AppInput(controller: _titleCtl),
                              ],
                            ),
                          ),
                          SizedBox(width: spacing * 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Assegnatario'),
                                SizedBox(height: spacing * 0.5),
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
                                  onChanged: (v) => setState(() => _assigneeId = v.isEmpty ? null : v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing * 2),
                      Row(
                        children: [
                          // Dal
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Dal'),
                                SizedBox(height: spacing * 0.5),
                                AppDatePickerInput(
                                  initialDate: _startDate,
                                  firstDate: DateTime(2000, 1, 1),
                                  lastDate: DateTime(2100, 12, 31),
                                  onDateSubmitted: (d) => setState(() => _startDate = d),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: spacing * 2),
                          // Al
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Al'),
                                SizedBox(height: spacing * 0.5),
                                AppDatePickerInput(
                                  initialDate: _dueDate,
                                  firstDate: DateTime(2000, 1, 1),
                                  lastDate: DateTime(2100, 12, 31),
                                  onDateSubmitted: (d) => setState(() => _dueDate = d),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: spacing * 2),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tipo'),
                                SizedBox(height: spacing * 0.5),
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
                      SizedBox(height: spacing * 2),
                      // Priorità (spostata sotto per aggiungere Tipo)
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Priorità'),
                                SizedBox(height: spacing * 0.5),
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
                      const Text('Note'),
                      SizedBox(height: spacing * 0.5),
                      AppTextarea(controller: _notesCtl),
                      if (_error != null) ...[
                        SizedBox(height: spacing * 2),
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
              variant: AppButtonVariant.default_,
              onPressed: _saving || _loading ? null : _submit,
              leading: const Icon(AppIcons.save),
              child: _saving ? Spinner(size: 18) : const Text('Salva'),
            ),
          ],
        ),
      ],
    );
  }


  String? _priorityCanonical(dynamic p) {
    if (p == null) return null;
    final s = p.toString().trim().toLowerCase();
    if (s.isEmpty || s == 'null' || s == '-') return null;
    if (s == '0' || s == 'low' || s == 'bassa') return 'low';
    if (s == '1' || s == 'normal' || s == 'normale' || s == 'medium' || s == 'medio') return 'normal';
    if (s == '2' || s == 'high' || s == 'alta') return 'high';
    return null;
  }

  int? _priorityToInt(String? p) {
    if (p == null) return null;
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

class _MatterOption {
  final String id;
  final String label;
  const _MatterOption({required this.id, required this.label});
  @override
  String toString() => label;
}

class _AssigneeOption {
  final String id;
  final String label;
  const _AssigneeOption({required this.id, required this.label});
}
// Sposto il pannello suggerimenti all’interno della classe di stato
