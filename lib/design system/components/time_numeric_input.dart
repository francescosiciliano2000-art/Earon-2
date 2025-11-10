// Numeric-only time input styled like AppInput, formatting HH : MM : 00.
// Does not open a select overlay; user types digits and we auto-format.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/themes.dart';

class AppTimeNumericInput extends StatefulWidget {
  const AppTimeNumericInput({
    super.key,
    this.initialTime,
    this.onTimeSubmitted,
    this.label,
  });

  final TimeOfDay? initialTime;
  final ValueChanged<TimeOfDay?>? onTimeSubmitted;
  final String? label;

  @override
  State<AppTimeNumericInput> createState() => _AppTimeNumericInputState();
}

class _AppTimeNumericInputState extends State<AppTimeNumericInput> {
  late TextEditingController _ctl;
  FocusNode? _internalFocusNode;
  bool _focusVisible = false;

  @override
  void initState() {
    super.initState();
    final TimeOfDay initial = widget.initialTime ?? const TimeOfDay(hour: 9, minute: 0);
    _ctl = TextEditingController(text: _fmt(initial));
    // Notifica default iniziale se non fornito
    if (widget.initialTime == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTimeSubmitted?.call(initial);
      });
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay? t) {
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh : $mm : 00';
  }

  // Parse from any string of digits into a TimeOfDay, clamped.
  TimeOfDay? _parseDigits(String digits) {
    if (digits.isEmpty) return null;
    final only = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (only.isEmpty) return null;
    int hh = 0;
    int mm = 0;
    if (only.length <= 2) {
      hh = int.tryParse(only) ?? 0;
    } else {
      hh = int.tryParse(only.substring(0, 2)) ?? 0;
      mm = int.tryParse(only.substring(2, only.length).padRight(2, '0').substring(0, 2)) ?? 0;
    }
    hh = hh.clamp(0, 23);
    mm = mm.clamp(0, 59);
    return TimeOfDay(hour: hh, minute: mm);
  }

  void _onChangedRaw(String raw) {
    final t = _parseDigits(raw);
    final newText = _fmt(t);
    final selectionBase = (_ctl.selection.baseOffset);
    setState(() {
      _ctl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (selectionBase <= 2) ? 2 : (selectionBase <= 7 ? 7 : 12),
        ),
      );
    });
    widget.onTimeSubmitted?.call(t);
  }

  void _snapSelectionToSegment() {
    final int pos = _ctl.selection.baseOffset;
    final int target = (pos <= 2) ? 2 : (pos <= 7 ? 7 : 12);
    _ctl.selection = TextSelection.collapsed(offset: target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>()!;
    final isDark = theme.brightness == Brightness.dark;

    const double height = 36.0; // h-9
    const double px = 12.0;

    final baseBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : cs.outline;
    final Color ringBase = tokens?.ring ?? cs.outlineVariant;
    final double ringAlpha = 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

    Color baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30)
        : cs.surface;

    final List<BoxShadow> ringShadows = _focusVisible
        ? [BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 3)]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ];

    final labelWidget = widget.label == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.label!,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );

    final FocusNode focusNode = _internalFocusNode ??= FocusNode();

    final field = Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: cs.primary,
          selectionHandleColor: cs.primary,
        ),
      ),
      child: TextField(
        controller: _ctl,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: _onChangedRaw,
        onTap: () {
          // Blocca la selezione sul segmento corrente (HH/MM/SS)
          _snapSelectionToSegment();
        },
        decoration: InputDecoration(
          isCollapsed: true,
          hintText: 'HH : MM : 00',
          contentPadding: const EdgeInsets.symmetric(horizontal: px, vertical: 6.0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.0),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        FocusableActionDetector(
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          child: SizedBox(
            height: height,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: baseBg,
                borderRadius: radii.md,
                border: Border.all(color: baseBorderColor, width: 1),
                boxShadow: ringShadows,
              ),
              child: Center(child: field),
            ),
          ),
        ),
      ],
    );
  }
}