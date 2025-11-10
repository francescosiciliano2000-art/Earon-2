// lib/features/clienti/presentation/merge_dialog.dart
import 'package:flutter/material.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/list_tile.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/theme/themes.dart';

class MergeDialog extends StatefulWidget {
  final List<String> clientIds;
  final List<Map<String, dynamic>> rows; // lista corrente per mostrare nomi
  const MergeDialog({super.key, required this.clientIds, required this.rows});

  @override
  State<MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<MergeDialog> {
  String? _masterId;

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Unisci clienti'),
          description: AppDialogDescription(
            'Scegli il cliente master. Gli altri verranno uniti e rimossi.',
          ),
        ),
        SizedBox(height: spacing * 2),
        SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.clientIds.map((id) {
                final row = widget.rows.firstWhere(
                  (r) => r['client_id'] == id,
                  orElse: () => {'name': id},
                );
                final name = row['name'] ?? id;
                final selected = _masterId == id;

                return AppListTile(
                  onTap: () => setState(() => _masterId = id),
                  leading: Icon(
                    selected
                        ? AppIcons.radioChecked
                        : AppIcons.radioUnchecked,
                  ),
                  title: Text(name),
                  subtitle: Text(id),
                );
              }),
            ],
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
              onPressed: _masterId == null
                  ? null
                  : () => Navigator.pop(context, _masterId),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ],
    );
  }
}
