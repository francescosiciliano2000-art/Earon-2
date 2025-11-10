// lib/components/alert.dart
import 'package:flutter/material.dart';
import '../theme/typography.dart';

/// Varianti supportate come in shadcn/ui
enum AlertVariant { defaultStyle, destructive }

/// Contenitore principale dell'Alert (equivalente a `Alert` di shadcn)
/// - Mantiene: rounded-lg, border, px-4 py-3, text-sm
/// - Layout: se è presente [leading] (icona), allinea come grid has-[>svg]
class Alert extends StatelessWidget {
  const Alert({
    super.key,
    this.leading,
    this.variant = AlertVariant.defaultStyle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ), // px-4 py-3
    this.radius = 12, // rounded-lg
    this.gap = 12, // has-[>svg]:gap-x-3
    required this.child,
  });

  final Widget? leading;
  final AlertVariant variant;
  final EdgeInsets padding;
  final double radius;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // shadcn: bg-card / text-card-foreground
    final bg = scheme.inversePrimary; // bg-card (light: neutral-50, dark: neutral-900)
    final fg = scheme.onSurface;      // text-card-foreground

    // Bordo token coerente con shadcn (--border)
    final borderColor = scheme.outline;

    // Variant styles (shadcn 'destructive' colora contenuto + icona + description)
    final isDestructive = variant == AlertVariant.destructive;
    final destructiveColor = scheme.error;

    final baseTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isDestructive ? destructiveColor : fg,
      // niente override di height qui per allineare ai default di React
    );

    final content = DefaultTextStyle(
      style: baseTextStyle ?? const TextStyle(fontSize: 12),
      child: IconTheme(
        data: IconThemeData(
          size: 16, // [&>svg]:size-4
          color: isDestructive ? destructiveColor : fg, // [&>svg]:text-current
        ),
        child: child,
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      // aria role="alert"
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        padding: padding,
        // has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] → leading 16px + gap 12px
        child: leading == null
            ? content
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, 2), // translate-y-0.5 (~2px)
                        child: IconTheme(
                          data: IconThemeData(
                            size: 16,
                            color: isDestructive ? destructiveColor : fg,
                          ),
                          child: leading!,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  // Colonna contenuti (title + description)
                  Expanded(child: content),
                ],
              ),
      ),
    );
  }
}

/// Titolo dell'alert (equivalente a `AlertTitle`)
/// - Mantiene: font-medium, tracking-tight, line-clamp-1, min-h-4
class AlertTitle extends StatelessWidget {
  const AlertTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final bt = Theme.of(context).textTheme.bodySmall; // text-sm (14px)
    final ty = Theme.of(context).extension<ShadcnTypography>() ?? ShadcnTypography.defaults();
    final fs = bt?.fontSize ?? ty.textSm;

    final style = TextStyle(
      fontSize: fs,
      fontWeight: FontWeight.w600, // font-medium
      // tracking-tight
      letterSpacing: ty.letterSpacingPx(fontSize: fs, em: ty.trackingTightEm),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 16), // min-h-4
      child: Text(
        text,
        maxLines: 1, // line-clamp-1
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// Descrizione dell’alert (equivalente a `AlertDescription`)
/// - Mantiene: text-muted-foreground, gap-1, text-sm, [&_p]:leading-relaxed
/// - In variante 'destructive' il testo assume ~90% dell'error (come shadcn)
class AlertDescription extends StatelessWidget {
  const AlertDescription(
    this.child, {
    super.key,
    this.isDestructive = false,
    this.verticalGap = 2, // gap-0.5 → 2px tra titolo e descrizione
  });

  final Widget child;
  final bool isDestructive;
  final double verticalGap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ty = Theme.of(context).extension<ShadcnTypography>() ?? ShadcnTypography.defaults();

    final muted = scheme.onSurface.withValues(alpha: 0.65); // text-muted-foreground
    final destructiveMuted = scheme.error.withValues(alpha: 0.90);

    // Propaga automaticamente la variante destructive se il contenitore ha DefaultTextStyle con color=error
    final inherited = DefaultTextStyle.of(context).style;
    final destructiveContext = inherited.color == scheme.error;
    final isDestructiveEffective = isDestructive || destructiveContext;

    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isDestructiveEffective ? destructiveMuted : muted,
      height: ty.leadingRelaxed, // leading-relaxed (1.625)
    );

    // Permette sia testo semplice che alberi con paragrafi analoghi
    return DefaultTextStyle.merge(
      style: style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // spacing iniziale coerente con grid gap-y-0.5 → 2px
          SizedBox(height: verticalGap),
          child,
        ],
      ),
    );
  }
}
