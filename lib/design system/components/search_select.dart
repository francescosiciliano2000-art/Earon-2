// search_select.dart
// Unione di "Select" (overlay e navigazione) e dell'aspetto di AppInput (barra di ricerca)
// Consente di digitare per cercare e selezionare un item dai risultati mostrati in overlay
// ancorato sotto al campo, evitando problemi di scroll dei dialog.

import 'package:flutter/material.dart';
import '../theme/themes.dart'; // DefaultTokens, ShadcnRadii
import 'select.dart' show SelectGroupData; // riuso dei data model

class AppSearchSelect extends StatefulWidget {
  const AppSearchSelect({
    super.key,
    required this.groups,
    this.value,
    this.placeholder,
    this.width = 280,
    this.enabled = true,
    this.isInvalid = false,
    this.onChanged,
    this.onQueryChanged,
    this.controller,
    this.focusNode,
    this.openOnFocus = true,
  });

  /// Gruppi di risultati da mostrare nel menu; possono essere aggiornati dall'esterno
  final List<SelectGroupData> groups;

  /// Valore selezionato corrente
  final String? value;

  /// Placeholder/Hint del campo di ricerca
  final String? placeholder;

  /// Larghezza del trigger/input
  final double width;

  final bool enabled;
  final bool isInvalid;

  /// Callback quando un item viene selezionato
  final ValueChanged<String>? onChanged;

  /// Callback quando il testo di ricerca cambia (per avviare una query remota)
  final ValueChanged<String>? onQueryChanged;

  /// Controller/focus opzionali (riusati da dialog in modo controllato)
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Se true apre l'overlay quando il campo va in focus
  final bool openOnFocus;

  @override
  State<AppSearchSelect> createState() => _AppSearchSelectState();
}

