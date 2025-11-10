import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'calendar.dart' as appcal hide ShadcnRadii, ShadcnExtra;
import '../theme/themes.dart';
import 'select.dart' show SelectSize;

class AppDatePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    Locale? locale,
    String? helpText,
    String? cancelText,
    String? confirmText,
    appcal.SelectableDayPredicate? selectableDayPredicate,
  }) async {
    final l10n = MaterialLocalizations.of(context);
    final help = helpText ?? l10n.datePickerHelpText;
    final cancel = cancelText ?? l10n.cancelButtonLabel;
    final confirm = confirmText ?? l10n.okButtonLabel;

    DateTime? selected = initialDate;

    Widget dialog = _DatePickerBaseDialog(
      title: help,
      content: appcal.Calendar(
        selectionMode: appcal.CalendarSelectionMode.single,
        value: initialDate,
        minDate: firstDate,
        maxDate: lastDate,
        locale: locale?.toLanguageTag(),
        useShortMonthNames: true,
        selectableDayPredicate: selectableDayPredicate,
        captionSelectSize: SelectSize.sm,
        onDaySelected: (d) => selected = d,
      ),
      onCancel: () => Navigator.of(context).pop(null),
      onConfirm: () => Navigator.of(context).pop(selected),
      canConfirm: () => selected != null,
      cancelText: cancel,
      confirmText: confirm,
    );

    return showDialog<DateTime?>(
      context: context,
      builder: (ctx) => dialog,
    );
  }
}

class AppDateRangePicker {
  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTime firstDate,
    required DateTime lastDate,
    DateTimeRange? initialDateRange,
    Locale? locale,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) async {
    final l10n = MaterialLocalizations.of(context);
    final help = helpText ?? l10n.dateRangePickerHelpText;
    final cancel = cancelText ?? l10n.cancelButtonLabel;
    final confirm = confirmText ?? l10n.okButtonLabel;

    DateTimeRange? selected = initialDateRange;

    Widget dialog = _DatePickerBaseDialog(
      title: help,
      content: appcal.Calendar(
        selectionMode: appcal.CalendarSelectionMode.range,
        rangeValue: initialDateRange,
        minDate: firstDate,
        maxDate: lastDate,
        locale: locale?.toLanguageTag(),
        useShortMonthNames: true,
        captionSelectSize: SelectSize.sm,
        onRangeSelected: (r) => selected = r,
      ),
      onCancel: () => Navigator.of(context).pop(null),
      onConfirm: () => Navigator.of(context).pop(selected),
      canConfirm: () => selected != null && selected!.start != selected!.end,
      cancelText: cancel,
      confirmText: confirm,
    );

    return showDialog<DateTimeRange?>(
      context: context,
      builder: (ctx) => dialog,
    );
  }
}

class AppDatePickerDialog extends StatelessWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Locale? locale;
  final String? helpText;
  final String? cancelText;
  final String? confirmText;
  final appcal.SelectableDayPredicate? selectableDayPredicate;
  const AppDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.locale,
    this.helpText,
    this.cancelText,
    this.confirmText,
    this.selectableDayPredicate,
  });
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateTime?>(
      future: AppDatePicker.show(
        context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        locale: locale,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
        selectableDayPredicate: selectableDayPredicate,
      ),
      builder: (ctx, snap) {
        return const SizedBox.shrink();
      },
    );
  }
}

class AppDatePickerInput extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?>? onDateSubmitted;
  final String? label;
  // Permette di rendere il pannello/overlay più largo del trigger.
  // Esempio: 1.4 significa 140% della larghezza del trigger.
  final double overlayWidthFactor;
  const AppDatePickerInput({
    super.key,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.onDateSubmitted,
    this.label,
    // Allarga leggermente l'overlay per evitare overflow del caption (mese+anno)
    this.overlayWidthFactor = 1.4,
  });

  @override
  State<AppDatePickerInput> createState() => _AppDatePickerInputState();
}

class _AppDatePickerInputState extends State<AppDatePickerInput>
    with SingleTickerProviderStateMixin {
  DateTime? _value;
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

  // Helpers per stimare l'altezza iniziale del calendario (5/6 righe)
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
    _value = widget.initialDate;
    final DateTime base = _value ?? DateTime.now();
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

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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

    // Rimosso: placeholder non utilizzato

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
                      _value == null ? 'Seleziona data' : _fmt(_value),
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
                      // Altezza: fissa a quella del contenuto osservato.
                      // In questo modo il pannello non "cresce" o "lascia vuoti".
                      // Decidi l'altezza target basata sul mese visibile.
                      // Se la misura corrente corrisponde al mese visibile uso la misura; altrimenti la stima.
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
                      // Altezza "tight": il contenitore segue esattamente il contenuto (o la stima) del mese corrente.
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
                      child: appcal.Calendar(
                        captionLayout: appcal.CaptionLayout.dropdown,
                        useShortMonthNames: true,
                        captionSelectSize: SelectSize.sm,
                        navButtonVariant: appcal.NavButtonVariant.ghost,
                        selectionMode: appcal.CalendarSelectionMode.single,
                        value: _value ?? DateTime.now(),
                        minDate: widget.firstDate,
                        maxDate: widget.lastDate,
                        onMonthChanged: (m) {
                          // Aggiorna mese visibile e ricalcola stima immediatamente
                          setState(() {
                            _visibleMonth = DateTime(m.year, m.month);
                          });
                          _entry?.markNeedsBuild();
                        },
                        onDaySelected: (d) {
                          setState(() => _value = d);
                          widget.onDateSubmitted?.call(d);
                          _removeOverlay();
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

// Reused from select.dart to observe content size for alignment
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
    // Evita di forzare un remount dell'intero subtree ad ogni build.
    // Il remount con UniqueKey causava la ricreazione del Calendar, interrompendo
    // la propagazione degli eventi (es. onChanged del caption) e resettando lo stato.
    // Manteniamo il subtree stabile per preservare lo stato interno.
    return widget.child;
  }
}

class _DatePickerBaseDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool Function() canConfirm;
  final String cancelText;
  final String confirmText;
  const _DatePickerBaseDialog({
    required this.title,
    required this.content,
    required this.onCancel,
    required this.onConfirm,
    required this.canConfirm,
    required this.cancelText,
    required this.confirmText,
  });
  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = Theme.of(context).extension<ShadcnRadii>()?.md ?? BorderRadius.circular(8);
    return AlertDialog(
      title: Text(title),
      content: content,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      actions: [
        TextButton(onPressed: onCancel, child: Text(cancelText)),
        FilledButton(
          onPressed: canConfirm() ? onConfirm : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}
