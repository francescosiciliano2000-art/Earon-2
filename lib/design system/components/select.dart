// select.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // icone Phosphor
import '../theme/themes.dart'; // tokens (DefaultTokens) e radii (ShadcnRadii)
// Rimosse funzioni di typeahead/keyboard: import non più necessari
// import 'package:flutter/services.dart'; // RawKeyboard, LogicalKeyboardKey
// import 'dart:async'; // typeahead buffer timer
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint

// ---- DATA ----
class SelectItemData {
  final String value;
  final String label;
  final bool enabled;
  const SelectItemData({
    required this.value,
    required this.label,
    this.enabled = true,
  });
}

class SelectGroupData {
  final String label;
  final List<SelectItemData> items;
  const SelectGroupData({required this.label, required this.items});
}

enum SelectSize { sm, md }

// ---- COMPONENT: AppSelect ----
class AppSelect extends StatefulWidget {
  final List<SelectGroupData> groups;
  final String? value;
  final String? placeholder;
  final double width;
  // Fattore di larghezza del menu rispetto al trigger. Default 1.0 (uguale).
  final double overlayWidthFactor;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool isInvalid;
  final SelectSize size;
  final bool enableTypeahead; // abilita digitazione per cercare senza barra di ricerca

  const AppSelect({
    super.key,
    required this.groups,
    this.value,
    this.placeholder,
    this.onChanged,
    this.width = 180,
    this.overlayWidthFactor = 1.0,
    this.enabled = true,
    this.isInvalid = false,
    this.size = SelectSize.md,
    this.enableTypeahead = true,
  });

  @override
  State<AppSelect> createState() => _AppSelectState();
}