class _AppSearchSelectState extends State<AppSearchSelect> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  String? _selected;
  Size _triggerSize = const Size(280, 36);
  Size _contentSize = Size.zero;
  bool _focusVisible = false;
  bool _hovered = false;

  late final TextEditingController _internalCtl;
  TextEditingController get _ctl => widget.controller ?? _internalCtl;

  FocusNode? _internalFocus;
  FocusNode get _focus => widget.focusNode ?? (_internalFocus ??= FocusNode());

  final ScrollController _menuScroll = ScrollController();
  // L'overlay non deve rubare il focus al TextField: manteniamo solo
  // un FocusNode per eventuali controlli, ma senza requestFocus.
  final FocusNode _overlayFocus = FocusNode(debugLabel: 'AppSearchSelectOverlay');

  // Navigation/ricerca come AppSelect
  int _activeIndex = -1;
  List<_ItemRef> _items = [];
  // Rimosse funzioni di typeahead: buffer e timer non più usati

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
    _internalCtl = TextEditingController();
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
    _menuScroll.dispose();
    _overlayFocus.dispose();
    _removeOverlay(immediate: true);
    _controller.dispose();
    _internalCtl.dispose();
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppSearchSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups) {
      // Quando i gruppi cambiano mentre l'overlay è aperto, rimandiamo
      // il rebuild dell'overlay al post‑frame per evitare l'errore
      // "setState() or markNeedsBuild() called during build".
      if (_entry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _entry == null) return;
          _rebuildItems();
          _entry!.markNeedsBuild();
        });
      }
    }
    if (oldWidget.value != widget.value) {
      _selected = widget.value;
    }
  }

  void _captureTriggerSize() {
    final ctx = _triggerKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box != null) _triggerSize = box.size;
  }

  void _openIfNeeded() {
    if (!widget.enabled) return;
    if (_entry == null) {
      _captureTriggerSize();
      _showOverlay();
    }
  }

  void _showOverlay() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _rebuildItems();
    _activeIndex = _items.indexWhere((e) => e.value == _selected && e.enabled);
    if (_activeIndex < 0) {
      _activeIndex = _items.indexWhere((e) => e.enabled);
    }

    final borderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);
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

    _entry = OverlayEntry(
      builder: (context) {
        final double offsetX = _contentSize.width > 0
            ? (_triggerSize.width - _contentSize.width)
            : 0;
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: _removeOverlay)),
            CompositedTransformFollower(
              link: _layerLink,
              // Sposta leggermente più in basso il pannello per non sovrapporsi
              // al bordo inferiore dell'input.
              offset: Offset(offsetX, _triggerSize.height + 12),
              showWhenUnlinked: false,
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.topRight,
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
                        constraints: BoxConstraints(
                          minWidth: _triggerSize.width,
                          maxWidth: _triggerSize.width,
                          maxHeight: 320,
                        ),
                        decoration: BoxDecoration(
                          color: panelBg,
                          borderRadius: Theme.of(context)
                                  .extension<ShadcnRadii>()
                                  ?.md ??
                              const BorderRadius.all(Radius.circular(6)),
                          border: Border.all(color: borderColor),
                          boxShadow: shadow,
                        ),
                        child: _buildMenuContent(cs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    _controller.forward();
  }

  void _removeOverlay({bool immediate = false}) async {
    if (_entry == null) return;
    if (!immediate) await _controller.reverse();
    _entry?.remove();
    _entry = null;
  }

  void _rebuildItems() {
    final items = <_ItemRef>[];
    for (final g in widget.groups) {
      for (final it in g.items) {
        items.add(_ItemRef(value: it.value, enabled: it.enabled, key: GlobalKey()));
      }
    }
    _items = items;
  }

  // Rimosso: gestore tastiera non utilizzato

  // Rimosso: estrazione carattere digitato (non utilizzata)

  // Rimosso: append type char (non utilizzato)

  // Rimosso: ricerca e focus via buffer (non utilizzata)

  // Rimosso: apply active index (non utilizzato)

  // Rimosso: move active (non utilizzato)

  // Rimosso: scroll item into view (non utilizzato)

  // Rimosso: select active (non utilizzato)

  Widget _buildMenuContent(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: Theme.of(context).extension<ShadcnRadii>()?.md ??
          const BorderRadius.all(Radius.circular(6)),
      child: Scrollbar(
        controller: _menuScroll,
        interactive: true,
        child: ListView(
          controller: _menuScroll,
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const AlwaysScrollableScrollPhysics(),
          children: _buildMenuChildren(cs, isDark),
        ),
      ),
    );
  }

  List<Widget> _buildMenuChildren(ColorScheme cs, bool isDark) {
    final children = <Widget>[];
    var refIndex = 0;
    for (final group in widget.groups) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Text(
            group.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              color: isDark
                  ? cs.onSurface.withValues(alpha: 0.6)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      );
      for (final item in group.items) {
        final ref = _items[refIndex];
        children.add(
          _SearchSelectMenuItem(
            key: ref.key,
            label: item.label,
            selected: _selected == item.value,
            enabled: item.enabled,
            focused: refIndex == _activeIndex,
            onTap: item.enabled
                ? () {
                    setState(() {
                      _selected = item.value;
                    });
                    if (widget.onChanged != null && _selected != null) {
                      widget.onChanged!.call(_selected!);
                    }
                    _removeOverlay();
                  }
                : null,
          ),
        );
        refIndex++;
      }
      children.add(const SizedBox(height: 4));
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>()!;
    final isDark = theme.brightness == Brightness.dark;

    const height = 36.0; // come AppInput
    const px = 12.0;

    // Bordo base e ring come AppInput
    final baseBorderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);

    final Color ringBase = widget.isInvalid
        ? cs.error
        : (tokens?.ring ?? cs.outlineVariant);

    final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

    Color baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30)
        : cs.surface;
    if (isDark && _hovered) {
      baseBg = cs.outlineVariant.withValues(alpha: 0.50);
    }

    final ringShadows = _focusVisible
        ? [BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 3)]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ];

    final effectiveBorderColor = widget.isInvalid ? cs.error : baseBorderColor;

    final hint = widget.placeholder ?? '';

    final field = Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: cs.primary,
          selectionHandleColor: cs.primary,
        ),
      ),
      child: TextField(
        key: _triggerKey,
        controller: _ctl,
        focusNode: _focus,
        enabled: widget.enabled,
        onChanged: (v) {
          widget.onQueryChanged?.call(v);
          if (widget.openOnFocus) _openIfNeeded();
        },
        onTap: () {
          if (widget.openOnFocus) _openIfNeeded();
        },
        minLines: 1,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: cs.primary,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.0),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          hintText: hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
            height: 1.0,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: px, vertical: 8),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
    );

    final body = widget.enabled
        ? field
        : IgnorePointer(child: Opacity(opacity: 0.5, child: field));

    return CompositedTransformTarget(
      link: _layerLink,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        child: MouseRegion(
          cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
          onEnter: (_) {
            if (widget.enabled) setState(() => _hovered = true);
          },
          onExit: (_) {
            if (widget.enabled) setState(() => _hovered = false);
          },
          child: SizedBox(
            width: widget.width,
            height: height,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: radii.md,
                boxShadow: ringShadows,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: baseBg,
                  borderRadius: radii.md,
                  border: Border.all(color: effectiveBorderColor, width: 1),
                ),
                child: Center(child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- ITEM DEL MENU (copia del comportamento di _SelectMenuItem) ----
class _SearchSelectMenuItem extends StatefulWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final bool focused;
  final VoidCallback? onTap;

  const _SearchSelectMenuItem({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    this.focused = false,
    this.onTap,
  });

  @override
  State<_SearchSelectMenuItem> createState() => _SearchSelectMenuItemState();
}

class _SearchSelectMenuItemState extends State<_SearchSelectMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radii = Theme.of(context).extension<ShadcnRadii>();

    final accentBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : cs.primary.withValues(alpha: 0.08);
    final baseBg = Colors.transparent;
    final hoverBg = isDark
        ? cs.onSurface.withValues(alpha: 0.07)
        : const Color(0xFFF3F4F6);

    final bgColor = widget.focused
        ? accentBg
        : (_hover && !widget.selected ? hoverBg : baseBg);

    final textColor = widget.enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5);
    final checkColor = cs.onSurface.withValues(alpha: 0.9);

    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textColor,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: (radii != null
                  ? BoxDecoration(borderRadius: radii.md)
                  : const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(6))))
              .copyWith(color: bgColor),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              if (widget.selected)
                Icon(Icons.check, size: 16, color: checkColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRef {
  _ItemRef({required this.value, required this.enabled, required this.key});
  final String value;
  final bool enabled;
  final GlobalKey key;
}

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
    return KeyedSubtree(key: UniqueKey(), child: widget.child);
  }
}