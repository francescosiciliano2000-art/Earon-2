import 'package:supabase_flutter/supabase_flutter.dart';

class GlobalSearchRepo {
  final SupabaseClient sb;
  GlobalSearchRepo(this.sb);

  Future<Map<String, List<Map<String, dynamic>>>> searchAll(
      String q, String? firmId) async {
    // se manca la firm o query vuota → nessun risultato
    if (firmId == null || firmId.isEmpty || q.trim().isEmpty) {
      return {'clients': [], 'matters': [], 'invoices': [], 'documents': []};
    }

    final like = '%${q.trim()}%';

    final futures = await Future.wait([
      sb
          .from('clients')
          .select('client_id,name,email')
          .eq('firm_id', firmId)
          .eq('status', 'active') // Filtra solo clienti attivi
          .ilike('name', like)
          .limit(5),
      sb
          .from('matters')
          .select('id,code,title,client_id')
          .eq('firm_id', firmId)
          .ilike('title', like)
          .limit(5),
      sb
          .from('invoices')
          .select('id,number,client_id,total,issue_date')
          .eq('firm_id', firmId)
          .ilike('number', like)
          .limit(5),
      sb
          .from('documents')
          .select('id,filename,matter_id,client_id')
          .eq('firm_id', firmId)
          .ilike('filename', like)
          .limit(5),
    ]);

    return {
      'clients': List<Map<String, dynamic>>.from(futures[0] as List),
      'matters': List<Map<String, dynamic>>.from(futures[1] as List),
      'invoices': List<Map<String, dynamic>>.from(futures[2] as List),
      'documents': List<Map<String, dynamic>>.from(futures[3] as List),
    };
  }
}
