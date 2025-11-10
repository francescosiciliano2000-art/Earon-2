import 'package:flutter/material.dart';

/// Placeholder semplice per futuri grafici
class ChartPlaceholder extends StatelessWidget {
  final double height;
  const ChartPlaceholder({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text('Grafico (placeholder)',
            style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
