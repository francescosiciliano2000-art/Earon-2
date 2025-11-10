// lib/components/sheet.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Side (equivalente a `side` di shadcn/ui: "top" | "right" | "bottom" | "left")
enum SheetSide { top, right, bottom, left }

/// API di comodo, in linea con l’approccio di `dialog.dart`:
/// mostra uno Sheet modale con overlay, animazioni e border come shadcn/ui.
Future<T?> showSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  SheetSide side = SheetSide.right,
  bool barrierDismissible = true,
  String barrierLabel = 'Close',
  Duration openDuration = const Duration(milliseconds: 500),
  Duration closeDuration = const Duration(milliseconds: 300),
  double? maxWidth,
  double widthFraction = 0.75,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _SheetRoute<T>(
      builder: builder,
      side: side,
      dismissible: barrierDismissible,
      barrierLabelText: barrierLabel,
      openDuration: openDuration,
      closeDuration: closeDuration,
      maxWidth: maxWidth,
      widthFraction: widthFraction,
    ),
  );
}

/// Header, Footer, Title, Description in stile shadcn/ui
class SheetHeader extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry padding;
  const SheetHeader({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [if (child != null) child!],
      ),
    );
  }
}

class SheetFooter extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry padding;
  const SheetFooter({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) {
    // mt-auto -> spinge in basso
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (child != null) child!],
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const SheetTitle(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    return Text(
      text,
      style: (style ?? base)?.copyWith(
        fontWeight: FontWeight.w600, // font-semibold
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class SheetDescription extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const SheetDescription(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    return Text(
      text,
      style: (style ?? base)?.copyWith(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant, // muted-foreground
      ),
    );
  }
}

/// Un pulsante "chiudi" riutilizzabile, analogo a `SheetClose`
class SheetCloseButton extends StatelessWidget {
  final VoidCallback? onClosed;
  const SheetCloseButton({super.key, this.onClosed});

  @override
  Widget build(BuildContext context) {
    // Stili: absolute top-4 right-4, rounded-xs, opacity-70 -> hover 100
    return Positioned(
      top: 16,
      right: 16,
      child: _HoverOpacity(
        child: IconButton(
          onPressed: () {
            Navigator.of(context).maybePop();
            onClosed?.call();
          },
          tooltip: 'Close',
          style: ButtonStyle(
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ), // rounded-xs
            ),
          ),
          icon: const Icon(Icons.close, size: 16),
        ),
      ),
    );
  }
}

/// ROUTE personalizzata per replicare:
/// - Overlay nero 50%
/// - Slide da lato selezionato
/// - Durata open 500ms / close 300ms
/// - Width 75% (w-3/4) con max 384 (sm:max-w-sm) su right/left
/// - Border sul lato aderente (border-l / border-r / border-t / border-b)
class _SheetRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final SheetSide side;
  final bool dismissible; // renamed to avoid collision with getter
  final String barrierLabelText; // renamed to avoid collision with getter
  final Duration openDuration;
  final Duration closeDuration;
  final double? maxWidth;
  final double widthFraction;

  _SheetRoute({
    required this.builder,
    required this.side,
    required this.dismissible,
    required this.barrierLabelText,
    required this.openDuration,
    required this.closeDuration,
    this.maxWidth,
    this.widthFraction = 0.75,
  });

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.5); // bg-black/50
  @override
  bool get maintainState => true;
  @override
  bool get opaque => false;
  @override
  String? get barrierLabel => barrierLabelText;

  @override
  Duration get transitionDuration => openDuration;
  @override
  Duration get reverseTransitionDuration => closeDuration;

  @override
  bool get barrierDismissible => dismissible;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Stack(
        children: [
          // Il barrier viene gestito dal PageRoute (tap-to-dismiss è di default).
          // Qui costruiamo solo il pannello.
          Align(
            alignment: _alignmentForSide(side),
            child: _AnimatedSlideIn(
              side: side,
              animation: animation,
              child: _SheetPanel(
                side: side,
                color: scheme.surface, // bg-background
                borderColor: scheme.outlineVariant, // border-*
                maxWidth: maxWidth,
                widthFraction: widthFraction,
                child: builder(context),
              ),
            ),
          ),
          // Bottone Close (in alto a dx dentro il pannello)
          // Nota: viene posizionato sopra; internamente lo hit-test è sul panel.
        ],
      ),
    );
  }

  Alignment _alignmentForSide(SheetSide s) {
    switch (s) {
      case SheetSide.right:
        return Alignment.centerRight;
      case SheetSide.left:
        return Alignment.centerLeft;
      case SheetSide.top:
        return Alignment.topCenter;
      case SheetSide.bottom:
        return Alignment.bottomCenter;
    }
  }
}

