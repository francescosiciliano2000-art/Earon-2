// lib/features/matters/presentation/change_client_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/search_select.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';

import '../data/matter_repo.dart';
import '../../clienti/data/cliente_repo.dart';
import 'matters_list_page.dart' show ClientOption;
import 'package:gestionale_desktop/core/supa_helpers.dart';

/// Dialog per cambiare il cliente associato a una pratica.
class ChangeClientDialog extends StatefulWidget {
  final String matterId;
  const ChangeClientDialog({super.key, required this.matterId});

  @override
  State<ChangeClientDialog> createState() => _ChangeClientDialogState();
}

class _ChangeClientDialogState extends State<ChangeClientDialog> {
  late final SupabaseClient _sb;
  late final MatterRepo _repo;
  late final ClienteRepo _clientsRepo;

  final _clientCtl = TextEditingController();
  String? _clientId;
  List<ClientOption> _clientOptions = const [];
  Timer? _clientDebounce;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
    _repo = MatterRepo(_sb);
    _clientsRepo = ClienteRepo(_sb);
    // Precarica i primi 20 clienti per evitare overlay vuoto su focus
    scheduleMicrotask(() => _onClientTextChanged());
  }

  @override
  void dispose() {
    _clientDebounce?.cancel();
    _clientCtl.dispose();
    super.dispose();
  }

  void _onClientTextChanged() {
    _clientDebounce?.cancel();
    _clientDebounce = Timer(const Duration(milliseconds: 300), () async {
      final text = _clientCtl.text.trim();
      try {
        final fid = await getCurrentFirmId();
        if (fid == null) return;
        final rows = await _clientsRepo.list(
          firmId: fid,
          q: text.isEmpty ? null : text,
          limit: text.isEmpty ? 20 : 50,
          offset: 0,
        );
        final opts = rows
            .map((r) => ClientOption(
                  id: '${r['client_id']}',
                  label: '${r['name'] ?? ''}',
                ))
            .toList();
        if (!mounted) return;
        setState(() => _clientOptions = opts);
      } catch (_) {}
    });
  }


  Future<void> _submit() async {
    if (_clientId == null || _clientId!.isEmpty) {
      setState(() => _error = 'Seleziona un cliente');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.changeClient(widget.matterId, _clientId!);
      if (!mounted) return;
      Navigator.of(context).pop(_clientId);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DefaultTokens>();
    final spacing = tokens?.spacingUnit ?? 8.0;
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Cambia cliente'),
          description: AppDialogDescription(
            'Seleziona un nuovo cliente da associare alla pratica.',
          ),
        ),
        SizedBox(height: spacing * 2),
        Row(
          children: [
            Expanded(
              child: AppSearchSelect(
                width: double.infinity,
                controller: _clientCtl,
                placeholder: 'Cerca cliente…',
                groups: [
                  SelectGroupData(
                    label: 'Clienti',
                    items: _clientOptions
                        .map((o) => SelectItemData(
                              value: o.id,
                              label: o.label,
                            ))
                        .toList(),
                  ),
                ],
                onQueryChanged: (q) {
                  _clientCtl.value = TextEditingValue(
                    text: q,
                    selection: TextSelection.collapsed(offset: q.length),
                  );
                  _onClientTextChanged();
                },
                onChanged: (value) {
                  final opt = _clientOptions.firstWhere(
                    (o) => o.id == value,
                    orElse: () => ClientOption(id: value, label: value),
                  );
                  setState(() {
                    _clientId = opt.id;
                    _clientCtl.text = opt.label;
                  });
                },
              ),
            ),
            if (_clientId != null)
              Padding(
                padding: EdgeInsets.only(left: spacing),
                child: AppButton(
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.icon,
                  onPressed: () {
                    setState(() {
                      _clientId = null;
                      _clientCtl.clear();
                      _clientOptions = const [];
                    });
                  },
                  child: const Icon(AppIcons.clear, size: 16),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          SizedBox(height: spacing * 2),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
        AppDialogFooter(
          children: [
            AppButton(
              variant: AppButtonVariant.ghost,
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: _saving ? null : _submit,
              child: _saving ? Spinner(size: 18) : const Text('Conferma'),
            ),
          ],
        ),
      ],
    );
  }
}
