import 'package:flutter/material.dart';
import 'calendar.dart' as appcal;
import 'button.dart';

/// Calendar with time presets (shadcn/ui parity)
/// - Colonna sinistra: calendario single-date
/// - Colonna destra: lista di slot orari (15 minuti) con selezione
/// - Footer: riepilogo + Continue button
class CalendarWithTimePresets extends StatefulWidget {
  const CalendarWithTimePresets({
    super.key,
    this.initialDate,
    this.startHour = const TimeOfDay(hour: 9, minute: 0),
    this.slotCount = 37,
    this.slotStepMinutes = 15,
    this.bookedDates,
    this.onSubmit,
    this.onChanged,
    this.showFooter = true,
    this.timePanelWidth,
    this.showSubmitButton = true,
    this.summaryBuilder,
  });

  final DateTime? initialDate;
  final TimeOfDay startHour;
  final int slotCount; // 37 come nel riferimento
  final int slotStepMinutes; // 15 minuti
  final List<DateTime>? bookedDates; // giorni da disabilitare (barrati)
  final void Function(DateTime date, String time)? onSubmit;
  /// Callback per notificare cambi di selezione (data o orario). Utile per integrazione in dialog esterni.
  final void Function(DateTime? date, String? time)? onChanged;
  /// Mostra/nasconde il footer interno con riepilogo e pulsante "Continue".
  final bool showFooter;
  /// Larghezza della colonna degli slot orari (default 192). Utile per prevenire overflow in dialog stretti.
  final double? timePanelWidth;
  /// Mostra il pulsante di submit nel footer (default true). In un dialog esterno può essere disattivato.
  final bool showSubmitButton;
  /// Permette di personalizzare il testo di riepilogo nel footer.
  /// Se non fornito, viene usato un testo di default in inglese.
  final String Function(DateTime? date, String? time)? summaryBuilder;

  @override
  State<CalendarWithTimePresets> createState() => _CalendarWithTimePresetsState();
}

class _CalendarWithTimePresetsState extends State<CalendarWithTimePresets> {
  late DateTime? _date = widget.initialDate ?? DateTime.now();
  String? _selectedTime = '10:00';
  final GlobalKey _calendarKey = GlobalKey();
  double? _leftPanelHeight; // altezza misurata del pannello calendario

  @override
  void initState() {
    super.initState();
    // Post frame per misurare l'altezza del calendario e vincolare la colonna degli slot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = _calendarKey.currentContext?.size;
      if (size != null && mounted) {
        setState(() {
          _leftPanelHeight = size.height;
        });
      }
    });
    // Notifica stato iniziale se richiesto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged?.call(_date, _selectedTime);
    });
  }

  List<String> _generateSlots() {
    return List.generate(widget.slotCount, (i) {
      final totalMinutes = i * widget.slotStepMinutes;
      final hour = widget.startHour.hour + (totalMinutes ~/ 60);
      final minute = totalMinutes % 60;
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m';
    });
  }

  bool _isBooked(DateTime d) {
    final bd = widget.bookedDates ?? const [];
    return bd.any((x) => x.year == d.year && x.month == d.month && x.day == d.day);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = cs.outline;
    final radius = BorderRadius.circular(12);
    final isMd = MediaQuery.of(context).size.width >= 768; // approx md breakpoint

    final slots = _generateSlots();

    final card = Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content area: responsive
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: isMd
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar area (left) prende tutto lo spazio rimanente
                      Expanded(
                        child: Container(
                          key: _calendarKey,
                          padding: const EdgeInsets.all(24),
                          child: appcal.Calendar(
                            selectionMode: appcal.CalendarSelectionMode.single,
                            value: _date,
                            initialMonth: _date,
                            showOutsideDays: true,
                            navButtonVariant: appcal.NavButtonVariant.ghost,
                            bookedDates: widget.bookedDates,
                            selectableDayPredicate: (d) => !_isBooked(d),
                            onDaySelected: (d) => setState(() {
                              _date = d;
                              widget.onChanged?.call(_date, _selectedTime);
                            }),
                            headerScale: 1.0,
                            cellSize: 52,
                          ),
                        ),
                      ),
                      // Time slots (right) larghezza configurabile (default 192 px)
                      Container(
                        width: widget.timePanelWidth ?? 192,
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: borderColor, width: 1)),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Vincolo di altezza massimo uguale al pannello di sinistra
                            maxHeight: (_leftPanelHeight ?? 360),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ScrollConfiguration(
                              behavior: const ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ...slots.map((time) {
                                      final selected = _selectedTime == time;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: AppButton(
                                          variant: selected ? AppButtonVariant.default_ : AppButtonVariant.outline,
                                          onPressed: () => setState(() {
                                            _selectedTime = time;
                                            widget.onChanged?.call(_date, _selectedTime);
                                          }),
                                          child: Text(time),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: appcal.Calendar(
                          selectionMode: appcal.CalendarSelectionMode.single,
                          value: _date,
                          initialMonth: _date,
                          showOutsideDays: true,
                          navButtonVariant: appcal.NavButtonVariant.ghost,
                          bookedDates: widget.bookedDates,
                          selectableDayPredicate: (d) => !_isBooked(d),
                          onDaySelected: (d) => setState(() {
                            _date = d;
                            widget.onChanged?.call(_date, _selectedTime);
                          }),
                          headerScale: 1.0,
                          cellSize: 44,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: borderColor, width: 1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ScrollConfiguration(
                            behavior: const ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...slots.map((time) {
                                    final selected = _selectedTime == time;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: AppButton(
                                        variant: selected ? AppButtonVariant.default_ : AppButtonVariant.outline,
                                        onPressed: () => setState(() {
                                          _selectedTime = time;
                                          widget.onChanged?.call(_date, _selectedTime);
                                        }),
                                        child: Text(time),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          // Footer (opzionale)
          if (widget.showFooter)
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final summaryText = widget.summaryBuilder != null
                    ? widget.summaryBuilder!.call(_date, _selectedTime)
                    : (() {
                        if (_date != null && _selectedTime != null) {
                          final w = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][_date!.weekday % 7];
                          final monthName = [
                            'January','February','March','April','May','June','July','August','September','October','November','December'
                          ][_date!.month - 1];
                          return 'Your meeting is booked for $w, ${_date!.day} $monthName at ${_selectedTime!}.';
                        }
                        return 'Select a date and time for your meeting.';
                      })();
                // Non usare Expanded dentro una Column a altezza non vincolata.
                // Creiamo un Text base e lo wrappiamo con Expanded solo nel layout a riga.
                final summaryTextWidget = Text(
                  summaryText,
                  style: Theme.of(context).textTheme.bodyMedium,
                );
                final buttonWidget = widget.showSubmitButton
                    ? AppButton(
                        variant: AppButtonVariant.outline,
                        enabled: _date != null && _selectedTime != null,
                        onPressed: (_date != null && _selectedTime != null)
                            ? () => widget.onSubmit?.call(_date!, _selectedTime!)
                            : null,
                        label: 'Continue',
                      )
                    : const SizedBox.shrink();

                return Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor, width: 1))),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: wide
                      ? Row(children: [Expanded(child: summaryTextWidget), const SizedBox(width: 16), if (widget.showSubmitButton) buttonWidget])
                      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [summaryTextWidget, if (widget.showSubmitButton) const SizedBox(height: 12), if (widget.showSubmitButton) buttonWidget]),
                );
              },
            ),
        ],
      ),
    );

    return card;
  }
}