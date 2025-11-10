# Database Schema Documentation

## Overview

Il database utilizza **PostgreSQL** tramite **Supabase** e segue una struttura modulare per la gestione di uno studio legale. Tutte le tabelle utilizzano UUID come chiavi primarie e includono campi di audit (`created_at`, `updated_at`).

## Tabelle Principali

### 1. **firms** - Studi Legali
Tabella principale che rappresenta gli studi legali.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `firm_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `name` | text | NO | - | Nome dello studio |
| `tax_code` | text | YES | - | Codice fiscale |
| `vat_number` | text | YES | - | Partita IVA |
| `address` | text | YES | - | Indirizzo |
| `city` | text | YES | - | Città |
| `postal_code` | text | YES | - | CAP |
| `country` | text | YES | 'IT' | Paese |
| `phone` | text | YES | - | Telefono |
| `email` | text | YES | - | Email |
| `website` | text | YES | - | Sito web |
| `logo_path` | text | YES | - | Percorso logo |
| `settings` | jsonb | YES | - | Impostazioni personalizzate |
| `status` | record_status | YES | 'active' | Stato del record |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 2. **profiles** - Profili Utente
Profili degli utenti collegati agli studi legali.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `profile_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `auth_user_id` | uuid | YES | - | ID utente Supabase Auth |
| `email` | text | NO | - | Email utente |
| `first_name` | text | YES | - | Nome |
| `last_name` | text | YES | - | Cognome |
| `role` | role_type | YES | 'guest' | Ruolo utente |
| `phone` | text | YES | - | Telefono |
| `avatar_path` | text | YES | - | Percorso avatar |
| `settings` | jsonb | YES | - | Impostazioni personali |
| `last_login` | timestamptz | YES | - | Ultimo accesso |
| `status` | record_status | YES | 'active' | Stato del record |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 3. **clients** - Clienti
Anagrafica dei clienti degli studi legali.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `client_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `name` | text | NO | - | Nome/Ragione sociale |
| `tax_code` | text | YES | - | Codice fiscale |
| `vat_number` | text | YES | - | Partita IVA |
| `email` | text | YES | - | Email |
| `phone` | text | YES | - | Telefono |
| `address` | text | YES | - | Indirizzo |
| `city` | text | YES | - | Città |
| `postal_code` | text | YES | - | CAP |
| `country` | text | YES | - | Paese |
| `notes` | text | YES | - | Note |
| `status` | record_status | YES | 'active' | Stato del record |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 4. **matters** - Pratiche Legali
Gestione delle pratiche/cause legali.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `matter_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `client_id` | uuid | NO | - | Riferimento al cliente |
| `title` | text | NO | - | Titolo della pratica |
| `description` | text | YES | - | Descrizione |
| `matter_number` | text | YES | - | Numero pratica |
| `legacy_client_id` | text | YES | - | ID cliente legacy |
| `court` | text | YES | - | Tribunale |
| `judge` | text | YES | - | Giudice |
| `opposing_party` | text | YES | - | Controparte |
| `case_value` | numeric | YES | - | Valore della causa |
| `hourly_rate` | numeric | YES | - | Tariffa oraria |
| `status` | matter_status | YES | 'open' | Stato della pratica |
| `opened_at` | date | YES | CURRENT_DATE | Data apertura |
| `closed_at` | date | YES | - | Data chiusura |
| `notes` | text | YES | - | Note |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 5. **tasks** - Attività/Task
Gestione delle attività e task.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `task_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `matter_id` | uuid | YES | - | Riferimento alla pratica |
| `assigned_to` | uuid | YES | - | Assegnato a (profile_id) |
| `created_by` | uuid | NO | - | Creato da (profile_id) |
| `title` | text | NO | - | Titolo del task |
| `description` | text | YES | - | Descrizione |
| `priority` | text | YES | 'medium' | Priorità |
| `status` | text | YES | 'pending' | Stato |
| `due_date` | date | YES | - | Data scadenza |
| `completed_at` | timestamptz | YES | - | Data completamento |
| `estimated_hours` | numeric | YES | - | Ore stimate |
| `actual_hours` | numeric | YES | - | Ore effettive |
| `tags` | text[] | YES | - | Tag |
| `dependencies` | uuid[] | YES | - | Dipendenze da altri task |
| `attachments` | jsonb | YES | - | Allegati |
| `comments` | jsonb | YES | - | Commenti |
| `recurring_pattern` | jsonb | YES | - | Pattern ricorrenza |
| `parent_task_id` | uuid | YES | - | Task padre |
| `performed_by` | text | YES | - | Eseguito da |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 6. **time_entries** - Registrazione Tempi
Tracciamento del tempo lavorato.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `time_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `matter_id` | uuid | NO | - | Riferimento alla pratica |
| `user_id` | uuid | NO | - | Riferimento all'utente |
| `started_at` | timestamptz | NO | - | Inizio attività |
| `minutes` | integer | NO | - | Durata in minuti |
| `type` | time_type | YES | 'work' | Tipo di attività |
| `description` | text | YES | - | Descrizione |
| `rate_used` | numeric | YES | - | Tariffa utilizzata |
| `billable` | boolean | YES | true | Fatturabile |
| `created_at` | timestamptz | YES | now() | Data creazione |

