// lib/features/agenda/presentation/hearing_disposition_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/components/dialog.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/alert.dart';
import '../../../design system/components/sonner.dart';
import '../../../design system/components/spinner.dart';
// Rimosso: date picker singolo (sostituito da CalendarRange per intervallo)
import '../../../design system/components/calendar_time_presets.dart';
import '../../../design system/components/calendar_range.dart';
import '../../../design system/components/calendar.dart';
import '../../../design system/theme/themes.dart';
import 'package:gestionale_desktop/core/supa_helpers.dart';
import '../../../design system/components/label.dart';
import '../../../design system/components/textarea.dart';

/// Dialog di "evasione" udienza (multistep)
/// Step 1: scelta esito (Rinviata, In riserva, A sentenza)
/// Step 2: form dipendente dalla scelta
class HearingDispositionDialog extends StatefulWidget {
  final Map<String, dynamic>
      hearing; // hearing row già caricato (hearing_id, matter_id, type, ends_at, time, courtroom, notes)
  const HearingDispositionDialog({super.key, required this.hearing});

  @override
  State<HearingDispositionDialog> createState() =>
      _HearingDispositionDialogState();
}

class _HearingDispositionDialogState extends State<HearingDispositionDialog> {
  late final SupabaseClient _sb;

  int _step = 1;
  String? _outcome; // 'rinviata' | 'in_riserva' | 'a_sentenza'

  // Per step 2
  DateTime? _date; // data scelta
  TimeOfDay? _time; // ora scelta
  // Intervallo adempimento per 'in_riserva' / 'a_sentenza'
  DateTimeRange? _range;

