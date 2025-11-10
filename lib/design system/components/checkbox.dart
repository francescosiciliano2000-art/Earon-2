// lib/components/checkbox.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // per DefaultTokens (ring)

class AppCheckboxTokens {
  final Color primary;
  final Color onPrimary;
  final Color border;
  final Color inputBg; // usato in dark come bg-input/30
  final Color destructive;
  final Color ring;

  const AppCheckboxTokens({
    required this.primary,
    required this.onPrimary,
    required this.border,
    required this.inputBg,
    required this.destructive,
    required this.ring,
  });

  factory AppCheckboxTokens.fromTheme(ThemeData t) {
    final cs = t.colorScheme;
    final tokens = t.extension<DefaultTokens>();
    return AppCheckboxTokens(
      primary: cs.primary,
      onPrimary: cs.onPrimary,
      border: cs.outlineVariant,
      inputBg: cs.surfaceContainer, // simile a "input"
      destructive: cs.error,
      ring: tokens?.ring ?? cs.primary,
    );
  }
}

/// Checkbox stile shadcn/ui (size-4, rounded-[4px], border-input, shadow-xs,
/// focus-visible:ring-[3px], aria-invalid ring/destructive, disabled opacity-50)
class AppCheckbox extends StatefulWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.isInvalid = false,
    this.enabled = true,
    this.size = 16.0, // size-4
    this.radius = const BorderRadius.all(Radius.circular(4)), // rounded-[4px]
    this.tokens,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isInvalid;
  final bool enabled;
  final double size;
  final BorderRadius radius;
  final AppCheckboxTokens? tokens;

  @override
  State<AppCheckbox> createState() => _AppCheckboxState();
}

class _AppCheckboxState extends State<AppCheckbox> {
  bool _focused = false;

  void _toggle() {
    if (!widget.enabled || widget.onChanged == null) return;
    widget.onChanged!.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.tokens ?? AppCheckboxTokens.fromTheme(theme);

    final isDark = theme.brightness == Brightness.dark;
    final checked = widget.value;
    final enabled = widget.enabled && widget.onChanged != null;

    // ---- Background / Border (replica delle utility shadcn) ----
    final Color bg = checked
        ? t.primary // data-[state=checked]:bg-primary
        : (isDark
            ? t.inputBg.withValues(alpha: 0.30) // dark:bg-input/30
            : theme.colorScheme.surface // light:bg-background
          );

    // Border precedence: invalid > focus-visible > checked > default
    Color border = t.border; // border-input
    if (checked) border = t.primary; // data-[state=checked]:border-primary
    if (_focused) {
      border = widget.isInvalid ? t.destructive : t.ring; // focus-visible:border-…
    }
    if (widget.isInvalid && !_focused) {
      border = t.destructive; // aria-invalid:border-destructive
    }

    // ---- Focus ring (focus-visible:ring-[3px]) + aria-invalid ----
    final Color ringBase = widget.isInvalid ? t.destructive : t.ring;
    final double ringAlpha = widget.isInvalid
        ? (isDark ? 0.40 : 0.20) // dark:aria-invalid:ring-…/40, light /20
        : 0.50; // ring-ring/50
    final ringShadow = _focused
        ? [
            BoxShadow(
              color: ringBase.withValues(alpha: ringAlpha),
              spreadRadius: 3, // 3px
              blurRadius: 0,
            ),
          ]
        : <BoxShadow>[];

    // ---- Shadow XS (shadow-xs) ----
    final BoxShadow baseShadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 1.5,
      offset: const Offset(0, 1),
    );

    // ---- Disabled opacity ----
    final double opacity = enabled ? 1.0 : 0.5; // disabled:opacity-50

    // ---- Icona (Indicator) ----
    final Color iconColor = checked ? t.onPrimary : Colors.transparent; // text-current

    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden, // disabled:cursor-not-allowed
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Opacity(
            opacity: opacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut, // transition-shadow
              height: widget.size,
              width: widget.size, // size-4 (quadrato)
              decoration: BoxDecoration(
                color: bg,
                borderRadius: widget.radius,
                border: Border.all(color: border, width: 1), // border
                boxShadow: [
                  ...ringShadow, // focus-visible:ring
                  baseShadow, // shadow-xs
                ],
              ),
              // Indicator: "grid place-content-center text-current transition-none"
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 14, // size-3.5 ~ 14px
                  color: iconColor, // text-primary-foreground quando checked
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
