// lib/features/matters/presentation/matter_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Design System
import '../../../design system/components/sheet.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/alert_dialog.dart';
import '../../../design system/components/label.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/sonner.dart';

// Data & helpers
import '../data/matter_repo.dart';
import '../data/matter_model.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
// import 'matter_edit_sheet.dart'; // sostituito da dialog

/// Sheet laterale (right) che sostituisce la pagina dettaglio delle pratiche
class MatterDetailSheet extends StatefulWidget {
  final String matterId;
  const MatterDetailSheet({super.key, required this.matterId});

  @override
  State<MatterDetailSheet> createState() => _MatterDetailSheetState();
}

class _MatterDetailSheetState extends State<MatterDetailSheet> {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;

  Matter? _matter;
  bool _loading = true;
  String? _error;

  // editable overview
  final _statusCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _bootstrap();
  }

  @override
  void dispose() {
    _statusCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _repo.get(widget.matterId);
      if (m == null) throw Exception('Pratica non trovata.');
      _statusCtl.text = m.status ?? '';
      _notesCtl.text = m.description ?? '';
      setState(() {
        _matter = m;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Metodi di supporto non utilizzati rimossi per pulizia del codice

  // Metodi non utilizzati rimossi per pulizia del codice

  Future<void> _confirmClose() async {
    await AppAlertDialog.show<bool>(
      context,
      title: 'Archiviare pratica?',
      description: 'Confermi l\'archiviazione della pratica?',
      cancelText: 'Annulla',
      confirmText: 'Archivia',
      destructive: false,
      barrierDismissible: false,
      onConfirm: () async {
        try {
          await _repo.close(widget.matterId);
          await _bootstrap();
          if (!mounted) return;
          toastSuccess(context, 'Pratica archiviata');
        } catch (e) {
          if (!mounted) return;
          toastError(context, 'Errore archiviazione: $e');
        }
      },
    );
    // La logica è gestita nell'onConfirm
    if (!mounted) return;
  }

  Future<void> _confirmReopen() async {
    await AppAlertDialog.show<bool>(
      context,
      title: 'Riaprire pratica?',
      description: 'Confermi la riapertura della pratica?',
      cancelText: 'Annulla',
      confirmText: 'Riapri',
      destructive: false,
      barrierDismissible: false,
      onConfirm: () async {
        try {
          await _repo.reopen(widget.matterId);
          await _bootstrap();
          if (!mounted) return;
          toastSuccess(context, 'Pratica riaperta');
        } catch (e) {
          if (!mounted) return;
          toastError(context, 'Errore riapertura: $e');
        }
      },
    );
    if (!mounted) return;
  }

  // Metodo di eliminazione non utilizzato rimosso

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final size = MediaQuery.sizeOf(context);
    final title = _matter?.title ?? 'Pratica';
    final code = _matter?.code ?? '';

    String composeHeader() {
      final left = code.trim().isEmpty ? '—' : code.trim();
      final right = title.trim().isEmpty ? 'Pratica' : title.trim();
      return [left, right].join(' - ');
    }

    return SizedBox(
      height: size.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (pinned): "code - title"
          SheetHeader(
            padding: EdgeInsets.only(
              left: su * 2,
              right: su * 2,
              top: su * 3.25,
              bottom: su * 2,
            ),
            child: SheetTitle(
              _loading ? 'Caricamento…' : composeHeader(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Spazio tra header e body
          SizedBox(height: su * 2),

          // Body scrollabile con sezioni richieste
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: su * 2),
              child: _loading
                  ? const Center(child: Spinner())
                  : _error != null
                      ? Text('Errore: $_error')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionTitle('Info'),
                            _buildInfoSection(),
                            SizedBox(height: su * 2),
                            _SectionTitle('Udienze'),
                            _buildHearingsSection(),
                            SizedBox(height: su * 2),
                            _SectionTitle('Memorandum'),
                            _buildTasksSection(),
                            SizedBox(height: su * 2),
                            _buildActionsSection(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeDate(DateTime? d) {
    if (d == null) return '—';
    final dt = d.toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  // --------------------- SEZIONE: INFO ---------------------
  Widget _buildInfoSection() {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final m = _matter;
    if (m == null) return const SizedBox.shrink();
    String v(dynamic x) => (x == null || ('$x').trim().isEmpty) ? '—' : '$x';

    Widget field(String label, String value, {double? width}) {
      final col = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label allineata allo sheet Cliente
          AppLabel(text: label),
          SizedBox(height: su * 1.0),
          _ReadOnlyInputBox(value: value),
        ],
      );
      return width != null ? SizedBox(width: width, child: col) : col;
    }

    Widget fieldArea(String label, String value, {double height = 72}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label allineata allo sheet Cliente
          AppLabel(text: label),
          SizedBox(height: su * 1.0),
          _ReadOnlyAreaBox(value: value, height: height),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prima riga: Codice, Area (Area a piena larghezza)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field('Codice', v(m.code), width: 160),
            SizedBox(width: su * 2),
            Expanded(child: field('Area', v(m.area))),
          ],
        ),
        SizedBox(height: su * 2),
        // Seconda riga: Foro (ancora più largo), Sezione (ancora più stretta), Giudice
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Foro', v(m.court))),
            SizedBox(width: su * 2),
            field('Sezione', v(m.courtSection), width: 70),
            SizedBox(width: su * 2),
            field('Giudice', v(m.judge), width: 110),
          ],
        ),
        SizedBox(height: su * 2),
        // Terza riga: Controparte, Avv. controparte
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field('Controparte', v(m.counterpartyName))),
            SizedBox(width: su * 2),
            Expanded(child: field('Avvocato controparte', v(m.opposingAttorneyName))),
          ],
        ),
        SizedBox(height: su * 2),
        // Quarta riga: Numero RG (ridotto), Codice registro, Apertura, Chiusura
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field('Numero RG', v(m.rgNumber), width: 120),
            SizedBox(width: su * 2),
            Expanded(child: field('Codice registro', v(m.registryCode))),
            SizedBox(width: su * 2),
            field('Apertura', _safeDate(m.openedAt), width: 120),
            SizedBox(width: su * 2),
            field('Chiusura', _safeDate(m.closedAt), width: 120),
          ],
        ),
        SizedBox(height: su * 2),
        // Note (multilinea)
        fieldArea('Note', v(m.description)),
      ],
    );
  }

  // --------------------- SEZIONE: UDIENZE ---------------------
  Future<List<Map<String, dynamic>>> _loadHearings() async {
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) return const [];
      final rows = await _sb
          .from('hearings')
          .select('hearing_id, type, ends_at, time, courtroom, notes')
          .eq('firm_id', fid)
          .eq('matter_id', widget.matterId)
          .order('ends_at', ascending: true)
          .order('time', ascending: true)
          .limit(500);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return const [];
    }
  }

  Widget _buildHearingsSection() {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final cs = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<ShadcnRadii>()?.sm ?? BorderRadius.circular(6);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadHearings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) return Text('Errore: ${snap.error}');
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Text('Nessuna udienza');

        int totalCount = rows.length;
        DateTime parseDate(String s) {
          if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
          return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
        }
        final now = DateTime.now();
        final futureCount = rows.where((r) => !parseDate('${r['ends_at'] ?? ''}').isBefore(now)).length;
        final pastCount = rows.where((r) => parseDate('${r['ends_at'] ?? ''}').isBefore(now)).length;

        String fmtDate(String s) {
          final d = parseDate(s);
          if (d.millisecondsSinceEpoch == 0) return '—';
          final dd = d.day.toString().padLeft(2, '0');
          final mm = d.month.toString().padLeft(2, '0');
          return '$dd/$mm/${d.year}';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cards conteggi
            Row(
              children: [
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
                        Text('Future', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                        SizedBox(height: su * 0.5),
                        Text('$futureCount', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: su * 1.5),
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
                        Text('Passate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                        SizedBox(height: su * 0.5),
                        Text('$pastCount', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: su * 1.5),
            // Lista udienze stile etichetta grande
            SizedBox(
              height: su * 24,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => SizedBox(height: su * 0.75),
                padding: EdgeInsets.zero,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  final date = fmtDate('${r['ends_at'] ?? ''}');
                  final type = ('${r['type'] ?? ''}').trim();
                  final room = ('${r['courtroom'] ?? ''}').trim();
                  final label = [date, if (type.isNotEmpty) type, if (room.isNotEmpty) 'Aula $room']
                      .join(' • ');
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
                        Icon(AppIcons.calendar, size: 16, color: cs.onTertiary),
                        SizedBox(width: su * 0.75),
                        Expanded(
                          child: Text(
                            label,
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

  // --------------------- SEZIONE: MEMORANDUM (TASKS) ---------------------
  Future<List<Map<String, dynamic>>> _loadTasks() async {
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) return const [];
      final rows = await _sb
          .from('tasks')
          .select('task_id, title, due_at, done, priority')
          .eq('firm_id', fid)
          .eq('matter_id', widget.matterId)
          .order('due_at', ascending: true, nullsFirst: true)
          .limit(500);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return const [];
    }
  }

  Widget _buildTasksSection() {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final cs = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<ShadcnRadii>()?.sm ?? BorderRadius.circular(6);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadTasks(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Spinner());
        }
        if (snap.hasError) return Text('Errore: ${snap.error}');
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Text('Nessun memorandum');

        final totalCount = rows.length;
        final openCount = rows.where((r) => (r['done'] ?? false) == false).length;
        final completedCount = rows.where((r) => (r['done'] ?? false) == true).length;

        String fmtDue(String s) {
          if (s.isEmpty) return 'Senza scadenza';
          final d = DateTime.tryParse(s);
          if (d == null) return 'Senza scadenza';
          final dd = d.day.toString().padLeft(2, '0');
          final mm = d.month.toString().padLeft(2, '0');
          return '$dd/$mm/${d.year}';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
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
                        Text('Completate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                        SizedBox(height: su * 0.5),
                        Text('$completedCount', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: su * 1.5),
            SizedBox(
              height: su * 24,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => SizedBox(height: su * 0.75),
                padding: EdgeInsets.zero,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  final due = fmtDue('${r['due_at'] ?? ''}');
                  final title = ('${r['title'] ?? ''}').trim();
                  final label = [due, if (title.isNotEmpty) title].join(' • ');
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
                        Icon(AppIcons.addTask, size: 16, color: cs.onTertiary),
                        SizedBox(width: su * 0.75),
                        Expanded(
                          child: Text(
                            label,
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

  // --------------------- SEZIONE: AZIONI (spostata sotto Memorandum) ---------------------
  Widget _buildActionsSection() {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final m = _matter;
    if (m == null) return const SizedBox.shrink();
    final status = (m.status ?? '').toLowerCase().trim();
    final isClosed = status == 'closed';
    final isOpen = status == 'open';

    List<Widget> actions = [];
    if (isOpen) {
      actions.add(
        AppButton(
          variant: AppButtonVariant.default_,
          leading: const Icon(AppIcons.checkCircle),
          onPressed: _confirmClose,
          child: const Text('Archivia'),
        ),
      );
    } else if (isClosed) {
      actions.add(
        AppButton(
          variant: AppButtonVariant.default_,
          leading: const Icon(AppIcons.restart),
          onPressed: _confirmReopen,
          child: const Text('Riapri'),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    // Spaziatura verticale e allineamento a destra, con larghezza del pulsante
    // pari al contenuto (non espanso).
    return Padding(
      padding: EdgeInsets.symmetric(vertical: su * 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions,
      ),
    );
  }

}

// --------------------- Helper UI widgets (replicati dallo sheet cliente) ---------------------
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
        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        SizedBox(height: su * 1.25),
      ],
    );
  }
}

class _ReadOnlyInputBox extends StatelessWidget {
  final String value;
  const _ReadOnlyInputBox({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radii = theme.extension<ShadcnRadii>()!;

    const double height = 36.0;
    const double px = 12.0;

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

class _ReadOnlyAreaBox extends StatelessWidget {
  final String value;
  final double height;
  const _ReadOnlyAreaBox({required this.value, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radii = theme.extension<ShadcnRadii>()!;

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