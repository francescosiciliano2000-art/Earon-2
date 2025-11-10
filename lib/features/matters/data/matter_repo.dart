// lib/features/matters/data/matter_repo.dart
// Repository per la gestione delle Pratiche (matters) con Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import 'package:gestionale_desktop/core/api_client.dart';

import 'matter_model.dart';

/// Eccezione minimale per i repository
class RepoException implements Exception {
  final String message;
  RepoException(this.message);
  @override
  String toString() => message;
}

class MatterRepo {
  final SupabaseClient sb;
  final ApiClient api;
  MatterRepo(this.sb, [ApiClient? api]) : api = api ?? ApiClient.create();

  /// Lista con filtri + search + paginazione
  /// Nota: courtId e responsibleId non esistono nello schema reale; court è text e
  /// non c'è un responsabile a livello di practice. Usiamo courtId come filtro su `court`.
  Future<List<Matter>> list({
    List<String> status = const [],
    String? clientId,
    String? courtId,
    String? responsibleId, // non supportato dallo schema → ignorato
    String? search,
    /// Campi di ricerca opzionali: se null usa il comportamento default (ampio).
    /// Valori supportati: 'code', 'rg_number', 'client_name', 'client_surname',
    /// oltre ai campi storici 'title', 'court', 'judge', 'description', 'counterparty_name'.
    List<String>? searchFields,
    int page = 1,
    int pageSize = 50,
    String? orderBy,
    bool asc = true,
  }) async {
    final fid = await getCurrentFirmId();
    if (fid == null || fid.isEmpty) {
      throw RepoException('Nessuno studio selezionato.');
    }

    PostgrestFilterBuilder q = sb
        .from('matters')
        .select([
          Matter.colId,
          Matter.colFirmId,
          Matter.colClientId,
          Matter.colCode,
          Matter.colTitle,
          Matter.colStatus,
          Matter.colArea,
          Matter.colCourt,
          Matter.colJudge,
          Matter.colDescription,
          Matter.colCounterpartyName,
          Matter.colRgNumber,
          Matter.colOpenedAt,
          Matter.colClosedAt,
          Matter.colCreatedAt,
          // Join cliente per visualizzare il nome
          // company_name non esiste nello schema: usiamo name (+ company_type)
          'client:clients(client_id,name,surname,kind,company_type)'
        ].join(','))
        .eq(Matter.colFirmId, fid);

    if (status.isNotEmpty) {
      q = q.inFilter(Matter.colStatus, status);
    }
    if (clientId != null && clientId.isNotEmpty) {
      q = q.eq(Matter.colClientId, clientId);
    }
    if (courtId != null && courtId.isNotEmpty) {
      q = q.eq(Matter.colCourt, courtId);
    }
    // responsibleId non presente nello schema matters → ignoriamo il filtro

    if (search != null && search.trim().isNotEmpty) {
      // PostgREST usa * come wildcard per like/ilike
      final like = '*${search.trim()}*';
      // Campi richiesti; default: codice, RG, cliente (per specifica utente)
      final fields = (searchFields == null || searchFields.isEmpty)
          ? <String>['code', 'rg_number', 'client', 'counterparty_name']
          : searchFields;

      final wantsCode = fields.contains('code');
      final wantsRg = fields.contains('rg_number');
      final wantsClient = fields.contains('client') ||
          fields.contains('client_name') ||
          fields.contains('client_surname');
      final wantsCounterparty =
          fields.contains('counterparty_name') || fields.contains('counterparty');

      final parts = <String>[];
      if (wantsCode) parts.add('${Matter.colCode}.ilike.$like');
      if (wantsRg) parts.add('${Matter.colRgNumber}.ilike.$like');
      if (wantsCounterparty) {
        parts.add('${Matter.colCounterpartyName}.ilike.$like');
      }

      if (wantsClient) {
        // Ricerca clienti per nome/cognome e filtra per client_id.in.(...)
        try {
          final clRes = await sb
              .from('clients')
              .select('client_id')
              .eq('firm_id', fid)
              .or('name.ilike.$like,surname.ilike.$like')
              .limit(200);
          final clList = List<Map<String, dynamic>>.from(clRes as List);
          final ids = clList
              .map((e) => '${e['client_id'] ?? ''}')
              .where((v) => v.isNotEmpty)
              .toList();
          if (ids.isNotEmpty) {
            parts.add('${Matter.colClientId}.in.(${ids.join(',')})');
          }
        } catch (_) {
          // ignora errori nella ricerca clienti; prosegui con code/rg
        }
      }

      if (parts.isNotEmpty) {
        q = q.or(parts.join(','));
      }
    }

    final start =
        ((page <= 0 ? 1 : page) - 1) * (pageSize <= 0 ? 50 : pageSize);
    final end = start + (pageSize <= 0 ? 50 : pageSize) - 1;

    // Ordinamento dinamico
    String mapOrder(String? f) {
      switch ((f ?? '').trim()) {
        case 'code':
          return Matter.colCode;
        case 'title':
          return Matter.colTitle;
        case 'status':
          return Matter.colStatus;
        case 'client_id':
          return Matter.colClientId;
        case 'court':
          return Matter.colCourt;
        case 'judge':
          return Matter.colJudge;
        case 'counterparty_name':
          return Matter.colCounterpartyName;
        case 'rg_number':
          return Matter.colRgNumber;
        case 'opened_at':
          return Matter.colOpenedAt;
        case 'closed_at':
          return Matter.colClosedAt;
        case 'created_at':
        default:
          return Matter.colCreatedAt;
      }
    }

    final col = mapOrder(orderBy);
    final res = await q.order(col, ascending: asc).range(start, end);
    if (res is List) {
      final list = List<Map<String, dynamic>>.from(res);
      return list.map(Matter.fromJson).toList();
    }
    if (res is Map) {
      final err = Map<String, dynamic>.from(res);
      final msg = (err['message'] ?? err['error'] ?? 'Risposta non valida').toString();
      throw RepoException('Errore ricerca pratiche: $msg');
    }
    throw RepoException('Errore ricerca pratiche: risposta non valida');
  }