class _AppSelectState extends State<AppSelect>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;
  VoidCallback? _overlayClose; // chiusura decoupled dell'overlay

  late AnimationController _controller; // usato solo per vecchio overlay; verrà ignorato dal nuovo overlay decoupled

  String? _selected;
  Size _triggerSize = const Size(180, 36);
  bool _focusVisible = false;
  bool _hovered = false;
  Size _contentSize = Size.zero;
  final ScrollController _menuScroll = ScrollController();
  final FocusNode _overlayFocus = FocusNode();
  int _activeIndex = -1;
  List<_ItemRef> _items = [];
  // Rimosse strutture per typeahead: non più utilizzate

  DateTime? _lastToggleAt; // debounce per evitare doppio toggle (tapDown + tap)
  DateTime? _openedAt; // timestamp di apertura per impedire chiusure troppo ravvicinate
  Offset _triggerGlobal = Offset.zero; // posizione globale del trigger per ancoraggio assoluto



  @override
  void initState() {
    super.initState();
    _selected = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 120),
    );
  }

  @override
  void didUpdateWidget(covariant AppSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kDebugMode) {
      debugPrint('[AppSelect] didUpdateWidget (entry=${_entry != null}, selected=$_selected)');
    }
    // Sincronizza lo stato interno quando cambia il valore controllato dal parent.
    // Questo consente di aggiornare la label del trigger quando il parent
    // imposta un nuovo "value" (es. cambio mese/anno via frecce nel calendario).
    if (widget.value != oldWidget.value || widget.value != _selected) {
      setState(() {
        _selected = widget.value;
      });
    }
  }

  @override
  void deactivate() {
    if (kDebugMode) debugPrint('[AppSelect] deactivate');
    super.deactivate();
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint('[AppSelect] dispose');
    // NON rimuovere l'overlay: ora è decoupled e può restare attivo anche se il trigger
    // viene smontato temporaneamente (es. Calendar dentro DatePicker).
    _controller.dispose();
    _menuScroll.dispose();
    _overlayFocus.dispose();
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

  void _toggle() {
    final now = DateTime.now();
    // Debounce: evita che onTapDown e onTap della stessa gesture provochino
    // open+close immediato.
    if (_lastToggleAt != null &&
        now.difference(_lastToggleAt!).inMilliseconds < 220) {
      if (kDebugMode) debugPrint('[AppSelect] toggle ignored (debounce)');
      return;
    }
    _lastToggleAt = now;
    if (!widget.enabled) return;
    if (_entry == null) {
      _captureTriggerSize();
      if (kDebugMode) debugPrint('[AppSelect] toggle → showOverlay (size=${widget.size}, w=${widget.width})');
      // Inserisci subito l'overlay: useremo un piccolo guard temporale sul backdrop
      // per evitare la chiusura immediata dovuta allo stesso tap di apertura.
      _showOverlay();
    } else {
      if (kDebugMode) debugPrint('[AppSelect] toggle → removeOverlay');
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (kDebugMode) debugPrint('[AppSelect] showOverlay start');
    // Cattura Theme una volta sola per evitare lookup su contesti potenzialmente
    // deattivati durante la vita dell'OverlayEntry.
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final ShadcnRadii? radii = theme.extension<ShadcnRadii>();

    _rebuildItems();
    // attiva indice corrente sulla selezione o primo abilitato
    _activeIndex = _items.indexWhere((e) => e.value == _selected && _isEnabledValue(e.value));
    if (_activeIndex < 0) {
      _activeIndex = _items.indexWhere((e) => e.enabled);
    }

    final borderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);
    final panelBg = isDark ? cs.surfaceContainerHigh : cs.surface;
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];

    // Backdrop gestito dal nuovo overlay
    // Overlay decoupled: gestisce da sé animazione, focus e backdrop.
    // Pre-costruisci il contenuto menu con uno ScrollController locale all'overlay,
    // così non dipende da risorse del trigger (che potrebbe venire smontato).
    final ScrollController overlayScroll = ScrollController();
    final Widget menuChild = ClipRRect(
      borderRadius:
          theme.extension<ShadcnRadii>()?.md ?? const BorderRadius.all(Radius.circular(6)),
      child: ListView(
        controller: overlayScroll,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        children: _buildMenuChildren(theme, cs, isDark),
      ),
    );

    _entry = OverlayEntry(
      builder: (context) {
        final double offsetX = _contentSize.width > 0
            ? (_triggerSize.width - _contentSize.width)
            : 0;
        final double overlayWidth = _triggerSize.width * widget.overlayWidthFactor;
        return _SelectOverlay(
          left: _triggerGlobal.dx + offsetX,
          top: _triggerGlobal.dy + _triggerSize.height + 8,
          width: overlayWidth,
          maxHeight: 320,
          borderColor: borderColor,
          panelBg: panelBg,
          shadow: shadow,
          borderRadius: radii?.md ?? const BorderRadius.all(Radius.circular(6)),
          menuChild: menuChild,
          onSize: (s) {
            if (_contentSize != s) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _contentSize = s);
                _entry?.markNeedsBuild();
              });
            }
          },
          onRequestClose: () {
            // Chiudi l'overlay dall'interno
            _overlayClose?.call();
          },
        );
      },
    );

    // Usa il rootOverlay per evitare problemi quando Navigator/route viene
    // smontato (es. con go_router). Così l'overlay non dipende da un contesto
    // che può essere deattivato durante l'animazione o il rebuild.
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    // Il nuovo overlay gestisce da sé focus e animazione
    _openedAt = DateTime.now();
    if (kDebugMode) debugPrint('[AppSelect] showOverlay inserted (immediate)');
    // Imposta la chiusura decoupled per consentire all'overlay di rimuovere sé stesso.
    _overlayClose = () {
      _entry?.remove();
      _entry = null;
      _openedAt = null;
      if (kDebugMode) debugPrint('[AppSelect] overlay removed (decoupled)');
    };
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

  bool _isEnabledValue(String? value) {
    if (value == null) return false;
    final i = _items.indexWhere((e) => e.value == value);
    return i >= 0 && _items[i].enabled;
  }

  // Rimosso: gestore tastiera non collegato

  // Rimosse funzioni di typeahead/keyboard non utilizzate

  void _removeOverlay({bool immediate = false, bool force = false}) async {
    if (_entry == null) return;
    // Evita rimozioni troppo ravvicinate all'apertura.
    if (_openedAt != null) {
      final dt = DateTime.now().difference(_openedAt!).inMilliseconds;
      if (!force) {
        if (immediate && dt < 350) {
          if (kDebugMode) debugPrint('[AppSelect] removeOverlay vetoed (dispose/immediate, dt=${dt}ms)');
          return;
        }
        if (!immediate && dt < 250) {
          if (kDebugMode) debugPrint('[AppSelect] removeOverlay vetoed (min open time, dt=${dt}ms)');
          return;
        }
      }
    }
    // Chiusura decoupled: lascia gestire animazione al widget overlay.
    if (_overlayClose != null) {
      _overlayClose!.call();
    } else {
      _entry?.remove();
      _entry = null;
    }
    _openedAt = null;
    if (kDebugMode) debugPrint('[AppSelect] overlay removed (immediate=$immediate, decoupled=${_overlayClose != null})');
  }

  // Rimosso: _buildMenuContent inutilizzato (overlay decoupled usa contenuto proprio)

  List<Widget> _buildMenuChildren(ThemeData theme, ColorScheme cs, bool isDark) {
    final children = <Widget>[];
    var refIndex = 0;
    for (final group in widget.groups) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Text(
            group.label,
            style: theme.textTheme.labelSmall?.copyWith(
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
              _SelectMenuItem(
                key: ref.key,
                label: item.label,
                selected: _selected == item.value,
                enabled: item.enabled,
                focused: refIndex == _activeIndex,
                onTap: item.enabled
                    ? () {
                        if (mounted) {
                          setState(() {
                            _selected = item.value;
                          });
                        }
                        if (widget.onChanged != null) {
                          if (kDebugMode) debugPrint('[AppSelect] onChanged (tap) value=${item.value}');
                          widget.onChanged!.call(item.value);
                        }
                        if (kDebugMode) debugPrint('[AppSelect] menu item tap → removeOverlay');
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

    final height = widget.size == SelectSize.sm ? 32.0 : 36.0; // h-8 o h-9
    final px = widget.size == SelectSize.sm ? 10.0 : 12.0; // sm più stretto
    // Riduci padding verticale per small per maggiore compattezza
    final py = widget.size == SelectSize.sm ? 4.0 : 6.0;

    // Bordi: come AppInput/Buttons outline
    final baseBorderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);

    final Color ringBase = widget.isInvalid
        ? cs.error
        : (tokens?.ring ?? cs.outlineVariant);

    final focusBorderColor = ringBase; // focus-visible:border-ring

    // Ring 3px: ring/50 o destructive/20/40
    final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

    // Background trigger
    Color baseBg = isDark
        ? cs.outlineVariant.withValues(alpha: 0.30) // dark:bg-input/30
        : cs.surface; // light: bg-background
    if (isDark && _hovered) {
      baseBg = cs.outlineVariant.withValues(alpha: 0.50); // dark:hover:bg-input/50
    }

    final ringShadow = _focusVisible
        ? [BoxShadow(color: focusRingColor, blurRadius: 0, spreadRadius: 3)]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ];

    final effectiveBorderColor = widget.isInvalid
        ? cs.error
        : (_focusVisible ? focusBorderColor : baseBorderColor);

    final textColor = cs.onSurface;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final label = _selected == null
        ? (widget.placeholder ?? '')
        : _labelForValue(_selected!, widget.groups);

    final trigger = SizedBox(
      width: widget.width,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(height: height),
        child: AnimatedContainer(
          key: _triggerKey,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: radii.md,
            border: Border.all(color: effectiveBorderColor, width: 1),
            boxShadow: ringShadow,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.enabled) _toggle();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label.isEmpty ? ' ' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (widget.size == SelectSize.sm
                              ? Theme.of(context).textTheme.bodySmall
                              : Theme.of(context).textTheme.bodyMedium)
                          ?.copyWith(
                        fontSize: widget.size == SelectSize.sm ? 12 : 14,
                        fontWeight: FontWeight.w500,
                        color: _selected == null ? muted : textColor,
                      ),
                    ),
                  ),
                  Icon(
                    PhosphorIcons.caretDown(PhosphorIconsStyle.regular),
                    size: widget.size == SelectSize.sm ? 14 : 16,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final body = widget.enabled
        ? trigger
        : IgnorePointer(child: Opacity(opacity: 0.5, child: trigger));

    return CompositedTransformTarget(
      link: _layerLink,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        child: MouseRegion(
          cursor:
              widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          onEnter: (_) {
            if (widget.enabled) setState(() => _hovered = true);
          },
          onExit: (_) {
            if (widget.enabled) setState(() => _hovered = false);
          },
          child: body,
        ),
      ),
    );
  }

  static String _labelForValue(String value, List<SelectGroupData> groups) {
    for (final g in groups) {
      for (final it in g.items) {
        if (it.value == value) return it.label;
      }
    }
    return value;
  }
}

