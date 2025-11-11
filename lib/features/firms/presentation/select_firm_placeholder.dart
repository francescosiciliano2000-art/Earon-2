import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/button.dart';

/// Placeholder mostrato quando nessuno studio (firm) è selezionato.
/// Offre una CTA per aprire la pagina di selezione studio.
class SelectFirmPlaceholder extends StatelessWidget {
  const SelectFirmPlaceholder({super.key});

  double _su(BuildContext context) =>
      (Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0);

  @override
  Widget build(BuildContext context) {
    final su = _su(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(su * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.buildingOffice, size: 48, color: cs.outline),
            SizedBox(height: su * 2),
            const Text('Seleziona uno studio per continuare'),
            SizedBox(height: su * 2),
            AppButton(
              variant: AppButtonVariant.default_,
              leading: const Icon(AppIcons.chevronRight),
              label: 'Seleziona studio',
              onPressed: () {
                if (context.mounted) context.go('/auth/select_firm');
              },
            ),
          ],
        ),
      ),
    );
  }
}