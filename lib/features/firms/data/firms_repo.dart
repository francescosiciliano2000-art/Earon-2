import 'package:supabase_flutter/supabase_flutter.dart';

class FirmsRepo {
  final SupabaseClient sb;
  FirmsRepo(this.sb);

  Future<List<Map<String, dynamic>>> listForUser(String userId) async {
    try {
      final profs =
          await sb.from('profiles').select('firm_id').eq('user_id', userId);

      final ids = (profs as List)
          .map((e) => e['firm_id'])
          .where((v) => v != null && v.toString().isNotEmpty)
          .map((v) => v.toString())
          .toList();

      if (ids.isEmpty) return [];

      final firms =
          await sb.from('firms').select('id,name').inFilter('id', ids);
      return List<Map<String, dynamic>>.from(firms as List);
    } on PostgrestException catch (e) {
      throw Exception('Caricamento studi non riuscito: ${e.message}');
    }
  }
}
