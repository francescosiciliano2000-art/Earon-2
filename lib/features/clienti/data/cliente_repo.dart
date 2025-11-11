// lib/features/clienti/data/cliente_repo.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/core/api_client.dart';

class ClienteRepo {
  final SupabaseClient sb;
  final ApiClient api;
  ClienteRepo(this.sb, [ApiClient? api]) : api = api ?? ApiClient.create();

  // LISTA con filtri + ordinamenti + paginazione
  Future<List<Map<String, dynamic>>> list({
    required String firmId,
    String? q,
    String? kind, // mantenuto per compatibilità UI, non filtrato a DB
    List<String> tagsAny = const [], // mantenuto per compatibilità UI
    List<String> tagsAll = const [], // mantenuto per compatibilità UI
    String orderBy = 'created_at',
    bool asc = false,
    int limit = 50,
    int offset = 0,
  }) async {
    // Base query
    PostgrestFilterBuilder qf = sb
        .from('clients')
        .select('*')
        .eq('firm_id', firmId);

    if (q != null && q.trim().isNotEmpty) {
      final term = q.trim();
      final tokens = term.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      final t1 = tokens.isNotEmpty ? tokens.first : null;
      final t2 = tokens.length > 1 ? tokens.last : null;
      // Ricerca avanzata:
      // - name ILIKE %term%
      // - surname ILIKE %term%
      // - and(name ILIKE %t1%, surname ILIKE %t2%)
      // - and(name ILIKE %t2%, surname ILIKE %t1%)
      final buf = <String>[
        'name.ilike.%$term%',
        'surname.ilike.%$term%',
        if (t1 != null && t2 != null) 'and(name.ilike.%$t1%,surname.ilike.%$t2%)',
        if (t1 != null && t2 != null) 'and(name.ilike.%$t2%,surname.ilike.%$t1%)',
      ];
      qf = qf.or(buf.join(','));
    }
    // kind/tags non sono presenti nello schema corrente: ignoriamo il filtro lato DB

    final qt = qf.order(orderBy, ascending: asc).range(offset, offset + limit - 1);
    final res = await qt;
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Conta il totale dei clienti per i filtri correnti (usato per paginazione)
  Future<int> count({
    required String firmId,
    String? q,
    String? kind, // mantenuto per compatibilità UI
    List<String> tagsAny = const [], // mantenuto per compatibilità UI
    List<String> tagsAll = const [], // mantenuto per compatibilità UI
  }) async {
    // Usa il conteggio nativo PostgREST via Supabase con FetchOptions(count: CountOption.exact)
    // per ottenere il totale esatto senza dipendenze dal .env/API esterna.
    PostgrestFilterBuilder qf = sb
        .from('clients')
        .select('client_id')
        .eq('firm_id', firmId);

    if (q != null && q.trim().isNotEmpty) {
      final term = q.trim();
      final tokens = term.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      final t1 = tokens.isNotEmpty ? tokens.first : null;
      final t2 = tokens.length > 1 ? tokens.last : null;
      final buf = <String>[
        'name.ilike.*$term*',
        'surname.ilike.*$term*',
        if (t1 != null && t2 != null) 'and(name.ilike.*$t1*,surname.ilike.*$t2*)',
        if (t1 != null && t2 != null) 'and(name.ilike.*$t2*,surname.ilike.*$t1*)',
      ];
      qf = qf.or(buf.join(','));
    }

    // Esegui query headless; il valore viene ritornato nell'oggetto risposta.
    final res = await qf.count(CountOption.exact);
    try {
      // Accesso dinamico per evitare warning su nullability
      final dynamic dyn = res;
      final c = dyn.count;
      if (c is int) return c;
      final data = dyn.data;
      if (data is List) return data.length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // CREA (ritorna id)
  Future<String> create({
    required String firmId,
    required String name,
    String? email,
    String? taxCode,
    String? vatNumber,
  }) async {
    final payload = {
      // NON inviare più 'client_id': lo genera Postgres
      'firm_id': firmId,
      'name': name,
      'email': email,
      'tax_code': taxCode,
      'vat_number': vatNumber,
    }..removeWhere((k, v) => v == null);

    final res =
        await sb.from('clients').insert(payload).select('client_id').single();

    return res['client_id'] as String;
  }

  // UPDATE (patch)
  Future<void> update(String clientId, Map<String, dynamic> patch) async {
    await sb.from('clients').update(patch).eq('client_id', clientId);
  }

  // GET ONE
  Future<Map<String, dynamic>?> getOne(String clientId) async {
    final res = await sb
        .from('clients')
        .select('*')
        .eq('client_id', clientId)
        .eq('status', 'active') // Filtra solo clienti attivi
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  // DELETE sicuro (gestisce FK)
  Future<String?> safeDelete(String clientId) async {
    try {
      await sb.from('clients').delete().eq('client_id', clientId);
      return null;
    } on PostgrestException catch (e) {
      final msg = (e.message).toString();
      final det = (e.details ?? '').toString();

      if (msg.contains('violates foreign key constraint') ||
          det.contains('foreign key')) {
        return 'Impossibile eliminare: il cliente è collegato ad altre entità (pratiche, fatture, documenti).';
      }
      return 'Errore: $msg';
    } catch (e) {
      return 'Errore: $e';
    }
  }

  // ===== RELAZIONI =====

  Future<List<Map<String, dynamic>>> mattersByClient(String clientId) async {
    final res = await sb
        .from('matters')
        .select('matter_id, code, title, counterparty_name, created_at')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> documentsByClient(String clientId) async {
    // 1) PROVA: filtro diretto su documents.client_id (se esiste)
    try {
      final res =
          await sb.from('documents').select('*').eq('client_id', clientId);
      final list = List<Map<String, dynamic>>.from(res as List);
      list.sort((a, b) {
        final da =
            (a['created_at'] ?? a['uploaded_at'] ?? a['date'])?.toString();
        final db =
            (b['created_at'] ?? b['uploaded_at'] ?? b['date'])?.toString();
        return (db ?? '').compareTo(da ?? ''); // DESC
      });
      return list;
    } on PostgrestException catch (e) {
      // 2) FALLBACK: non c'è client_id → risali dalle pratiche (matters) e filtra per matter_id
      if (e.code != '42703') rethrow; // errore diverso → propaga

      // prendo le practice del cliente per ottenere gli ids
      final midsRes = await sb
          .from('matters')
          .select('matter_id')
          .eq('client_id', clientId);

      final mids = (midsRes as List)
          .map((r) => r['matter_id'])
          .whereType<String>()
          .toList();

      if (mids.isEmpty) return [];

      // Postgrest-dart (versione tua) non ha in_ → uso filter('in', '(... )')
      String pgArray(List<String> ids) =>
          '(${ids.map((id) => '"$id"').join(',')})';

      final res2 = await sb
          .from('documents')
          .select('*')
          .filter('matter_id', 'in', pgArray(mids));

      final list = List<Map<String, dynamic>>.from(res2 as List);
      list.sort((a, b) {
        final da =
            (a['created_at'] ?? a['uploaded_at'] ?? a['date'])?.toString();
        final db =
            (b['created_at'] ?? b['uploaded_at'] ?? b['date'])?.toString();
        return (db ?? '').compareTo(da ?? ''); // DESC
      });
      return list;
    }
  }

  Future<List<Map<String, dynamic>>> invoicesByClient(String clientId) async {
    final res = await sb
        .from('invoices')
        .select('invoice_id, number, issue_date, totals')
        .eq('client_id', clientId)
        .order('issue_date', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ====== PAGAMENTI PER CLIENTE ======
  Future<List<Map<String, dynamic>>> paymentsByClient({
    required String firmId,
    required String clientId,
    int limit = 100,
  }) async {
    // Variante A: se la tabella payments HA client_id
    try {
      final res = await sb
          .from('payments')
          // join con invoices per avere il numero fattura e filtrare per client
          .select(
            'payment_id, date, method, amount, reference, invoices!inner(invoice_id, number, client_id)',
          )
          .eq('invoices.client_id', clientId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      // Se fallisce (es. manca client_id), tento la Variante B
    }

    // Variante B: se payments NON ha client_id → join su invoices
    final res2 = await sb
        .from('payments')
        .select('''
          payment_id, amount, paid_at, method, note,
          invoices!inner(invoice_id, number, client_id)
        ''')
        .eq('firm_id', firmId)
        .eq('invoices.client_id', clientId)
        .order('paid_at', ascending: false)
        .limit(limit);

    final out = <Map<String, dynamic>>[];
    for (final r in (res2 as List)) {
      final inv = r['invoices'] as Map<String, dynamic>?;
      out.add({
        'payment_id': r['payment_id'],
        'invoice_id': inv?['invoice_id'],
        'invoice_number': inv?['number'],
        'amount': r['amount'],
        'paid_at': r['paid_at'],
        'method': r['method'],
        'note': r['note'],
      });
    }
    return out;
  }

  // ===== EXPORT CSV =====
  Future<String> exportCsv(String firmId, {String? kind}) async {
    final rows = await list(firmId: firmId, kind: kind, limit: 10000);
    final headers = [
      'client_id',
      'firm_id',
      'name',
      'surname',
      'kind',
      'email',
      'tax_code',
      'vat_number',
      'phone',
      'address',
      'city',
      'province',
      'zip',
      'country',
      'billing_notes',
      'tags',
      'status',
      'created_at',
      'updated_at'
    ];
    final buf = StringBuffer();
    buf.writeln(headers.join(','));
    for (final r in rows) {
      final line = headers.map((h) {
        final v = r[h];
        if (v == null) return '';
        if (v is List || v is Map) return jsonEncode(v).replaceAll('\n', ' ');
        return '$v'.replaceAll(',', ' ');
      }).join(',');
      buf.writeln(line);
    }
    return buf.toString();
  }

  // ===== MERGE CLIENTS (base) =====
  Future<String?> mergeClients({
    required String masterId,
    required List<String> duplicateIds,
  }) async {
    if (duplicateIds.isEmpty) return null;

    try {
      // sposta relazioni sulle tabelle che puntano a client_id
      await sb
          .from('matters')
          .update({'client_id': masterId}).inFilter('client_id', duplicateIds);

      await sb
          .from('documents')
          .update({'client_id': masterId}).inFilter('client_id', duplicateIds);

      await sb
          .from('invoices')
          .update({'client_id': masterId}).inFilter('client_id', duplicateIds);

      // unione tag sul master
      final master = await getOne(masterId);
      final Set<String> masterTags =
          ((master?['tags'] as List?)?.map((e) => '$e').toSet()) ?? {};

      for (final dupId in duplicateIds) {
        final dup = await getOne(dupId);
        final dtags = ((dup?['tags'] as List?)?.map((e) => '$e').toSet()) ?? {};
        masterTags.addAll(dtags);
      }
      await update(masterId, {'tags': masterTags.toList()});

      // elimina duplicati
      await sb.from('clients').delete().inFilter('client_id', duplicateIds);

      return null;
    } catch (e) {
      return 'Merge non riuscito: $e';
    }
  }

  // ===== MERGE AVANZATO =====
  Future<String?> mergeClientsAdvanced({
    required String masterId,
    required List<String> duplicateIds,
    required Map<String, dynamic> patch,
  }) async {
    try {
      // 1) patch sul master
      if (patch.isNotEmpty) {
        await update(masterId, patch);
      }

      // 2) riallineo relazioni su tabelle che puntano a client_id
      if (duplicateIds.isNotEmpty) {
        await sb.from('matters').update({'client_id': masterId}).filter(
            'client_id', 'in', duplicateIds);
        await sb.from('documents').update({'client_id': masterId}).filter(
            'client_id', 'in', duplicateIds);
        await sb.from('invoices').update({'client_id': masterId}).filter(
            'client_id', 'in', duplicateIds);
        await sb
            .from('payments')
            .update({'client_id': masterId})
            .filter('client_id', 'in', duplicateIds)
            .catchError((_) {}); // se la colonna non esiste è ok
      }

      // 3) unione tag (master + dups + eventuali dal patch)
      final master = await getOne(masterId);
      final Set<String> tags =
          ((master?['tags'] as List?)?.map((e) => '$e').toSet()) ?? {};
      if (patch['tags'] is List) {
        tags.addAll((patch['tags'] as List).map((e) => '$e'));
      }
      for (final id in duplicateIds) {
        final dup = await getOne(id);
        tags.addAll(((dup?['tags'] as List?)?.map((e) => '$e').toSet()) ?? {});
      }
      await update(masterId, {'tags': tags.toList()});

      // 4) elimina duplicati
      if (duplicateIds.isNotEmpty) {
        await sb
            .from('clients')
            .delete()
            .filter('client_id', 'in', duplicateIds);
      }

      return null;
    } catch (e) {
      return 'Merge non riuscito: $e';
    }
  }

  // ===== BULK UPSERT (CSV import) =====
  Future<String?> bulkUpsertClients({
    required String firmId,
    required List<Map<String, dynamic>> rows,
  }) async {
    try {
      final sanitized = <Map<String, dynamic>>[];

      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw);

        // firm_id sempre impostato
        m['firm_id'] = firmId;

        // normalizza tags (accetta stringa "tag1, tag2" o lista)
        final t = m['tags'];
        if (t is String) {
          final parts = t
              .split(RegExp(r'[;,]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          m['tags'] = parts;
        } else if (t == null) {
          m['tags'] = [];
        }

        // client_id se manca -> generato
        m['client_id'] ??= const UuidV4().generate();

        // rimuovi chiavi null
        m.removeWhere((k, v) => v == null);

        sanitized.add(m);
      }

      await sb
          .from('clients')
          .upsert(sanitized, onConflict: 'client_id')
          .select('client_id');

      return null;
    } on PostgrestException catch (e) {
      return 'Errore import: ${e.message}';
    } catch (e) {
      return 'Errore import: $e';
    }
  }
}

// ====== piccolo helper per UUID v4 ======
class UuidV4 {
  const UuidV4();
  String generate() {
    String r(int n) =>
        (DateTime.now().microsecondsSinceEpoch + n).toRadixString(16);
    return '${r(1)}-${r(2)}-${r(3)}-${r(4)}-${r(5)}';
  }
}
