// lib/components/calendar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'select.dart';

// Se usi Phosphor per coerenza col tuo DS, lascia questa import.
// In caso non l’avessi, puoi rimuoverla: il codice ha un fallback sulle Icons di Material.
// import 'package:phosphor_flutter/phosphor_flutter.dart';

// Opzionali: se nel tuo progetto hai le ThemeExtensions shadcn (ShadcnExtra / ShadcnRadii),
// il widget le leggerà. Altrimenti fa fallback su ColorScheme.
@immutable
class ShadcnExtra extends ThemeExtension<ShadcnExtra> {
  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarBorder;
  final Color sidebarRing;
  final Color surface;
  final Color surfaceForeground;
  const ShadcnExtra({
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarBorder,
    required this.sidebarRing,
    required this.surface,
    required this.surfaceForeground,
  });

  @override
  ShadcnExtra copyWith({
    Color? sidebar,
    Color? sidebarForeground,
    Color? sidebarPrimary,
    Color? sidebarPrimaryForeground,
    Color? sidebarAccent,
    Color? sidebarAccentForeground,
    Color? sidebarBorder,
    Color? sidebarRing,
    Color? surface,
    Color? surfaceForeground,
  }) {
    return ShadcnExtra(
      sidebar: sidebar ?? this.sidebar,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarPrimaryForeground:
          sidebarPrimaryForeground ?? this.sidebarPrimaryForeground,
      sidebarAccent: sidebarAccent ?? this.sidebarAccent,
      sidebarAccentForeground:
          sidebarAccentForeground ?? this.sidebarAccentForeground,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarRing: sidebarRing ?? this.sidebarRing,
      surface: surface ?? this.surface,
      surfaceForeground: surfaceForeground ?? this.surfaceForeground,
    );
  }

  @override
  ThemeExtension<ShadcnExtra> lerp(
      ThemeExtension<ShadcnExtra>? other, double t) {
    if (other is! ShadcnExtra) return this;
    Color lerpC(Color a, Color b) => Color.lerp(a, b, t)!;
    return ShadcnExtra(
      sidebar: lerpC(sidebar, other.sidebar),
      sidebarForeground: lerpC(sidebarForeground, other.sidebarForeground),
      sidebarPrimary: lerpC(sidebarPrimary, other.sidebarPrimary),
      sidebarPrimaryForeground:
          lerpC(sidebarPrimaryForeground, other.sidebarPrimaryForeground),
      sidebarAccent: lerpC(sidebarAccent, other.sidebarAccent),
      sidebarAccentForeground:
          lerpC(sidebarAccentForeground, other.sidebarAccentForeground),
      sidebarBorder: lerpC(sidebarBorder, other.sidebarBorder),
      sidebarRing: lerpC(sidebarRing, other.sidebarRing),
      surface: lerpC(surface, other.surface),
      surfaceForeground: lerpC(surfaceForeground, other.surfaceForeground),
    );
  }
}

