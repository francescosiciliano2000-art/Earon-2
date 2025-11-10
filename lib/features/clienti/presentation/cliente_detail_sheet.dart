// lib/features/clienti/presentation/cliente_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Design System
import '../../../design system/components/sheet.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/list_tile.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/components/label.dart';

import '../../clienti/data/cliente_repo.dart';

/// Sheet laterale (right) che mostra i dettagli del cliente.
class ClienteDetailSheet extends StatefulWidget {
  final String clientId;
  const ClienteDetailSheet({super.key, required this.clientId});

  @override
  State<ClienteDetailSheet> createState() => _ClienteDetailSheetState();
}

class _ClienteDetailSheetState extends State<ClienteDetailSheet> {
  final _fmtDate = DateFormat('dd/MM/yyyy');
  final _fmtMoney = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  late final SupabaseClient _sb;
  late final ClienteRepo _repo;

  Map<String, dynamic>? _client;
  bool _loadingHeader = true;

  // futures per le sezioni utilizzate
  late Future<List<Map<String, dynamic>>> _mattersFut;
  late Future<List<_ActivityItem>> _activityFut;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = ClienteRepo(_sb);
    _loadHeader();
    _buildFutures();
  }

  Future<String?> _currentFirmId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('currentFirmId');
  }

  Future<void> _loadHeader() async {
    try {
      final c = await _repo.getOne(widget.clientId);
      if (!mounted) return;
      setState(() {
        _client = c;
        _loadingHeader = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHeader = false);
    }
  }

  void _buildFutures() {
    _mattersFut = _repo.mattersByClient(widget.clientId);
    _activityFut = _buildActivityFuture();
  }

  Future<List<Map<String, dynamic>>> _buildPaymentsFuture() async {
    final fid = await _currentFirmId();
    if (fid == null || fid.isEmpty) {
      throw Exception('Nessuno studio selezionato (firm mancante).');
    }
    return _repo.paymentsByClient(
      firmId: fid,
      clientId: widget.clientId,
      limit: 200,
    );
  }

  Future<List<_ActivityItem>> _buildActivityFuture() async {
    final matters = await _repo.mattersByClient(widget.clientId);
    final docs = await _repo.documentsByClient(widget.clientId);
    final invs = await _repo.invoicesByClient(widget.clientId);
    final pays = await _buildPaymentsFuture();

    final items = <_ActivityItem>[];

    for (final m in matters) {
      items.add(_ActivityItem(
        whenIso: '${m['created_at'] ?? ''}',
        icon: AppIcons.gavel,
        title: m['title'] ?? 'Pratica',
        subtitle: 'Codice: ${m['code'] ?? '—'}',
      ));
    }
    for (final d in docs) {
      items.add(_ActivityItem(
        whenIso: '${d['created_at'] ?? ''}',
        icon: AppIcons.description,
        title: d['title'] ?? 'Documento',
        subtitle: 'Documento creato',
      ));
    }
    for (final i in invs) {
      final tot = _formatInvoiceTotal(i['totals']);
      items.add(_ActivityItem(
        whenIso: '${i['issue_date'] ?? ''}',
        icon: AppIcons.invoice,
        title: 'Fattura ${i['number'] ?? ''}',
        subtitle: tot == '—' ? 'Fattura emessa' : 'Totale $tot',
      ));
    }
    for (final p in pays) {
      String invNum = '';
      final invNode = p['invoices'];
      if (invNode is Map) {
        invNum = '${invNode['number'] ?? ''}';
      } else if (invNode is List && invNode.isNotEmpty && invNode.first is Map) {
        invNum = '${(invNode.first as Map)['number'] ?? ''}';
      }
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      items.add(_ActivityItem(
        whenIso: '${p['date'] ?? ''}',
        icon: AppIcons.currencyEur,
        title: 'Pagamento ${_fmtMoney.format(amount)}',
        subtitle: invNum.isNotEmpty ? 'Fattura $invNum' : '',
      ));
    }

    items.sort((a, b) => b.when.compareTo(a.when));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final name = _buildHeaderTitle();

    // Importante: il panel esterno (SheetPanel) avvolge il child in uno
    // SingleChildScrollView. Per mantenere il titolo visibile, rendiamo il
    // nostro child alto quanto il viewport; lo scroll avviene solo nel corpo
    // interno (Expanded + SingleChildScrollView), così l’header resta visibile.
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      height: size.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (pinned)
          SheetHeader(
            padding: EdgeInsets.only(
              left: su * 2,
              right: su * 2,
              top: su * 3.25,
              bottom: su * 2,
            ),
            child: SheetTitle(
              _loadingHeader ? 'Caricamento…' : name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Spazio tra header e body
          SizedBox(height: su * 2),

          // Body scrollabile: sezioni
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: su * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // INFO (read-only)
                  _SectionTitle('Info'),
                  _buildInfoSection(),
                  SizedBox(height: su * 2),
                  _SectionTitle('Pratiche'),
                  _buildMattersSection(),
                  SizedBox(height: su * 2),
                  // Sezione Attività: temporaneamente nascosta (non eliminata)
                  Offstage(
                    offstage: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle('Attività'),
                        _buildActivitySection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------- HEADER TITLE ---------------------
  String _buildHeaderTitle() {
    if (_loadingHeader || _client == null) return 'Caricamento…';
    final c = _client!;
    final kind = (c['kind'] ?? '').toString();
    if (kind == 'company') {
      final company = (c['name'] ?? '').toString();
      final companyType = (c['company_type'] ?? '').toString();
      return [company, companyType]
          .where((e) => e.trim().isNotEmpty)
          .join(' ')
          .trim();
    }
    // default/persona: Nome + Cognome
    final name = (c['name'] ?? '').toString();
    final surname = (c['surname'] ?? '').toString();
    final s = [name, surname].where((e) => e.trim().isNotEmpty).join(' ');
    return s.isEmpty ? 'Cliente' : s;
  }

  // --------------------- SEZIONE: INFO ---------------------
  Widget _buildInfoSection() {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    if (_loadingHeader) return const Center(child: Spinner());
    final c = _client ?? const {};
    String v(dynamic x) => (x == null || ('$x').trim().isEmpty) ? '—' : '$x';
    final kind = (c['kind'] ?? 'person').toString();

    // Helper: blocco label sopra valore, con valore dentro un box stile input (read-only)
    Widget field(String label, String value, {double? width}) {
      final col = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLabel(text: label),
          SizedBox(height: su * 1.0),
          _ReadOnlyInputBox(value: value),
        ],
      );
      return width != null ? SizedBox(width: width, child: col) : col;
    }

    // Variante multilinea (textarea read-only) per testi lunghi
    Widget fieldMultiline(String label, String value, {double height = 72}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLabel(text: label),
          SizedBox(height: su * 1.0),
          _ReadOnlyAreaBox(value: value, height: height),
        ],
      );
    }

    // Persona: righe come nel dialog
    final person = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome e Cognome non mostrati: già presenti nell'header
        // Codice fiscale + Genere + Telefono
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CF flessibile per evitare overflow
            Expanded(child: field('Codice fiscale', v(c['tax_code']))),
            SizedBox(width: su * 2),
            field('Genere', v(c['gender']), width: 100),
            SizedBox(width: su * 2),
            field('Numero di telefono', v(c['phone']), width: 160),
          ],
        ),
        SizedBox(height: su * 2),
        // Email + PEC
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Email', v(c['email']))),
            SizedBox(width: su * 2),
            Expanded(child: field('PEC', v(c['pec_email']))),
          ],
        ),
        SizedBox(height: su * 2),
        // Indirizzo + Numero civico
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Indirizzo', v(c['address']))),
            SizedBox(width: su * 2),
            field('Numero civico', v(c['street_number']), width: 120),
          ],
        ),
        SizedBox(height: su * 2),
        // Città / Provincia / CAP / Paese — su una riga con spazio pienamente sfruttato
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Città', v(c['city']))),
            SizedBox(width: su * 2),
            field('Provincia', v(c['province']), width: 80),
            SizedBox(width: su * 2),
            field('CAP', v(c['zip']), width: 70),
            SizedBox(width: su * 2),
            field('Paese', v(c['country']), width: 60),
          ],
        ),
        SizedBox(height: su * 2),
        // Note di fatturazione
        fieldMultiline('Note di fatturazione', v(c['billing_notes'])),
        SizedBox(height: su * 2),
        // Tag rimosso come richiesto
      ],
    );

    // Azienda: righe come nel dialog
    final company = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ragione sociale e Forma giuridica non mostrati: già in header
        // P.IVA + Telefono su una sola riga a tutta larghezza
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Partita IVA', v(c['vat_number']))),
            SizedBox(width: su * 2),
            field('Numero di telefono', v(c['phone']), width: 160),
          ],
        ),
        SizedBox(height: su * 2),
        // Oggetto sociale come blocco multilinea
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppLabel(text: 'Oggetto sociale'),
            SizedBox(height: su * 1.0),
            _ReadOnlyAreaBox(value: v(c['company_object'])),
          ],
        ),
        SizedBox(height: su * 2),
        // Email + PEC
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Email', v(c['email']))),
            SizedBox(width: su * 2),
            Expanded(child: field('PEC', v(c['pec_email']))),
          ],
        ),
        SizedBox(height: su * 2),
        // Indirizzo + Numero civico
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Indirizzo', v(c['address']))),
            SizedBox(width: su * 2),
            field('Numero civico', v(c['street_number']), width: 120),
          ],
        ),
        SizedBox(height: su * 2),
        // Città / Provincia / CAP / Paese — su una riga con spazio pienamente sfruttato
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Città', v(c['city']))),
            SizedBox(width: su * 2),
            field('Provincia', v(c['province']), width: 80),
            SizedBox(width: su * 2),
            field('CAP', v(c['zip']), width: 70),
            SizedBox(width: su * 2),
            field('Paese', v(c['country']), width: 60),
          ],
        ),
        SizedBox(height: su * 2),
        // Note
        field('Note', v(c['billing_notes'])),
        SizedBox(height: su * 2),
        // Tag rimosso come richiesto
      ],
    );

    return kind == 'company' ? company : person;
  }

  // Removed unused helpers: _composeAddress, _composeTags

  // --------------------- SEZIONE: PRATICHE ---------------------
  Widget _buildMattersSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _mattersFut,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) return Text('Errore: ${snap.error}');
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Text('Nessuna pratica');
        final labelClient = _clientLabel();
        final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
        final cs = Theme.of(context).colorScheme;
        final radii = Theme.of(context).extension<ShadcnRadii>()?.sm ?? BorderRadius.circular(6);

        // Counts per status
        final int totalCount = rows.length;
        final int openCount = rows.where((r) => '${r['status']}'.toLowerCase() == 'open').length;
        final int closedCount = rows.where((r) => '${r['status']}'.toLowerCase() == 'closed').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cards dei conteggi: Totali (numerone con bordo), Open, Closed
            Row(
              children: [
                // Card Totali (numerone)
                Expanded(
                  child: Container(
                  padding: EdgeInsets.symmetric(horizontal: su * 2, vertical: su * 1.5),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: radii,
                    color: cs.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Totali', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                      SizedBox(height: su * 0.75),
                      Text('$totalCount', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  ),
                ),
                SizedBox(width: su * 2),
                // Card Aperte
                Expanded(
                  child: Container(
                  padding: EdgeInsets.symmetric(horizontal: su * 1.5, vertical: su * 1.25),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: radii,
                    color: cs.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aperte', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                      SizedBox(height: su * 0.5),
                      Text('$openCount', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  ),
                ),
                SizedBox(width: su * 1.5),
                // Card Archiviate
                Expanded(
                  child: Container(
                  padding: EdgeInsets.symmetric(horizontal: su * 1.5, vertical: su * 1.25),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: radii,
                    color: cs.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Archiviate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                      SizedBox(height: su * 0.5),
                      Text('$closedCount', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  ),
                ),
              ],
            ),
            SizedBox(height: su * 1.5),
            // Lista pratiche: altezza fissa, scroll interno, item come etichette grandi
            SizedBox(
              height: su * 24, // altezza fissa (circa ~192px con su=8)
              child: rows.isEmpty
                  ? Center(child: Text('Nessuna pratica'))
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => SizedBox(height: su * 0.75),
                      padding: EdgeInsets.zero,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        // Riga full-width: icona folder + "code - Cliente/Controparte"
                        final String lineText = _composeMatterCodeAndParties(r, labelClient);
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: su * 1.25, vertical: su * 0.75),
                          decoration: BoxDecoration(
                            color: cs.tertiary,
                            borderRadius: Theme.of(context).extension<ShadcnRadii>()?.sm ?? BorderRadius.circular(6),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(AppIcons.folder, size: 16, color: cs.onTertiary),
                              SizedBox(width: su * 0.75),
                              Expanded(
                                child: Text(
                                  lineText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _clientLabel() {
    final c = _client;
    if (c == null) return 'Cliente';
    final kind = (c['kind'] ?? 'person').toString();
    if (kind == 'company') {
      final company = (c['name'] ?? '').toString();
      final companyType = (c['company_type'] ?? '').toString();
      final s = [company, companyType]
          .where((e) => e.trim().isNotEmpty)
          .join(' ')
          .trim();
      return s.isEmpty ? 'Cliente' : s;
    }
    final name = (c['name'] ?? '').toString();
    final surname = (c['surname'] ?? '').toString();
    final s = [name, surname].where((e) => e.trim().isNotEmpty).join(' ');
    return s.isEmpty ? 'Cliente' : s;
  }

  // Removed unused helper: _composeMatterLabel (replaced by _composeMatterCodeAndParties)

  /// Composizione richiesta: sempre e solo "code - Cliente/Controparte"
  /// senza fallback al titolo della pratica. Usa "—" quando i campi sono vuoti.
  String _composeMatterCodeAndParties(Map<String, dynamic> r, String clientLabel) {
    final code = (r['code'] ?? '').toString();
    final cp = (r['counterparty_name'] ?? '').toString();
    final left = code.trim().isEmpty ? '—' : code.trim();
    final right = [clientLabel, cp.trim().isEmpty ? '—' : cp.trim()].join('/');
    return [left, right].join(' - ');
  }

  // --------------------- SEZIONE: DOCUMENTI ---------------------
  // Removed unused section: _buildDocumentsSection

  // --------------------- SEZIONE: FATTURE ---------------------
  // Removed unused section: _buildInvoicesSection

  // --------------------- SEZIONE: PAGAMENTI ---------------------
  // Removed unused section: _buildPaymentsSection

  // --------------------- SEZIONE: ATTIVITÀ ---------------------
  Widget _buildActivitySection() {
    return FutureBuilder<List<_ActivityItem>>(
      future: _activityFut,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) return Text('Errore: ${snap.error}');
        final items = snap.data ?? const [];
        if (items.isEmpty) return const Text('Nessuna attività recente');
        return Column(
          children: [
            for (final a in items.take(30))
              AppListTile(
                leading: Icon(a.icon),
                title: Text(a.title),
                subtitle: Text([
                  if (a.subtitle.isNotEmpty) a.subtitle,
                  _fmtDate.format(a.when.toLocal()),
                ].join('  •  ')),
              ),
          ],
        );
      },
    );
  }

  // --------------------- Helpers ---------------------
  // Rimosso helper inutilizzato: _safeDate

  // Rimosso helper inutilizzato: _buildPaymentSubtitle

  String _formatInvoiceTotal(dynamic totalsJson) {
    if (totalsJson is Map<String, dynamic>) {
      final keys = ['grand_total', 'total', 'amount', 'totale'];
      for (final k in keys) {
        final v = totalsJson[k];
        if (v is num) return _fmtMoney.format(v);
        if (v is String) {
          final n = num.tryParse(v);
          if (n != null) return _fmtMoney.format(n);
        }
      }
    }
    return '—';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final style = Theme.of(context).textTheme.titleSmall;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: su * 1.25),
          child: Text(text, style: style?.copyWith(fontWeight: FontWeight.w600)),
        ),
        // Separator sotto al titolo
        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        SizedBox(height: su * 1.25),
      ],
    );
  }
}

