// lib/components/input_group.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // DefaultTokens + ShadcnRadii

/// AppInputGroup — gruppo di input con add-on a sinistra/destra (testo o pulsanti)
/// Parità visiva con shadcn/ui:
/// - Altezza default: h-9 (36px)
/// - Radius: rounded-md
/// - Bordi: 1px complessivo sul contenitore (non sui segmenti interni)
/// - Focus-visible: bordo = tokens.ring e ring esterno 3px
/// - Invalid: bordo e ring su destructive
/// - Disabled: opacity-50 e pointer-events none
/// - Background: light → background; dark → input/30
/// - Addon: nessun bordo interno; solo padding e colore "muted-foreground"
class AppInputGroup extends StatefulWidget {
  const AppInputGroup({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.enabled = true,
    this.isInvalid = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.leading,
    this.trailing,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool enabled;
  final bool isInvalid;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  /// Widget opzionali adiacenti all'input (es. AppButton, testo, icone)
  final Widget? leading;
  final Widget? trailing;

  @override
  State<AppInputGroup> createState() => _AppInputGroupState();
}

class _AppInputGroupState extends State<AppInputGroup> {
  final FocusNode _focusNode = FocusNode();
  bool _focusVisible = false; // focus-visible (solo tastiera)

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
    final radii = theme.extension<ShadcnRadii>()!;

    final isDark = theme.brightness == Brightness.dark;

    const double height = 36.0; // h-9
    final BorderRadius radius = radii.md;

    // Colori base
    final Color baseBorderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);

    final Color ringBase = widget.isInvalid ? cs.error : (tokens?.ring ?? cs.outlineVariant);
    final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

    final baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30) // dark:bg-input/30
        : cs.surface; // light:bg-background

    // Ombre: ring esterno 3px quando focus-visible, altrimenti shadow-xs
    final List<BoxShadow> ringShadows = _focusVisible
        ? [BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 3)]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ];

    final Color containerBorderColor = widget.isInvalid
        ? cs.error
        : (_focusVisible ? (tokens?.ring ?? cs.outlineVariant) : baseBorderColor);

    // Campo input borderless (come InputGroupInput in React)
    // Padding verticale: per i campi single-line (es. password, obscureText=true)
    // aumentiamo il padding verticale per centrare meglio il testo.
    EdgeInsets contentPadding = EdgeInsets.symmetric(
      horizontal: 12,
      vertical: widget.obscureText ? 10 : 4,
    );
    if (widget.leading != null) {
      contentPadding = contentPadding.copyWith(left: 8); // has-[inline-start]: [&>input]:pl-2
    }
    if (widget.trailing != null) {
      contentPadding = contentPadding.copyWith(right: 8); // has-[inline-end]: [&>input]:pr-2
    }

    final field = Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: cs.primary,
          selectionHandleColor: cs.primary,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        obscureText: widget.obscureText,
        // Per i campi oscurati (password) Flutter richiede maxLines==1 e niente expands
        expands: widget.obscureText ? false : true,
        minLines: widget.obscureText ? 1 : null,
        maxLines: widget.obscureText ? 1 : null,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: cs.primary,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14.0,
          // Per i campi password manteniamo una line-height più stretta
          height: widget.obscureText ? 1.0 : 1.25,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.25,
          ),
          contentPadding: contentPadding,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
    );

    final body = widget.enabled ? field : IgnorePointer(child: Opacity(opacity: 0.5, child: field));

    // Addon inline (sinistra/destra): nessun bordo interno, solo padding
    Widget buildAddon(Widget child, {required bool isLeading}) {
      final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6); // text-muted-foreground
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusNode.requestFocus(),
        child: DefaultTextStyle.merge(
          style: theme.textTheme.bodyMedium!.copyWith(fontSize: 14, height: 1.25, color: textColor),
          child: IconTheme.merge(
            data: IconThemeData(size: 16, color: textColor),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12).copyWith(
                left: isLeading ? 12 : 0,
                right: isLeading ? 0 : 12,
              ),
              child: Align(alignment: Alignment.center, child: child),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[];
    if (widget.leading != null) {
      children.add(buildAddon(widget.leading!, isLeading: true));
    }
    children.add(Expanded(child: SizedBox(height: height, child: body)));
    if (widget.trailing != null) {
      children.add(buildAddon(widget.trailing!, isLeading: false));
    }

    return FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          height: height,
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: radius,
            border: Border.all(color: containerBorderColor, width: 1),
            boxShadow: ringShadows,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}