class _SheetPanel extends StatelessWidget {
  final SheetSide side;
  final Color color;
  final Color borderColor;
  final Widget child;
  final double? maxWidth;
  final double widthFraction;

  const _SheetPanel({
    required this.side,
    required this.color,
    required this.borderColor,
    required this.child,
    this.maxWidth,
    this.widthFraction = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // w-3/4 con max 384px (24rem), come "sm:max-w-sm"
    final double targetWidth = side == SheetSide.left || side == SheetSide.right
        ? math.min(size.width * widthFraction, maxWidth ?? 384)
        : size.width;

    // h-auto per top/bottom, full-height per left/right
    final double? targetHeight =
        (side == SheetSide.top || side == SheetSide.bottom)
        ? null
        : size.height;

    final border = switch (side) {
      SheetSide.right => Border(left: BorderSide(color: borderColor, width: 1)),
      SheetSide.left => Border(right: BorderSide(color: borderColor, width: 1)),
      SheetSide.top => Border(bottom: BorderSide(color: borderColor, width: 1)),
      SheetSide.bottom => Border(top: BorderSide(color: borderColor, width: 1)),
    };

    // Container principale del pannello (flex col + gap-4)
    final panel = Material(
      color: color,
      elevation: 8, // shadow-lg
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: targetWidth,
          // Per top/bottom lasciamo height "auto" (in base al contenuto).
        ),
        child: Container(
          decoration: BoxDecoration(border: border),
          child: Stack(
            children: [
              // Contenuto (colonna con gap simile a gap-4)
              _GapColumn(
                gap: 16,
                children: [
                  // Il chiamante costruisce header/body/footer con padding coerenti.
                  // Qui mettiamo solo uno Scroll se serve.
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: child,
                    ),
                  ),
                ],
              ),
              const SheetCloseButton(),
            ],
          ),
        ),
      ),
    );

    if (targetHeight == null) {
      // top/bottom: height auto (lasciamo che il contenuto definisca l'altezza)
      return panel;
    } else {
      // left/right: occupa full height
      return SizedBox(height: targetHeight, child: panel);
    }
  }
}

/// Slide + fade coerenti con:
/// data-[state=open]:slide-in-from-*, data-[state=closed]:slide-out-to-*
/// ease-in-out; open 500ms / close 300ms (gestite dalla route)
class _AnimatedSlideIn extends StatelessWidget {
  final SheetSide side;
  final Animation<double> animation;
  final Widget child;

  const _AnimatedSlideIn({
    required this.side,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tween = switch (side) {
      SheetSide.right => Tween<Offset>(
        begin: const Offset(1.0, 0),
        end: Offset.zero,
      ),
      SheetSide.left => Tween<Offset>(
        begin: const Offset(-1.0, 0),
        end: Offset.zero,
      ),
      SheetSide.top => Tween<Offset>(
        begin: const Offset(0, -1.0),
        end: Offset.zero,
      ),
      SheetSide.bottom => Tween<Offset>(
        begin: const Offset(0, 1.0),
        end: Offset.zero,
      ),
    };

    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);

    return SlideTransition(
      position: tween.animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// Colonna con spaziatura fissa tra i figli (equivalente a gap-4).
class _GapColumn extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const _GapColumn({required this.children, this.gap = 16});

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(SizedBox(height: gap));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced,
    );
  }
}

/// Effetto hover: opacity 0.7 -> 1.0
class _HoverOpacity extends StatefulWidget {
  final Widget child;
  const _HoverOpacity({required this.child});

  @override
  State<_HoverOpacity> createState() => _HoverOpacityState();
}

class _HoverOpacityState extends State<_HoverOpacity> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _hover ? 1.0 : 0.7,
        child: widget.child,
      ),
    );
  }
}
