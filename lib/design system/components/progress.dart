import 'package:flutter/material.dart';

import '../theme/themes.dart';

/// Linear progress indicator aligned with the design system tokens.
class AppProgressBar extends StatelessWidget {
  final double? value;
  final double minHeight;

  const AppProgressBar({super.key, this.value, this.minHeight = 4});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<ShadcnRadii>();
    final cs = theme.colorScheme;

    return ClipRRect(
      borderRadius: radii?.sm ?? BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value,
        minHeight: minHeight,
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        color: cs.primary,
      ),
    );
  }
}
