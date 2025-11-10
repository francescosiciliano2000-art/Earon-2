// app_switch.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/themes.dart'; // per DefaultTokens (ring) se presenti nel tema

/// Port fedele dello shadcn/ui Switch (Radix) per questo progetto.
/// Dimensioni & comportamenti:
/// - Track: w=32, h=18.4 (~1.15rem), rounded-full
/// - Thumb: 16x16, rounded-full, traduce da x=0 a x=100%-2px
/// - Focus ring: 3px (boxShadow esterno) su focus-visible
/// - Disabled: opacity 0.5
/// - Transizioni: 150ms easeInOut
class AppSwitch extends StatefulWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isInvalid = false, // come aria-invalid → ring "destructive"
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool isInvalid;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AppSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<AppSwitch> {
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Misure shadcn
    const double trackWidth = 32;
    const double trackHeight = 18.4; // 1.15rem
    const double thumbSize = 16;

    // Colori base per track unchecked: light → grigio (non bianco), dark → bg-input/80
    final Color inputColor =
        theme.inputDecorationTheme.fillColor ??
        (isDark
            ? const Color(0xFF2A2A2E)
            : cs.surface);

    // In light mode vogliamo il track grigio quando OFF; in dark manteniamo l'attuale comportamento
    final Color lightUncheckedTrack = cs.surfaceContainerHighest;

    final Color trackColor = widget.value
        ? cs.primary
        : (isDark ? inputColor.withValues(alpha: 0.80) : lightUncheckedTrack);

    // Bordo: come altri controlli (outline) quando unchecked o invalid; ring al focus
    final Color ringBase = widget.isInvalid
        ? cs.error
        : (theme.extension<DefaultTokens>()?.ring ?? cs.outlineVariant);
    final Color ringOverlay = ringBase.withValues(alpha: 0.50);

    final Color baseBorderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);

    final Color effectiveBorderColor = widget.isInvalid
        ? cs.error
        : (_focused
            ? ringBase
            : (widget.value ? Colors.transparent : baseBorderColor));

    // Colori thumb: light → background; dark: unchecked → foreground, checked → primary-foreground
    final Color thumbColor = isDark
        ? (widget.value ? cs.onPrimary : cs.onSurface)
        : cs.surface;

    final BorderRadius radius = BorderRadius.circular(trackHeight / 2);

    // Rimuove l'ombra drop; mantiene solo il focus ring a 3px quando a fuoco
    final List<BoxShadow> trackShadows = [
      if (_focused)
        BoxShadow(
          color: ringOverlay,
          blurRadius: 0,
          spreadRadius: 3, // ring-[3px]
        ),
    ];

    // Scorciatoie tastiera: Space/Enter
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
    };

    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: shortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _toggle();
            return null;
          },
        ),
      },
      child: Semantics(
        label: widget.semanticLabel,
        checked: widget.value,
        button: true,
        enabled: widget.enabled,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: MouseRegion(
            cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
            child: GestureDetector(
              onTap: widget.enabled ? _toggle : null,
              onHorizontalDragUpdate: widget.enabled
                  ? (details) {
                      if (details.delta.dx > 0 && !widget.value) {
                        widget.onChanged(true);
                      } else if (details.delta.dx < 0 && widget.value) {
                        widget.onChanged(false);
                      }
                    }
                  : null,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: trackWidth,
                height: trackHeight + 2, // spazio extra per evitare il taglio inferiore dell'ombra
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    width: trackWidth,
                    height: trackHeight,
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: trackColor,
                      border: Border.all(color: effectiveBorderColor, width: 1),
                      borderRadius: radius,
                      boxShadow: trackShadows,
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          color: thumbColor,
                          borderRadius: BorderRadius.circular(thumbSize / 2),
                        ),
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