### 7. **expenses** - Spese
Gestione delle spese sostenute.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `expense_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `matter_id` | uuid | YES | - | Riferimento alla pratica |
| `user_id` | uuid | NO | - | Riferimento all'utente |
| `type` | expense_type | NO | - | Tipo di spesa |
| `description` | text | NO | - | Descrizione |
| `amount` | numeric | NO | - | Importo |
| `currency` | text | YES | 'EUR' | Valuta |
| `receipt_path` | text | YES | - | Percorso ricevuta |
| `billable` | boolean | YES | true | Fatturabile |
| `billed` | boolean | YES | false | Fatturato |
| `invoice_id` | uuid | YES | - | Riferimento fattura |
| `incurred_at` | date | NO | - | Data sostenimento |
| `status` | record_status | YES | 'active' | Stato del record |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 8. **hearings** - Udienze
Gestione delle udienze e appuntamenti in tribunale.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `hearing_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `matter_id` | uuid | NO | - | Riferimento alla pratica |
| `title` | text | NO | - | Titolo udienza |
| `description` | text | YES | - | Descrizione |
| `court` | text | YES | - | Tribunale |
| `judge` | text | YES | - | Giudice |
| `courtroom` | text | YES | - | Aula |
| `scheduled_at` | timestamptz | NO | - | Data e ora programmata |
| `duration_minutes` | integer | YES | 60 | Durata in minuti |
| `notes` | text | YES | - | Note |
| `outcome` | text | YES | - | Esito |
| `status` | record_status | YES | 'active' | Stato del record |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

### 9. **invoices** - Fatture
Gestione delle fatture emesse.

| Campo | Tipo | Nullable | Default | Descrizione |
|-------|------|----------|---------|-------------|
| `invoice_id` | uuid | NO | gen_random_uuid() | Chiave primaria |
| `firm_id` | uuid | NO | - | Riferimento allo studio |
| `client_id` | uuid | NO | - | Riferimento al cliente |
| `matter_id` | uuid | YES | - | Riferimento alla pratica |
| `invoice_number` | text | NO | - | Numero fattura |
| `issue_date` | date | NO | - | Data emissione |
| `due_date` | date | YES | - | Data scadenza |
| `subtotal` | numeric | NO | 0 | Subtotale |
| `vat_amount` | numeric | NO | 0 | Importo IVA |
| `withholding_amount` | numeric | YES | 0 | Ritenuta d'acconto |
| `pension_fund_amount` | numeric | YES | 0 | Cassa previdenziale |
| `total_amount` | numeric | NO | 0 | Totale |
| `currency` | text | YES | 'EUR' | Valuta |
| `notes` | text | YES | - | Note |
| `status` | invoice_status | YES | 'draft' | Stato fattura |
| `pdf_path` | text | YES | - | Percorso PDF |
| `sent_at` | timestamptz | YES | - | Data invio |
| `created_at` | timestamptz | YES | now() | Data creazione |
| `updated_at` | timestamptz | YES | now() | Data aggiornamento |

