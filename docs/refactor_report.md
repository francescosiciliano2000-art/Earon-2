Refactor report — Design System alignment (spacing, radii, widths)

Sintesi
- Obiettivo: sostituire valori numerici (EdgeInsets/SizedBox/Radius) con token del Design System, standardizzare larghezze di AppSelect e rimuovere fallback numerici dove possibile.
- Stato: completato per le pagine Pratiche e Clienti principali; Dashboard parziale (CTA). Ulteriore audit in corso su /lib. Token colore aggiornati per contrasto AA, incluse le coppie white-on-success/warning/error.

File modificati
1) lib/features/matters/presentation/matter_detail_page.dart
   - Overview/Parties/Hours/Tasks/Hearings/Billing/BottomSheets: sostituiti EdgeInsets.all(12/16) → AppSpacing.s/m; SizedBox(8/12/16) → AppSpacing.xs/s/m; Wrap.spacing → AppSpacing.xs; BorderRadius fallback 8 → AppRadii.standard().m.
   - Billing tab: padding 16 → AppSpacing.m; gap 12 → AppSpacing.s.
   - Documents section: gap 8 → AppSpacing.xs; Wrap.spacing 8 → AppSpacing.xs; radius fallback 8 → AppRadii.standard().m.

2) lib/features/matters/presentation/matters_list_page.dart
   - Kanban: padding 12 → AppSpacing.s; header padding 12 → AppSpacing.s.
   - Empty state: gaps 8/12 → AppSpacing.xs/s.
   - Toolbar: confermata larghezza controlli (page size 120, filtri 160, ricerca 280).

3) lib/features/matters/presentation/matter_create_sheet.dart
   - Topbar: gap 8 → AppSpacing.xs.
   - Error block: gap 12 → AppSpacing.s.

4) lib/features/matters/presentation/matter_edit_sheet.dart
   - Topbar: gap 8 → AppSpacing.xs.
   - Error block: gap 12 → AppSpacing.s.

5) lib/features/clienti/presentation/new_client_dialog.dart
   - Gap 8 → AppSpacing.xs.

6) lib/features/dashboard/presentation/dashboard_page.dart
   - CTA (seleziona studio): gap 8 → AppSpacing.xs.

7) lib/theme/tokens.dart
   - primary: #5468FF → #3F55F0 per garantire AA (white on primary ≥ 4.5).
   - secondary: #F36B21 → #B54D0B per garantire AA (white on secondary ≥ 4.5).
   - info: allineato al nuovo primary (#3F55F0) per coerenza e AA.
   - success (Light): #1BAF5D → #0A5A30 per garantire AA (white on success ≥ 4.5).
   - warning (Light): #C78F00 → #8B5E00 per garantire AA (white on warning ≥ 4.5).
   - success/warning/error (Dark): scuriti per garantire AA con white-on-* ≥ 4.5.

Standard larghezze AppSelect
- Page size: 120px → applicato/già presente in MattersList e ClientiPage.
- Filtri: 160px → applicato/già presente in MattersList e ClientiPage.
- Ricerca/lookup: 280px → applicato/già presente in MattersList; ImportWizard mapping usa 280 per leggibilità.

Preview verificati
- http://localhost:8081/matters/list: Kanban/toolbar/empty state — nessun errore browser; verificata correzione overflow verticale.
- http://localhost:8081/clienti: page size/filtri e dialog — nessun errore browser.
- http://localhost:8081/dashboard: CTA spacing — nessun errore browser.

Checklist (parziale)
- [x] AppSpacing usato al posto di EdgeInsets/SizedBox numerici nelle pagine Pratiche/Clienti toccate.
- [x] AppRadii usato (fallback non numerico) nelle sezioni aggiornate.
- [x] Larghezze AppSelect standard verificate/applicate.
- [ ] Audit /lib rimanente per colori hardcoded, tipografia inline, Material grezzi, Theme locali.
- [x] Test di contrasto AA su AppTokens (light/dark) per primary/secondary/info: superata soglia 4.5 con testo bianco.
- [x] Test di contrasto AA aggiuntivi su success/warning/error (white-on-* in Light/Dark): tutti superati.
- [ ] Verifiche responsività 1440/1024/390 con correzioni Overflow.
- [ ] Accessibilità: focus ring tastiera, target ≥44px, tooltip su icone critiche, empty/error states standard.

Note
- AppSpacing è const double, utilizzabile in contesti const con EdgeInsets/SizedBox.
- AppRadii è ThemeExtension; per fallback senza numerici si è usato AppRadii.standard().m quando necessario.
 - AppTokens: i colori primary/secondary sono stati scuriti per rispettare AA con testo bianco; il token info è stato allineato al primary. Success/warning/error sono stati adeguati per white-on-* AA (Light+Dark). In alternativa, possiamo introdurre onTokens (onSuccess/onWarning/onError) se si desidera mantenere i valori brand originali sui background e gestire il colore del testo separatamente.