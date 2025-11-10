import 'package:flutter/material.dart';
import '../../theme/themes.dart';
import '../../theme/global_tokens.dart';

/// SparklineChart: grafico linea minimale per KPI
/// - Usa i token del Design System (colori) e si adatta al tema
/// - Dati: lista di double (es. [prev, current])
class SparklineChart extends StatelessWidget {
  final List<double> data;
  final double height;
  final double strokeWidth;
  final EdgeInsets padding;


  const SparklineChart({
    super.key,
    required this.data,
    this.height = 96,
    this.strokeWidth = 2.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    final gt = Theme.of(context).extension<GlobalTokens>();
    final dt = Theme.of(context).extension<DefaultTokens>();
    
    return SizedBox(
      height: height,
      child: Padding(
        padding: padding,
        child: CustomPaint(
          painter: _SparklinePainter(
            data: data,
            color: (dt?.chart.isNotEmpty == true ? dt!.chart[2] : null) ?? Theme.of(context).colorScheme.primary,
            strokeWidth: strokeWidth,
            gridColor: gt?.border ?? Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final Color gridColor;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Draw a subtle baseline grid
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // horizontal mid line
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), grid);

    // Normalize data
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final span = (maxVal - minVal).abs();
    final safeSpan = span == 0 ? 1.0 : span;

    // Build path across width
    final dx = size.width / (data.length - 1);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final normY = (data[i] - minVal) / safeSpan; // 0..1
      final y = size.height - (normY * (size.height * 0.9)); // keep 10% padding top
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}