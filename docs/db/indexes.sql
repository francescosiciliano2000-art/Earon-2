-- Indici consigliati per performance in gestione pratiche
-- Verificare che le colonne e i nomi tabelle corrispondano allo schema reale.

-- Estensioni utili per ricerche testuali
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- matters: filtri frequenti su firm_id + status/court, ricerche su title/code
CREATE INDEX IF NOT EXISTS idx_matters_firm_status ON public.matters (firm_id, status);
CREATE INDEX IF NOT EXISTS idx_matters_firm_court ON public.matters (firm_id, court);
CREATE INDEX IF NOT EXISTS idx_matters_firm_client ON public.matters (firm_id, client_id);
CREATE INDEX IF NOT EXISTS idx_matters_created_at ON public.matters (created_at);

-- Ricerca LIKE/ILIKE su title e code con trigram (migliora il search '%...%')
CREATE INDEX IF NOT EXISTS idx_matters_title_trgm ON public.matters USING GIN (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_matters_code_trgm ON public.matters USING GIN (code gin_trgm_ops);

-- invoice_lines: controllo collegamenti e listing per matter_id
CREATE INDEX IF NOT EXISTS idx_invoice_lines_matter ON public.invoice_lines (matter_id);

-- time_entries: KPI e filtri
CREATE INDEX IF NOT EXISTS idx_time_entries_firm_billable ON public.time_entries (firm_id, billable);

-- invoices: KPI mensili e receivables
CREATE INDEX IF NOT EXISTS idx_invoices_firm_issue ON public.invoices (firm_id, issue_date);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices (status);

-- tasks/hearings per agenda
CREATE INDEX IF NOT EXISTS idx_tasks_matter ON public.tasks (matter_id);
CREATE INDEX IF NOT EXISTS idx_hearings_matter ON public.hearings (matter_id);

-- Nota: usare CREATE INDEX CONCURRENTLY su tabelle molto grandi, eseguendo in transazioni separate.