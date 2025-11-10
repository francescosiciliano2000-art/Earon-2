import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/themes.dart';

/// ---------------------------------------------------------------------------
/// TooltipProvider
/// ---------------------------------------------------------------------------
/// Mantiene il delay di apertura come nel componente shadcn.
/// In React: TooltipPrimitive.Provider delayDuration={...}
class TooltipProvider extends InheritedWidget {
  final Duration delayDuration;

  const TooltipProvider({
    super.key,
    required this.delayDuration,
    required super.child,
  });

  static TooltipProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TooltipProvider>();
  }

  @override
  bool updateShouldNotify(TooltipProvider oldWidget) =>
      delayDuration != oldWidget.delayDuration;
}

/// Helper per comodità: wrapper con default delay = 0ms
class ShadcnTooltipProvider extends StatelessWidget {
  final Duration delayDuration;
  final Widget child;

  const ShadcnTooltipProvider({
    super.key,
    this.delayDuration = Duration.zero,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TooltipProvider(delayDuration: delayDuration, child: child);
  }
}

/// ---------------------------------------------------------------------------
/// Tooltip (Root)
/// ---------------------------------------------------------------------------
/// In React: TooltipPrimitive.Root
/// Fornisce uno scope interno per sincronizzare Trigger & Content.
class _TooltipScope extends InheritedWidget {
  final _TooltipController controller;

  const _TooltipScope({
    required this.controller,
    required super.child,
  });

  static _TooltipController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TooltipScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_TooltipScope oldWidget) =>
      controller != oldWidget.controller;
}

class Tooltip extends StatefulWidget {
  /// Manteniamo la parità con Radix: possibilità di passare `open`/`defaultOpen`/`onOpenChange`.
  /// Per semplicità: esponiamo solo `defaultOpen` (controllo non vincolante).
  final bool defaultOpen;
  final Widget child;

  const Tooltip({required super.key, this.defaultOpen = false, required this.child});

  @override
  State<Tooltip> createState() => _TooltipState();
}

class _TooltipState extends State<Tooltip> with TickerProviderStateMixin {
  late final _TooltipController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _TooltipController(
      vsync: this,
      initiallyOpen: widget.defaultOpen,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TooltipScope(controller: _controller, child: widget.child);
  }
}

/// ---------------------------------------------------------------------------
/// Trigger
/// ---------------------------------------------------------------------------
/// In React: TooltipPrimitive.Trigger
/// Mostra il tooltip all’hover/focus (desktop) e long-press (touch).
class TooltipTrigger extends StatefulWidget {
  final Widget child;

  const TooltipTrigger({super.key, required this.child});

  @override
  State<TooltipTrigger> createState() => _TooltipTriggerState();
}

class _TooltipTriggerState extends State<TooltipTrigger> {
  final _key = GlobalKey();
  Timer? _openTimer;

  _TooltipController get _controller {
    final c = _TooltipScope.of(context);
    assert(c != null, 'TooltipTrigger deve essere dentro Tooltip.');
    return c!;
  }

  Duration get _delay {
    return TooltipProvider.of(context)?.delayDuration ?? Duration.zero;
  }

  void _scheduleOpen() {
    _cancelTimer();
    _openTimer = Timer(_delay, () {
      _controller.show(anchorKey: _key, context: context);
    });
  }

  void _cancelTimer() {
    _openTimer?.cancel();
    _openTimer = null;
  }

