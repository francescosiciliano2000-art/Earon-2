import 'package:flutter/material.dart';
import '../theme/theme_builder.dart';
import '../theme/themes.dart';
import 'input_group.dart';
import '../../../core/responsive.dart';
import '../icons/app_icons.dart';
import './topbar_styles.dart';

/// TopBar minimal: search, actions, user menu, notifications.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueChanged<String>? onSearch;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? userMenu;
  final bool showNotifications;
  final PreferredSizeWidget? bottom;

  const TopBar({
    super.key,
    this.onSearch,
    this.actions = const [],
    this.leading,
    this.userMenu,
    this.showNotifications = false,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gt = context.tokens;
    final dt = theme.extension<DefaultTokens>();
    final isMobile = isDisplayMobile(context);
    final spacing = dt?.spacingUnit ?? 8.0;

    return AppBar
(
      backgroundColor: gt.background,
      elevation: 0,
      titleSpacing: 0,
      shape: Border(bottom: BorderSide(color: gt.border, width: 1)),
      bottom: bottom,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing * 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: Theme.of(context)
                          .extension<AppTopBarStyles>()
                          ?.leadingIconSize ??
                      20,
                ),
                child: leading!,
              ),
              SizedBox(width: spacing * 2),
            ],
            if (onSearch != null) ...[
              if (isMobile) ...[
                IconButton(
                  tooltip: 'Cerca',
                  icon: const Icon(AppIcons.search),
                  onPressed: () => onSearch?.call(''),
                ),
                const Spacer(),
              ] else ...[
                Expanded(
                  child: AppInputGroup(
                    hintText: 'Cerca…',
                    leading: const Icon(AppIcons.search),
                    onSubmitted: onSearch,
                  ),
                ),
              ],
            ] else ...[
              const Spacer(),
            ],
            SizedBox(width: spacing * 2),
            if (showNotifications)
              IconButton(
                tooltip: 'Notifiche',
                onPressed: () {},
                icon: const Icon(AppIcons.notifications),
              ),
            ...actions,
            SizedBox(width: spacing * 0.5),
            userMenu ?? const _DefaultUserMenu(),
          ],
        ),
      ),
    );
  }
}

class _DefaultUserMenu extends StatelessWidget {
  const _DefaultUserMenu();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rr = theme.extension<ShadcnRadii>();
    final dt = theme.extension<DefaultTokens>();
    final isMobile = isDisplayMobile(context);
    final spacing = dt?.spacingUnit ?? 8.0;
    final gt = context.tokens;
    return Chip(
      shape: RoundedRectangleBorder(
        borderRadius: rr?.sm ?? BorderRadius.circular(6),
        side: BorderSide(color: gt.border),
      ),
      labelPadding: EdgeInsets.symmetric(horizontal: spacing * 1.5),
      avatar: const CircleAvatar(radius: 12, child: Icon(AppIcons.person, size: 16)),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMobile) ...[
            Text('Utente', style: theme.textTheme.labelLarge),
            SizedBox(width: spacing * 1.5),
          ],
          const Icon(AppIcons.expandMore),
        ],
      ),
    );
  }
}
