# Changelog

All notable changes to this project will be documented in this file.

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