  bool _saving = false;
  String? _error;
  // Note opzionali inserite dall'utente nello step 2
  final TextEditingController _notesCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sb = Supabase.instance.client;
  }

  DateTime _combineDateTime(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_outcome == null || _outcome!.isEmpty) {
      setState(() => _error = 'Seleziona un esito');
      return;
    }
    if (_step == 1) {
      // Opzione semplice: 'Eseguita' → chiudiamo subito e impostiamo done=true
      if (_outcome == 'eseguita') {
        setState(() { _saving = true; _error = null; });
        try {
          final h = widget.hearing;
          final hearingId = '${h['hearing_id'] ?? ''}';
          if (hearingId.isEmpty) throw Exception('Id udienza mancante');
          await _sb.from('hearings').update({'done': true}).eq('hearing_id', hearingId);
          if (!mounted) return;
          Navigator.of(context).pop({'outcome': _outcome, 'message': 'Udienza segnata come eseguita'});
          return;
        } catch (e) {
          if (!mounted) return;
          AppToaster.of(context).error('Errore salvataggio: ${e.toString()}');
          setState(() => _error = e.toString());
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      }
      setState(() => _step = 2);
      return;
    }
    // Step 2: validazioni specifiche
    if ((_outcome == 'rinviata' ||
        _outcome == 'in_riserva' ||
        _outcome == 'a_sentenza')) {
      // Validazioni specifiche per ciascun esito
      if (_outcome == 'rinviata') {
        if (_date == null) {
          setState(() => _error = 'Seleziona una data');
          return;
        }
        if (_time == null) {
          setState(() => _error = 'Seleziona un orario');
          return;
        }
      } else {
        // In riserva / A sentenza → richiede intervallo (start/end)
        if (_range == null) {
          setState(() => _error = 'Seleziona un intervallo (inizio e fine)');
          return;
        }
      }
    }

    // Esecuzione
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fid = await getCurrentFirmId();
      if (fid == null || fid.isEmpty) {
        throw Exception('Nessuno studio selezionato.');
      }
      final h = widget.hearing;
      final hearingId = '${h['hearing_id'] ?? ''}';
      final matterId = '${h['matter_id'] ?? ''}';
      if (hearingId.isEmpty) throw Exception('Id udienza mancante');

      // Common payload pieces from original hearing
      final type =
          (h['type']?.toString() ?? '').isEmpty ? null : h['type']?.toString();
      final courtroom = (h['courtroom']?.toString() ?? '').isEmpty
          ? null
          : h['courtroom']?.toString();
      final notes = (h['notes']?.toString() ?? '').isEmpty
          ? null
          : h['notes']?.toString();

      if (_outcome == 'rinviata') {
        // 1) Aggiorna udienza corrente: adjourned_at = data/ora scelti
        final adj = _combineDateTime(_date!, _time!);
        await _sb
            .from('hearings')
            .update({'adjourned_at': adj.toIso8601String(), 'done': true}).eq('hearing_id', hearingId);

        // 2) Crea nuova udienza con stessi riferimenti nella data scelta
        final hh = _time!.hour.toString().padLeft(2, '0');
        final mi = _time!.minute.toString().padLeft(2, '0');
        final newEndsAt = _combineDateTime(_date!, _time!).toIso8601String();
        // starts_at non può essere nullo: impostiamo default alla giornata odierna (00:00)
        final now = DateTime.now();
        final startsToday =
            DateTime(now.year, now.month, now.day).toIso8601String();
        // Note per la nuova udienza: se l'utente inserisce testo, prevale sulle note originali
        final typedNotes = _notesCtl.text.trim();
        await _sb.from('hearings').insert({
          'firm_id': fid,
          'matter_id': matterId.isEmpty ? null : matterId,
          'type': type,
          'starts_at': startsToday,
          'ends_at': newEndsAt,
          'time': '$hh:$mi:00',
          'courtroom': courtroom,
          'notes': (typedNotes.isNotEmpty ? typedNotes : notes),
        });
        if (!mounted) return;
        // Costruisci messaggio dettagliato per il parent (unico toast)
        final dd = _date!;
        final hhmm =
            '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
        final msg =
            'Udienza rinviata con successo al ${dd.day.toString().padLeft(2, '0')}-${dd.month.toString().padLeft(2, '0')}-${(dd.year % 100).toString().padLeft(2, '0')} alle ore $hhmm';
        Navigator.of(context).pop({'outcome': _outcome, 'message': msg});
        return;
      }

      if (_outcome == 'in_riserva' || _outcome == 'a_sentenza') {
        final title = _outcome == 'in_riserva'
            ? 'Verifica Scioglimento'
            : 'Verifica Provvedimento';
        // Intervallo richiesto: mappiamo su start_at e due_at (inizio/fine giornata)
        final sd = _range!.start;
        final ed = _range!.end;
        final startAt = DateTime(sd.year, sd.month, sd.day, 0, 0, 0);
        final dueAt = DateTime(ed.year, ed.month, ed.day, 23, 59, 59);
        final noteText = _notesCtl.text.trim();
        await _sb.from('tasks').insert({
          'firm_id': fid,
          'matter_id': matterId.isEmpty ? null : matterId,
          'title': noteText.isNotEmpty ? '$title — $noteText' : title,
          'type': 'onere',
          'start_at': startAt.toIso8601String(),
          'due_at': dueAt.toIso8601String(),
        });
        if (!mounted) return;
        // Marca l'udienza come evasa
        await _sb.from('hearings').update({'done': true}).eq('hearing_id', hearingId);
        // Messaggio dettagliato per il parent (unico toast)
        String label = _outcome == 'in_riserva'
            ? 'Adempimento di verifica scioglimento'
            : 'Adempimento di verifica provvedimento';
        String fmtDate(DateTime d) =>
            '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${(d.year % 100).toString().padLeft(2, '0')}';
        final msg = '$label creato dal ${fmtDate(sd)} al ${fmtDate(ed)}';
        Navigator.of(context).pop({'outcome': _outcome, 'message': msg});
        return;
      }

      throw Exception('Esito non gestito');
    } catch (e) {
      if (!mounted) return;
      AppToaster.of(context).error('Errore salvataggio: ${e.toString()}');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetStep2State() {
    _date = null;
    _time = null;
    _range = null;
    _notesCtl.clear();
  }

  void _onOutcomeSelect(String v) {
    setState(() {
      _outcome = v;
      _resetStep2State();
    });
  }

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final h = widget.hearing;
    final matterId = '${h['matter_id'] ?? ''}';
    // Larghezza condizionale: più ampia SOLO nello step 2 di "Rinviata"
    final double computedMaxWidth =
        (_step == 2 && _outcome == 'rinviata') ? 680.0 : 560.0;
    return AppDialogContent(
      // Dialog più largo per evitare overflow del calendario + slot
      maxWidth: computedMaxWidth,
      // Spostiamo il pulsante di chiusura nell'header per allinearlo al titolo
      showCloseButton: false,
      children: [
        AppDialogHeader(
          title: const AppDialogTitle('Evasione udienza'),
          showCloseButton: true,
          description: _step == 1
              ? const AppDialogDescription('Com’è finita l’udienza?')
              : null, // Nello step 2 spostiamo la descrizione vicino al calendario nel body
          gapBetweenTitleAndDescription: 4,
        ),
        // Spaziatura tra header e corpo: per lo step 2 non aggiungiamo extra,
        // lasciando il gap di default del contenitore (16px)
        SizedBox(height: _step == 2 ? 0 : su * 2),
        // Corpo scrollabile con altezza massima per prevenire overflow del pannello
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step == 1) ...[
                  AppLabel(text: 'Esito udienza'),
                  // Spaziatura aumentata sotto l'etichetta
                  SizedBox(height: su * 1.5),
                  // Radiogroup con card verticali: ciascuna ha titolo, testo e selettore a destra
                  Column(
                    children: [
                      _OutcomeVerticalCard(
                        title: 'Rinviata',
                        description:
                            'Segna l’udienza come rinviata e pianifica una nuova data. L’udienza corrente viene aggiornata (adjourned_at) e ne viene creata una nuova.',
                        value: 'rinviata',
                        selected: _outcome == 'rinviata',
                        onSelect: () => _onOutcomeSelect('rinviata'),
                      ),
                      // Spaziatura verticale aumentata tra le card
                      SizedBox(height: su * 1.5),
                      _OutcomeVerticalCard(
                        title: 'In riserva',
                        description:
                            'Crea un adempimento di “Verifica Scioglimento” collegato alla pratica per la data scelta.',
                        value: 'in_riserva',
                        selected: _outcome == 'in_riserva',
                        onSelect: () => _onOutcomeSelect('in_riserva'),
                      ),
                      // Spaziatura verticale aumentata tra le card
                      SizedBox(height: su * 1.5),
                      _OutcomeVerticalCard(
                        title: 'A sentenza',
                        description:
                            'Crea un adempimento di “Verifica Provvedimento” collegato alla pratica per la data scelta.',
                        value: 'a_sentenza',
                        selected: _outcome == 'a_sentenza',
                        onSelect: () => _onOutcomeSelect('a_sentenza'),
                      ),
                      // Spaziatura verticale aumentata tra le card
                      SizedBox(height: su * 1.5),
                      _OutcomeVerticalCard(
                        title: 'Eseguita',
                        description:
                            'Segna l’udienza come eseguita/evasa e chiude il dialogo senza ulteriori passaggi.',
                        value: 'eseguita',
                        selected: _outcome == 'eseguita',
                        onSelect: () => _onOutcomeSelect('eseguita'),
                      ),
                    ],
                  ),
                ] else if (_outcome == 'rinviata') ...[
                  // Mostriamo la descrizione direttamente sopra al calendario,
                  // con lo stesso spacing che c'è tra calendario e footer (16px → su*2)
                  AppDialogDescription(
                    'Indica data e ora del rinvio. Alla conferma verrà creata una nuova udienza e verrà aggiornato il rinvio di quella corrente.',
                  ),
                  SizedBox(height: su * 2),
                  AppTextarea(
                    controller: _notesCtl,
                    minLines: 3,
                    hintText:
                        'Informazioni aggiuntive per la nuova udienza di rinvio',
                  ),
                  SizedBox(height: su * 2),
                  CalendarWithTimePresets(
                    initialDate: _date,
                    timePanelWidth: 176,
                    onChanged: (d, timeStr) {
                      setState(() {
                        _date = d;
                        if (timeStr != null && timeStr.isNotEmpty) {
                          final parts = timeStr.split(':');
                          final hh = int.tryParse(parts[0]) ?? 0;
                          final mm =
                              int.tryParse(parts.length > 1 ? parts[1] : '0') ??
                                  0;
                          _time = TimeOfDay(hour: hh, minute: mm);
                        } else {
                          _time = null;
                        }
                      });
                    },
                    showFooter: true,
                    showSubmitButton: false, // usiamo i bottoni del dialog
                    summaryBuilder: (d, ts) {
                      if (d != null && ts != null && ts.isNotEmpty) {
                        const giorni = [
                          'Domenica',
                          'Lunedì',
                          'Martedì',
                          'Mercoledì',
                          'Giovedì',
                          'Venerdì',
                          'Sabato'
                        ];
                        const mesi = [
                          'gennaio',
                          'febbraio',
                          'marzo',
                          'aprile',
                          'maggio',
                          'giugno',
                          'luglio',
                          'agosto',
                          'settembre',
                          'ottobre',
                          'novembre',
                          'dicembre'
                        ];
                        final gg = giorni[d.weekday % 7];
                        final mmName = mesi[d.month - 1];
                        return 'La tua udienza sarà rinviata a $gg, ${d.day} $mmName alle ore $ts';
                      }
                      return 'Seleziona una data e un orario per il rinvio.';
                    },
                  ),
                ] else ...[
                  // In riserva / A sentenza → descrizione compatta + intervallo con CalendarRange posizionato vicino
                  AppDialogDescription(
                      'Creazione adempimenti: scegli la data per creare l’attività correlata alla pratica.'),
                  SizedBox(height: su),
                  AppTextarea(
                    controller: _notesCtl,
                    minLines: 3,
                    hintText:
                        'Dettagli o promemoria per l’adempimento che verrà creato',
                  ),
                  SizedBox(height: su),
                  CalendarRange(
                    value: _range,
                    onChanged: (r) => setState(() => _range = r),
                    // Allineiamo parte dello stile al CalendarWithTimePresets
                    navButtonVariant: NavButtonVariant.ghost,
                    cellSize: 56,
                    bordered: true,
                  ),
                  // Nessuna selezione di orario richiesta in queste varianti
                ],
                if (_error != null) ...[
                  SizedBox(height: su * 1.5),
                  Alert(
                    variant: AlertVariant.destructive,
                    child: AlertDescription(Text(_error!)),
                  ),
                ],
                if ((matterId).isEmpty) ...[
                  SizedBox(height: su * 1.5),
                  Alert(
                    variant: AlertVariant.defaultStyle,
                    child: const AlertDescription(
                      Text(
                          'Attenzione: questa udienza non è collegata ad alcuna pratica. Alcune azioni potrebbero non essere disponibili.'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AppDialogFooter(
          children: [
            if (_step == 1)
              AppButton(
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annulla'),
              ),
            if (_step == 2)
              AppButton(
                variant: AppButtonVariant.outline,
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _step = 1;
                          _resetStep2State();
                        }),
                child: const Text('Indietro'),
              ),
            AppButton(
              variant: AppButtonVariant.default_,
              onPressed: _saving ? null : _confirm,
              child: _saving
                  ? const Spinner(size: 18)
                  : Text(_step == 1 ? 'Avanti' : 'Conferma'),
            ),
          ],
        ),
      ],
    );
  }
}