  void _hide() {
    _cancelTimer();
    _controller.hide();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MouseRegion + Focus + GestureDetector per gestire hover/focus/long-press.
    return FocusableActionDetector(
      onShowHoverHighlight: (hovering) {
        if (hovering) {
          _scheduleOpen();
        } else {
          _hide();
        }
      },
      onShowFocusHighlight: (focused) {
        if (focused) {
          _scheduleOpen();
        } else {
          _hide();
        }
      },
      child: MouseRegion(
        onEnter: (_) => _scheduleOpen(),
        onExit: (_) => _hide(),
        child: GestureDetector(
          key: _key,
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => _scheduleOpen(),
          onLongPressEnd: (_) => _hide(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Content
/// ---------------------------------------------------------------------------
/// In React: TooltipPrimitive.Content
/// Porta in overlay con animazioni (fade+zoom+slide), lato (top/right/bottom/left),
/// sideOffset ed arrow 45°.
enum TooltipSide { top, right, bottom, left }

class TooltipContent extends StatefulWidget {
  final Widget child;
  final TooltipSide side;
  final double sideOffset;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  const TooltipContent({
    super.key,
    required this.child,
    this.side = TooltipSide.top,
    this.sideOffset = 0.0,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 6,
    ), // px-3 py-1.5
    this.borderRadius,
  });

  @override
  State<TooltipContent> createState() => _TooltipContentState();
}

class _TooltipContentState extends State<TooltipContent> {
  _TooltipController get _controller {
    final c = _TooltipScope.of(context);
    assert(c != null, 'TooltipContent deve essere dentro Tooltip.');
    return c!;
  }

  @override
  void initState() {
    super.initState();
    // Spostato in didChangeDependencies per evitare l'errore:
    // dependOnInheritedWidgetOfExactType chiamato prima che initState sia completato.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.registerContent(widget);
  }

  @override
  void didUpdateWidget(covariant TooltipContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.registerContent(widget);
  }

  @override
  void dispose() {
    _controller.unregisterContent(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Non renderizza nulla nel tree normale: è gestito in Overlay.
    return const SizedBox.shrink();
  }
}

/// ---------------------------------------------------------------------------
/// Controller interno che gestisce Overlay e animazioni.
/// ---------------------------------------------------------------------------
class _TooltipController {
  _TooltipController({
    required TickerProvider vsync,
    bool initiallyOpen = false,
  }) : _animationController = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 160),
         reverseDuration: const Duration(milliseconds: 120),
       ) {
    if (initiallyOpen) {
      _animationController.value = 1;
    }
  }

  final AnimationController _animationController;
  OverlayEntry? _entry;
  final LayerLink _link = LayerLink();
  final Set<TooltipContent> _contents = {};

  // Stato
  bool _open = false;
  BuildContext? _lastContext;
  GlobalKey? _anchorKey;

  void registerContent(TooltipContent content) {
    _contents.add(content);
    // se aperto, ricostruisci overlay per cogliere i nuovi parametri
    if (_open) _rebuild();
  }

  void unregisterContent(TooltipContent content) {
    _contents.remove(content);
    if (_open) _rebuild();
  }

  TooltipContent get _currentContent {
    // Ultimo registrato ha la precedenza (come in React composition)
    return _contents.isNotEmpty
        ? _contents.last
        : const TooltipContent(child: SizedBox());
  }

  void show({required GlobalKey anchorKey, required BuildContext context}) {
    _lastContext = context;
    _anchorKey = anchorKey;
    if (_open) {
      _rebuild();
      return;
    }
    _open = true;
    _insert();
    _animationController.forward();
  }

  void hide() {
    if (!_open) return;
    _animationController.reverse().then((_) => _remove());
  }

  void dispose() {
    _animationController.dispose();
    _remove();
  }

  void _insert() {
    if (_entry != null || _lastContext == null || _anchorKey == null) return;

    _entry = OverlayEntry(
      builder: (context) {
        return _TooltipOverlay(
          controller: this,
          link: _link,
          animation: CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
      },
    );

    final overlay = Overlay.of(_lastContext!, rootOverlay: true);
    // Inseriamo anche il CompositedTransformTarget sul trigger
    final renderObject = _anchorKey!.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      // Avvolgi dinamicamente il trigger con CompositedTransformTarget? Non possibile qui.
      // Soluzione: usiamo un Positioned follower con calcolo assoluto dal rect del trigger.
      // --> Implementato direttamente nell'overlay.
    }

    overlay.insert(_entry!);
  }

  void _rebuild() {
    _entry?.markNeedsBuild();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
    _open = false;
  }
}

/// ---------------------------------------------------------------------------
/// Overlay con posizionamento + animazioni + arrow.
/// ---------------------------------------------------------------------------
class _TooltipOverlay extends StatefulWidget {
  final _TooltipController controller;
  final LayerLink link;
  final Animation<double> animation;

  const _TooltipOverlay({
    required this.controller,
    required this.link,
    required this.animation,
  });

  @override
  State<_TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<_TooltipOverlay> {
  Rect _anchorRect = Rect.zero;
  Size? _tooltipSize; // misura reale del contenuto, appena disponibile

  TooltipContent get content => widget.controller._currentContent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _TooltipOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final key = widget.controller._anchorKey;
    final ctx = key?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final offset = box.localToGlobal(Offset.zero);
    setState(() {
      _anchorRect = offset & box.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // shadcn: Content usa bg-foreground e text-background
    final bg = scheme.onSurface; // "foreground"
    final fg = scheme.surface; // "background"

    // Border radius md ~ 6px (tema se presente)
    final radii = Theme.of(context).extension<ShadcnRadii>();
    final radius = content.borderRadius ?? (radii?.sm ?? BorderRadius.circular(6));

    // Arrow size ~ 10, ma shadcn usa 2.5 (rem) -> in px = 10
    const double arrowSize = 10;

    // Calcola la posizione del content rispetto al trigger.
    final side = content.side;
    final gap = content.sideOffset;

    final estimatedSize = _tooltipSize ?? const Size(160, 32);

    // Stima della posizione iniziale (prima del layout effettivo del child):
    Offset position = _computePosition(
      side: side,
      anchor: _anchorRect,
      estimatedTooltipSize: estimatedSize,
      gap: gap + arrowSize / 2,
    );

    // Slide dipende dal lato
    final slideOffset = _slideForSide(side);

    // Transform origin in shadcn dipende da side: mappiamo ad allineamento equivalente.
    final alignment = _alignmentForSide(side);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => widget.controller.hide(),
      child: Stack(
        children: [
          // Positioned "libero": usiamo un Align + Transform per animare scale/slide.
          Positioned(
            left: position.dx,
            top: position.dy,
            child: _AnimatedTooltipContainer(
              animation: widget.animation,
              slideOffset: slideOffset,
              alignment: alignment,
              builder: (context) {
                return _SizeObserver(
                  onChange: (size) {
                    if (_tooltipSize != size) {
                      setState(() => _tooltipSize = size);
                    }
                  },
                  child: _TooltipBubble(
                    fg: fg,
                    bg: bg,
                    radius: radius,
                    padding: content.padding,
                    side: side,
                    arrowSize: arrowSize,
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontSize: 12, // text-xs
                        color: fg,
                      ),
                      child: IconTheme(
                        data: IconThemeData(size: 16, color: fg),
                        child: content.child,
                      ),
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

  Offset _slideForSide(TooltipSide side) {
    // Simula le utility shadcn: data-[side=top]: slide-in-from-bottom-2, ecc.
    switch (side) {
      case TooltipSide.top:
        return const Offset(0, 8); // entra dal basso verso l’alto
      case TooltipSide.bottom:
        return const Offset(0, -8); // entra dall’alto verso il basso
      case TooltipSide.left:
        return const Offset(8, 0); // entra da destra verso sinistra
      case TooltipSide.right:
        return const Offset(-8, 0); // entra da sinistra verso destra
    }
  }

  Alignment _alignmentForSide(TooltipSide side) {
    switch (side) {
      case TooltipSide.top:
        return Alignment.bottomCenter; // origin bottom when appearing above
      case TooltipSide.bottom:
        return Alignment.topCenter; // origin top when appearing below
      case TooltipSide.left:
        return Alignment.centerRight; // origin right when appearing left
      case TooltipSide.right:
        return Alignment.centerLeft; // origin left when appearing right
    }
  }

  Offset _computePosition({
    required TooltipSide side,
    required Rect anchor,
    required Size estimatedTooltipSize,
    required double gap,
  }) {
    switch (side) {
      case TooltipSide.top:
        return Offset(
          anchor.left + (anchor.width - estimatedTooltipSize.width) / 2,
          anchor.top - estimatedTooltipSize.height - gap,
        );
      case TooltipSide.bottom:
        return Offset(
          anchor.left + (anchor.width - estimatedTooltipSize.width) / 2,
          anchor.bottom + gap,
        );
      case TooltipSide.left:
        return Offset(
          anchor.left - estimatedTooltipSize.width - gap,
          anchor.top + (anchor.height - estimatedTooltipSize.height) / 2,
        );
      case TooltipSide.right:
        return Offset(
          anchor.right + gap,
          anchor.top + (anchor.height - estimatedTooltipSize.height) / 2,
        );
    }
  }
}

/// Contenitore animato: fade + scale(0.95→1) + translate (slideOffset)
class _AnimatedTooltipContainer extends StatelessWidget {
  final Animation<double> animation;
  final Offset slideOffset;
  final WidgetBuilder builder;
  final Alignment alignment;

  const _AnimatedTooltipContainer({
    required this.animation,
    required this.slideOffset,
    required this.builder,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = animation;
    final scale = Tween<double>(begin: 0.95, end: 1).animate(animation);
    final slide = Tween<Offset>(
      begin: slideOffset,
      end: Offset.zero,
    ).animate(animation);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: opacity.value,
          child: Transform.translate(
            offset: slide.value,
            child: Transform.scale(
              scale: scale.value,
              alignment: alignment,
              child: builder(context),
            ),
          ),
        );
      },
    );
  }
}

/// Bubble + Arrow (rotated square 45° con radius 2)
class _TooltipBubble extends StatelessWidget {
  final Color bg; // sfondo della bubble (shadcn: foreground)
  final Color fg; // testo/icone (shadcn: background)
  final BorderRadius radius;
  final EdgeInsets padding;
  final TooltipSide side;
  final double arrowSize;
  final Widget child;

  const _TooltipBubble({
    required this.bg,
    required this.fg,
    required this.radius,
    required this.padding,
    required this.side,
    required this.arrowSize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Distanza di "inset" per simulare la traduzione della freccia dentro la bubble
    // (in shadcn l'arrow è parzialmente sotto la bubble, non separato).
    const double arrowInset = 2;

    final bubble = DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Padding(padding: padding, child: child),
    );

    final arrow = Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: arrowSize,
        height: arrowSize,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    // Sovrappone l'arrow alla bubble creando il "notch" come da shadcn.
    final double overlap = (arrowSize / 2) - arrowInset;

    Widget withArrow = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        bubble,
        Positioned(
          // Per lato top: arrow sotto la bubble, parzialmente sovrapposta
          bottom: side == TooltipSide.top ? -overlap : null,
          // Per lato bottom: arrow sopra la bubble
          top: side == TooltipSide.bottom ? -overlap : null,
          // Per lato left/right: sovrapposizione orizzontale
          left: side == TooltipSide.right ? -overlap : null,
          right: side == TooltipSide.left ? -overlap : null,
          child: arrow,
        ),
      ],
    );

    return Material(type: MaterialType.transparency, child: withArrow);
  }
}

/// Osserva la size del child dopo il layout e notifica eventuali cambiamenti.
class _SizeObserver extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;
  const _SizeObserver({required this.child, required this.onChange});

  @override
  State<_SizeObserver> createState() => _SizeObserverState();
}

class _SizeObserverState extends State<_SizeObserver> {
  Size? _lastSize;

  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = context.size;
      if (size != null && size != _lastSize) {
        _lastSize = size;
        widget.onChange(size);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _notify();
  }

  @override
  void didUpdateWidget(covariant _SizeObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    _notify();
    return widget.child;
  }
}
