import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Convert an OKLCH color to a Flutter [Color] (sRGB) with optional alpha.
/// Parameters:
/// - [l]: lightness in [0,1]
/// - [c]: chroma (>=0)
/// - [hDeg]: hue angle in degrees (0..360). Ignored when c==0.
/// - [alpha]: alpha in [0,1]
Color oklch(double l, double c, double hDeg, {double alpha = 1.0}) {
  // Convert OKLCH -> OKLab
  final hRad = (hDeg % 360) * math.pi / 180.0;
  final aLab = c * math.cos(hRad);
  final bLab = c * math.sin(hRad);

  // OKLab -> linear sRGB
  final l_ = l + 0.3963377774 * aLab + 0.2158037573 * bLab;
  final m_ = l - 0.1055613458 * aLab - 0.0638541728 * bLab;
  final s_ = l - 0.0894841775 * aLab - 1.2914855480 * bLab;

  double pow3(double x) => x * x * x;
  final l3 = pow3(l_);
  final m3 = pow3(m_);
  final s3 = pow3(s_);

  double rLin = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699282 * s3;
  double gLin = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  double bLin = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

  // Clamp linear values to [0,1]
  rLin = rLin.clamp(0.0, 1.0);
  gLin = gLin.clamp(0.0, 1.0);
  bLin = bLin.clamp(0.0, 1.0);

  double toSrgb(double x) {
    if (x <= 0.0031308) return 12.92 * x;
    final v = math.pow(x, 1.0 / 2.4) as double;
    return 1.055 * v - 0.055;
  }

  int clamp8(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

  int r = clamp8((toSrgb(rLin) * 255.0).round());
  int g = clamp8((toSrgb(gLin) * 255.0).round());
  int b = clamp8((toSrgb(bLin) * 255.0).round());
  int a8 = clamp8((alpha * 255.0).round());

  return Color((a8 << 24) | (r << 16) | (g << 8) | b);
}
