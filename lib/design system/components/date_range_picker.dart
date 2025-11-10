import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'calendar_range.dart';
import 'calendar.dart' as appcal;
import '../theme/themes.dart';
import 'select.dart' show SelectSize;

/// AppDateRangePickerInput
///
/// Input con trigger che apre un overlay contenente il CalendarRange
/// per la selezione di un intervallo di date (start/end). Lo stile
/// è allineato ad AppDatePickerInput (singola data) e al design system.
class AppDateRangePickerInput extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTimeRange?>? onRangeSubmitted;
  final String? label;
  /// Permette di rendere il pannello più largo del trigger.
  /// Esempio: 1.4 significa 140% della larghezza del trigger.
  final double overlayWidthFactor;

  const AppDateRangePickerInput({
    super.key,
    this.initialRange,
    required this.firstDate,
    required this.lastDate,
    this.onRangeSubmitted,
    this.label,
    this.overlayWidthFactor = 1.2,
  });

  @override
  State<AppDateRangePickerInput> createState() => _AppDateRangePickerInputState();
}

class _AppDateRangePickerInputState extends State<AppDateRangePickerInput>
    with SingleTickerProviderStateMixin {
  DateTimeRange? _range;
  // Traccia il mese visibile del calendario per stimare l'altezza (5/6 righe)
  late DateTime _visibleMonth;
  DateTime? _lastSizedMonth; // mese per cui è stata misurata _contentSize
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
  bool _backdropActive = false; // attiva il backdrop dopo un breve delay

  int _weeksForMonth(DateTime base, {int firstDayOfWeek = DateTime.monday}) {
    final firstOfMonth = DateTime(base.year, base.month, 1);
    final int shift = (firstOfMonth.weekday - firstDayOfWeek + 7) % 7;
    final lastOfMonth = DateTime(base.year, base.month + 1, 0);
    final int tail = ((firstDayOfWeek + 6) - lastOfMonth.weekday + 7) % 7;
    final int daysInMonth = lastOfMonth.day;
    final int total = shift + daysInMonth + tail;
    int weekCount = (total / 7).ceil();
    if (weekCount < 5) weekCount = 5;
    if (weekCount > 6) weekCount = 6;
    return weekCount;
  }

  double _estimateCalendarHeight({required int weeks}) {
    // calendar defaults: cellSize=32.0, headerScale=1.0, captionLayout=dropdown
    const double cellSize = 32.0;
    const double headerH = cellSize * 1.0;
    const double vPad = 12.0 * 2; // container padding (top+bottom)
    const double gapBelowHeader = 8.0; // Padding tra header e contenuto
    const double weekdaysH = cellSize; // intestazione giorni della settimana
    const double rowH = cellSize + 8.0; // ogni riga ha padding-top:8
    return vPad + headerH + gapBelowHeader + weekdaysH + (weeks * rowH);
  }

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    final DateTime base = _range?.start ?? DateTime.now();
    _visibleMonth = DateTime(base.year, base.month);
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

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtRange(DateTimeRange? r) => r == null
      ? ''
      : '${_fmt(r.start)} - ${_fmt(r.end)}';

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

    final trigger = IntrinsicWidth(
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
              child: Builder(
                builder: (context) {
                  final String label = _range == null
                      ? 'Seleziona intervallo'
                      : _fmtRange(_range);
                  final textStyle = theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _range == null
                            ? cs.onSurface.withValues(alpha: 0.6)
                            : cs.onSurface,
                      ) ??
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
                  final tp = TextPainter(
                    text: TextSpan(text: label, style: textStyle),
                    maxLines: 1,
                    textDirection: Directionality.of(context),
                  )..layout();
                  const double caret = 18.0;
                  const double gap = 8.0;
                  final double textW = tp.size.width;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: textW,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle,
                        ),
                      ),
                      const SizedBox(width: gap),
                      const Icon(Icons.keyboard_arrow_down, size: caret),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
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
  }

  void _showOverlay() {
    // Mantieni l'intervallo eventualmente già selezionato.
    // L'utente potrà modificarlo cliccando sul calendario: se clicca dopo lo start
    // verrà aggiornata la data di fine, se clicca prima dello start si riparte da
    // una nuova selezione (gestito dal componente CalendarRange).

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

    _backdropActive = false; // disattiva backdrop inizialmente
    _entry = OverlayEntry(builder: (context) {
      final double offsetX = _contentSize.width > 0
          ? (_triggerSize.width - _contentSize.width)
          : 0;
      // Spazio disponibile sopra/sotto il trigger:
      final screenH = MediaQuery.of(context).size.height;
      const margin = 12.0;
      final availableBelow = screenH - (_triggerGlobal.dy + _triggerSize.height + 8.0) - margin;
      final availableAbove = _triggerGlobal.dy - margin;
      final measuredH = _contentSize.height;
      final placeAbove = measuredH > 0
          ? (measuredH > availableBelow && availableAbove >= measuredH)
          : false; // prima misura: mostra sotto
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
                        setState(() {
                          _contentSize = s;
                          _lastSizedMonth = _visibleMonth;
                        });
                        _entry?.markNeedsBuild();
                      });
                    }
                  },
                  child: Container(
                    constraints: () {
                      // Larghezza: come prima (può essere più larga del trigger).
                      final maxW = math.max(
                        _triggerSize.width,
                        _triggerSize.width * widget.overlayWidthFactor,
                      );
                      const double epsilon = 2.0; // margine per bordo/rounding SOLO sulla stima
                      final double availableH = placeAbove ? availableAbove : availableBelow;
                      final DateTime month = _visibleMonth;
                      final int weeks = _weeksForMonth(month);
                      final double estimate = _estimateCalendarHeight(weeks: weeks) + epsilon;

                      final bool measuredForCurrentMonth =
                          _contentSize.height > 0 && _lastSizedMonth == month;
                      final double target = measuredForCurrentMonth
                          ? _contentSize.height
                          : estimate;
                      final double targetH = math.max(0.0, math.min(target, availableH)).toDouble();
                      return BoxConstraints(
                        minWidth: _triggerSize.width,
                        maxWidth: maxW,
                        minHeight: targetH,
                        maxHeight: targetH,
                      );
                    }(),
                    decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius: Theme.of(context)
                              .extension<ShadcnRadii>()
                              ?.md ??
                          const BorderRadius.all(Radius.circular(6)),
                      border: Border.all(color: borderColor),
                      boxShadow: shadow,
                    ),
                    child: ClipRRect(
                      borderRadius: Theme.of(context)
                              .extension<ShadcnRadii>()
                              ?.md ??
                          const BorderRadius.all(Radius.circular(6)),
                      child: CalendarRange(
                        bordered: false, // l'overlay ha già bordo/ombra
                        captionLayout: appcal.CaptionLayout.dropdown,
                        useShortMonthNames: true,
                        captionSelectSize: SelectSize.sm,
                        navButtonVariant: appcal.NavButtonVariant.ghost,
                        value: _range,
                        minDate: widget.firstDate,
                        maxDate: widget.lastDate,
                        onChanged: (r) {
                          // Mantieni l'overlay aperto: l'utente può continuare a modificare.
                          setState(() => _range = r);
                          // Forza il rebuild dell'overlay per riflettere subito la nuova selezione
                          _entry?.markNeedsBuild();
                          if (r != null && r.start != r.end) {
                            widget.onRangeSubmitted?.call(r);
                          }
                        },
                        onMonthChanged: (m) {
                          setState(() => _visibleMonth = DateTime(m.year, m.month));
                          _entry?.markNeedsBuild();
                        },
                      ),
                    ),
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
    // Attiva il backdrop dopo un breve delay per non catturare il tap di apertura
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _backdropActive = true;
      });
      _entry?.markNeedsBuild();
    });
  }

  void _removeOverlay({bool immediate = false}) async {
    if (_entry == null) return;
    if (!immediate) await _controller.reverse();
    _entry?.remove();
    _entry = null;
  }
}

// Osserva la dimensione del contenuto per allineare overlay e calcolare altezza
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