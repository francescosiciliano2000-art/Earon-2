// lib/components/radio_group.dart
import 'package:flutter/material.dart';
import '../theme/theme_builder.dart';
import '../theme/themes.dart';
import '../theme/typography.dart';

/// Opzione del RadioGroup
class AppRadioOption<T> {
  const AppRadioOption({required this.value, required this.label, this.enabled = true});
  final T value;
  final String label;
  final bool enabled;
}

enum AppRadioDirection { vertical, horizontal }

/// RadioGroup stile shadcn/ui
class AppRadioGroup<T> extends StatefulWidget {
  const AppRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.direction = AppRadioDirection.vertical,
    this.gap = 12,
    this.itemGap = 8,
  });

  final List<AppRadioOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final AppRadioDirection direction;
  final double gap; // spazio tra item quando vertical
  final double itemGap; // spazio tra bullet e label

  @override
  State<AppRadioGroup<T>> createState() => _AppRadioGroupState<T>();
}

class _AppRadioGroupState<T> extends State<AppRadioGroup<T>> {
  @override
  Widget build(BuildContext context) {
    final children = widget.options
        .map((o) => _AppRadioItem<T>(
              label: o.label,
              selected: widget.value == o.value,
              enabled: o.enabled,
              gap: widget.itemGap,
              onTap: () {
                if (o.enabled) widget.onChanged(o.value);
              },
            ))
        .toList();

    switch (widget.direction) {
      case AppRadioDirection.vertical:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _intersperse(children, SizedBox(height: widget.gap)),
        );
      case AppRadioDirection.horizontal:
        return Wrap(
          alignment: WrapAlignment.start,
          spacing: widget.gap,
          runSpacing: widget.gap / 2,
          children: children,
        );
    }
  }

  List<Widget> _intersperse(List<Widget> input, Widget separator) {
    if (input.isEmpty) return input;
    final out = <Widget>[];
    for (var i = 0; i < input.length; i++) {
      out.add(input[i]);
      if (i < input.length - 1) out.add(separator);
    }
    return out;
  }
}

class _AppRadioItem<T> extends StatefulWidget {
  const _AppRadioItem({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.gap,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final double gap;
  final VoidCallback onTap;

  @override
  State<_AppRadioItem<T>> createState() => _AppRadioItemState<T>();
}

class _AppRadioItemState<T> extends State<_AppRadioItem<T>> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final defaults = Theme.of(context).extension<DefaultTokens>();
    final ty = Theme.of(context).extension<ShadcnTypography>() ?? ShadcnTypography.defaults();

    final enabled = widget.enabled;
    final selected = widget.selected;

    final baseBorder = tokens.border;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In shadcn: focus-visible:border-ring (niente ring visivo addizionale nel tuo setup),
    // background leggero in dark (dark:bg-input/30)
    final circleBorderColor = _focused
        ? (defaults?.ring ?? tokens.ring)
        : (selected ? tokens.primary : baseBorder);
    final circleFillColor = isDark
        ? tokens.input.withValues(alpha: 0.30)
        : Colors.white; // in light: sfondo pieno bianco

    final labelStyle = TextStyle(
      fontSize: ty.textSm, // shadcn usa text-sm per la label
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: enabled ? 1 : 0.5),
      height: 1.25,
    );

    // Nessun ring esterno: solo una leggera shadow-xs
    final List<BoxShadow> shadows = [
      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 1, spreadRadius: 0),
    ];

    final opacity = enabled ? 1.0 : 0.6;

    final radioVisual = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: circleFillColor,
        shape: BoxShape.circle,
        border: Border.all(color: circleBorderColor, width: 1.0),
        boxShadow: shadows,
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: selected ? 8 : 0,
          height: selected ? 8 : 0,
          decoration: BoxDecoration(
            color: selected ? tokens.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    final interactive = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: Opacity(
            opacity: opacity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                radioVisual,
                SizedBox(width: widget.gap),
                Text(widget.label, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      button: false,
      label: widget.label,
      child: interactive,
    );
  }
}
