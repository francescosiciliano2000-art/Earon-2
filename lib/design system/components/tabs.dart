// lib/components/tabs.dart
import 'package:flutter/material.dart';

/// Tabs — contenitore principale (equivalente a TabsPrimitive Root)
class Tabs extends StatefulWidget {
  const Tabs({
    super.key,
    this.value,
    this.defaultValue,
    this.onValueChange,
    this.gap = 8.0, // "gap-2"
    this.axis = Axis.vertical, // shadcn usa colonna (lista + contenuto)
    required this.child,
  });

  /// Valore controllato (se fornito, l'istanza è "controlled")
  final String? value;

  /// Valore iniziale (usato solo se [value] è null)
  final String? defaultValue;

  /// Callback quando cambia tab
  final ValueChanged<String>? onValueChange;

  /// Spazio tra TabsList e TabsContent ("gap-2")
  final double gap;

  /// Layout principale: di default colonna (lista sopra, contenuto sotto)
  final Axis axis;

  /// Contenuto: includerà generalmente [TabsList] e uno o più [TabsContent]
  final Widget child;

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  late String? _current;

  bool get _isControlled => widget.value != null;

  @override
  void initState() {
    super.initState();
    _current = widget.value ?? widget.defaultValue;
  }

  @override
  void didUpdateWidget(covariant Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isControlled) {
      _current = widget.value;
    }
  }

  void _setValue(String next) {
    if (_isControlled) {
      if (widget.onValueChange != null) widget.onValueChange!(next);
    } else {
      setState(() => _current = next);
      if (widget.onValueChange != null) widget.onValueChange!(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = TabsScope(
      value: _current,
      setValue: _setValue,
      child: widget.child,
    );

    if (widget.axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      );
    } else {
      return Row(mainAxisSize: MainAxisSize.min, children: [child]);
    }
  }
}

/// Inherited scope per condividere valore e setter a Trigger/Content
class TabsScope extends InheritedWidget {
  const TabsScope({
    super.key,
    required super.child,
    required this.value,
    required this.setValue,
  });

  final String? value;
  final void Function(String value) setValue;

  static TabsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TabsScope>();
    assert(scope != null, 'TabsScope non trovato nel context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(TabsScope oldWidget) => value != oldWidget.value;
}

/// TabsList — contenitore dei trigger (equivalente a TabsPrimitive List)
class TabsList extends StatelessWidget {
  const TabsList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(3), // "p-[3px]"
    this.height = 36, // "h-9"
    this.radius = 12, // "rounded-lg"
    this.background,
    this.foreground,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final double height;
  final double radius;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? _bgMuted(scheme);
    final fg = foreground ?? _textMutedForeground(scheme);

    // inline-flex, w-fit, items-center, rounded-lg
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: fg, height: 1.0),
        child: IconTheme.merge(
          data: IconThemeData(color: fg, size: 16), // [&_svg]:size-4
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  // shadcn: bg-muted (light: grigio più scuro, dark: presente e percettibile)
  Color _bgMuted(ColorScheme s) {
    final isDark = s.brightness == Brightness.dark;
    // React: TabsList usa bg-muted. In Flutter:
    // - Light: usiamo surfaceContainerHighest per un grigio visibile (più scuro del background)
    // - Dark: prima era s.surface (troppo simile al background). Usiamo surfaceContainerHigh per renderlo percepibile.
    return isDark ? s.surfaceContainerHigh : s.surfaceContainerHighest;
  }

  // shadcn: text-muted-foreground
  Color _textMutedForeground(ColorScheme s) {
    final isDark = s.brightness == Brightness.dark;
    return isDark ? s.onSurface.withValues(alpha: 0.6) : s.onSurfaceVariant;
  }
}

/// TabsTrigger — singolo tab (equivalente a TabsPrimitive Trigger)
class TabsTrigger extends StatefulWidget {
  const TabsTrigger({
    super.key,
    required this.value,
    required this.child,
    this.disabled = false,
    this.radius = 8, // "rounded-md"
    this.padding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 6,
    ), // px-2 py-1
    this.gap = 6, // gap-1.5
    this.borderActive,
    this.bgActive,
    this.textActive,
    this.textInactive,
  });

  /// Valore del tab
  final String value;

  /// Contenuto (icona + testo, etc.)
  final Widget child;

  /// Disabilitato
  final bool disabled;

  /// Raggio per pill
  final double radius;

  /// Padding interno
  final EdgeInsets padding;

  /// Spazio tra icone e testo
  final double gap;

  /// Override stile attivo
  final Color? borderActive;
  final Color? bgActive;
  final Color? textActive;

  /// Override stile inattivo
  final Color? textInactive;

  @override
  State<TabsTrigger> createState() => _TabsTriggerState();
}

