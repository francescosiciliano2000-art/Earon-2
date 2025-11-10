import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'button.dart';
import 'separator.dart';
import '../theme/theme_builder.dart';
import '../theme/themes.dart';
import '../icons/app_icons.dart';

/// AppCombobox (shadcn/ui parity-style)
/// - Trigger: AppButton (outline) con etichetta e icona chevrons
/// - Popover: contenitore con input di ricerca e lista filtrabile
/// - Selezione: aggiorna il valore e chiude il popover; riclick sullo stesso valore lo deseleziona
///
/// Nota: usa OverlayEntry con CompositedTransformTarget/Follower per un posizionamento preciso.
class ComboboxItem {
  const ComboboxItem({required this.value, required this.label});
  final String value;
  final String label;
}

/// Raggruppo di item per AppCombobox (es. per regione)
class ComboboxGroupData {
  final String label;
  final List<ComboboxItem> items;
  const ComboboxGroupData({required this.label, required this.items});
}

class AppCombobox extends StatefulWidget {
  const AppCombobox({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.onQueryChanged,
    this.placeholder = 'Select…',
    this.width = 200,
    this.buttonVariant = AppButtonVariant.outline,
    this.emptyLabel = 'Nessun risultato',
    this.searchHintText = 'Cerca…',
    this.popoverWidthFactor = 1.0,
    this.groups,
    this.popoverMatchWidestRow = false,
  });

  final List<ComboboxItem> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  // Callback opzionale per ricerca lato chiamante (server-side o async)
  final ValueChanged<String>? onQueryChanged;
  final String placeholder;
  final double width;
  final AppButtonVariant buttonVariant;
  // Testo mostrato quando il filtro non trova elementi
  final String emptyLabel;
  // Testo della hint del campo di ricerca interno
  final String searchHintText;
  // Fattore di larghezza del popover rispetto al trigger (es. 1.6 = +60%)
  final double popoverWidthFactor;
  // Opzionale: fornisci gruppi di elementi (es. regioni)
  final List<ComboboxGroupData>? groups;
  // Se true, la larghezza del popover corrisponde alla riga con etichetta più larga
  final bool popoverMatchWidestRow;

  @override
  State<AppCombobox> createState() => _AppComboboxState();
}

class _AppComboboxState extends State<AppCombobox> {
  final LayerLink _link = LayerLink();
  // Key per misurare correttamente dimensione e posizione del trigger.
  // Evita di usare il contesto dell'Overlay per recuperare RenderBox,
  // che porta a misure errate (schermo intero).
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _backdropEntry;
  OverlayEntry? _popoverEntry;
  bool _open = false;
  String _query = '';

  // Utility: ottieni lista piatta filtrata degli item da mostrare
  List<(String value, String label, bool isGroupHeader)> _visibleFlatItems() {
    final String q = _query.trim().toLowerCase();
    // Se gruppi sono forniti, includi intestazioni e filtra item per query.
    if (widget.groups != null && widget.groups!.isNotEmpty) {
      final List<(String, String, bool)> out = [];
      for (final g in widget.groups!) {
        final filtered = g.items.where((it) {
          if (q.isEmpty) return true;
          return it.label.toLowerCase().contains(q);
        }).toList();
        if (filtered.isEmpty) continue;
        // intestazione gruppo
        out.add(('', g.label, true));
        // items del gruppo
        out.addAll(filtered.map((it) => (it.value, it.label, false)));
      }
      return out;
    }
    // Altrimenti usa items flat
    final items = widget.items.where((it) {
      if (q.isEmpty) return true;
      return it.label.toLowerCase().contains(q);
    }).map((it) => (it.value, it.label, false)).toList();
    return items;
  }

