# Project Rules

## Stack e contesto
- Linguaggi principali: **Flutter/Dart** (frontend) e **Supabase/Postgres** (backend).
- Il progetto segue una struttura modulare: ogni feature in `lib/features/...`.
- I dati vengono gestiti tramite repository (pattern `repo.dart`) collegati alle tabelle Supabase.

## Linee guida generali
- Mantieni **naming coerente** con il DB (snake_case nel DB → camelCase in Dart).
- Prima di modificare o refactorare file core, proponi un piano sintetico.
- Non creare o eliminare tabelle, colonne o policy senza richiesta esplicita.
- Rispetta sempre la struttura delle cartelle esistenti.
- Quando generi nuovo codice:
  - preferisci classi e metodi concisi, commentati,
  - allinea i tipi con lo schema reale del DB.

## Interazione con Supabase
- Usa la variabile d'ambiente `$SUPABASE_DB_URL` per interrogare il DB.
- Non mostrare o stampare segreti o password in chiaro.
- Usa comandi `psql` solo in **read-only** (schema, metadata, SELECT limitate).
- Prima di proporre query o join, verifica schema e relazioni con introspezione (`introspect.sql`).

## Output
- Quando produci documentazione o analisi, usa formato **Markdown** con sezioni chiare.
- Mantieni sempre un tono tecnico e conciso.
