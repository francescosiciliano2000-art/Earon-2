// lib/components/breadcrumb.dart
import 'package:flutter/material.dart';
import '../theme/typography.dart';

class AppBreadcrumbItemData {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const AppBreadcrumbItemData({
    required this.label,
    this.onTap,
    this.enabled = true,
  });
}

/// AppBreadcrumb — percorso con separatori, allineato allo stile shadcn
class AppBreadcrumb extends StatelessWidget {
  const AppBreadcrumb({
    super.key,
    required this.items,
    this.currentIndex,
    this.separator = '/',
    this.gap = 8.0, // gap-2
    this.overflow = AxisDirection.right, // scroll orizzontale a destra di default
  });

  final List<AppBreadcrumbItemData> items;
  final int? currentIndex; // se non specificato, ultimo item come current
  final String separator;
  final double gap;
  final AxisDirection overflow;

  @override
  Widget build(BuildContext context) {
    final ty = Theme.of(context).extension<ShadcnTypography>() ?? ShadcnTypography.defaults();
    final cs = Theme.of(context).colorScheme;

    final idxCurrent = currentIndex ?? (items.isEmpty ? null : items.length - 1);

    // Colori: default mutato, current in foreground
    final Color baseColor = cs.onSurface.withValues(alpha: 0.65);
    final Color hoverColor = cs.onSurface;

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final isCurrent = idxCurrent == i;
      children.add(_Crumb(
        label: it.label,
        enabled: it.enabled && !isCurrent && it.onTap != null,
        isCurrent: isCurrent,
        onTap: it.onTap,
        baseColor: baseColor,
        hoverColor: hoverColor,
        fontSize: ty.textSm,
      ));
      if (i < items.length - 1) {
        children.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: gap / 2),
          child: Text(separator, style: TextStyle(color: baseColor, fontSize: ty.textSm)),
        ));
      }
    }

    final row = Row(mainAxisSize: MainAxisSize.min, children: children);

    // Gestione overflow: scroll orizzontale opzionale
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: overflow == AxisDirection.left,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

class _Crumb extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool isCurrent;
  final VoidCallback? onTap;
  final double fontSize;
  final Color baseColor;
  final Color hoverColor;

  const _Crumb({
    required this.label,
    required this.enabled,
    required this.isCurrent,
    required this.onTap,
    required this.fontSize,
    required this.baseColor,
    required this.hoverColor,
  });

  @override
  State<_Crumb> createState() => _CrumbState();
}

class _CrumbState extends State<_Crumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isCurrent
        ? Theme.of(context).colorScheme.onSurface
        : (_hovered && widget.enabled ? widget.hoverColor : widget.baseColor);

    final text = Text(
      widget.label,
      style: TextStyle(
        color: color,
        fontSize: widget.fontSize,
        fontWeight: widget.isCurrent ? FontWeight.w500 : FontWeight.w400,
        height: 1.25,
      ),
    );

    final content = widget.enabled
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: text),
          )
        : Opacity(opacity: widget.isCurrent ? 1.0 : 0.65, child: text);

    return content;
  }
}