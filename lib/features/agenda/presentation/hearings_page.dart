import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';

import '../../../design system/components/button.dart';
import '../../../design system/components/progress.dart';
import '../../../design system/icons/app_icons.dart';
import 'package:gestionale_desktop/features/agenda/presentation/hearing_create_dialog.dart';
import '../../../design system/components/list_tile.dart';
import '../../../design system/components/dialog.dart';

class HearingsPage extends StatefulWidget {
  const HearingsPage({super.key});

  @override
  State<HearingsPage> createState() => _HearingsPageState();
}

class _HearingsPageState extends State<HearingsPage> {
  late final SupabaseClient _sb;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _hearings = const [];

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _loadHearings();
  }

  Future<void> _loadHearings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }
      final rows = await _sb
          .from('hearings')
          .select('hearing_id, type, starts_at, courtroom, notes')
          .eq('firm_id', fid)
          .order('starts_at', ascending: true, nullsFirst: true);
      final list = (rows as List).cast<Map<String, dynamic>>();
      setState(() => _hearings = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openCreateHearing() async {
    final created = await AppDialog.show(
      context,
      builder: (ctx) => const HearingCreateDialog(),
    );
    if (created != null) {
      await _loadHearings();
    }
  }

  String _fmtDate(dynamic iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse('$iso').toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year} $hh:$mi';
    } catch (_) {
      return '—';
    }
  }

  Widget _hearingTile(Map<String, dynamic> h) {
    final type = '${h['type'] ?? 'Udienza'}';
    final date = _fmtDate(h['starts_at']);
    final courtroom = h['courtroom'] != null && '${h['courtroom']}'.isNotEmpty
        ? 'Aula: ${h['courtroom']}'
        : null;
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(AppIcons.gavel),
      title: Text(type),
      subtitle: Text(courtroom != null ? '$date • $courtroom' : date),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () {
        // NOTE: apri dettaglio udienza
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.gavel),
              const SizedBox(width: 8),
              Text('Udienze', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              AppButton(
                variant: AppButtonVariant.secondary,
                leading: const Icon(AppIcons.refresh),
                onPressed: _loading ? null : _loadHearings,
                child: const Text('Aggiorna'),
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: AppButtonVariant.default_,
                leading: const Icon(AppIcons.add),
                onPressed: _openCreateHearing,
                child: const Text('Nuova'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Elenco udienze',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_loading) const AppProgressBar(),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text('Errore: $_error',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_hearings.isEmpty && !_loading && _error == null)
                    const Text('Nessuna udienza trovata.'),
                  if (_hearings.isNotEmpty)
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _hearings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _hearingTile(_hearings[i]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
