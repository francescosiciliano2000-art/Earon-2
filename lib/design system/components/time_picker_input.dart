// time_picker_input.dart
// Unico input per l'orario che apre un overlay con due colonne di selezione: Ore e Minuti.
// Pattern di overlay ancorato come AppDatePickerInput.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/themes.dart';

class AppTimePickerInput extends StatefulWidget {
  final TimeOfDay? initialTime;
  final ValueChanged<TimeOfDay?>? onTimeSubmitted;
  final String? label;
  final double overlayWidthFactor;
  final int minuteStep;
  const AppTimePickerInput({
    super.key,
    this.initialTime,
    this.onTimeSubmitted,
    this.label,
    this.overlayWidthFactor = 1.15,
    this.minuteStep = 5,
  });

  @override
  State<AppTimePickerInput> createState() => _AppTimePickerInputState();
}

class _AppTimePickerInputState extends State<AppTimePickerInput>
    with SingleTickerProviderStateMixin {
  TimeOfDay? _value;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  Size _triggerSize = const Size(180, 36);
  Size _contentSize = Size.zero;
  Offset _triggerGlobal = Offset.zero;
  bool _focusVisible = false;
  bool _hovered = false;
  bool _backdropActive = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialTime;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeOverlay(immediate: true);
    _controller.dispose();
    super.dispose();
  }

  void _captureTriggerSize() {
    final ctx = _triggerKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box != null) {
      _triggerSize = box.size;
      _triggerGlobal = box.localToGlobal(Offset.zero);
    }
  }

  String _fmt(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>()!;
    final isDark = theme.brightness == Brightness.dark;

    const double height = 36.0; // h-9
    const double px = 12.0;
    const double py = 6.0;

    final baseBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : cs.outline;
    final Color ringBase = tokens?.ring ?? cs.outlineVariant;
    final double ringAlpha = 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

    Color baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30)
        : cs.surface;
    if (isDark && _hovered) {
      baseBg = cs.outlineVariant.withValues(alpha: 0.50);
    }

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

    final trigger = SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height),
        child: AnimatedContainer(
          key: _triggerKey,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: radii.md,
            border: Border.all(color: baseBorderColor, width: 1),
            boxShadow: ringShadows,
          ),
          child: InkWell(
            borderRadius: radii.md,
            onTap: () {
              _captureTriggerSize();
              _showOverlay();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: px, vertical: py),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _value == null ? 'Seleziona orario' : _fmt(_value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _value == null
                            ? cs.onSurface.withValues(alpha: 0.6)
                            : cs.onSurface,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        CompositedTransformTarget(
          link: _layerLink,
          child: FocusableActionDetector(
            onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: trigger,
            ),
          ),
        ),
      ],
    );

    return body;
  }

  void _showOverlay() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : cs.outline;
    final panelBg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Theme.of(context).colorScheme.surface;
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];

    _backdropActive = false;
    _entry = OverlayEntry(builder: (context) {
      final double offsetX = _contentSize.width > 0
          ? (_triggerSize.width - _contentSize.width)
          : 0;
      final screenH = MediaQuery.of(context).size.height;
      const margin = 12.0;
      final availableBelow = screenH - (_triggerGlobal.dy + _triggerSize.height + 8.0) - margin;
      final availableAbove = _triggerGlobal.dy - margin;
      final measuredH = _contentSize.height;
      final placeAbove = measuredH > 0
          ? (measuredH > availableBelow && availableAbove >= measuredH)
          : false;
      final double offsetY = placeAbove ? -(measuredH + 8.0) : (_triggerSize.height + 8.0);

      return Stack(children: [
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: !_backdropActive,
            child: GestureDetector(onTap: _removeOverlay),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(offsetX, offsetY),
          showWhenUnlinked: false,
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: placeAbove ? Alignment.bottomRight : Alignment.topRight,
                child: _SizeObserver(
                  onSize: (s) {
                    if (_contentSize != s) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _contentSize = s);
                        _entry?.markNeedsBuild();
                      });
                    }
                  },
                  child: Container(
                    constraints: () {
                      final maxW = math.max(
                        _triggerSize.width,
                        _triggerSize.width * widget.overlayWidthFactor,
                      );
                      // Altezza massima: 320 come nei menu select
                      final double availableH = placeAbove ? availableAbove : availableBelow;
                      final double targetH = math.max(0.0, math.min(320.0, availableH)).toDouble();
                      return BoxConstraints(
                        minWidth: _triggerSize.width,
                        maxWidth: maxW,
                        minHeight: targetH,
                        maxHeight: targetH,
                      );
                    }(),
                    decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius: Theme.of(context).extension<ShadcnRadii>()?.md ??
                          const BorderRadius.all(Radius.circular(6)),
                      border: Border.all(color: borderColor),
                      boxShadow: shadow,
                    ),
                    child: _buildOverlayContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    });

    Overlay.of(context).insert(_entry!);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _backdropActive = true);
      _entry?.markNeedsBuild();
    });
  }

  Widget _buildOverlayContent() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);

    final hourItems = [for (int h = 0; h < 24; h++) h];
    final minuteItems = [for (int m = 0; m < 60; m += widget.minuteStep) m];

    int? selHour = _value?.hour;
    int? selMin = _value?.minute == null
        ? null
        : (_value!.minute - (_value!.minute % widget.minuteStep));

    Widget buildColumn({required String title, required List<int> items, required int? selected, required ValueChanged<int> onPick}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? cs.onSurface.withValues(alpha: 0.6) : const Color(0xFF6B7280),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final val = items[index];
                  final label = val.toString().padLeft(2, '0');
                  final selectedFlag = selected == val;
                  final bg = selectedFlag
                      ? (isDark ? Colors.white.withValues(alpha: 0.08) : cs.primary.withValues(alpha: 0.08))
                      : Colors.transparent;
                  final textColor = cs.onSurface;
                  return InkWell(
                    onTap: () => onPick(val),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: Theme.of(context).extension<ShadcnRadii>()?.md ?? const BorderRadius.all(Radius.circular(6)),
                        color: bg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: textStyle?.copyWith(color: textColor),
                            ),
                          ),
                          if (selectedFlag) Icon(Icons.check, size: 16, color: cs.onSurface.withValues(alpha: 0.9)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        buildColumn(
          title: 'Ore',
          items: hourItems,
          selected: selHour,
          onPick: (h) {
            final mm = _value?.minute ?? 0;
            setState(() => _value = TimeOfDay(hour: h, minute: mm));
          },
        ),
        Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: cs.outline.withValues(alpha: 0.5)),
        buildColumn(
          title: 'Minuti',
          items: minuteItems,
          selected: selMin,
          onPick: (m) {
            final hh = _value?.hour ?? 0;
            final newVal = TimeOfDay(hour: hh, minute: m);
            setState(() => _value = newVal);
            widget.onTimeSubmitted?.call(newVal);
            _removeOverlay();
          },
        ),
      ],
    );
  }

  void _removeOverlay({bool immediate = false}) async {
    if (_entry == null) return;
    if (!immediate) await _controller.reverse();
    _entry?.remove();
    _entry = null;
  }
}

// Osservatore per misurare dimensione del pannello (riuso pattern date_picker)
class _SizeObserver extends StatefulWidget {
  const _SizeObserver({required this.child, required this.onSize});
  final Widget child;
  final ValueChanged<Size> onSize;
  @override
  State<_SizeObserver> createState() => _SizeObserverState();
}

class _SizeObserverState extends State<_SizeObserver> {
  Size _last = Size.zero;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final s = box.size;
        if (s != _last) {
          _last = s;
          widget.onSize(s);
        }
      }
    });
    return widget.child;
  }
}