## Enumerazioni (ENUM)

### expense_type
- `court_fee` - Spese processuali
- `postage` - Spese postali  
- `expert` - Consulenze
- `travel` - Trasferte
- `other` - Altre spese

### invoice_status
- `draft` - Bozza
- `issued` - Emessa
- `sent` - Inviata
- `paid` - Pagata
- `partially_paid` - Parzialmente pagata
- `void` - Annullata

### matter_status
- `open` - Aperta
- `on_hold` - In sospeso
- `suspended` - Sospesa
- `closed` - Chiusa

### party_role
- `client` - Cliente
- `counterparty` - Controparte
- `third_party` - Terza parte

### record_status
- `active` - Attivo
- `deleted` - Eliminato

### role_type
- `owner` - Proprietario
- `partner` - Partner
- `associate` - Associato
- `paralegal` - Paralegal
- `admin` - Amministratore
- `billing` - Fatturazione
- `guest` - Ospite

### tax_regime
- `forfettario` - Regime forfettario
- `ordinario` - Regime ordinario
- `minimi` - Minimi
- `esente` - Esente

### time_type
- `work` - Lavoro
- `meeting` - Riunione
- `hearing` - Udienza
- `travel` - Trasferta
- `admin` - Amministrativo

## Relazioni Principali

### Gerarchia Studio → Clienti → Pratiche
```
firms (1) → (N) clients (1) → (N) matters
```

### Pratiche → Attività/Tempi/Spese
```
matters (1) → (N) tasks
matters (1) → (N) time_entries  
matters (1) → (N) expenses
matters (1) → (N) hearings
```

### Fatturazione
```
clients (1) → (N) invoices (1) → (N) invoice_lines
expenses (N) → (1) invoices
```

### Utenti e Profili
```
firms (1) → (N) profiles
profiles (1) → (N) tasks (assigned_to)
profiles (1) → (N) time_entries (user_id)
```

## Indici Principali

- **matters**: `firm_id + status`, `firm_id + client_id`, `created_at`
- **time_entries**: `firm_id + billable`, `matter_id`
- **invoices**: `firm_id + issue_date`, `status`
- **tasks**: `firm_id + status`, `assigned_to + due_date`
- **hearings**: `firm_id + scheduled_at`, `matter_id`

## Note Tecniche

1. **UUID**: Tutte le chiavi primarie utilizzano UUID v4
2. **Timestamp**: Tutti i timestamp sono con timezone (timestamptz)
3. **Soft Delete**: Utilizzo del campo `status` per soft delete
4. **Audit Trail**: Campi `created_at` e `updated_at` automatici
5. **Multi-tenancy**: Isolamento dati tramite `firm_id`
6. **JSONB**: Utilizzo di JSONB per dati strutturati flessibili

## Modelli Dart Corrispondenti

| Tabella | Modello Dart | Percorso |
|---------|--------------|----------|
| `clients` | `Cliente` | `lib/features/clienti/data/models/cliente.dart` |
| `matters` | `Matter` | `lib/features/matters/data/matter_model.dart` |
| `tasks` | `Task` | `lib/features/agenda/data/models/task_model.dart` |
| `time_entries` | `TimeEntry` | `lib/features/time_tracking/data/models/time_entry_model.dart` |
| `expenses` | `Expense` | `lib/features/expenses/data/models/expense_model.dart` |
| `hearings` | `Hearing` | `lib/features/agenda/data/models/hearing_model.dart` |

---

*Documentazione generata automaticamente dal database schema - Ultimo aggiornamento: $(date)*