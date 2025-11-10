// lib/features/clienti/presentation/new_client_dialog.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Toast Design System
import '../../../design system/components/sonner.dart';
// Button + Input + Textarea Design System
import '../../../design system/components/button.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/input.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/textarea.dart';
import '../../../design system/components/select.dart';
import '../../../design system/components/label.dart';
import '../../../design system/components/tabs.dart';
// Theme tokens (DefaultTokens + ShadcnRadii)
import '../../../design system/theme/themes.dart';
// Icone

import '../../clienti/data/cliente_repo.dart';

class NewClientDialog extends StatefulWidget {
  /// Se valorizzato, il dialog lavora in **edit mode**
  final Map<String, dynamic>? editing;
  const NewClientDialog({super.key, this.editing});

  @override
  State<NewClientDialog> createState() => _NewClientDialogState();
}

class _NewClientDialogState extends State<NewClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _repo = ClienteRepo(Supabase.instance.client);

  // campi
  final _nameCtl = TextEditingController();
  final _surnameCtl =
      TextEditingController(); // nuovo: cognome (solo per person)
  final _emailCtl = TextEditingController();
  final _pecEmailCtl =
      TextEditingController(); // nuovo: email PEC (entrambi i tipi)
  final _taxCodeCtl = TextEditingController(); // CF
  final _vatCtl = TextEditingController(); // P.IVA
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _civicCtl =
      TextEditingController(); // nuovo: numero civico (entrambi i tipi)
  final _cityCtl = TextEditingController();
  final _provinceCtl = TextEditingController(); // nuovo: provincia
  final _zipCtl = TextEditingController();
  final _countryCtl = TextEditingController(text: 'IT');
  final _notesCtl = TextEditingController();
  final _tagsCtl = TextEditingController(); // CSV di tag
  final _companyObjectCtl =
      TextEditingController(); // nuovo: oggetto sociale (solo azienda)

  String _kind = 'person'; // person | company
  String? _gender; // nuovo: sesso (solo persona) → 'M' | 'F'
  String? _companyType; // nuovo: forma giuridica (solo azienda)
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtl.text = e['name'] ?? '';
      // Lo schema corrente non ha 'surname': se il nome contiene cognome, l'utente può modificare manualmente
      _surnameCtl.text = e['surname'] ?? '';
      _emailCtl.text = e['email'] ?? '';
      _taxCodeCtl.text = e['tax_code'] ?? '';
      _vatCtl.text = e['vat_number'] ?? '';
      _phoneCtl.text = e['phone'] ?? '';
      _addressCtl.text = e['address'] ?? '';
      _cityCtl.text = e['city'] ?? '';
      // 'province' non presente a DB – campo locale opzionale
      _provinceCtl.text = e['province'] ?? '';
      // Allineamento col DB DEV: usa 'zip'
        _zipCtl.text = e['zip'] ?? '';
      _countryCtl.text = (e['country'] ?? 'IT').toString();
      // Allineamento col DB DEV: usa 'billing_notes'
      _notesCtl.text = e['billing_notes'] ?? '';
      // Tag/kind non sono presenti nello schema corrente
      final tags = (e['tags'] as List?)?.map((s) => '$s').toList() ?? [];
      _tagsCtl.text = tags.join(', ');
      _kind = (e['kind'] ?? 'person').toString();
      // campi nuovi opzionali: se lo schema futuro li conterrà, prefill
      _pecEmailCtl.text = e['pec_email']?.toString() ?? '';
      // DB DEV: il numero civico è in 'street_number'
      _civicCtl.text = e['street_number']?.toString() ?? '';
      _gender = e['gender']?.toString();
      _companyType = e['company_type']?.toString();
      _companyObjectCtl.text = e['company_object']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _surnameCtl.dispose();
    _emailCtl.dispose();
    _pecEmailCtl.dispose();
    _taxCodeCtl.dispose();
    _vatCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _civicCtl.dispose();
    _cityCtl.dispose();
    _provinceCtl.dispose();
    _zipCtl.dispose();
    _countryCtl.dispose();
    _notesCtl.dispose();
    _tagsCtl.dispose();
    _companyObjectCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final toaster = AppToaster.of(context);

    try {
      if (widget.editing == null) {
        // CREATE
        final sp = await SharedPreferences.getInstance();
        final firmId = sp.getString('currentFirmId');
        if (firmId == null) {
          if (mounted) {
            toaster.warning('Nessuno studio selezionato');
          }
          return;
        }

        toaster.loading('Creazione cliente…');
        // Per persona: salva nome in 'name' e cognome in 'surname'
        final givenName = _nameCtl.text.trim();
        final newId = await _repo.create(
          firmId: firmId,
          name: givenName,
          email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
          taxCode:
              _taxCodeCtl.text.trim().isEmpty ? null : _taxCodeCtl.text.trim(),
          vatNumber: _vatCtl.text.trim().isEmpty ? null : _vatCtl.text.trim(),
        );

        // Patch con campi extra allineati allo schema DEV
        final address = _addressCtl.text.trim();
        final notes = _notesCtl.text.trim();
        final patch = <String, dynamic>{
          'phone': _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
          'address': address.isEmpty ? null : address,
          // Salva numero civico in colonna dedicata
          'street_number': _civicCtl.text.trim().isEmpty ? null : _civicCtl.text.trim(),
          'city': _cityCtl.text.trim().isEmpty ? null : _cityCtl.text.trim(),
          // DB: zip (non postal_code nell'ambiente DEV)
          'zip':
              _zipCtl.text.trim().isEmpty ? null : _zipCtl.text.trim(),
          'country':
              _countryCtl.text.trim().isEmpty ? null : _countryCtl.text.trim(),
          'billing_notes': notes.isEmpty ? null : notes,
          // Campi richiesti
          'kind': _kind,
          'gender': _kind == 'person' && (_gender != null && _gender!.trim().isNotEmpty) ? _gender : null,
          'province': _provinceCtl.text.trim().isEmpty ? null : _provinceCtl.text.trim(),
          'pec_email': _pecEmailCtl.text.trim().isEmpty ? null : _pecEmailCtl.text.trim(),
          // Campi specifici per Azienda
          'company_type': _kind == 'company' && (_companyType != null && _companyType!.trim().isNotEmpty) ? _companyType : null,
          'company_object': _kind == 'company' && _companyObjectCtl.text.trim().isNotEmpty ? _companyObjectCtl.text.trim() : null,
        }..removeWhere((k, v) => v == null || (v is List && v.isEmpty));

        if (patch.isNotEmpty) {
          await _repo.update(newId, patch);
        }

        // Gestione PEC come contatto collegato (role = 'pec')
        await _upsertPECContact(newId);

        if (mounted) {
          Navigator.pop(context, true);
          toaster.success('Cliente creato con successo');
        }
      } else {
        // UPDATE
        toaster.loading('Aggiornamento cliente…');
        final id = widget.editing!['client_id'] as String;
        final address = _addressCtl.text.trim();
        final notes = _notesCtl.text.trim();
        final patch = <String, dynamic>{
          // Aggiorna separatamente nome e cognome
          'name': _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim(),
          'surname': _kind == 'person' && _surnameCtl.text.trim().isNotEmpty ? _surnameCtl.text.trim() : null,
          'email': _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
          'tax_code':
              _taxCodeCtl.text.trim().isEmpty ? null : _taxCodeCtl.text.trim(),
          'vat_number':
              _vatCtl.text.trim().isEmpty ? null : _vatCtl.text.trim(),
          'phone': _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
          'address': address.isEmpty ? null : address,
          // Salva numero civico in colonna dedicata
          'street_number': _civicCtl.text.trim().isEmpty ? null : _civicCtl.text.trim(),
          'city': _cityCtl.text.trim().isEmpty ? null : _cityCtl.text.trim(),
          // DB: zip (non postal_code nell'ambiente DEV)
          'zip':
              _zipCtl.text.trim().isEmpty ? null : _zipCtl.text.trim(),
          'country':
              _countryCtl.text.trim().isEmpty ? null : _countryCtl.text.trim(),
          'billing_notes': notes.isEmpty ? null : notes,
          // Campi richiesti
          'kind': _kind,
          'gender': _kind == 'person' && (_gender != null && _gender!.trim().isNotEmpty) ? _gender : null,
          'province': _provinceCtl.text.trim().isEmpty ? null : _provinceCtl.text.trim(),
          'pec_email': _pecEmailCtl.text.trim().isEmpty ? null : _pecEmailCtl.text.trim(),
        }..removeWhere((k, v) => v == null || (v is List && v.isEmpty));

        await _repo.update(id, patch);
        await _upsertPECContact(id);
        if (mounted) {
          Navigator.pop(context, true);
          toaster.success('Cliente aggiornato');
        }
      }
    } catch (e) {
      if (!mounted) return;
      toaster.error('Errore salvataggio: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Helpers non utilizzati rimossi per pulizia lint

  // Salva/aggiorna contatto PEC sul cliente
  Future<void> _upsertPECContact(String clientId) async {
    final pec = _pecEmailCtl.text.trim();
    if (pec.isEmpty) return; // nulla da salvare
    final sp = await SharedPreferences.getInstance();
    final firmId = sp.getString('currentFirmId');
    if (firmId == null || firmId.isEmpty) return;
    final sb = Supabase.instance.client;
    try {
      final existing = await sb
          .from('contacts')
          .select('contact_id')
          .eq('client_id', clientId)
          .eq('role', 'pec')
          .maybeSingle();
      if (existing != null && existing['contact_id'] != null) {
        await sb
            .from('contacts')
            .update({'email': pec}).eq('contact_id', existing['contact_id']);
      } else {
        await sb.from('contacts').insert({
          'firm_id': firmId,
          'client_id': clientId,
          'name': _nameCtl.text.trim(),
          'role': 'pec',
          'email': pec,
          'status': 'active',
        });
      }
    } catch (_) {
      // Silenzioso: non blocca il salvataggio del cliente
    }
  }

  // _label non utilizzato: rimosso

  // --- PERSONA ---
  Widget _buildPersonForm(BuildContext context, double su) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome + Cognome
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Nome'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _nameCtl),
                ],
              ),
            ),
            SizedBox(width: su * 1.5),
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Cognome'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _surnameCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Codice fiscale + Sesso + Telefono
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Codice fiscale'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _taxCodeCtl),
                ],
              ),
            ),
            SizedBox(width: su * 1.5),
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Genere'),
                  SizedBox(height: su * 1.5),
                  AppSelect(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                    groups: const [
                      SelectGroupData(
                        label: 'Genere',
                        items: [
                          SelectItemData(value: 'M', label: 'Uomo'),
                          SelectItemData(value: 'F', label: 'Donna'),
                          SelectItemData(value: 'Other', label: 'Altro'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: su * 1.5),
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Numero di telefono'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _phoneCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Email + Email PEC
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Email'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _emailCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'PEC'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _pecEmailCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Indirizzo + Numero civico
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Indirizzo'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _addressCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Numero civico'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _civicCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Città / Provincia / CAP / Paese
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Città'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _cityCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Provincia'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _provinceCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'CAP'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _zipCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Paese'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _countryCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Note di fatturazione (textarea)
        AppLabel(text: 'Note di fatturazione'),
        SizedBox(height: su * 1.5),
        AppTextarea(
          controller: _notesCtl,
          minLines: 3,
        ),
        SizedBox(height: su * 2),

        // Tag
        AppLabel(text: 'Tag'),
        SizedBox(height: su * 1.5),
        AppInput(controller: _tagsCtl, hintText: 'Tag (separati da virgola)'),
      ],
    );
  }

  // --- AZIENDA ---
  Widget _buildCompanyForm(BuildContext context, double su) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ragione sociale + Forma giuridica
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Ragione sociale'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _nameCtl),
                ],
              ),
            ),
            SizedBox(width: su * 1.5),
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Forma giuridica'),
                  SizedBox(height: su * 1.5),
                  AppSelect(
                    value: _companyType,
                    onChanged: (v) => setState(() => _companyType = v),
                    groups: const [
                      // — SOCIETÀ —
                      SelectGroupData(label: 'Società', items: [
                        SelectItemData(value: 'SS', label: 'S.s.'),
                        SelectItemData(value: 'SNC', label: 'S.n.c.'),
                        SelectItemData(value: 'SAS', label: 'S.a.s.'),
                        SelectItemData(value: 'SRL', label: 'S.r.l.'),
                        SelectItemData(value: 'SRLS', label: 'S.r.l.s.'),
                        SelectItemData(value: 'SPA', label: 'S.p.A.'),
                        SelectItemData(value: 'SAPA', label: 'S.a.p.A.'),
                        SelectItemData(value: 'COOP', label: 'Soc. Coop.'),
                        SelectItemData(
                            value: 'COOP_SOCIALE', label: 'Soc. Coop. Sociale'),
                        SelectItemData(value: 'CONS', label: 'Soc. Cons.'),
                        SelectItemData(value: 'SE', label: 'S.E.'),
                        SelectItemData(value: 'SCE', label: 'S.C.E.'),
                      ]),

                      // — ENTI —
                      SelectGroupData(label: 'Enti', items: [
                        SelectItemData(
                            value: 'ASSOCIAZIONE', label: 'Associazione'),
                        SelectItemData(
                            value: 'FONDAZIONE', label: 'Fondazione'),
                        SelectItemData(value: 'COMITATO', label: 'Comitato'),
                        SelectItemData(value: 'CONSORZIO', label: 'Consorzio'),
                        SelectItemData(
                            value: 'ENTE_PUBB_ECON',
                            label: 'Ente Pubblico Economico'),
                        SelectItemData(
                            value: 'ENTE_RELIGIOSO', label: 'Ente Religioso'),
                        SelectItemData(
                            value: 'ETS', label: 'Ente del Terzo Settore'),
                        SelectItemData(value: 'ONLUS', label: 'ONLUS'),
                        SelectItemData(value: 'APS', label: 'APS'),
                        SelectItemData(value: 'ODV', label: 'ODV'),
                      ]),

                      // — ALTRE FORME —
                      SelectGroupData(label: 'Altre Forme', items: [
                        SelectItemData(
                            value: 'DITTA', label: 'Ditta Individuale'),
                        SelectItemData(
                            value: 'IMPRESA_FAMILIARE',
                            label: 'Impresa Familiare'),
                        SelectItemData(
                            value: 'SOCIETA_FATTO', label: 'Società di Fatto'),
                        SelectItemData(value: 'GEIE', label: 'GEIE'),
                        SelectItemData(
                            value: 'RETE_IMPRESE', label: 'Rete di Imprese'),
                        SelectItemData(value: 'TRUST', label: 'Trust'),
                        SelectItemData(
                            value: 'STUDIO_ASSOCIATO',
                            label: 'Studio Associato'),
                        SelectItemData(
                            value: 'ASSOC_PROF',
                            label: 'Associazione Professionale'),
                        SelectItemData(
                            value: 'STP',
                            label: 'Società tra Professionisti (STP)'),
                      ]),

                      // — INTERPRETAZIONI MINORITARIE —
                      SelectGroupData(
                          label: 'Interpretazioni Minoritarie',
                          items: [
                            SelectItemData(
                                value: 'SOCIETA_IRREGOLARE',
                                label: 'Società Irregolare'),
                            SelectItemData(
                                value: 'SOCIETA_GODIMENTO',
                                label: 'Società di Mero Godimento'),
                            SelectItemData(
                                value: 'SOCIETA_ESTERA',
                                label:
                                    'Società Estera senza Stabile Organizzazione'),
                            SelectItemData(
                                value: 'ENTE_ECCLESIASTICO',
                                label:
                                    'Ente Ecclesiastico Civilmente Riconosciuto'),
                            SelectItemData(
                                value: 'FONDAZIONE_BANCARIA',
                                label: 'Fondazione Bancaria'),
                            SelectItemData(
                                value: 'CONSORSIO_NON_ISCRITTO',
                                label: 'Consorzio senza Iscrizione CCIAA'),
                          ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Sezione due colonne: sx (P.IVA + Telefono), dx (Oggetto sociale textarea)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Partita IVA'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _vatCtl),
                  SizedBox(height: su * 2),
                  AppLabel(text: 'Telefono'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _phoneCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Oggetto sociale'),
                  SizedBox(height: su * 1.5),
                  AppTextarea(
                    controller: _companyObjectCtl,
                    minLines: 5,
                  ),
                  SizedBox(height: su * 1.0),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Email + Email PEC
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Email'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _emailCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'PEC'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _pecEmailCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Indirizzo + Numero civico
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Indirizzo'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _addressCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Numero civico'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _civicCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Città / Provincia / CAP / Paese
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Città'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _cityCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Provincia'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _provinceCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'CAP'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _zipCtl),
                ],
              ),
            ),
            SizedBox(width: su * 2),
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(text: 'Paese'),
                  SizedBox(height: su * 1.5),
                  AppInput(controller: _countryCtl),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: su * 2),

        // Note (textarea)
        AppLabel(text: 'Note'),
        SizedBox(height: su * 1.5),
        AppTextarea(
          controller: _notesCtl,
          minLines: 3,
        ),
        SizedBox(height: su * 2),

        // Tag
        AppLabel(text: 'Tag'),
        SizedBox(height: su * 1.5),
        AppInput(controller: _tagsCtl, hintText: 'Tag (separati da virgola)'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return AppDialogContent(
      showCloseButton: true,
      children: [
        // Header coerente con il design, senza IconButton manuale
        AppDialogHeader(
          title: AppDialogTitle(editing ? 'Modifica cliente' : 'Nuovo cliente'),
          description: AppDialogDescription(
            editing
                ? 'Aggiorna le informazioni del cliente selezionato.'
                : 'Compila i dati per aggiungere un nuovo cliente al tuo studio.',
          ),
        ),
        SizedBox(height: 6),
        SizedBox(
          width: 620,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabs Persona/Azienda ripristinate
                  Tabs(
                    value: _kind,
                    onValueChange: (v) {
                      if (!editing) setState(() => _kind = v);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabsList(
                          children: const [
                            TabsTrigger(
                                value: 'person', child: Text('Persona')),
                            SizedBox(width: 8),
                            TabsTrigger(
                                value: 'company', child: Text('Azienda')),
                          ],
                        ),
                        SizedBox(height: su * 2),
                        // Contenuto Persona
                        TabsContent(
                          value: 'person',
                          expand: false,
                          child: _buildPersonForm(context, su),
                        ),
                        // Contenuto Azienda
                        TabsContent(
                          value: 'company',
                          expand: false,
                          child: _buildCompanyForm(context, su),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppDialogFooter(
          children: [
            AppButton(
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            AppButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const Spinner(size: 18)
                  : Text(editing ? 'Salva' : 'Crea'),
            ),
          ],
        ),
      ],
    );
  }
}
