import 'package:flutter/material.dart';
import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';

/// Helper per determinare il tipo di finestra utilizzando l'API
/// `getWindowType` del package `adaptive_breakpoints`.

AdaptiveWindowType _typeOf(BuildContext context) => getWindowType(context);

bool isDisplayMobile(BuildContext context) {
  final t = _typeOf(context);
  return t == AdaptiveWindowType.small || t == AdaptiveWindowType.xsmall;
}

bool isDisplayTablet(BuildContext context) {
  final t = _typeOf(context);
  return t == AdaptiveWindowType.medium;
}

bool isDisplayDesktop(BuildContext context) {
  final t = _typeOf(context);
  return t == AdaptiveWindowType.large || t == AdaptiveWindowType.xlarge;
}

bool isDisplayXlDesktop(BuildContext context) {
  final t = _typeOf(context);
  return t == AdaptiveWindowType.xlarge;
}

/// Restituisce una label utile per logging/analytics
String windowTypeLabel(BuildContext context) {
  switch (_typeOf(context)) {
    case AdaptiveWindowType.xsmall:
      return 'xsmall';
    case AdaptiveWindowType.small:
      return 'small';
    case AdaptiveWindowType.medium:
      return 'medium';
    case AdaptiveWindowType.large:
      return 'large';
    case AdaptiveWindowType.xlarge:
      return 'xlarge';
  }
  // Fallback di sicurezza per evitare ritorni nulli in caso di valori futuri.
  return 'unknown';
}
