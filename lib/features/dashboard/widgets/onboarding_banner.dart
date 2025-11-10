import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../design system/icons/app_icons.dart';
// Design System
import '../../../design system/components/button.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/components/card.dart';
import '../../../design system/components/list_tile.dart';

class OnboardingBanner extends StatelessWidget {
  final bool show;
  const OnboardingBanner({super.key, required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.all((Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 2),
      child: AppCard(
        content: AppCardContent(
          child: AppListTile(
            leading: const Icon(AppIcons.flag),
            title: const Text('Completa l’onboarding per evitare errori fiscali'),
            subtitle: const Text('Manca qualcosa nella checklist iniziale'),
            trailing: AppButton(
              variant: AppButtonVariant.default_,
              onPressed: () => context.go('/onboarding/checklist'),
              child: const Text('Apri checklist'),
            ),
          ),
        ),
      ),
    );
  }
}
