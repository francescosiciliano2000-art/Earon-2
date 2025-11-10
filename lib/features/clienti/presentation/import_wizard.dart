// lib/features/clienti/presentation/import_wizard.dart
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Design System components
import '../../../design system/components/app_data_table.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/dialog.dart';
// Theme tokens
import '../../../design system/theme/themes.dart';
import '../../../design system/icons/app_icons.dart';

import '../../clienti/data/cliente_repo.dart';

class ImportClientsWizard extends StatefulWidget {
  final String firmId;
  const ImportClientsWizard({super.key, required this.firmId});

  @override
  State<ImportClientsWizard> createState() => _ImportClientsWizardState();
}

class _ImportClientsWizardState extends State<ImportClientsWizard> {
  int _step = 0;

  // dati CSV
  List<List<dynamic>> _table = [];
  List<String> _headers = [];

  // mapping: campo destinazione -> header CSV selezionato oppure null
  final Map<String, String?> _map = {
    'client_id': null,
    'name': null,
    'kind': null,
    'email': null,
    'tax_code': null,
    'vat_number': null,
    'phone': null,
    'address': null,
    'city': null,
    'zip': null,
    'country': null,
    'billing_notes': null,
    'tags': null,
  };

  bool _importing = false;
  String? _error;

  Future<void> _pickCsv() async {
    setState(() => _error = null);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      Uint8List bytes;
      if (kIsWeb) {
        bytes = res.files.first.bytes!;
      } else {
        final path = res.files.first.path!;
        bytes = await File(path).readAsBytes();
      }

      final content = utf8.decode(bytes);
      final table = const CsvToListConverter(eol: '\n').convert(content);

      if (table.isEmpty) {
        setState(() => _error = 'CSV vuoto.');
        return;
      }

      final headers = table.first.map((e) => '$e').toList();
      setState(() {
        _table = table;
        _headers = headers;
        _step = 1;
      });

      _autoGuessMapping(headers);
    } catch (e) {
      setState(() => _error = 'Errore lettura CSV: $e');
    }
  }

  void _autoGuessMapping(List<String> headers) {
    String? guess(Iterable<String> keys) {
      for (final h in headers) {
        final n = h.toLowerCase().trim();
        for (final k in keys) {
          if (n.contains(k)) return h;
        }
      }
      return null;
    }

    _map['name'] =
        _map['name'] ?? guess(['nome', 'ragione', 'denominazione', 'name']);
    _map['email'] = _map['email'] ?? guess(['mail', 'email']);
    _map['kind'] =
        _map['kind'] ?? guess(['tipo', 'kind', 'persona', 'azienda']);
    _map['vat_number'] = _map['vat_number'] ?? guess(['p.iva', 'iva', 'vat']);
    _map['tax_code'] =
        _map['tax_code'] ?? guess(['cf', 'codice fiscale', 'tax']);
    _map['phone'] = _map['phone'] ?? guess(['tel', 'phone', 'cell']);
    _map['address'] = _map['address'] ?? guess(['indirizzo', 'address']);
    _map['city'] = _map['city'] ?? guess(['città', 'comune', 'city']);
    _map['zip'] = _map['zip'] ?? guess(['cap', 'zip']);
    _map['country'] = _map['country'] ?? guess(['stato', 'country', 'paese']);
    _map['billing_notes'] =
        _map['billing_notes'] ?? guess(['note', 'fatturazione', 'billing']);
    _map['tags'] = _map['tags'] ?? guess(['tag', 'tags', 'etichette']);
    _map['client_id'] =
        _map['client_id'] ?? guess(['id', 'client_id', 'guid', 'uuid']);
    setState(() {});
  }

  Widget _mappingDropdown(String target) {
    return AppSelect(
      value: _map[target],
      placeholder: target,
      width: double.infinity,
      groups: [
        SelectGroupData(
          label: target,
          items: [
            const SelectItemData(value: '', label: '(nessuno)'),
            ..._headers.map((h) => SelectItemData(value: h, label: h)),
          ],
        ),
      ],
      onChanged: (v) => setState(() => _map[target] = v.isEmpty ? null : v),
    );
  }

  List<Map<String, dynamic>> _buildMappedRows() {
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < _table.length; i++) {
      final line = _table[i];
      String? cell(String? header) {
        if (header == null) return null;
        final idx = _headers.indexOf(header);
        if (idx < 0 || idx >= line.length) return null;
        final v = line[idx];
        return (v == null || '$v'.trim().isEmpty) ? null : '$v';
      }

      final m = <String, dynamic>{
        'client_id': cell(_map['client_id']),
        'name': cell(_map['name']),
        'kind': cell(_map['kind']),
        'email': cell(_map['email']),
        'tax_code': cell(_map['tax_code']),
        'vat_number': cell(_map['vat_number']),
        'phone': cell(_map['phone']),
        'address': cell(_map['address']),
        'city': cell(_map['city']),
        'zip': cell(_map['zip']),
        'country': cell(_map['country']),
        'billing_notes': cell(_map['billing_notes']),
        'tags': cell(_map['tags']), // stringa; repo la convertirà in lista
      };

      // name è l’unico che davvero ha senso richiedere
      if ((m['name'] ?? '').toString().trim().isEmpty) continue;

      rows.add(m);
    }
    return rows;
  }

  Future<void> _doImport() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final rows = _buildMappedRows();
      if (rows.isEmpty) {
        setState(() {
          _error = 'Nessuna riga valida da importare.';
          _importing = false;
        });
        return;
      }

      final repo = ClienteRepo(Supabase.instance.client);
      final err =
          await repo.bulkUpsertClients(firmId: widget.firmId, rows: rows);
      if (err != null) {
        setState(() {
          _error = err;
          _importing = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Errore import: $e';
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final actions = _buildActions(su);
    return AppDialogContent(
      children: [
        const AppDialogHeader(
          title: AppDialogTitle('Importa clienti (CSV)'),
          description: AppDialogDescription(
            'Carica un CSV, mappa le colonne e conferma l’importazione.',
          ),
        ),
        SizedBox(height: su * 2),
        SizedBox(
          width: 720,
          child: _buildStep(su),
        ),
        if (actions.isNotEmpty) AppDialogFooter(children: actions),
      ],
    );
  }

  Widget _buildStep(double su) {
    if (_error != null) {
      return Text(
        _error!,
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(color: Theme.of(context).colorScheme.error),
      );
    }

    switch (_step) {
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Step 1: seleziona un file CSV con l’intestazione nella prima riga.'),
            SizedBox(height: su * 2),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: _pickCsv,
              leading: const Icon(AppIcons.uploadFile),
              child: const Text('Scegli CSV…'),
            ),
          ],
        );

      case 1:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Step 2: mappa colonne'),
              SizedBox(height: su * 2),
              Wrap(
                spacing: su * 2,
                runSpacing: su * 2,
                children: _map.keys.map((k) {
                  return SizedBox(
                    width: 280,
                    child: _mappingDropdown(k),
                  );
                }).toList(),
              ),
              SizedBox(height: su * 2),
              Text(
                'Suggerimento: se il tuo CSV ha colonne “Ragione Sociale, P.IVA, CF, Email, Telefono, Tags…”, prova a mappare “Ragione Sociale → name”, “P.IVA → vat_number”, “CF → tax_code”, “Tags → tags”.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );

      case 2:
        final preview = _buildMappedRows().take(20).toList();
        if (preview.isEmpty) {
          return const Text('Niente da mostrare (verifica il mapping).');
        }
        final cols = [
          'client_id',
          'name',
          'kind',
          'email',
          'tax_code',
          'vat_number',
          'phone',
          'address',
          'city',
          'zip',
          'country',
          'billing_notes',
          'tags'
        ];
        return Padding(
          padding: EdgeInsets.only(bottom: su * 2),
          child: AppDataTable(
            columns: [for (final c in cols) AppDataColumn(label: c)],
            rows: [
              for (final r in preview)
                AppDataRow(
                  cells: [for (final c in cols) Text('${r[c] ?? ''}')],
                ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildActions(double su) {
    switch (_step) {
      case 0:
        return [
          AppButton(
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Chiudi'),
          ),
        ];
      case 1:
        return [
          AppButton(
            variant: AppButtonVariant.ghost,
            onPressed: () => setState(() => _step = 0),
            child: const Text('Indietro'),
          ),
          AppButton(
            variant: AppButtonVariant.default_,
            onPressed: () => setState(() => _step = 2),
            child: const Text('Anteprima'),
          ),
        ];
      case 2:
        return [
          AppButton(
            variant: AppButtonVariant.ghost,
            onPressed: () => setState(() => _step = 1),
            child: const Text('Indietro'),
          ),
          AppButton(
            variant: AppButtonVariant.default_,
            onPressed: _importing ? null : _doImport,
            leading: _importing ? null : const Icon(AppIcons.playlistAddCheck),
            child: _importing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: Spinner(size: 18),
                      ),
                      SizedBox(width: su),
                      const Text('Importa'),
                    ],
                  )
                : const Text('Importa'),
          ),
        ];
      default:
        return [];
    }
  }
}
