// lib/components/skeleton.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart';

/// AppSkeleton — placeholder con effetto pulse (come shadcn/ui)
/// API minima:
/// - width/height opzionali (se null espande in larghezza/altezza disponibile)
/// - borderRadius (default: md)
/// - baseColor: usa "muted" semantico (ricavato dal ColorScheme) o override
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    // Tailwind animate-pulse: 2s cubic-bezier(0.4, 0, 0.6, 1)
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _curve = CurvedAnimation(parent: _controller, curve: const Cubic(0.4, 0.0, 0.6, 1.0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<ShadcnRadii>()!;

    // Base "muted" dal ColorScheme
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final base = widget.baseColor ?? (isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.20)
        : cs.surfaceContainerHighest.withValues(alpha: 0.60));

    // Colore di picco leggermente più chiaro per dare l'effetto di respiro
    // Manteniamo una variazione molto sottile per evitare flicker/jank.
    final Color target = Color.lerp(base, Colors.white, isDark ? 0.10 : 0.06)!;

    final radius = widget.borderRadius ?? radii.md;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          // Interpolazione del colore (invece di Opacity sul subtree) per evitare lag
          final Color animated = Color.lerp(base, target, _curve.value)!;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: animated,
              borderRadius: radius,
            ),
          );
        },
      ),
    );
  }
}

// Nota: niente shimmer. L'effetto è una leggera variazione del fill come in shadcn/ui.