  /// Conta il totale delle pratiche per i filtri correnti (per paginazione API)
  Future<int> count({
    List<String> status = const [],
    String? clientId,
    String? courtId,
    String? search,
    /// Campi di ricerca opzionali: coerenti con list()
    List<String>? searchFields,
  }) async {
    final fid = await getCurrentFirmId();
    if (fid == null || fid.isEmpty) {
      throw RepoException('Nessuno studio selezionato.');
    }

    final conds = <String>['${Matter.colFirmId}.eq.$fid'];
    if (status.isNotEmpty) {
      String quote(String s) => '"${s.replaceAll('"', '')}"';
      final items = status.map(quote).join(',');
      conds.add('${Matter.colStatus}.in.($items)');
    }
    if (clientId != null && clientId.isNotEmpty) {
      conds.add('${Matter.colClientId}.eq.$clientId');
    }
    if (courtId != null && courtId.isNotEmpty) {
      conds.add('${Matter.colCourt}.eq.$courtId');
    }

    String? orStr;
    if (search != null && search.trim().isNotEmpty) {
      final like = '*${search.trim()}*';
      final fields = (searchFields == null || searchFields.isEmpty)
          ? <String>['code', 'rg_number', 'client']
          : searchFields;

      final wantsCode = fields.contains('code');
      final wantsRg = fields.contains('rg_number');
      final wantsClient = fields.contains('client') ||
          fields.contains('client_name') ||
          fields.contains('client_surname');

      final parts = <String>[];
      if (wantsCode) parts.add('${Matter.colCode}.ilike.$like');
      if (wantsRg) parts.add('${Matter.colRgNumber}.ilike.$like');

      if (wantsClient) {
        try {
          final clRes = await sb
              .from('clients')
              .select('client_id')
              .eq('firm_id', fid)
              .or('name.ilike.$like,surname.ilike.$like')
              .limit(200);
          final clList = List<Map<String, dynamic>>.from(clRes as List);
          final ids = clList
              .map((e) => '${e['client_id'] ?? ''}')
              .where((v) => v.isNotEmpty)
              .toList();
          if (ids.isNotEmpty) {
            parts.add('${Matter.colClientId}.in.(${ids.join(',')})');
          }
        } catch (_) {}
      }

      if (parts.isNotEmpty) orStr = parts.join(',');
    }

    final Map<String, dynamic> query = {
      'select': Matter.colId,
      if (conds.isNotEmpty) 'and': '(${conds.join(',')})',
      if (orStr != null) 'or': '($orStr)',
    };

    final total = await api.count('matters', query: query);
    return total;
  }