  @override
  void dispose() {
    _removeEntries();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppCombobox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se il popover è aperto e cambiano gli items, pianifichiamo il rebuild
    // post‑frame per evitare "markNeedsBuild during build".
    if (_open && _popoverEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popoverEntry?.markNeedsBuild();
      });
    }
  }

  void _removeEntries() {
    _popoverEntry?.remove();
    _popoverEntry = null;
    _backdropEntry?.remove();
    _backdropEntry = null;
  }

  void _setOpen(bool value) {
    if (value == _open) return;
    setState(() {
      _open = value;
      // Reset della query per evitare che il filtro persista.
      _query = '';
    });
    if (_open) {
      _showPopover();
    } else {
      _removeEntries();
    }
  }

  void _showPopover() {
    final tokens = context.tokens;

    _backdropEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _setOpen(false),
        child: Container(color: Colors.transparent),
      ),
    );

    _popoverEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Stack(children: [
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            // Calcolo dinamico di offset e dimensioni ad ogni rebuild
            offset: () {
              // Usa il RenderBox del trigger (tramite _triggerKey),
              // non quello dell'Overlay, per evitare misure sballate.
              final renderBox = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox == null) return const Offset(0, 36);
              final screenWidth = MediaQuery.of(context).size.width;
              final targetTopLeft = renderBox.localToGlobal(Offset.zero);
              final targetLeft = targetTopLeft.dx;
              final triggerWidth = renderBox.size.width;
              // Larghezza desiderata del popover
              final desiredWidth = _computePopoverWidth(context, triggerWidth, screenWidth);
              const double kMargin = 12.0;
              final availableRight = screenWidth - targetLeft - kMargin;
              double offsetX;
              if (desiredWidth > availableRight) {
                offsetX = -(desiredWidth - availableRight);
              } else {
                offsetX = 0.0;
              }
              return Offset(offsetX, 36);
            }(),
            child: Material(
              elevation: 0,
              color: Colors.transparent,
              child: Container(
                width: () {
                  final renderBox = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox == null) return widget.width;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final triggerWidth = renderBox.size.width;
                  return _computePopoverWidth(context, triggerWidth, screenWidth);
                }(),
                // L'altezza del popover si adatta al contenuto, con un massimo.
                constraints: () {
                  final renderBox = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox == null) return const BoxConstraints(maxHeight: 320);
                  final screenHeight = MediaQuery.of(context).size.height;
                  final targetTopLeft = renderBox.localToGlobal(Offset.zero);
                  final targetBottom = targetTopLeft.dy + renderBox.size.height;
                  const double kOffsetY = 36.0;
                  final availableBelow = screenHeight - (targetBottom + kOffsetY) - 12;
                  final maxH = availableBelow.clamp(100.0, 320.0);
                  // Imposta anche una altezza minima per evitare il "collasso"
                  // quando la lista è molto filtrata. Rispetta lo spazio disponibile.
                  final minH = math.max(0.0, math.min(availableBelow, 140.0));
                  return BoxConstraints(minHeight: minH, maxHeight: maxH);
                }(),
                decoration: BoxDecoration(
                  // Usa i token popover per allineare lo stile a shadcn/ui
                  color: tokens.popover,
                  border: Border.all(color: tokens.border, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search input
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 32,
                            child: Center(
                              child: Icon(
                                AppIcons.search,
                                size: 16,
                                color: tokens.popoverForeground.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Search inline senza bordo né sfondo
                          const _SearchFieldSpacer(),
                          Expanded(
                            child: _SearchField(
                              hintText: widget.searchHintText,
                              height: 32,
                              verticalOffset: 0.70,
                              onChanged: (v) {
                                setState(() => _query = v);
                                _popoverEntry?.markNeedsBuild();
                                // Propaga la query al chiamante (se fornita)
                                widget.onQueryChanged?.call(v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Separator tra input e lista
                    const AppSeparator(orientation: Axis.horizontal, thickness: 1.0),
                    // Items list — si adatta al contenuto, con max 320px
                    Flexible(
                      child: ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: _buildItems(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(_backdropEntry!);
    overlay.insert(_popoverEntry!);
  }

  List<Widget> _buildItems() {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isDark = theme.brightness == Brightness.dark;
    final items = _visibleFlatItems();

    final current = widget.value;

    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.emptyLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }
    final List<Widget> out = [];
    for (final (value, label, isHeader) in items) {
      if (isHeader) {
        out.add(_ComboboxGroupHeader(label: label));
        continue;
      }
      final selected = value == current;
      out.add(_ComboboxListItem(
        label: label,
        selected: selected,
        onTap: () {
          final next = selected ? null : value;
          widget.onChanged?.call(next);
          _setOpen(false);
        },
        hoverBg: isDark
            ? tokens.input.withValues(alpha: 0.30)
            : tokens.accent,
        textColor: tokens.popoverForeground,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = () {
      final v = widget.value;
      if (v == null || v.isEmpty) return widget.placeholder;
      // Cerca nei gruppi, poi negli items flat
      if (widget.groups != null && widget.groups!.isNotEmpty) {
        for (final g in widget.groups!) {
          final match = g.items.firstWhere(
            (it) => it.value == v,
            orElse: () => const ComboboxItem(value: '', label: ''),
          );
          if (match.value.isNotEmpty) return match.label;
        }
      }
      final match = widget.items.firstWhere(
        (it) => it.value == v,
        orElse: () => ComboboxItem(value: v, label: v),
      );
      return match.label;
    }();

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        key: _triggerKey,
        width: widget.width,
        height: 36, // allinea alla height del range picker
        child: AppButton(
          variant: widget.buttonVariant,
          onPressed: () => _setOpen(!_open),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              Icon(Icons.unfold_more, color: cs.onSurface.withValues(alpha: 0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Intestazione di gruppo (es. Regione)
class _ComboboxGroupHeader extends StatelessWidget {
  final String label;
  const _ComboboxGroupHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tokens.popoverForeground.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Calcola la larghezza desiderata del popover:
// - Se popoverMatchWidestRow: misura la larghezza massima delle righe visibili
// - Altrimenti: usa triggerWidth * popoverWidthFactor
double _measureTextWidth(BuildContext context, String text, TextStyle? style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(minWidth: 0, maxWidth: double.infinity);
  return tp.size.width;
}

extension on _AppComboboxState {
  double _computePopoverWidth(BuildContext context, double triggerWidth, double screenWidth) {
    if (!widget.popoverMatchWidestRow) {
      final desired = (triggerWidth * widget.popoverWidthFactor)
          .clamp(triggerWidth, screenWidth - 24.0);
      return desired;
    }
    // Misura la riga più larga tra gli elementi visibili (escludendo intestazioni)
    final items = _visibleFlatItems().where((e) => !e.$3).toList();
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    double maxLabel = 0.0;
    for (final e in items) {
      final w = _measureTextWidth(context, e.$2, textStyle);
      if (w > maxLabel) maxLabel = w;
    }
    // Larghezza riga = margin(6*2) + padding(10*2) + label + spazio icona(16 + 8)
    const double margins = 12.0;
    const double paddings = 20.0;
    const double iconSpace = 24.0; // icona 16 + gap 8
    final rowWidth = maxLabel + margins + paddings + iconSpace;
    final desired = rowWidth.clamp(triggerWidth, screenWidth - 24.0);
    return desired;
  }
}

/// Item della lista con stato di hover esplicito (senza ripple) e checkmark a destra.
class _ComboboxListItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color hoverBg;
  final Color textColor;
  const _ComboboxListItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.hoverBg,
    required this.textColor,
  });

  @override
  State<_ComboboxListItem> createState() => _ComboboxListItemState();
}

class _ComboboxListItemState extends State<_ComboboxListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<ShadcnRadii>();
    final bg = _hovered ? widget.hoverBg : Colors.transparent;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: widget.textColor);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          // Margine coerente con Select: restringe l'hover rispetto al pannello
          margin: const EdgeInsets.symmetric(horizontal: 6),
          // Allineamento altezza riga al Select: niente altezza fissa, padding verticale 6
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            // Usa lo stesso raggio del trigger (md) come nel Select
            borderRadius: radii?.md ?? const BorderRadius.all(Radius.circular(6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: textStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Opacity(
                opacity: widget.selected ? 1.0 : 0.0,
                child: Icon(Icons.check, size: 16, color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Piccolo spacer per allineare verticalmente il search alla baseline
class _SearchFieldSpacer extends StatelessWidget {
  const _SearchFieldSpacer();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Campo di ricerca inline, senza bordo né sfondo.
class _SearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final double height;
  final double verticalOffset; // micro‑tuning verticale del testo (±)
  const _SearchField({
    required this.hintText,
    required this.onChanged,
    this.height = 32,
    this.verticalOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Allineamento ottico del testo: usa strutStyle e contentPadding zero.
    final height = this.height;
    const fontSize = 14.0;
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextField(
          autofocus: true,
          textAlignVertical: TextAlignVertical.center,
          cursorColor: cs.primary,
          strutStyle: const StrutStyle(
            fontSize: fontSize,
            height: 1.0,
            forceStrutHeight: true,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize, height: 1.0),
          decoration: InputDecoration(
            isCollapsed: true,
            hintText: hintText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: fontSize,
              height: 1.0,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            // Padding simmetrico per centrare: base 8.0 ± micro‑tuning
            contentPadding: EdgeInsets.only(
              top: 8.0 - verticalOffset,
              bottom: 8.0 + verticalOffset,
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}