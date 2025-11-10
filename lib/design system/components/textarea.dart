// components/textarea.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // per ShadcnRadii e DefaultTokens nelle Theme.extensions

/// AppTextarea
/// Replica il comportamento/visual della textarea shadcn:
/// - min-h-16 (64px)
/// - px-3 / py-2
/// - rounded-md
/// - border-input con focus-visible:border-ring + ring 3px (ring/50)
/// - aria-invalid => border/ring destructive (dark: ring /40, light: /20)
/// - dark:bg-input/30
class AppTextarea extends StatefulWidget {
  const AppTextarea({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.enabled = true,
    this.isInvalid = false,
    this.minLines = 3, // 3 linee ~ min-h-16 con py-2
    this.maxLines,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool enabled;
  final bool isInvalid;
  final int minLines;
  final int? maxLines;

  @override
  State<AppTextarea> createState() => _AppTextareaState();
}

class _AppTextareaState extends State<AppTextarea> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<DefaultTokens>();
    final isDark = theme.brightness == Brightness.dark;

    final radii = theme.extension<ShadcnRadii>() ?? ShadcnRadii(
      xs: BorderRadius.circular(4),
      sm: BorderRadius.circular(6),
      md: BorderRadius.circular(8),
      lg: BorderRadius.circular(12),
      xl: BorderRadius.circular(16),
    );

    // Mappature shadcn → Flutter
    final borderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline); // allinea a AppButton.outline

    // Colore base per ring/border in focus: usa il token "ring" come in shadcn
    final Color ringBase = widget.isInvalid
        ? cs.error
        : (tokens?.ring ?? cs.outlineVariant);

    // Overlay del ring: ring/50 (o destructive /20 light, /40 dark)
    final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
    final Color focusRingOverlay = ringBase.withValues(alpha: ringAlpha);

    // Border in focus: NON cambiare il colore quando compare il ring (sia light che dark)
    final Color effectiveBorderColor = widget.isInvalid ? cs.error : borderColor;

    // Background base (shadcn: dark:bg-input/30, light:bg-background)
    final Color baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30) // dark:bg-input/30
        : cs.surface; // light:bg-background

    // Disabled only in light mode: usare un grigio più percettibile (coerente con bg-muted)
    final Color fillBg = (!widget.enabled && !isDark)
        ? cs.surfaceContainerHighest
        : baseBg;

    // padding: px-3 / py-2 → 12 / 8 (simmetrico come shadcn)
    const double px = 12.0;
    const double pyTop = 8.0; // default shadcn: py-2
    const double pyBottom = 8.0;
    final radius = radii.md;

    // Outline base
    final outline = OutlineInputBorder(
      borderSide: BorderSide(
        color: effectiveBorderColor,
        width: 1,
      ),
      borderRadius: radius,
    );

    // Ring 3px come boxShadow “esterno” + shadow-xs quando non focused
    final ringShadow = _focused
        ? [BoxShadow(color: focusRingOverlay, blurRadius: 0, spreadRadius: 3)]
        : [
            // shadow-xs leggerissima (transition-[color,box-shadow])
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ];

    const double fontSize = 14.0; // md:text-sm su desktop

    final field = TextField(
      focusNode: _focusNode,
      controller: widget.controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      minLines: widget.minLines,
      maxLines: widget.maxLines, // null = espansione libera
      cursorColor: cs.primary,
      style: theme.textTheme.bodyMedium?.copyWith(
        // React: text-base (16) su mobile e md:text-sm (14) su desktop.
        fontSize: fontSize,
      ),
      decoration: InputDecoration(
        isDense: true,
        // label interno disattivato esplicitamente
        labelText: null,
        hintText: widget.hintText,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          // placeholder:text-muted-foreground e stessa dimensione del testo
          color: const Color(0xFF737373),
          fontSize: fontSize,
        ),
        filled: true,
        fillColor: fillBg,
        contentPadding: const EdgeInsets.fromLTRB(
          px,
          pyTop,
          px,
          pyBottom,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline, // mantiene il bordo neutro, il ring è un overlay esterno
        disabledBorder: outline.copyWith(
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.6)),
        ),
        errorBorder: outline.copyWith(borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(color: cs.error),
        ),
      ),
    );

    final interactive = widget.enabled
        ? field
        : IgnorePointer(child: Opacity(opacity: 0.5, child: field));

    // Il contenitore segue l'altezza del TextField (minLines=3 ≈ min-h-16) e applica il ring
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: ringShadow),
      child: interactive,
    );

    return SizedBox(
      width: double.infinity, // w-full
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
        child: content,
      ),
    );
  }
}
