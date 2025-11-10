// lib/core/shared_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

const _kCurrentFirmId = 'currentFirmId';
const _kRememberMe = 'rememberMe';
const _kRememberedEmail = 'rememberedEmail';

Future<String?> currentFirmId() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(_kCurrentFirmId);
}

Future<void> setCurrentFirmId(String firmId) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kCurrentFirmId, firmId);
}

Future<void> clearCurrentFirmId() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kCurrentFirmId);
}

// --- Remember Me helpers ---

Future<bool> getRememberMe() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(_kRememberMe) ?? false;
}

Future<void> setRememberMe(bool value) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kRememberMe, value);
}

Future<String?> getRememberedEmail() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString(_kRememberedEmail);
}

Future<void> setRememberedEmail(String email) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kRememberedEmail, email);
}

Future<void> clearRememberedEmail() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kRememberedEmail);
}
