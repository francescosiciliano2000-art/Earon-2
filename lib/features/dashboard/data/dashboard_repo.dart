import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;

class DashboardRepo {
  final SupabaseClient sb;
  DashboardRepo(this.sb);

  // Helpers sicuri (non fanno crash se una query fallisce: ritorna vuoto/0 e logga)
  Future<List<Map<String, dynamic>>> _safeList(Future<dynamic> fut,
      {String tag = ''}) async {
    try {
      final res = await fut;
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      dev.log('[DashboardRepo] $tag -> $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<num> _safeNum(Future<dynamic> fut, num Function(List list) map,
      {String tag = ''}) async {
    try {
      final res = await fut;
      final list = (res as List);
      return map(list);
    } catch (e) {
      dev.log('[DashboardRepo] $tag -> $e');
      return 0;
    }
  }

  // Estrae il totale dal JSONB invoices.totals
  num _pickInvoiceTotal(Map<String, dynamic> inv) {
    final t = inv['totals'];
    if (t is Map) {
      // 1) Chiavi dirette più comuni (eng + it)
      for (final k in [
        'grand_total',
        'gross_total',
        'total',
        'totale',
        'amount',
        'net_total',
        'amount_due',
        'balance',
      ]) {
        final v = t[k];
        if (v is num) return v;
        if (v != null) {
          final parsed = num.tryParse('$v');
          if (parsed != null) return parsed;
        }
      }

      // 2) Calcolo composito se abbiamo componenti (imponibile/iva/cpa/bollo/ritenuta)
      num getN(String key) {
        final v = t[key];
        if (v is num) return v;
        if (v != null) return num.tryParse('$v') ?? 0;
        return 0;
      }

      // Prova varie convenzioni per imponibile/subtotal
      final imponibile = getN('imponibile') + getN('subtotal') + getN('base');
      final iva = getN('iva') + getN('vat');
      final cpa = getN('cpa') + getN('cassa') + getN('withholding_fund');
      final bollo = getN('bollo') + getN('stamp_duty');
      final ritenuta = getN('ritenuta') + getN('withholding_tax');

      final composed = imponibile + iva + cpa + bollo - ritenuta;
      if (composed != 0) return composed;
    }
    return 0;
  }

  // ---- KPI ----
  Future<Map<String, num>> fetchKpis(String firmId) async {
    final today = DateTime.now();
    final startMonth = DateTime(today.year, today.month, 1).toIso8601String();
    final startPrevMonth = DateTime(today.year, today.month - 1, 1).toIso8601String();

    // 1) Ore da fatturare = somma minuti delle time_entries billable (nel tuo schema NON esiste "invoiced")
    final billableHours = await _safeNum(
      sb
          .from('time_entries')
          .select('minutes,billable')
          .eq('firm_id', firmId)
          .eq('billable', true),
      (rows) {
        final minutes = rows
            .map((e) => (e['minutes'] ?? 0) as num)
            .fold<num>(0, (a, b) => a + b);
        return minutes / 60;
      },
      tag: 'kpi:time_entries',
    );

    // 2) Fatture emesse nel mese = somma di "totals" (jsonb) nel mese
    final invoicesIssuedMonth = await _safeNum(
      sb
          .from('invoices')
          .select('totals,issue_date')
          .eq('firm_id', firmId)
          .gte('issue_date', startMonth),
      (rows) => rows
          .map((e) => Map<String, dynamic>.from(e))
          .map(_pickInvoiceTotal)
          .fold<num>(0, (a, b) => a + b),
      tag: 'kpi:invoices_month',
    );

    // 2b) Fatture emesse nel mese precedente
    final prevInvoicesIssuedMonth = await _safeNum(
      sb
          .from('invoices')
          .select('totals,issue_date')
          .eq('firm_id', firmId)
          .gte('issue_date', startPrevMonth)
          .lt('issue_date', startMonth),
      (rows) => rows
          .map((e) => Map<String, dynamic>.from(e))
          .map(_pickInvoiceTotal)
          .fold<num>(0, (a, b) => a + b),
      tag: 'kpi:invoices_prev_month',
    );

    // 3) Da incassare = sum( totals – pagamenti ) per fatture con status 'issued' (non paid/void)
    num receivablesOpen = 0;
    final openInv = await _safeList(
      sb
          .from('invoices')
          .select('invoice_id,totals,status')
          .eq('firm_id', firmId)
          .not('status', 'in', '(paid,void)'),
      tag: 'kpi:open_invoices',
    );
    for (final inv in openInv) {
      final invId = inv['invoice_id'];
      final total = _pickInvoiceTotal(inv);
      final pays = await _safeList(
        sb.from('payments').select('amount').eq('invoice_id', invId),
        tag: 'kpi:payments invoice $invId',
      );
      final paid = pays
          .map((p) => p['amount'])
          .map((v) => v is num ? v : num.tryParse('$v') ?? 0)
          .fold<num>(0, (a, b) => a + b);
      receivablesOpen += total - paid;
    }

    // 3b) Da incassare del mese precedente (fatture emesse nel mese precedente non chiuse)
    num prevReceivablesOpen = 0;
    final prevOpenInv = await _safeList(
      sb
          .from('invoices')
          .select('invoice_id,totals,status,issue_date')
          .eq('firm_id', firmId)
          .gte('issue_date', startPrevMonth)
          .lt('issue_date', startMonth)
          .not('status', 'in', '(paid,void)'),
      tag: 'kpi:open_invoices_prev_month',
    );
    for (final inv in prevOpenInv) {
      final invId = inv['invoice_id'];
      final total = _pickInvoiceTotal(inv);
      final pays = await _safeList(
        sb.from('payments').select('amount').eq('invoice_id', invId),
        tag: 'kpi:payments invoice prev $invId',
      );
      final paid = pays
          .map((p) => p['amount'])
          .map((v) => v is num ? v : num.tryParse('$v') ?? 0)
          .fold<num>(0, (a, b) => a + b);
      prevReceivablesOpen += total - paid;
    }

    return {
      'billable_hours': billableHours,
      'invoices_issued_month': invoicesIssuedMonth,
      'receivables_open': receivablesOpen,
      'prev_invoices_issued_month': prevInvoicesIssuedMonth,
      'prev_receivables_open': prevReceivablesOpen,
    };
  }

  // ---- Prossime udienze ----
  Future<List<Map<String, dynamic>>> nextHearings(String firmId,
      {int days = 7, int limit = 5}) async {
    final now = DateTime.now();
    final todayIso = now.toIso8601String();
    final untilIso = now.add(Duration(days: days)).toIso8601String();
    final rows = await _safeList(
      sb
          .from('hearings')
          .select('hearing_id,starts_at,courtroom,notes,matter_id')
          .eq('firm_id', firmId)
          .gte('starts_at', todayIso)
          .lte('starts_at', untilIso)
          .order('starts_at', ascending: true)
          .limit(limit),
      tag: 'hearings',
    );
    return rows
        .map((h) => {
              'id': h['hearing_id'],
              'date': h['starts_at'],
              'subject': h['notes'] ?? 'Udienza',
              'court': h['courtroom'] ?? '',
              'matter_id': h['matter_id'],
            })
        .toList();
  }

  // ---- Task in scadenza ----
  Future<List<Map<String, dynamic>>> dueTasks(String firmId,
      {int days = 7, bool onlyMine = false, bool includeDone = false}) async {
    final now = DateTime.now();
    final until = now.add(Duration(days: days)).toIso8601String();
    final uid = sb.auth.currentUser?.id;

    var q = sb
        .from('tasks')
        .select('task_id,title,due_at,assigned_to,done,priority,matter_id')
        .eq('firm_id', firmId)
        .gte('due_at', now.toIso8601String())
        .lte('due_at', until);

    if (!includeDone) {
      q = q.eq('done', false);
    }

    if (onlyMine && uid != null) {
      q = q.eq('assigned_to', uid);
    }

    final rows =
        await _safeList(q.order('due_at', ascending: true), tag: 'tasks_due');
    return rows
        .map((t) => {
              'id': t['task_id'],
              'title': t['title'] ?? 'Task',
              'due_date': t['due_at'],
              'assignee_id': t['assigned_to'],
              'status': t['done'] == true ? 'done' : 'open',
              'priority': t['priority'],
              'matter_id': t['matter_id'],
            })
        .toList();
  }

  // ---- Mini calendario (tasks + hearings) ----
  Future<Map<DateTime, List<Map<String, dynamic>>>> calendar(String firmId,
      {int days = 30, bool onlyMine = false}) async {
    final now = DateTime.now();
    final until = now.add(Duration(days: days)).toIso8601String();
    final uid = sb.auth.currentUser?.id;

    final hearings = await _safeList(
      sb
          .from('hearings')
          .select('hearing_id,starts_at,notes')
          .eq('firm_id', firmId)
          .gte('starts_at', now.toIso8601String())
          .lte('starts_at', until),
      tag: 'calendar:hearings',
    );

    var tq = sb
        .from('tasks')
        .select('task_id,title,due_at,assigned_to,done')
        .eq('firm_id', firmId)
        .gte('due_at', now.toIso8601String())
        .lte('due_at', until);
    if (onlyMine && uid != null) {
      tq = tq.eq('assigned_to', uid);
    }
    final tasks = await _safeList(tq, tag: 'calendar:tasks');

    final Map<DateTime, List<Map<String, dynamic>>> map = {};
    void add(DateTime d, Map<String, dynamic> it) {
      final key = DateTime(d.year, d.month, d.day);
      map.putIfAbsent(key, () => []);
      map[key]!.add(it);
    }

    for (final h in hearings) {
      final d = DateTime.tryParse('${h['starts_at']}')?.toLocal();
      if (d != null) {
        add(d, {
          'type': 'hearing',
          'id': h['hearing_id'],
          'subject': h['notes'] ?? 'Udienza'
        });
      }
    }
    for (final t in tasks) {
      final d = DateTime.tryParse('${t['due_at']}')?.toLocal();
      if (d != null) {
        add(d, {
          'type': 'task',
          'id': t['task_id'],
          'title': t['title'] ?? 'Task'
        });
      }
    }
    return map;
  }

  // ---- Activity ----
  Future<Map<String, List<Map<String, dynamic>>>> activity(String firmId,
      {int limit = 5}) async {
    final docs = await _safeList(
      sb
          .from('documents')
          .select('doc_id,title,created_at,matter_id')
          .eq('firm_id', firmId)
          .order('created_at', ascending: false)
          .limit(limit),
      tag: 'activity:documents',
    );

    final matters = await _safeList(
      sb
          .from('matters')
          .select('matter_id,code,title,created_at,client_id')
          .eq('firm_id', firmId)
          .order('created_at', ascending: false)
          .limit(limit),
      tag: 'activity:matters',
    );

    return {
      'documents': docs
          .map((d) => {
                'id': d['doc_id'],
                'filename': d['title'] ?? 'Documento',
                'created_at': d['created_at'],
                'matter_id': d['matter_id'],
              })
          .toList(),
      'matters': matters
          .map((m) => {
                'id': m['matter_id'],
                'code': m['code'] ?? '',
                'title': m['title'] ?? 'Pratica',
                'created_at': m['created_at'],
                'client_id': m['client_id'],
              })
          .toList(),
    };
  }

  // Serie mensile "Da incassare" (ultimi N mesi) basata su fatture emesse nel mese non chiuse
  Future<List<Map<String, dynamic>>> receivablesMonthlySeries(String firmId, {int months = 6}) async {
    final today = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final start = DateTime(today.year, today.month - i, 1);
      final end = DateTime(today.year, today.month - i + 1, 1);
      final rows = await _safeList(
        sb
            .from('invoices')
            .select('invoice_id,totals,status,issue_date')
            .eq('firm_id', firmId)
            .gte('issue_date', start.toIso8601String())
            .lt('issue_date', end.toIso8601String())
            .not('status', 'in', '(paid,void)'),
        tag: 'series:receivables_month_${start.year}-${start.month}',
      );
      num amount = 0;
      for (final inv in rows) {
        final invId = inv['invoice_id'];
        final total = _pickInvoiceTotal(inv);
        final pays = await _safeList(
          sb.from('payments').select('amount').eq('invoice_id', invId),
          tag: 'series:payments_$invId',
        );
        final paid = pays
            .map((p) => p['amount'])
            .map((v) => v is num ? v : num.tryParse('$v') ?? 0)
            .fold<num>(0, (a, b) => a + b);
        amount += total - paid;
      }
      out.add({
        'month': start.toIso8601String(), // ISO per serializzazione
        'amount': amount,
      });
    }
    return out;
  }
}