  /// Ottieni una pratica per id
  Future<Matter?> get(String id) async {
    if (id.isEmpty) return null;
    final res = await sb
        .from('matters')
        .select([
          '*',
          'client:clients(client_id,name,surname,kind,company_type)'
        ].join(','))
        .eq(Matter.colId, id)
        .maybeSingle();
    if (res == null) return null;
    return Matter.fromJson(Map<String, dynamic>.from(res));
  }

  /// Crea una nuova pratica.
  /// Nota: `code` è NOT NULL e unique per firm → generiamo un codice temporaneo.
  Future<Matter> create({
    required String clientId,
    required String subject,
    String? status,
    String? area,
    String? courtId,
    String? judge,
    String? counterpartyName,
    String? rgNumber,
    String? opposingAttorneyName,
    String? registryCode,
    String? courtSection,
    DateTime? openedAt,
    String? responsibleId, // non supportato dallo schema
    String? notes,
  }) async {
    final fid = await getCurrentFirmId();
    if (fid == null || fid.isEmpty) {
      throw RepoException('Nessuno studio selezionato.');
    }

    final code = 'M-${DateTime.now().millisecondsSinceEpoch}';

    String? dateOnly(DateTime? d) => d?.toIso8601String().substring(0, 10);

    final payload = <String, dynamic>{
      Matter.colFirmId: fid,
      Matter.colClientId: clientId,
      Matter.colCode: code,
      Matter.colTitle: subject,
      if (status != null && status.isNotEmpty) Matter.colStatus: status,
      if (area != null && area.isNotEmpty) Matter.colArea: area,
      if (courtId != null && courtId.isNotEmpty) Matter.colCourt: courtId,
      if (judge != null && judge.isNotEmpty) Matter.colJudge: judge,
      if (counterpartyName != null && counterpartyName.isNotEmpty)
        Matter.colCounterpartyName: counterpartyName,
      if (rgNumber != null && rgNumber.isNotEmpty) Matter.colRgNumber: rgNumber,
      if (opposingAttorneyName != null && opposingAttorneyName.isNotEmpty)
        Matter.colOpposingAttorneyName: opposingAttorneyName,
      if (registryCode != null && registryCode.isNotEmpty)
        Matter.colRegistryCode: registryCode,
      if (courtSection != null && courtSection.isNotEmpty)
        Matter.colCourtSection: courtSection,
      if (notes != null && notes.isNotEmpty) Matter.colDescription: notes,
      Matter.colOpenedAt: dateOnly(openedAt) ?? todayISODate(),
    }..removeWhere((k, v) => v == null);

    try {
      final res = await sb.from('matters').insert(payload).select('*').single();
      return Matter.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      throw RepoException('Creazione pratica non riuscita: ${e.message}');
    } catch (e) {
      throw RepoException('Creazione pratica non riuscita: $e');
    }
  }

