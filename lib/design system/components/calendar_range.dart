import 'package:flutter/material.dart';
import 'calendar.dart';
import '../components/select.dart';
import '../theme/themes.dart';

/// CalendarRange
///
/// Wrapper del componente Calendar per la selezione di un intervallo
/// [DateTimeRange] (start/end), analogo alla variante "mode=range" di shadcn/ui.
/// Non modifica il core Calendar: espone un'API semplificata e uno shell
/// opzionale con bordo/ombra per allinearsi allo stile "rounded-lg border shadow-sm".
class CalendarRange extends StatefulWidget {
  const CalendarRange({
    super.key,
    this.value,
    this.onChanged,
    this.defaultMonth,
    this.bordered = true,
    this.padding,
    // Passthrough delle principali opzioni del Calendar
    this.showOutsideDays = true,
    this.captionLayout = CaptionLayout.label,
    this.captionSelectSize = SelectSize.sm,
    this.useShortMonthNames = false,
    this.navButtonVariant = NavButtonVariant.outline,
    this.minDate,
    this.maxDate,
    this.locale,
    this.cellSize = 32.0,
    this.showWeekNumbers = false,
    this.firstDayOfWeek = DateTime.monday,
    this.selectableDayPredicate,
    this.headerScale = 1.0,
    this.onMonthChanged,
    this.dayBadgeCount,
  });

  /// Valore controllato dell'intervallo. Se nullo, il widget gestisce
  /// internamente lo stato (uncontrolled).
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?>? onChanged;

  /// Mese predefinito da mostrare all'apertura (tipicamente `value?.start`).
  final DateTime? defaultMonth;

  /// Se true, avvolge il calendario in un contenitore con bordo e ombra leggera.
  final bool bordered;
  final EdgeInsets? padding;

  // Passthrough props (vedi Calendar)
  final bool showOutsideDays;
  final CaptionLayout captionLayout;
  final SelectSize captionSelectSize;
  final bool useShortMonthNames;
  final NavButtonVariant navButtonVariant;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String? locale;
  final double cellSize;
  final bool showWeekNumbers;
  final int firstDayOfWeek;
  final bool Function(DateTime date)? selectableDayPredicate;
  final double headerScale;
  final ValueChanged<DateTime>? onMonthChanged;
  final int Function(DateTime)? dayBadgeCount;

  @override
  State<CalendarRange> createState() => _CalendarRangeState();
}

class _CalendarRangeState extends State<CalendarRange> {
  DateTimeRange? _internal;

  DateTimeRange? get _effectiveValue => widget.value ?? _internal;

  void _setValue(DateTimeRange? r) {
    if (widget.value == null) {
      setState(() => _internal = r);
    }
    widget.onChanged?.call(r);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final content = Calendar(
      initialMonth: widget.defaultMonth ?? _effectiveValue?.start,
      showOutsideDays: widget.showOutsideDays,
      captionLayout: widget.captionLayout,
      captionSelectSize: widget.captionSelectSize,
      useShortMonthNames: widget.useShortMonthNames,
      navButtonVariant: widget.navButtonVariant,
      selectionMode: CalendarSelectionMode.range,
      rangeValue: _effectiveValue,
      onRangeSelected: (r) => _setValue(r),
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      locale: widget.locale,
      cellSize: widget.cellSize,
      showWeekNumbers: widget.showWeekNumbers,
      firstDayOfWeek: widget.firstDayOfWeek,
      selectableDayPredicate: widget.selectableDayPredicate == null
          ? null
          : (d) => widget.selectableDayPredicate!(d),
      headerScale: widget.headerScale,
      onMonthChanged: widget.onMonthChanged,
      dayBadgeCount: widget.dayBadgeCount,
    );

    if (!widget.bordered) return content;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // ~8% black → shadow-sm
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: widget.padding ?? EdgeInsets.all(su * 2),
        child: content,
      ),
    );
  }
}