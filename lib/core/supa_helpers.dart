import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

SupabaseClient get sb => Supabase.instance.client;

Future<String?> getCurrentFirmId() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString('currentFirmId');
}

Future<void> setCurrentFirmId(String firmId) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString('currentFirmId', firmId);
}

String todayISODate() => DateTime.now().toIso8601String().substring(0, 10);

Future<void> removeCurrentFirmId() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove('currentFirmId');
}

Future<void> ensureFirmSelected(BuildContext context) async {
  final sp = await SharedPreferences.getInstance();
  final existing = sp.getString('currentFirmId');
  final sb = Supabase.instance.client;
  final uid = sb.auth.currentUser?.id;
  final email = sb.auth.currentUser?.email;
  if (uid == null) {
    debugPrint('[Firm] ensureFirmSelected: nessun utente autenticato');
    return;
  }
  debugPrint('[Firm] ensureFirmSelected: uid=$uid email=${email ?? 'null'}');

  final profs = await sb.from('profiles').select('firm_id').eq('user_id', uid);
  final ids = (profs as List)
      .map((e) => e['firm_id'])
      .where((v) => v != null && v.toString().isNotEmpty)
      .map((v) => v.toString())
      .toList();

  if (ids.isEmpty) {
    debugPrint('[Firm] ensureFirmSelected: nessuna firm associata');
    if (context.mounted) context.go('/auth/select_firm');
    return;
  }

  // Verifica: se esiste firm salvata ma NON appartiene all'utente corrente → correggi
  if (existing != null && existing.isNotEmpty) {
    final belongs = ids.contains(existing);
    if (belongs) {
      debugPrint('[Firm] ensureFirmSelected: firmId valida=$existing');
      return; // ok
    }
    debugPrint(
        '[Firm] ensureFirmSelected: firmId salvata non valida → riassegno');
    await sp.setString('currentFirmId', ids.first);
    debugPrint('[Firm] ensureFirmSelected: firmId impostata=${ids.first}');
    return;
  }

  if (ids.length == 1) {
    await sp.setString('currentFirmId', ids.first);
    debugPrint(
        '[Firm] ensureFirmSelected: auto-selezionata firmId=${ids.first}');
    return;
  }
  debugPrint('[Firm] ensureFirmSelected: più di una firm → chiedi selezione');
  if (context.mounted) context.go('/auth/select_firm');
}