// (rimosso) _OutcomeCard: sostituito da _OutcomeVerticalCard per layout richiesto

/// Card verticale con radio bullet a destra (niente pulsante "Seleziona")
class _OutcomeVerticalCard extends StatelessWidget {
  final String title;
  final String description;
  final String value;
  final bool selected;
  final VoidCallback onSelect;
  const _OutcomeVerticalCard({
    required this.title,
    required this.description,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final su = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        // Padding interno aumentato su tutti i lati
        padding: EdgeInsets.symmetric(horizontal: su * 2, vertical: su * 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  selected ? colorScheme.primary : colorScheme.outlineVariant),
          color: selected ? colorScheme.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Testo a sinistra (titolo + descrizione)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titolo con lo stesso stile di AppLabel ("Esito udienza")
                  AppLabel(text: title),
                  SizedBox(height: su * 0.5),
                  // Descrizione con lo stesso stile di AppDialogDescription ("Com’è finita l’udienza?")
                  AppDialogDescription(description),
                ],
              ),
            ),
            SizedBox(width: su),
            // Selettore a destra: bullet custom
            _RightRadioBullet(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// Piccolo radio-bullet visuale a destra, coerente con il DS
class _RightRadioBullet extends StatelessWidget {
  const _RightRadioBullet({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final border = cs.outlineVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      alignment: Alignment.topRight,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: isDark ? cs.surface.withValues(alpha: 0.30) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? primary : border, width: 1.0),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: selected ? 8 : 0,
            height: selected ? 8 : 0,
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
