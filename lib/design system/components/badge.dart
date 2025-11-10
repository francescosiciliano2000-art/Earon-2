// lib/components/badge.dart
import 'package:flutter/material.dart';
import '../theme/theme_builder.dart';
import '../theme/typography.dart';

enum AppBadgeVariant { default_, secondary, destructive, outline }

/// AppBadge — porting di `Badge` shadcn/ui
/// - rounded-md, border, px-2.5 py-0.5, text-xs, font-semibold
/// - Varianti: default, secondary, destructive, outline
/// - Ora supporta [leading] (icona opzionale) e [gap] (spazio icona-testo)
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    this.variant = AppBadgeVariant.default_,
    this.label,
    this.child,
    this.leading,
    this.gap = 6,
    this.padding = const EdgeInsets.symmetric(
        horizontal: 10, vertical: 2), // px-2.5 py-0.5
    this.borderRadius =
        const BorderRadius.all(Radius.circular(6)), // rounded-md
  });

  final AppBadgeVariant variant;
  final String? label;
  final Widget? child;

  /// Icona opzionale da mostrare prima del testo.
  final Widget? leading;

  /// Spazio tra icona e testo.
  final double gap;

  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ty = Theme.of(context).extension<ShadcnTypography>() ??
        ShadcnTypography.defaults();

    Color bg;
    Color fg;
    Color? border;

    switch (variant) {
      case AppBadgeVariant.default_:
        bg = t.primary;
        fg = t.primaryForeground;
        border = Colors.transparent;
        break;
      case AppBadgeVariant.secondary:
        bg = t.secondary;
        fg = t.secondaryForeground;
        border = Colors.transparent;
        break;
      case AppBadgeVariant.destructive:
        bg = t.destructive;
        fg = t.destructiveForeground;
        border = Colors.transparent;
        break;
      case AppBadgeVariant.outline:
        bg = Colors.transparent;
        fg = Theme.of(context).colorScheme.onSurface;
        border = t.border;
        break;
    }

    // --- Contenuto badge ---
    final baseTextStyle = TextStyle(
      fontSize: ty.textXs, // text-xs
      fontWeight: FontWeight.w600, // font-semibold
      color: fg,
      height: 1.2,
    );

    final content = DefaultTextStyle(
      style: baseTextStyle,
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(size: 12, color: fg),
                  child: leading!,
                ),
                SizedBox(width: gap),
              ],
              Flexible(
                child: Text(
                  label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: Border.all(color: border, width: 1),
      ),
      child: Padding(padding: padding, child: content),
    );
  }
}
