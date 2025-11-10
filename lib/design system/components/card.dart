// app_card.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // per ShadcnRadii / DefaultTokens
import '../theme/typography.dart';

/// AppCard replica visivamente lo shadcn `Card`
/// bg-card, text-card-foreground, rounded-xl, border, py-6, shadow-sm, gap-6
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
    this.gap = 24.0, // gap-6
    this.border = true,
    this.elevated = true, // shadow-sm
    this.decoration,
  });

  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  final double gap;
  final bool border;
  final bool elevated;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radii =
        theme.extension<ShadcnRadii>() ??
        ShadcnRadii(xs: BorderRadius.circular(4), sm: BorderRadius.circular(6), md: BorderRadius.circular(8), lg: BorderRadius.circular(12), xl: BorderRadius.circular(16));
    final base =
        decoration ??
        BoxDecoration(
          color: cs.inversePrimary, // bg-card: light=neutral-50, dark=neutral-900
          // rounded-xl (Tailwind = 12px) → radii.lg
          borderRadius: radii.lg,
          border: border
              ? Border.all(color: cs.outline) // border (token --border)
              : null,
          boxShadow: elevated
              ? const [
                  // shadow-sm → 0 1px 2px rgba(0,0,0,0.05)
                  BoxShadow(
                    color: Color(0x0D000000), // 5% black
                    blurRadius: 2,
                    spreadRadius: 0,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [],
        );

    // Costruiamo le sezioni con gap-6 verticale tra i blocchi
    final sections = <Widget>[
      if (header != null) header!,
      if (content != null) content!,
      if (footer != null) footer!,
    ];

    Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withGaps(sections, gap),
    );

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium!.copyWith(
        color: cs.onSurface, // text-card-foreground
      ),
      child: Container(
        decoration: base,
        padding: padding, // py-6 (gli slot aggiungono px-6 dove serve)
        child: column,
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> children, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(SizedBox(height: gap));
      }
    }
    return out;
  }
}

/// Header: grid 2 righe (title/description), opzionale colonna azione a destra.
/// px-6, gap-2; se ha bordo inferiore, aggiunge pb-6 come in shadcn.
class AppCardHeader extends StatelessWidget {
  const AppCardHeader({
    super.key,
    this.title,
    this.description,
    this.action,
    this.showBottomBorder = false,
  });

  final Widget? title;
  final Widget? description;
  final Widget? action;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contentCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) title!,
        if (description != null) ...[
          const SizedBox(height: 8), // gap-2
          description!,
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        border: showBottomBorder ? Border(bottom: BorderSide(color: cs.outline)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24), // px-6
      child: Padding(
        padding: EdgeInsets.only(bottom: showBottomBorder ? 24 : 0), // [.border-b]:pb-6
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: contentCol),
            if (action != null) ...[
              const SizedBox(width: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Title: font-semibold, leading-none
class AppCardTitle extends StatelessWidget {
  const AppCardTitle(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Non forziamo una size specifica (come in React): eredita dal contesto
    final base = DefaultTextStyle.of(context).style;
    return DefaultTextStyle.merge(
      style: base.copyWith(
        fontWeight: FontWeight.w600, // font-semibold
        height: 1.0, // leading-none
      ),
      child: child,
    );
  }
}

/// Description: text-sm, text-muted-foreground
class AppCardDescription extends StatelessWidget {
  const AppCardDescription(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.extension<ShadcnTypography>();
    return DefaultTextStyle.merge(
      style: DefaultTextStyle.of(context).style.copyWith(
        fontSize: tt?.textSm ?? 14, // text-sm
        color: cs.onSurface.withValues(alpha: 0.70), // text-muted-foreground
      ),
      child: child,
    );
  }
}

/// Action: wrapper utile se si vuole comporre fuori da AppCardHeader(action:)
class AppCardAction extends StatelessWidget {
  const AppCardAction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(alignment: Alignment.topRight, child: child);
  }
}

/// Content: px-6
class AppCardContent extends StatelessWidget {
  const AppCardContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // px-6
      child: child,
    );
  }
}

/// Footer: flex, items-center, px-6; opzionale top border con pt-6 come in shadcn.
class AppCardFooter extends StatelessWidget {
  const AppCardFooter({
    super.key,
    required this.child,
    this.showTopBorder = false,
  });

  final Widget child;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // px-6
      child: Align(alignment: Alignment.centerLeft, child: child),
    );

    if (!showTopBorder) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: cs.outline),
        const SizedBox(height: 24), // [.border-t]: pt-6
        row,
      ],
    );
  }
}
