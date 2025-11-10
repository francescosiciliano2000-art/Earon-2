// app_input.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // per ShadcnRadii in Theme.extensions

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.enabled = true,
    this.isInvalid = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final bool enabled;
  final bool isInvalid;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  FocusNode? _internalFocusNode;
  bool _focusVisible = false; // focus-visible (solo tastiera)

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>()!;

    // Breakpoint come in apps/v4: md:text-sm su schermi >=768px
    final isMd = MediaQuery.of(context).size.width >= 768;
    final fontSize =
        isMd ? 14.0 : 16.0; // text-base su mobile, md:text-sm su desktop

    // Altezza del box e padding orizzontale (usa 40.0 se vuoi h-10)
    const height = 36.0;
    const px = 12.0;

    // Platform tweak: iOS e macOS tendono a spingere la baseline un filo in alto
    final platform = Theme.of(context).platform;
    final isCupertinoLike =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final baselineTweak =
        isCupertinoLike ? 0.75 : 0.0; // 0.5–1.0px va bene quasi sempre

    // Padding verticale "ottico": centra il testo nel box, poi applica il tweak
    // Uso lineHeight 1.1 per evitare extra-leading che alza il testo.
    const lineHeight = 1.1;
    final contentHeight = fontSize * lineHeight;
    final py = ((height - contentHeight) / 2) + baselineTweak;

    // Token shadcn
    final isDark = theme.brightness == Brightness.dark;

    // Colori di bordo base/focus allineati ai Buttons outline
    final baseBorderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);

    // Usa il token "ring" come in shadcn per il bordo in focus
    final Color ringBase =
        widget.isInvalid ? cs.error : (tokens?.ring ?? cs.outlineVariant);

    // Colore ring come in React: ring/50 (o destructive/20 light, /40 dark se invalid)
    final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

    // Background: in light usa bg-background (→ cs.surface), in dark un leggero fill tipo input/30
    final baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30) // dark:bg-input/30
        : cs.surface; // light:bg-background
    final bg = baseBg; // React non cambia il bg in hover per l'input

    final radius = radii.md;

    // Ring (focus-visible) come React: un alone esterno, non deve "tintare" il fill interno
    final List<BoxShadow> ringShadows = _focusVisible
        ? [BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 3)]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ];

    // BORDO: NON cambiare il colore del bordo quando compare il ring (sia light che dark)
    final Color effectiveBorderColor =
        widget.isInvalid ? cs.error : baseBorderColor;

    // Usa il focusNode fornito se presente, altrimenti uno interno
    final FocusNode effectiveFocusNode = widget.focusNode ?? (_internalFocusNode ??= FocusNode());

    final field = Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: cs.primary,
          selectionHandleColor: cs.primary,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: effectiveFocusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        obscureText: widget.obscureText,
        // Single-line come shadcn/ui
        minLines: 1,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: cs.primary,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          height: 1.0, // nessun extra-leading: aiuta a centrare otticamente
        ),
        // niente StrutStyle forzato: può spingere in alto la baseline
        decoration: InputDecoration(
          isCollapsed: true, // rimuove il padding implicito di Material
          labelText: null,
          filled: false,
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: fontSize,
            height: 1.0,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: px,
            vertical: py, // padding calcolato
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
    );

    final body = widget.enabled
        ? field
        : IgnorePointer(child: Opacity(opacity: 0.5, child: field));

    return FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.text
            : SystemMouseCursors.forbidden,
        child: SizedBox(
          height: height, // h-9 (usa 40.0 per h-10)
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: ringShadows, // solo ring/shadow esterno
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: Border.all(color: effectiveBorderColor, width: 1),
              ),
              // Centro l'intero TextField dentro il box (elimina qualsiasi residuo d’asimmetria)
              child: Center(child: body),
            ),
          ),
        ),
      ),
    );
  }
}
