import 'package:flutter/material.dart';
import '../../theme/themes.dart';
import '../../theme/global_tokens.dart';

/// Contenitore per grafici (integrazione futura charts_lite)
class ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const ChartContainer(
      {super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gt = theme.extension<GlobalTokens>();
    final dt = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(dt?.spacingUnit ?? 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: dt?.spacingUnit ?? 16.0),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: gt?.muted ?? theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular((radii?.sm ?? 8.0) as double),
                  border: Border.all(color: gt?.border ?? theme.colorScheme.outline),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
