// lib/components/separator.dart
import 'package:flutter/material.dart';
import '../theme/theme_builder.dart';

/// AppSeparator — equivalente del componente `Separator` di shadcn/ui
/// - Usa i GlobalTokens per il colore di bordo (tokens.border)
/// - Spessore di default 1px
/// - Supporta orientamento orizzontale/verticale e margine opzionale
class AppSeparator extends StatelessWidget {
  const AppSeparator({
    super.key,
    this.orientation = Axis.horizontal,
    this.thickness = 1.0,
    this.color,
    this.margin,
  });

  final Axis orientation;
  final double thickness;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.border;

    final bar = DecoratedBox(
      decoration: BoxDecoration(color: c),
      child: const SizedBox.shrink(),
    );

    final sized = orientation == Axis.horizontal
        ? SizedBox(height: thickness, width: double.infinity, child: bar)
        : SizedBox(width: thickness, height: double.infinity, child: bar);

    return Container(margin: margin, child: sized);
  }
}