// ---- ITEM DEL MENU ----
class _SelectMenuItem extends StatefulWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final bool focused;
  final VoidCallback? onTap;

  const _SelectMenuItem({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    this.focused = false,
    this.onTap,
  });

  @override
  State<_SelectMenuItem> createState() => _SelectMenuItemState();
}

class _SelectMenuItemState extends State<_SelectMenuItem> {
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

    // Non applicare l'hover background quando l'elemento è selezionato:
    // deve mostrare solo il check. Manteniamo l'accentBg quando è focused via tastiera.
    final bgColor = widget.focused
        ? accentBg
        : (_hover && !widget.selected ? hoverBg : baseBg);

    final textColor = widget.enabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.5);

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
          margin: const EdgeInsets.symmetric(
            horizontal: 6,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          // Il bordo dell'hover deve avere lo stesso raggio del trigger (radii.md)
          decoration: (radii != null
                  ? BoxDecoration(borderRadius: radii.md)
                  : const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ))
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
    return KeyedSubtree(
      key: UniqueKey(),
      child: widget.child,
    );
  }
}

// Overlay decoupled: widget che gestisce animazione, focus e backdrop indipendentemente
// dallo State del trigger, così da sopravvivere a smontaggi temporanei del trigger.
class _SelectOverlay extends StatefulWidget {
  const _SelectOverlay({
    required this.left,
    required this.top,
    required this.width,
    required this.maxHeight,
    required this.borderColor,
    required this.panelBg,
    required this.shadow,
    required this.borderRadius,
    required this.menuChild,
    required this.onSize,
    required this.onRequestClose,
  });

