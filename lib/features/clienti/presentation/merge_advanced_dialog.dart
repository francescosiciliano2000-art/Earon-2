// lib/features/clienti/presentation/merge_advanced_dialog.dart
import 'package:flutter/material.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/theme/themes.dart';

class MergeAdvancedResult {
  final String masterId;
  final List<String> duplicates;
  final Map<String, dynamic> patch; // valori finali scelti
  MergeAdvancedResult(this.masterId, this.duplicates, this.patch);
}

class MergeAdvancedDialog extends StatefulWidget {
  final Map<String, dynamic> master; // riga master
  final List<Map<String, dynamic>> duplicatesRows; // righe duplicate
  const MergeAdvancedDialog({
    super.key,
    required this.master,
    required this.duplicatesRows,
  });

  @override
  State<MergeAdvancedDialog> createState() => _MergeAdvancedDialogState();
}

class _MergeAdvancedDialogState extends State<MergeAdvancedDialog> {
  late String _masterId;
  late final List<String> _dupIds;

  // campi gestiti (aggiungi/rimuovi liberamente)
  final List<String> _fields = const [
    'name',
    'email',
    'phone',
    'address',
    'city',
    'zip',
    'country',
    'tax_code',
    'vat_number',
    'billing_notes'
  ];

  // scelta per ogni campo: value
  final Map<String, dynamic> _picked = {};

  // unione tag
  final Set<String> _tags = {};

  @override
  void initState() {
    super.initState();
    _masterId = widget.master['client_id'] as String;
    _dupIds = widget.duplicatesRows.map((e) => '${e['client_id']}').toList();

    // prepopolo scelte col master
    for (final f in _fields) {
      _picked[f] = widget.master[f];
    }
    // unione tag
    _tags.addAll(_toTags(widget.master['tags']));
    for (final r in widget.duplicatesRows) {
      _tags.addAll(_toTags(r['tags']));
    }
  }

  Set<String> _toTags(dynamic v) {
    if (v == null) return {};
    if (v is List) {
      return v
          .map((e) => '$e')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    if (v is String) {
      return v
          .split(RegExp(r'[;,]')) // separa su virgola o ;
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return {'$v'.trim()}.where((e) => e.isNotEmpty).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Unisci clienti (avanzato)'),
          description: AppDialogDescription(
            'Scegli i valori finali per ogni campo prima di completare l’unione.',
          ),
        ),
        SizedBox(height: spacing * 2),
        SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildMasterSelector(),
                SizedBox(height: spacing * 2),
                ..._fields.map(_buildFieldResolver),
                const Divider(),
                _buildTagsEditor(),
              ],
            ),
          ),
        ),
        AppDialogFooter(
          children: [
            AppButton(
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            AppButton(
              onPressed: () {
                final patch = {..._picked, 'tags': _tags.toList()};
                Navigator.pop(
                    context, MergeAdvancedResult(_masterId, _dupIds, patch));
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMasterSelector() {
    final candidates = [widget.master, ...widget.duplicatesRows];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cliente master', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0),
        Wrap(
          spacing: (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 2,
          children: candidates.map((r) {
            final id = '${r['client_id']}';
            final name = '${r['name'] ?? id}';
            return ChoiceChip(
              selected: _masterId == id,
              label: Text(name),
              onSelected: (_) => setState(() => _masterId = id),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFieldResolver(String field) {
    final candidates = <Map<String, dynamic>>[
      {'label': 'Master', 'value': widget.master[field]},
      ...widget.duplicatesRows.asMap().entries.map((e) => {
            'label': 'Dup #${e.key + 1}',
            'value': e.value[field],
          })
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(field, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: candidates.map((c) {
            final v = c['value'];
            final label = '${c['label']}: ${v ?? '—'}';
            final isSel = _picked[field] == v;
            return ChoiceChip(
               selected: isSel,
               label: Text(label),
               onSelected: (_) => setState(() => _picked[field] = v),
             );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tag uniti', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0),
        Wrap(
          spacing: Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0,
          runSpacing: Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0,
          children: _tags
              .map((t) => Chip(
                    label: Text(t),
                    onDeleted: () => setState(() => _tags.remove(t)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Aggiungi tag (Invio per confermare)',
          ),
          onSubmitted: (txt) {
            final parts = txt
                .split(RegExp(r'[;,]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty);
            setState(() => _tags.addAll(parts));
          },
        ),
      ],
    );
  }
}