@immutable
class ShadcnRadii extends ThemeExtension<ShadcnRadii> {
  final double md;
  const ShadcnRadii({required this.md});
  @override
  ShadcnRadii copyWith({double? md}) => ShadcnRadii(md: md ?? this.md);
  @override
  ThemeExtension<ShadcnRadii> lerp(
      ThemeExtension<ShadcnRadii>? other, double t) {
    if (other is! ShadcnRadii) return this;
    return ShadcnRadii(md: lerpDouble(md, other.md, t));
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

// API simile a DayPicker del TSX
enum CaptionLayout { label, dropdown }

// Variant per i bottoni di navigazione dell'header
enum NavButtonVariant { outline, ghost }

enum CalendarSelectionMode { single, range }

typedef SelectableDayPredicate = bool Function(DateTime date);

class Calendar extends StatefulWidget {
  const Calendar({
    super.key,
    this.initialMonth,
    this.showOutsideDays = true,
    this.captionLayout = CaptionLayout.label,
    this.captionSelectSize = SelectSize.sm,
    this.useShortMonthNames = false,
    this.navButtonVariant = NavButtonVariant.outline,
    this.selectionMode = CalendarSelectionMode.single,
    this.value,
    this.rangeValue,
    this.onDaySelected,
    this.onRangeSelected,
    this.minDate,
    this.maxDate,
    this.locale,
    this.cellSize = 32.0, // mappa --cell-size: spacing(8)
    this.showWeekNumbers = false,
    this.firstDayOfWeek = DateTime.monday,
    this.selectableDayPredicate,
    this.headerScale = 1.0, // fattore di scala per header (frecce + titolo)
    this.onMonthChanged,
    this.dayBadgeCount,
    this.bookedDates,
  });

  final DateTime? initialMonth;
  final bool showOutsideDays;
  final CaptionLayout captionLayout;
  // Consente di controllare la dimensione dei select Mese/Anno nel caption
  // (small nel date picker, più grande nella view calendario).
  final SelectSize captionSelectSize;
  // Variante per il nome del mese nel caption: corto (MMM) o esteso (MMMM).
  // Richiesta: nel calendario aperto dai select usare la sigla (true),
  // nella pagina calendario usare il nome esteso (false).
  final bool useShortMonthNames;
  final NavButtonVariant navButtonVariant;
  final CalendarSelectionMode selectionMode;

  // SINGLE
  final DateTime? value;
  final ValueChanged<DateTime>? onDaySelected;

  // RANGE
  final DateTimeRange? rangeValue;
  final ValueChanged<DateTimeRange>? onRangeSelected;

  final DateTime? minDate;
  final DateTime? maxDate;
  final String? locale;
  final double cellSize;
  final bool showWeekNumbers;
  final int firstDayOfWeek; // 1=Mon..7=Sun
  final SelectableDayPredicate? selectableDayPredicate;
  final double headerScale;
  final ValueChanged<DateTime>? onMonthChanged;
  // Opzionale: consente di mostrare un badge con conteggio eventi per giorno.
  // Se restituisce > 0 per una data, verrà mostrato un piccolo badge nell'angolo.
  final int Function(DateTime)? dayBadgeCount;
  // Facoltativo: giorni "prenotati" (non selezionabili) mostrati con testo barrato
  // e senza desaturazione (opacity piena). Se presenti, verranno anche trattati
  // come disabled ai fini del tap.
  final List<DateTime>? bookedDates;

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late DateTime _visibleMonth;
  // Rimosso: variabile non utilizzata

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      (widget.initialMonth ??
              widget.value ??
              widget.rangeValue?.start ??
              DateTime.now())
          .year,
      (widget.initialMonth ??
              widget.value ??
              widget.rangeValue?.start ??
              DateTime.now())
          .month,
    );
    // Notifica mese visibile iniziale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMonthChanged?.call(_visibleMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    // build
    final scheme = Theme.of(context).colorScheme;
    final extra = Theme.of(context).extension<ShadcnExtra>();
    final radii = Theme.of(context).extension<ShadcnRadii>();

    final primary = scheme.primary;
    final onPrimary = scheme.onPrimary;
    final accent = scheme.surfaceContainerHighest; // usato come "accent" shadcn
    final onAccent = scheme.onSurfaceVariant.withValues(alpha: 0.9);
    final ring = extra?.sidebarRing ?? scheme.primary.withValues(alpha: 0.5);
    final border = extra?.sidebarBorder ?? scheme.outlineVariant;
    final mutedFg = scheme.onSurface.withValues(alpha: 0.6);
    final radius = (radii?.md ?? 8.0);

    // Default alla locale italiana se non specificata, per sigle mesi in italiano
    final localeName = widget.locale ?? 'it';
    final l10n = MaterialLocalizations.of(context);
    final monthFmt = DateFormat.MMMM(localeName);
    final shortMonthFmt = DateFormat.MMM(localeName);
    final weekdayShort = DateFormat.E(localeName);

    final days =
        _daysForMonth(_visibleMonth, firstDayOfWeek: widget.firstDayOfWeek);
    final weekNumbers = _computeWeekNumbers(days);
    final weekCount = days.length ~/ 7;

    final headerH = widget.cellSize * widget.headerScale;

    return Semantics(
      label: 'Calendar',
      child: Container(
        // bg-background + p-3
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            // NAV (assoluto top-0 inset-x-0, justify-between)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavIconButton(
                icon: Icons.chevron_left, // fallback; vedi commento su Phosphor
                tooltip: l10n.previousMonthTooltip,
                size: headerH,
                ring: ring,
                border: border,
                variant: widget.navButtonVariant,
                onTap: _goPrevMonth,
              ),
              _MonthCaption(
                month: _visibleMonth,
                layout: widget.captionLayout,
                onChanged: (y, m) {
                  if (!mounted) return;
                  try {
                    setState(() {
                      _visibleMonth = DateTime(y, m);
                    });
                    widget.onMonthChanged?.call(_visibleMonth);
                  } catch (e, st) {
                    // Se qualcosa va storto, log leggero in debug
                    debugPrint('[Calendar] setState error: $e\n$st');
                  }
                },
                monthFmt: monthFmt,
                shortMonthFmt: shortMonthFmt,
                useShortNames: widget.useShortMonthNames,
                cellHeight: headerH,
                textColor: Theme.of(context).colorScheme.onSurface,
                border: border,
                ring: ring,
                radius: radius,
                minDate: widget.minDate,
                maxDate: widget.maxDate,
                selectSize: widget.captionSelectSize,
              ),
              _NavIconButton(
                icon: Icons.chevron_right,
                tooltip: l10n.nextMonthTooltip,
                size: headerH,
                ring: ring,
                border: border,
                variant: widget.navButtonVariant,
                onTap: _goNextMonth,
              ),
            ],
          ),
        ),

            // Contenuto (mesi, tabella)
            Padding(
              padding: EdgeInsets.only(
                  top: headerH + 8), // spazio per la nav
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Weekdays header
                  Row(
                    children: [
                      if (widget.showWeekNumbers)
                        SizedBox(
                          width: widget.cellSize,
                          height: widget.cellSize,
                          child: const SizedBox.shrink(),
                        ),
                      ...List.generate(7, (i) {
                        final weekday =
                            ((widget.firstDayOfWeek + i - 1) % 7) + 1;
                        final date = _firstWeekdayDate(weekday);
                        final label = weekdayShort.format(date);
                        return Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            height: widget.cellSize,
                            child: Text(
                              label,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: mutedFg,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  // Weeks (dinamico: 5 o 6 righe in base al mese)
                  ...List.generate(weekCount, (wi) {
                    final rowDays = days.skip(wi * 7).take(7).toList();
                    final wn = weekNumbers[wi];
                    return SizedBox(
                      height: widget.cellSize + 8,
                      child: Row(
                        children: [
                          if (widget.showWeekNumbers)
                            SizedBox(
                              width: widget.cellSize,
                              child: Center(
                                child: Text(
                                  '$wn',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: mutedFg,
                                      ),
                                ),
                              ),
                            ),
                          ...List.generate(7, (di) {
                            final d = rowDays[di];
                            final isOutside = d.month != _visibleMonth.month;
                            if (isOutside && !widget.showOutsideDays) {
                              return Expanded(
                                  child: SizedBox(height: widget.cellSize));
                            }

                          final isDisabled = (widget.minDate != null &&
                                  d.isBefore(_stripTime(widget.minDate!))) ||
                              (widget.maxDate != null &&
                                  d.isAfter(_stripTime(widget.maxDate!))) ||
                              (widget.selectableDayPredicate != null &&
                                    !widget.selectableDayPredicate!(d)) ||
                              (widget.bookedDates?.any((bd) => _isSameDate(bd, d)) ?? false);

                            final isToday = _isSameDate(d, DateTime.now());
                            final selSingle = widget.selectionMode ==
                                    CalendarSelectionMode.single &&
                                widget.value != null &&
                                _isSameDate(widget.value!, d);

                            final selRange = widget.selectionMode ==
                                    CalendarSelectionMode.range &&
                                widget.rangeValue != null &&
                                !_isBefore(d, widget.rangeValue!.start) &&
                                !_isAfter(d, widget.rangeValue!.end);

                            final isRangeStart = widget.selectionMode ==
                                    CalendarSelectionMode.range &&
                                widget.rangeValue != null &&
                                _isSameDate(d, widget.rangeValue!.start);
                            final isRangeEnd = widget.selectionMode ==
                                    CalendarSelectionMode.range &&
                                widget.rangeValue != null &&
                                _isSameDate(d, widget.rangeValue!.end);

                            final bg = () {
                              if (selSingle) return primary;
                              if (isRangeStart || isRangeEnd) return primary;
                              if (selRange) return accent;
                              if (isToday) return accent;
                              return Colors.transparent;
                            }();

                            final fg = () {
                              if (selSingle) return onPrimary;
                              if (isRangeStart || isRangeEnd) return onPrimary;
                              if (selRange) return onAccent;
                              if (isToday) return onAccent;
                              return Theme.of(context).colorScheme.onSurface;
                            }();

                            BorderRadius? br;
                            if (isRangeStart && isRangeEnd) {
                              // Intervallo di un solo giorno: pill arrotondata
                              br = BorderRadius.circular(radius);
                            } else if (selRange && !isRangeStart && !isRangeEnd) {
                              // Giorni intermedi del range: barra continua senza arrotondamenti
                              br = BorderRadius.zero;
                            } else if (isRangeStart) {
                              // Inizio intervallo: pill piena arrotondata (non tagliata)
                              br = BorderRadius.circular(radius);
                            } else if (isRangeEnd) {
                              // Fine intervallo: pill piena arrotondata (non tagliata)
                              br = BorderRadius.circular(radius);
                            } else if (selSingle || isToday) {
                              br = BorderRadius.circular(radius);
                            }

                            // Se la data è "booked" (disabilitata ma con stile barrato),
                            // non applicare il muted.
                            final bool isBooked = widget.bookedDates?.any((bd) => _isSameDate(bd, d)) ?? false;
                            final showMuted = isOutside || (isDisabled && !isBooked);
                            final mutedColor = Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.6);

                            final badgeCount = widget.dayBadgeCount?.call(d);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _CalendarDayButton(
                                  date: d,
                                  size: widget.cellSize,
                                  background: bg,
                                  foreground: showMuted ? mutedColor ?? fg : fg,
                                  borderRadius: br,
                                  ring: ring,
                                  isDisabled: isDisabled,
                                  isFocused:
                                      false, // focus ring simulabile se ti serve con roving focus
                                  badgeCount: badgeCount,
                                  textDecoration: isBooked ? TextDecoration.lineThrough : null,
                                  onTap: isDisabled
                                      ? null
                                      : () {
                                          if (widget.selectionMode ==
                                              CalendarSelectionMode.single) {
                                            widget.onDaySelected?.call(d);
                                          } else {
                                            final current = widget.rangeValue;
                                            if (current == null) {
                                              // Primo click: inizia nuovo intervallo
                                              widget.onRangeSelected?.call(
                                                DateTimeRange(start: d, end: d),
                                              );
                                            } else if (current.start == current.end) {
                                              // Secondo click: completa l'intervallo
                                              final start = _isBefore(d, current.start)
                                                  ? d
                                                  : current.start;
                                              final end = _isBefore(d, current.start)
                                                  ? current.start
                                                  : d;
                                              widget.onRangeSelected?.call(
                                                DateTimeRange(start: start, end: end),
                                              );
                                            } else {
                                              // Intervallo già completo
                                              // Se il giorno cliccato è prima dello start → reset e nuova selezione
                                              // Se è uguale o dopo lo start → aggiorna la data di fine
                                              if (_isBefore(d, current.start)) {
                                                widget.onRangeSelected?.call(
                                                  DateTimeRange(start: d, end: d),
                                                );
                                              } else {
                                                widget.onRangeSelected?.call(
                                                  DateTimeRange(start: current.start, end: d),
                                                );
                                              }
                                            }
                                          }
                                        },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goPrevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
    widget.onMonthChanged?.call(_visibleMonth);
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
    widget.onMonthChanged?.call(_visibleMonth);
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.ring,
    required this.border,
    this.variant = NavButtonVariant.outline,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final double size;
  final Color ring;
  final Color border;
  final NavButtonVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final btnSize = size;
    return Semantics(
      button: true,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: btnSize,
            width: btnSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // ghost: niente bordo; outline: bordo sottile
              border: variant == NavButtonVariant.outline
                  ? Border.all(color: border)
                  : null,
              color: variant == NavButtonVariant.ghost
                  ? Colors.transparent
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }
}

class _MonthCaption extends StatelessWidget {
  const _MonthCaption({
    required this.month,
    required this.layout,
    required this.onChanged,
    required this.monthFmt,
    required this.shortMonthFmt,
    required this.useShortNames,
    required this.cellHeight,
    required this.textColor,
    required this.border,
    required this.ring,
    required this.radius,
    this.minDate,
    this.maxDate,
    this.selectSize = SelectSize.sm,
  });

  final DateTime month;
  final CaptionLayout layout;
  final void Function(int year, int month) onChanged;
  final DateFormat monthFmt;
  final DateFormat shortMonthFmt;
  final bool useShortNames;
  final double cellHeight;
  final Color textColor;
  final Color border;
  final Color ring;
  final double radius;
  final DateTime? minDate;
  final DateTime? maxDate;
  final SelectSize selectSize;

  @override
  Widget build(BuildContext context) {
    if (layout == CaptionLayout.dropdown) {
      // Anni: sempre dall'anno corrente fino a 100 anni indietro.
      // Richiesta: ignoriamo min/max qui e usiamo range fisso [now.year .. now.year-100].
      final int currentYear = DateTime.now().year;
      final int startYear = currentYear;
      final int endYear = currentYear - 100;
      final int count = (startYear - endYear) + 1;
      final years = List.generate(count, (i) => startYear - i);
      final months = List.generate(12, (i) => i + 1);
      return SizedBox(
        height: cellHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiniField<int>(
              value: month.month,
              items: months,
              // Usa sigla (MMM) quando richiesto, altrimenti nome esteso (MMMM).
              labelBuilder: (m) {
                final df = useShortNames ? shortMonthFmt : monthFmt;
                final raw = df.format(DateTime(2024, m, 1));
                return raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';
              },
              onChanged: (m) {
                onChanged(month.year, m);
              },
              border: border,
              ring: ring,
              radius: radius,
              size: selectSize,
              groupLabel: 'Mese',
            ),
            const SizedBox(width: 6),
            _MiniField<int>(
              value: month.year,
              items: years,
              labelBuilder: (y) => y.toString(),
              onChanged: (y) {
                onChanged(y, month.month);
              },
              border: border,
              ring: ring,
              radius: radius,
              size: selectSize,
              groupLabel: 'Anno',
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: cellHeight,
      child: Center(
        child: Text(
          '${(useShortNames ? shortMonthFmt : monthFmt).format(month)} ${month.year}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
        ),
      ),
    );
  }
}

class _MiniField<T> extends StatelessWidget {
  const _MiniField({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    required this.border,
    required this.ring,
    required this.radius,
    this.size = SelectSize.sm,
    this.groupLabel = '',
    this.width,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final Color border;
  final Color ring;
  final double radius;
  final SelectSize size;
  final String groupLabel;
  final double? width;

  @override
  Widget build(BuildContext context) {
    // Usa il select della design system al posto del DropdownButton,
    // così il menu si apre correttamente anche dentro overlay nidificati.
    final groups = [
      SelectGroupData(
        label: groupLabel.isEmpty ? ' ' : groupLabel,
        items: items
            .map((e) => SelectItemData(
                  value: e.toString(),
                  label: labelBuilder(e),
                ))
            .toList(),
      ),
    ];

    String? current = value.toString();

    // Misura dinamicamente la larghezza del testo corrente per adattare il trigger
    // (small: font 12, weight 500; medium: font 14, weight 500)
    double measureTextWidth(String text) {
      final bool isMd = size == SelectSize.md;
      final textStyle = (isMd
              ? Theme.of(context).textTheme.bodyMedium
              : Theme.of(context).textTheme.bodySmall)
          ?.copyWith(
            fontSize: isMd ? 14 : 12,
            fontWeight: FontWeight.w500,
          ) ??
          TextStyle(fontSize: isMd ? 14 : 12, fontWeight: FontWeight.w500);
      final tp = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout();
      return tp.size.width;
    }

    final currentLabel = labelBuilder(value);
    final textW = measureTextWidth(currentLabel);
    final bool isMd = size == SelectSize.md;
    final horizontalPadding = (isMd ? 12.0 : 10.0) * 2; // px
    final double caret = isMd ? 16.0 : 14.0;
    final double gap = isMd ? 6.0 : 4.0;
    final dynamicWidth = textW + horizontalPadding + caret + gap;
    // Larghezza extra: più ampia per md per mostrare label estese (es. "Novembre")
    final double widenExtra = isMd ? 16.0 : 8.0; // px
    final double effectiveWidth = dynamicWidth + widenExtra;

    // Diagnostica: mostra i valori correnti passati al trigger/select (solo in debug)
    assert(() {
      debugPrint('[Calendar] _MiniField build group="$groupLabel" label="$currentLabel" raw="$current"');
      return true;
    }());

    return AppSelect(
      groups: groups,
      value: current,
      width: width ?? effectiveWidth,
      overlayWidthFactor: 1.2,
      size: size,
      onChanged: (v) {
        // Converte indietro a T; attualmente usiamo int per mese/anno.
        T parsed;
        if (T == int) {
          parsed = int.parse(v) as T;
        } else {
          parsed = v as T;
        }
        // Logging semplice per diagnosi dei tap su mese/anno (solo in debug)
        assert(() {
          debugPrint('[Calendar] _MiniField onChanged → $parsed');
          return true;
        }());
        try {
          onChanged(parsed);
          assert(() {
            debugPrint('[Calendar] _MiniField → parent onChanged invoked successfully');
            return true;
          }());
        } catch (e, st) {
          debugPrint('[Calendar] _MiniField → parent onChanged error: $e\n$st');
        }
      },
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.date,
    required this.size,
    required this.background,
    required this.foreground,
    required this.borderRadius,
    required this.ring,
    required this.isDisabled,
    required this.isFocused,
    required this.onTap,
    this.badgeCount,
    this.textDecoration,
  });

  final DateTime date;
  final double size;
  final Color background;
  final Color foreground;
  final BorderRadius? borderRadius;
  final Color ring;
  final bool isDisabled;
  final bool isFocused;
  final VoidCallback? onTap;
  final int? badgeCount;
  final TextDecoration? textDecoration;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);

    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            boxShadow: isFocused
                ? [
                    // group-data-[focused=true]/day:ring-[3px] approx
                    BoxShadow(
                      color: ring.withValues(alpha: 0.5),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: SizedBox(
              height: size,
              width: double.infinity,
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w500,
                            decoration: textDecoration,
                          ),
                    ),
                  ),
                  if ((badgeCount ?? 0) > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${badgeCount ?? 0}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------- Helpers --------

List<DateTime> _daysForMonth(DateTime base,
    {int firstDayOfWeek = DateTime.monday}) {
  final firstOfMonth = DateTime(base.year, base.month, 1);
  final int shift = (firstOfMonth.weekday - firstDayOfWeek + 7) % 7;
  final start = firstOfMonth.subtract(Duration(days: shift));
  // ultimo giorno del mese corrente
  final lastOfMonth = DateTime(base.year, base.month + 1, 0);
  // giorni necessari per completare l'ultima settimana
  final int tail = ((firstDayOfWeek + 6) - lastOfMonth.weekday + 7) % 7;
  final int daysInMonth = lastOfMonth.day;
  final int total = shift + daysInMonth + tail;
  // numero di settimane: evita 4 righe (usa minimo 5) e massimo 6
  int weekCount = (total / 7).ceil();
  if (weekCount < 5) weekCount = 5;
  if (weekCount > 6) weekCount = 6;
  final int len = weekCount * 7;
  return List.generate(len, (i) => DateTime(start.year, start.month, start.day + i));
}

List<int> _computeWeekNumbers(List<DateTime> days) {
  // ISO week number approx; per una preview basta il numero della settimana dell’inizio riga.
  final weekCount = days.length ~/ 7;
  return List.generate(weekCount, (w) => _isoWeekNumber(days[w * 7]));
}

int _isoWeekNumber(DateTime date) {
  // approssimazione ISO-8601
  final thursday =
      date.add(Duration(days: (DateTime.thursday - date.weekday + 7) % 7));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week1 = firstThursday
      .add(Duration(days: -(firstThursday.weekday - DateTime.thursday)));
  return (thursday.difference(week1).inDays ~/ 7) + 1;
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool _isBefore(DateTime a, DateTime b) =>
    a.isBefore(DateTime(b.year, b.month, b.day));
bool _isAfter(DateTime a, DateTime b) =>
    a.isAfter(DateTime(b.year, b.month, b.day));
DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _firstWeekdayDate(int weekday) {
  // restituisce una data fittizia con quel weekday
  final now = DateTime.now();
  final diff = (weekday - now.weekday) % 7;
  return now.add(Duration(days: diff));
}