  final double left;
  final double top;
  final double width;
  final double maxHeight;
  final Color borderColor;
  final Color panelBg;
  final List<BoxShadow> shadow;
  final BorderRadius borderRadius;
  final Widget menuChild;
  final ValueChanged<Size> onSize;
  final VoidCallback onRequestClose;

  @override
  State<_SelectOverlay> createState() => _SelectOverlayState();
}

class _SelectOverlayState extends State<_SelectOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  bool _backdropActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Avvia apertura
    _controller.forward();
    // Attiva backdrop dopo breve delay (ridotto per migliorare la percezione di reattività)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() => _backdropActive = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (mounted) {
      await _controller.reverse();
    }
    widget.onRequestClose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: !_backdropActive,
            child: GestureDetector(onTap: _close),
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.topRight,
                child: _SizeObserver(
                  onSize: widget.onSize,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: widget.width,
                      maxWidth: widget.width,
                      maxHeight: widget.maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: widget.panelBg,
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: widget.borderColor),
                      boxShadow: widget.shadow,
                    ),
                    child: widget.menuChild,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Alias per compatibilità: molte pagine usano ancora ShadcnSelect.
// Manteniamo la stessa API di AppSelect inoltrando al suo costruttore.
class ShadcnSelect extends AppSelect {
  const ShadcnSelect({
    super.key,
    required super.groups,
    super.value,
    super.placeholder,
    super.width = 180,
    super.onChanged,
    super.enabled = true,
    super.isInvalid = false,
    super.size = SelectSize.md,
    super.enableTypeahead = true,
  });
}
