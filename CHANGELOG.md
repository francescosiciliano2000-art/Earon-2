## 2025-11-17 — v0.1.8

### Funzionalità — Udienze
- Dialog "Evasione udienza": aggiunta opzione "Eseguita" nello step 1. Se selezionata e confermata, chiude il dialog e imposta `done = TRUE` sull'udienza senza ulteriori passaggi.

### Funzionalità — Pratiche
- Selezione "Foro/Tribunale": ora alimentata direttamente da `lib/features/courtroom.json` tramite `CourtroomRepo.watchGroups()` e `AppCombobox` in `MatterCreateSheet` e `MatterEditSheet`. Qualsiasi modifica al JSON si riflette automaticamente nelle opzioni.

### Calendario & UI
- Migliorato il selettore intervallo (CalendarRange) per gli adempimenti post-udienza.
- Pulizia lint: resta solo un warning informativo su `BuildContext` across async gaps.

### Versioning
- Bump a `0.1.8+1` in `pubspec.yaml`.

## 0.1.7+1 - 2025-11-17
- Sidebar: nascosta voce Dashboard.
- Post-login: landing direttamente su Clienti.
- Pulizia lint: flutter analyze senza issue.

# Changelog

All notable changes to this project will be documented in this file.

## 2025-11-13 — v0.1.6

### Rename & Branding
- Aggiornato il titolo finestra e i riferimenti di prodotto a "Earon" su Windows, Linux e macOS (menu bar e bundle `.app`).
- Aggiornato titoli della web app (`index.html`) e manifest PWA (`manifest.json`) a "Earon".
- UI: aggiornato il nome nell’`app_sidebar.dart` da "Gestionale" a "Earon".

### Funzionalità — Udienze
- Migliorata la selezione della pratica nel dialog "Nuova udienza": ricerca asincrona con debounce e copertura campi ampliata (`code`, `rg_number`, `client`, `counterparty_name`, `title`) per trovare più pratiche durante la digitazione.

### Versioning
- Bump versione applicazione a `0.1.6+1` in `pubspec.yaml` (branch `development-v0.1.6`).

### Note
- Il nome del pacchetto Flutter (`name: gestionale_desktop`) rimane invariato per evitare regressioni sugli import. L’installer Windows è già configurato per rinominare l’eseguibile in `Earon.exe`.

## 2025-10-17

### Fix UI (AppSelect)
- Aggiunta ellissi del testo per le voci selezionate tramite `selectedItemBuilder`, evitando overflow nei campi della toolbar (Foro, Responsabile) della pagina "Pratiche".
- Supporto modalità "densa" (`dense: true`) per ridurre l'altezza del `DropdownButtonFormField` e migliorare la compattezza della toolbar.
- Dimensione icona condizionale: `iconSize = 20` quando `dense` è `true`, altrimenti `24`, per evitare regressioni visive nei selettori non densi.

### Code Quality
- Sostituito l'uso deprecato di `value` con `initialValue` nel `DropdownButtonFormField` di `AppSelect`.

### Test
- Inizializzazione di Supabase nei test (`setUpAll`) con valori fittizi per prevenire crash dovuti al router durante il bootstrap.
- Registrata implementazione mock di `SharedPreferences` nei test per evitare `MissingPluginException`.
- Tutti i test esistenti passano (`flutter test`).

### Note
- Le modifiche sono puramente visive per la toolbar "Pratiche"; non impattano la logica di selezione/ricerca.