# Project Context (Flutter + Supabase)

- Stack: Flutter, supabase_flutter, go_router.
- Modules principali: dashboard, clienti (list/detail/create/edit/merge/import).
- Tabelle chiave: clients, matters, documents, invoices, payments.
- Convenzioni:
  - `firm_id` sempre filtrato.
  - clients.tags è `text[]` (filtri: overlaps/contains).
- TODO attuali: attività nel dettaglio cliente, import wizard, merge avanzato.