class _TabsTriggerState extends State<TabsTrigger> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scope = TabsScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isActive = scope.value == widget.value;
    final isDark = scheme.brightness == Brightness.dark;

    // Colori coerenti con classi shadcn:
    // active: bg-background (light), dark:bg-input/30 + border input, text-foreground
    final Color darkInput = Theme.of(context).inputDecorationTheme.fillColor ?? scheme.surfaceContainerHighest;
    final bgActive = widget.bgActive ?? (isDark ? darkInput.withValues(alpha: 0.30) : scheme.surface);
    final textActive = widget.textActive ?? scheme.onSurface;
    final textInactive = widget.textInactive ?? (isDark ? scheme.onSurface.withValues(alpha: 0.6) : scheme.onSurface);

    // Prefer input border color for dark active border if available, else fallback
    final enabledBorder = Theme.of(context).inputDecorationTheme.enabledBorder;
    Color? inputBorderColor;
    if (enabledBorder is OutlineInputBorder) {
      inputBorderColor = enabledBorder.borderSide.color;
    }
    final borderActive = widget.borderActive ?? (isDark ? (inputBorderColor ?? scheme.outlineVariant) : Colors.transparent);

    // Ring focus: focus-visible:border-ring + focus-visible:ring-ring/50
    final Color ringBase = scheme.outlineVariant;
    final Color ringOverlay = ringBase.withValues(alpha: 0.5);

    final base = DefaultTextStyle(
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w600, // "font-medium"
        color: isActive ? textActive : textInactive,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          size: 16,
          color: isActive ? textActive : textInactive,
        ),
        child: _Pill(
          radius: widget.radius,
          padding: widget.padding,
          isActive: isActive,
          borderColor: _focused ? ringBase : (isActive ? borderActive : Colors.transparent),
          bgColor: isActive ? bgActive : Colors.transparent,
          showRing: _focused,
          ringColor: ringOverlay,
          child: _Gap(gap: widget.gap, child: widget.child),
        ),
      ),
    );

    return FocusableActionDetector(
      enabled: !widget.disabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: Opacity(
        opacity: widget.disabled ? 0.5 : 1.0, // disabled:opacity-50
        child: InkWell(
          onTap: widget.disabled ? null : () => scope.setValue(widget.value),
          borderRadius: BorderRadius.circular(widget.radius),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: base,
        ),
      ),
    );
  }

}

/// TabsContent — contenuto condizionale (equivalente a TabsPrimitive Content)
class TabsContent extends StatelessWidget {
  const TabsContent({
    super.key,
    required this.value,
    required this.child,
    this.expand = true, // "flex-1 outline-none"
  });

  final String value;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scope = TabsScope.of(context);
    final visible = scope.value == value;

    final content = Visibility(
      visible: visible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: false,
      child: child,
    );

    if (expand) {
      return Flexible(fit: FlexFit.loose, child: content);
    }
    return content;
  }
}

/// --- Helpers UI ---

class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    required this.radius,
    required this.padding,
    required this.isActive,
    required this.borderColor,
    required this.bgColor,
    required this.showRing,
    required this.ringColor,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final bool isActive;
  final Color borderColor;
  final Color bgColor;
  final bool showRing;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    // Simula: "h-[calc(100%-1px)]" mantenendo pill leggermente più bassa dell'altezza del TabsList.
    // In Flutter usiamo semplicemente un minHeight coerente con il padding della list.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        // border sempre presente come in React (border border-transparent),
        // su focus diventa "border-ring" e su dark+active diventa "border-input"
        border: Border.all(color: borderColor, width: 1),
        boxShadow: showRing
            ? [
                // focus-visible:ring-[3px] + outline simulato
                BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: 3),
              ]
            : (isActive
                ? [
                    // data-[state=active]:shadow-sm
                    const BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      spreadRadius: 0,
                    ),
                  ]
                : null),
      ),
      child: child,
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.child, required this.gap});

  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // Supporta "gap-1.5" automaticamente per Row/Wrap di contenuto eterogeneo
    return _Gapper(gap: gap, child: child);
  }
}

/// Applica gap tra i figli se sono Row/Wrap, altrimenti lascia intatto.
/// Ci permette di usare lo stesso widget TabsTrigger per 'icona + testo' o solo testo.
class _Gapper extends StatelessWidget {
  const _Gapper({required this.child, required this.gap});
  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (child is Row) {
      final row = child as Row;
      return Row(
        key: row.key,
        mainAxisAlignment: row.mainAxisAlignment,
        mainAxisSize: row.mainAxisSize,
        crossAxisAlignment: row.crossAxisAlignment,
        textDirection: row.textDirection,
        verticalDirection: row.verticalDirection,
        textBaseline: row.textBaseline,
        children: _withGap(row.children, gap, isRow: true),
      );
    }
    if (child is Wrap) {
      final wrap = child as Wrap;
      return Wrap(
        key: wrap.key,
        direction: wrap.direction,
        alignment: wrap.alignment,
        spacing: gap,
        runAlignment: wrap.runAlignment,
        runSpacing: wrap.runSpacing,
        crossAxisAlignment: wrap.crossAxisAlignment,
        textDirection: wrap.textDirection,
        verticalDirection: wrap.verticalDirection,
        clipBehavior: wrap.clipBehavior,
        children: wrap.children,
      );
    }
    // fallback: se è un Widget singolo (icona o testo), lo wrappiamo in Row per applicare gap a livello superiore
    return Row(mainAxisSize: MainAxisSize.min, children: [child]);
  }

  List<Widget> _withGap(List<Widget> items, double gap, {required bool isRow}) {
    if (items.isEmpty) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(SizedBox(width: isRow ? gap : 0, height: isRow ? 0 : gap));
      }
    }
    return out;
  }
}
