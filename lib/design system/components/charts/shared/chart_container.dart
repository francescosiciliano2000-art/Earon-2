import 'package:flutter/material.dart';
import 'chart_colors.dart';

class ChartContainer extends StatelessWidget {
  const ChartContainer(
      {super.key, required this.child, this.height = 250, this.colors});
  final Widget child;
  final double height;
  final ChartColors? colors;

  @override
  Widget build(BuildContext context) {
    final c = colors ?? ChartColors.fallback(context);
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(height: height, child: child),
    );
  }
}