  /// Aggiorna campi editabili della pratica
  Future<Matter> update(
    String id, {
    String? code,
    String? subject,
    String? status,
    String? area,
    String? courtId,
    String? judge,
    String? notes,
    String? counterpartyName,
    String? rgNumber,
    String? opposingAttorneyName,
    String? registryCode,
    String? courtSection,
    DateTime? openedAt,
    DateTime? closedAt,
  }) async {
    if (id.isEmpty) throw RepoException('Id pratica mancante.');

    String? dateOnly(DateTime? d) => d?.toIso8601String().substring(0, 10);

    final patch = <String, dynamic>{
      if (code != null) Matter.colCode: code,
      if (subject != null) Matter.colTitle: subject,
      if (status != null) Matter.colStatus: status,
      if (area != null) Matter.colArea: area,
      if (courtId != null) Matter.colCourt: courtId,
      if (judge != null) Matter.colJudge: judge,
      if (notes != null) Matter.colDescription: notes,
      if (counterpartyName != null) Matter.colCounterpartyName: counterpartyName,
      if (rgNumber != null) Matter.colRgNumber: rgNumber,
      if (opposingAttorneyName != null)
        Matter.colOpposingAttorneyName: opposingAttorneyName,
      if (registryCode != null) Matter.colRegistryCode: registryCode,
      if (courtSection != null) Matter.colCourtSection: courtSection,
      if (openedAt != null) Matter.colOpenedAt: dateOnly(openedAt),
      if (closedAt != null) Matter.colClosedAt: dateOnly(closedAt),
    };

    if (patch.isEmpty) {
      final current = await get(id);
      if (current == null) throw RepoException('Pratica non trovata.');
      return current;
    }

    try {
      final res = await sb
          .from('matters')
          .update(patch)
          .eq(Matter.colId, id)
          .select('*')
          .single();
      return Matter.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      throw RepoException('Aggiornamento non riuscito: ${e.message}');
    } catch (e) {
      throw RepoException('Aggiornamento non riuscito: $e');
    }
  }

  /// Chiudi pratica: imposta closed_at (e prova a settare status = 'closed')
  Future<void> close(String id) async {
    if (id.isEmpty) throw RepoException('Id pratica mancante.');
    final patch = {
      Matter.colClosedAt: todayISODate(),
      Matter.colStatus:
          'closed', // potrebbe fallire se enum non contiene 'closed'
    };
    try {
      await sb.from('matters').update(patch).eq(Matter.colId, id);
    } on PostgrestException catch (e) {
      // fallback: almeno chiudi la data
      try {
        await sb
            .from('matters')
            .update({Matter.colClosedAt: todayISODate()}).eq(Matter.colId, id);
      } catch (_) {}
      throw RepoException('Chiusura pratica non riuscita: ${e.message}');
    }
  }

  /// Riapri pratica: rimuove closed_at (e prova a settare status = 'open')
  Future<void> reopen(String id) async {
    if (id.isEmpty) throw RepoException('Id pratica mancante.');
    final patch = {
      Matter.colClosedAt: null,
      Matter.colStatus: 'open',
    };
    try {
      await sb.from('matters').update(patch).eq(Matter.colId, id);
    } on PostgrestException catch (e) {
      // fallback: almeno azzera la data
      try {
        await sb
            .from('matters')
            .update({Matter.colClosedAt: null}).eq(Matter.colId, id);
      } catch (_) {}
      throw RepoException('Ri apertura pratica non riuscita: ${e.message}');
    }
  }

  /// Elimina pratica. Deve fallire se esistono invoice_lines collegate.
  Future<void> delete(String id) async {
    if (id.isEmpty) throw RepoException('Id pratica mancante.');
    // Pre-check su invoice_lines
    final inv = await sb
        .from('invoice_lines')
        .select('line_id')
        .eq('matter_id', id)
        .limit(1);
    final hasInvoiceLines = (inv as List).isNotEmpty;
    if (hasInvoiceLines) {
      throw RepoException(
          'Impossibile cancellare: esistono righe di fattura collegate alla pratica.');
    }

    try {
      await sb.from('matters').delete().eq(Matter.colId, id);
    } on PostgrestException catch (e) {
      throw RepoException('Cancellazione non riuscita: ${e.message}');
    }
  }

  /// Cambia il cliente associato alla pratica (FK).
  Future<void> changeClient(String id, String newClientId) async {
    if (id.isEmpty || newClientId.isEmpty) {
      throw RepoException('Parametri mancanti.');
    }
    try {
      await sb
          .from('matters')
          .update({Matter.colClientId: newClientId}).eq(Matter.colId, id);
    } on PostgrestException catch (e) {
      throw RepoException(
          'Cambio cliente non riuscito (verifica FK e studio): ${e.message}');
    }
  }
}