class _ActivityItem {
  final DateTime when;
  final IconData icon;
  final String title;
  final String subtitle;
  _ActivityItem({
    required String whenIso,
    required this.icon,
    required this.title,
    this.subtitle = '',
  }) : when = _parseWhen(whenIso);

  static DateTime _parseWhen(String iso) {
    if (iso.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      return DateTime.tryParse(iso) ??
          DateTime.parse(iso.split('T').first); // “YYYY-MM-DD”
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}

// --------------------- Read-only boxed inputs ---------------------
/// Box monos riga con look coerente agli input del design system (AppInput),
/// ma non interattivo (read-only). Usato per i valori della sezione Info.
class _ReadOnlyInputBox extends StatelessWidget {
  final String value;
  const _ReadOnlyInputBox({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radii = theme.extension<ShadcnRadii>()!;

    // Dimensioni come l'input: h-9, px-3
    const double height = 36.0;
    const double px = 12.0;

    // Colori coerenti con AppInput
    final isDark = theme.brightness == Brightness.dark;
    final baseBorderColor = isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline;
    final baseBg = isDark ? cs.outlineVariant.withValues(alpha: 0.30) : cs.surface;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: radii.md,
          border: Border.all(color: baseBorderColor, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: px),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

/// Variante area (multi-linea) per testi più lunghi.
class _ReadOnlyAreaBox extends StatelessWidget {
  final String value;
  final double height;
  const _ReadOnlyAreaBox({required this.value, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radii = theme.extension<ShadcnRadii>()!;

    // Colori coerenti con AppInput
    final isDark = theme.brightness == Brightness.dark;
    final baseBorderColor = isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline;
    final baseBg = isDark ? cs.outlineVariant.withValues(alpha: 0.30) : cs.surface;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: radii.md,
          border: Border.all(color: baseBorderColor, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}