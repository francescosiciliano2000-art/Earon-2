// app_button.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart';
import '../theme/global_tokens.dart';

enum AppButtonVariant { default_, destructive, outline, secondary, ghost, link }

enum AppButtonSize { default_, sm, lg, icon, iconSm, iconLg }

/// Opzionale: token per colori "shadcn-like".
class AppButtonTokens {
  final Color primary;
  final Color onPrimary;
  final Color destructive;
  final Color onDestructive;
  final Color secondary;
  final Color onSecondary;
  final Color accentBg; // usato per hover di outline/ghost
  final Color accentFg;
  final Color background;
  final Color input; // per outline dark
  final Color border;
  final Color ring; // focus ring

  const AppButtonTokens({
    required this.primary,
    required this.onPrimary,
    required this.destructive,
    required this.onDestructive,
    required this.secondary,
    required this.onSecondary,
    required this.accentBg,
    required this.accentFg,
    required this.background,
    required this.input,
    required this.border,
    required this.ring,
  });

  /// Deriva dai Theme extensions (GlobalTokens + DefaultTokens) se presenti.
  factory AppButtonTokens.fromTheme(ThemeData theme) {
    final cs = theme.colorScheme;
    final gt = theme.extension<GlobalTokens>();
    final dt = theme.extension<DefaultTokens>();
    return AppButtonTokens(
      primary: gt?.primary ?? cs.primary,
      onPrimary: gt?.primaryForeground ?? cs.onPrimary,
      destructive: gt?.destructive ?? cs.error,
      onDestructive: gt?.destructiveForeground ?? cs.onError,
      // In shadcn, secondary è un neutro (bg-secondary), non il brand secondary.
      secondary: gt?.secondary ?? (cs.brightness == Brightness.dark ? cs.surface : cs.surfaceContainerHighest),
      onSecondary: gt?.secondaryForeground ?? cs.onSurface,
      accentBg: gt?.accent ?? cs.tertiary,
      accentFg: gt?.accentForeground ?? cs.onTertiary,
      background: gt?.background ?? cs.surface,
      input: gt?.input ?? cs.outlineVariant,
      border: gt?.border ?? cs.outline,
      ring: dt?.ring ?? gt?.ring ?? cs.primary,
    );
  }

  /// Fallback: derivazione solo da ColorScheme.
  factory AppButtonTokens.fromScheme(ColorScheme s) {
    final isDark = s.brightness == Brightness.dark;
    return AppButtonTokens(
      primary: s.primary,
      onPrimary: s.onPrimary,
      destructive: s.error,
      onDestructive: s.onError,
      secondary: isDark ? s.surface : s.surfaceContainerHighest,
      onSecondary: s.onSurface,
      accentBg: s.tertiary,
      accentFg: s.onTertiary,
      background: s.surface,
      input: s.outlineVariant,
      border: s.outline,
      ring: s.primary,
    );
  }
}

class AppButton extends StatefulWidget {
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool enabled;
  final bool isInvalid; // aria-invalid parity
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final String? label; // compat: consente AppButton(label: '...')
  final Widget? leading; // compat: AppButton(leading: Icon(...))
  final Widget? trailing; // compat: AppButton(trailing: Icon(...))
  final EdgeInsets? contentPadding;
  final BorderRadius? borderRadius;
  final AppButtonTokens? tokens;
  // Nuovo: forza forma circolare (rounded-full). Utile per bottoni "rounded" separati dagli icon.
  final bool circular;

