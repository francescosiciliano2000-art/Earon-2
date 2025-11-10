import 'package:flutter/material.dart';
import '../theme/themes.dart';

/// List item coerente con il design system (equivalente a Material ListTile).
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.dense,
    this.contentPadding,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>();
    final spacing = tokens?.spacingUnit ?? 8.0;
    final radius = radii?.md ?? BorderRadius.circular(8);
    final padding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: spacing * 2,
          vertical: (dense ?? false) ? spacing * 0.75 : spacing,
        );
    final foreground = theme.colorScheme.onSurface;
    final muted = foreground.withValues(alpha: 0.65);

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
        ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: foreground,
        );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
          color: muted,
          height: 1.2,
        ) ??
        TextStyle(
          fontSize: 12,
          color: muted,
        );

    final children = <Widget>[];

    if (leading != null) {
      children.add(Padding(
        padding: EdgeInsets.only(right: spacing * 1.5),
        child: IconTheme.merge(
          data: const IconThemeData(size: 20),
          child: leading!,
        ),
      ));
    }

    final columnChildren = <Widget>[];
    if (title != null) {
      columnChildren.add(DefaultTextStyle(
        style: titleStyle,
        child: title!,
      ));
    }
    if (subtitle != null) {
      columnChildren.add(SizedBox(height: spacing * 0.5));
      columnChildren.add(DefaultTextStyle(
        style: subtitleStyle,
        child: subtitle!,
      ));
    }

    children.add(Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: columnChildren,
      ),
    ));

    if (trailing != null) {
      children.add(Padding(
        padding: EdgeInsets.only(left: spacing * 1.5),
        child: trailing!,
      ));
    }

    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
      ),
      child: Row(
        crossAxisAlignment:
            subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: children,
      ),
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: MouseRegion(
        cursor: (enabled && (onTap != null || onLongPress != null))
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: body,
          ),
        ),
      ),
    );
  }
}
