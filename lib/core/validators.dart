class Validators {
  static String? required(String? v, {String field = 'Campo'}) {
    if (v == null || v.trim().isEmpty) return '$field obbligatorio';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email obbligatoria';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Email non valida';
  }
}
