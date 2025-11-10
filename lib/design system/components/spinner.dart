// lib/components/spinner.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Spinner (parità con shadcn/ui Spinner che usa Loader2Icon + `animate-spin`)
/// - default size: 16 (equiv. a "size-4" Tailwind)
/// - aria/semantics: etichetta "Loading" (role=status)
/// - colore: eredita il "currentColor" (IconTheme/DefaultTextStyle) se non passato
/// - animazione: rotazione lineare infinita (1s), come `animate-spin`
class Spinner extends StatefulWidget {
  const Spinner({
    super.key,
    this.size = 16.0,
    this.strokeWidth = 2.0,
    this.semanticsLabel = 'Loading',
    this.color,
  });

  /// Dimensione lato (px). In shadcn `size-4` ≈ 16px.
  final double size;

  /// Spessore dell’anello.
  final double strokeWidth;

  /// Etichetta accessibilità.
  final String semanticsLabel;

  /// Colore opzionale del bordo attivo. Se null, eredita dal contesto (currentColor).
  final Color? color;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000), // Tailwind animate-spin default ~1s
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Eredita "currentColor" come in SVG: prima IconTheme, poi DefaultTextStyle, poi theme primary
    final inheritedColor = IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        theme.colorScheme.primary;
    final effectiveColor = widget.color ?? inheritedColor;

    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      // Flutter non ha `role="status"`, usiamo liveRegion per annuncio
      liveRegion: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RotationTransition(
          turns: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linear),
          ),
          child: CustomPaint(
            painter: _Loader2Painter(
              color: effectiveColor,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter che approssima il glyph di `Loader2Icon`:
/// un cerchio con una piccola gap, per rendere visibile la rotazione.
class _Loader2Painter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _Loader2Painter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    final double inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth);

    // Disegna un arco (circa 300°) lasciando una gap (~60°) come molti spinner SVG.
    // Questo rende visibile la rotazione, come `Loader2Icon` con animate-spin.
    const double sweepDegrees = 300; // 300° arco visibile
    final double startRadians = -math.pi / 2; // parte dall'alto
    final double sweepRadians = sweepDegrees * math.pi / 180.0;

    canvas.drawArc(rect, startRadians, sweepRadians, false, paint);
  }

  @override
  bool shouldRepaint(covariant _Loader2Painter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