  const AppButton({
    super.key,
    this.variant = AppButtonVariant.default_,
    this.size = AppButtonSize.default_,
    this.enabled = true,
    this.isInvalid = false,
    this.onPressed,
    this.onLongPress,
    this.child,
    this.label,
    this.leading,
    this.trailing,
    this.contentPadding,
    this.borderRadius,
    this.tokens,
    this.circular = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Preferisci i tokens dal Theme per allinearti a shadcn
    final t = widget.tokens ?? AppButtonTokens.fromTheme(theme);
    final radii = theme.extension<ShadcnRadii>();
    final tokens = theme.extension<DefaultTokens>();

    // Radius: default rounded-md (token radii.md)
    final bool isIconSize = widget.size == AppButtonSize.icon ||
        widget.size == AppButtonSize.iconSm ||
        widget.size == AppButtonSize.iconLg;

    final defaultRadius = radii?.md ?? BorderRadius.circular(8);
    final radius = widget.borderRadius ?? (widget.circular ? BorderRadius.circular(9999) : defaultRadius);

    // ---- Size map (Tailwind equivalenti) ----
    final metrics = _sizeMetrics(widget.size);

    // ---- Stato abilitato/disabled ----
    final enabled = widget.enabled && widget.onPressed != null;

    // ---- Style per variante ----
    final brightness = theme.brightness;
    final style = _variantStyle(
      variant: widget.variant,
      tokens: t,
      hovered: _hovered,
      pressed: _pressed,
      focused: _focused,
      isInvalid: widget.isInvalid,
      brightness: brightness,
    );

    // Opacità disabled come shadcn (opacity-50 + pointer-events-none)
    final effectiveOpacity = enabled ? 1.0 : 0.5;

    // Focus ring 3px (focus-visible:ring-[3px])
    final Color ringBase = widget.isInvalid
        ? t.destructive
        : (tokens?.ring ?? t.ring);
    final Color ringColor = widget.isInvalid
        ? ringBase.withValues(alpha: brightness == Brightness.dark ? 0.40 : 0.20)
        : ringBase.withValues(alpha: 0.50);
    final ringShadow = _focused
        ? [
            BoxShadow(
              color: ringColor,
              blurRadius: 0,
              spreadRadius: 3, // 3px ring
            ),
          ]
        : null;

    final padding = widget.contentPadding ??
        EdgeInsets.symmetric(horizontal: metrics.px, vertical: metrics.pyY != 0 ? metrics.pyY.toDouble() : 0);

    Widget content;
    if (widget.child != null) {
      content = widget.child!;
    } else {
      final children = <Widget>[];
      if (widget.leading != null) children.add(widget.leading!);
      if (widget.label != null) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 8));
        children.add(Text(widget.label!));
      }
      if (widget.trailing != null) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 8));
        children.add(widget.trailing!);
      }
      content = children.isEmpty
          ? const SizedBox.shrink()
          : Row(mainAxisSize: MainAxisSize.min, children: children);
    }

    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Opacity(
          opacity: effectiveOpacity,
          child: ConstrainedBox(
            constraints: isIconSize
                ? BoxConstraints.tightFor(height: metrics.h, width: metrics.h)
                : BoxConstraints(minHeight: metrics.h, minWidth: 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: radius,
                border: style.borderColor != null ? Border.all(color: style.borderColor!, width: 1) : null,
                boxShadow: [
                  if (ringShadow != null) ...ringShadow,
                  if (style.shadow != null) style.shadow!,
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onHighlightChanged: (v) => setState(() => _pressed = v),
                  onTap: enabled ? widget.onPressed : null,
                  onLongPress: enabled ? widget.onLongPress : null,
                  borderRadius: radius,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  child: Padding(
                    padding: isIconSize ? EdgeInsets.zero : padding,
                    child: DefaultTextStyle(
                      style: style.textStyle,
                      child: IconTheme(
                        data: IconThemeData(
                          size: (() {
                            // Mappa la dimensione dell'icona in base alla size del bottone
                            switch (widget.size) {
                              case AppButtonSize.iconSm:
                                return 14.0; // small
                              case AppButtonSize.icon:
                                return 16.0; // medium
                              case AppButtonSize.iconLg:
                                return 18.0; // large
                              default:
                                return 16.0; // default testo/icone
                            }
                          })(),
                          color: style.iconColor ?? style.textStyle.color,
                        ),
                        child: Center(child: content),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolvedStyle {
  final Color? bg;
  final Color? borderColor;
  final TextStyle textStyle;
  final Color? iconColor;
  final BoxShadow? shadow;

  const _ResolvedStyle({
    required this.bg,
    required this.borderColor,
    required this.textStyle,
    this.iconColor,
    this.shadow,
  });
}

class _SizeMetrics {
  final double h; // height
  final double px; // padding x
  final double pyX; // unused, reserved
  final double pyY; // padding y
  const _SizeMetrics(this.h, this.px, this.pyX, this.pyY);
}

_SizeMetrics _sizeMetrics(AppButtonSize size) {
  switch (size) {
    case AppButtonSize.sm: // h-8 px-3 gap-1.5
      return const _SizeMetrics(32, 12, 0, 6);
    case AppButtonSize.lg: // h-10 px-6
      return const _SizeMetrics(40, 24, 0, 8);
    case AppButtonSize.iconSm: // size-7 (ridotto)
      return const _SizeMetrics(28, 0, 0, 0);
    case AppButtonSize.icon: // size-8
      return const _SizeMetrics(32, 0, 0, 0);
    case AppButtonSize.iconLg: // size-9
      return const _SizeMetrics(36, 0, 0, 0);
    case AppButtonSize.default_: // h-9 px-4 py-2
      return const _SizeMetrics(36, 16, 8, 8);
  }
}

_ResolvedStyle _variantStyle({
  required AppButtonVariant variant,
  required AppButtonTokens tokens,
  required bool hovered,
  required bool pressed,
  required bool focused,
  required bool isInvalid,
  required Brightness brightness,
}) {
  // Tipografia: shadcn → text-sm font-medium
  // In Flutter: fontSize 14, weight 500.
  final baseText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

  Color? bg;
  Color? border;
  Color? icon;
  TextStyle text = baseText;
  BoxShadow? shadow;

  switch (variant) {
    case AppButtonVariant.default_:
      bg = tokens.primary;
      if (hovered) {
        // Parità con React: hover:bg-primary/90 → alpha 0.90
        bg = tokens.primary.withValues(alpha: 0.90);
      }
      text = baseText.copyWith(color: tokens.onPrimary);
      icon = tokens.onPrimary;
      // focus ring gestito fuori
      break;

    case AppButtonVariant.destructive:
      bg = brightness == Brightness.dark
          ? tokens.destructive.withValues(alpha: 0.60) // dark:bg-destructive/60
          : tokens.destructive;
      if (hovered) {
        // Parità con React: hover:bg-destructive/90 → alpha 0.90
        bg = tokens.destructive.withValues(alpha: 0.90);
      }
      text = baseText.copyWith(color: Colors.white); // shadcn usa text-white
      icon = Colors.white;
      break;

    case AppButtonVariant.outline:
      bg = brightness == Brightness.dark
          ? tokens.input.withValues(alpha: 0.30) // dark:bg-input/30
          : tokens.background;
      border = brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.15) // dark:border-white/15
          : tokens.border; // light:border (neutral-200)
      if (hovered) {
        bg = brightness == Brightness.dark
            ? tokens.input.withValues(alpha: 0.50) // dark:hover:bg-input/50
            : tokens.accentBg; // hover:bg-accent
        text = baseText.copyWith(color: tokens.accentFg); // hover:text-accent-foreground
        icon = tokens.accentFg;
      } else {
        text = baseText.copyWith(color: tokens.accentFg); // text-foreground at rest
        icon = tokens.accentFg;
      }
      // outline: niente shadow in shadcn
      shadow = null;
      break;

    case AppButtonVariant.secondary:
      // Parità con React: bg-secondary + text-secondary-foreground
      bg = tokens.secondary;
      if (hovered) {
        // hover:bg-secondary/80
        bg = tokens.secondary.withValues(alpha: 0.80);
      }
      text = baseText.copyWith(color: tokens.onSecondary);
      icon = tokens.onSecondary;
      break;

    case AppButtonVariant.ghost:
      bg = Colors.transparent;
      if (hovered) {
        bg = brightness == Brightness.dark
            ? tokens.input.withValues(alpha: 0.30) // dark:hover:bg-input/30
            : tokens.accentBg; // hover:bg-accent
      }
      text = baseText.copyWith(color: tokens.accentFg);
      icon = tokens.accentFg;
      break;

    case AppButtonVariant.link:
      bg = Colors.transparent;
      text = baseText.copyWith(
        color: tokens.primary,
        decoration: hovered ? TextDecoration.underline : TextDecoration.none,
        decorationColor: tokens.primary,
      );
      icon = tokens.primary;
      break;
  }

  return _ResolvedStyle(
    bg: bg,
    borderColor: border,
    textStyle: text,
    iconColor: icon,
    shadow: shadow,
  );
}
