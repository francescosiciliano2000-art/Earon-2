# Schema Differences Report

**Data generazione:** $(date)  
**Versione schema:** Corrente (da Supabase)

## 📋 Sommario

Durante l'analisi dello schema del database e l'allineamento dei modelli Dart, sono state identificate diverse discrepanze e sono state apportate le seguenti modifiche:

## 🔧 Modifiche Apportate

### 1. Modello `Cliente` - Allineamento con tabella `clients`

**File:** `lib/features/clienti/data/cliente.dart`

#### Campi Rimossi (non presenti nel DB):
- `kind` - Campo non presente nella tabella `clients`
- `surname` - Campo non presente nella tabella `clients` 
- `province` - Campo non presente nella tabella `clients`
- `tags` - Campo non presente nella tabella `clients`

#### Campi Rinominati:
- `zip` → `postalCode` (per allinearsi a `postal_code` nel DB)
- `billingNotes` → `notes` (per allinearsi a `notes` nel DB)

#### Costanti Colonna Aggiornate:
- Rimosso: `colKind`, `colSurname`, `colProvince`, `colZip`, `colTags`
- Aggiunto: `colPostalCode` 
- Mantenuto: `colNotes` (già esistente)

### 2. Nuovi Modelli Dart Creati

#### TimeEntry Model
**File:** `lib/features/time_tracking/data/models/time_entry_model.dart`
- Creato modello completo per tabella `time_entries`
- Include tutti i campi: `timeId`, `firmId`, `matterId`, `userId`, `startedAt`, `minutes`, `type`, `description`, `rateUsed`, `billable`, `createdAt`
- Metodi: `fromJson`, `toInsertJson`, `toUpdateJson`, `copyWith`

#### Expense Model  
**File:** `lib/features/expenses/data/models/expense_model.dart`
- Creato modello completo per tabella `expenses`
- Include tutti i campi: `expenseId`, `firmId`, `matterId`, `userId`, `type`, `description`, `amount`, `currency`, `receiptPath`, `billable`, `billed`, `invoiceId`, `incurredAt`, `status`, `createdAt`, `updatedAt`
- Metodi: `fromJson`, `toInsertJson`, `toUpdateJson`, `copyWith`

#### Hearing Model
**File:** `lib/features/agenda/data/models/hearing_model.dart`  
- Creato modello completo per tabella `hearings`
- Include tutti i campi: `hearingId`, `firmId`, `matterId`, `title`, `description`, `court`, `judge`, `courtroom`, `scheduledAt`, `durationMinutes`, `notes`, `outcome`, `status`, `createdAt`, `updatedAt`
- Metodi: `fromJson`, `toInsertJson`, `toUpdateJson`, `copyWith`

### 3. Documentazione Aggiornata

**File:** `docs/database.md`
- Creata documentazione completa dello schema database
- Mappatura tabelle → modelli Dart
- Descrizione relazioni e indici principali
- Note tecniche su RLS e sicurezza

## 🔍 Tabelle Analizzate

### ✅ Con Modelli Dart Esistenti/Creati:
- `matters` → `MatterModel` (esistente)
- `tasks` → `TaskModel` (esistente) 
- `clients` → `Cliente` (aggiornato)
- `time_entries` → `TimeEntry` (creato)
- `expenses` → `Expense` (creato)
- `hearings` → `Hearing` (creato)

### ⚠️ Senza Modelli Dart (da valutare):
- `firms` - Tabella principale per studi legali
- `profiles` - Profili utente collegati ad auth
- `invoices` - Fatturazione
- `invoice_lines` - Righe fattura
- `parties` - Parti processuali
- `documents` - Documenti allegati
- `contacts` - Contatti
- `audit_log` - Log di audit
- `notifications` - Notifiche
- `mailboxes` - Caselle email
- `matter_parties` - Relazione many-to-many
- `payments` - Pagamenti

## 🎯 Raccomandazioni

### Priorità Alta:
1. **Firms Model** - Fondamentale per multi-tenancy
2. **Profiles Model** - Gestione utenti e permessi
3. **Invoices Model** - Core business per fatturazione

### Priorità Media:
4. **Documents Model** - Gestione allegati
5. **Parties Model** - Gestione parti processuali
6. **Contacts Model** - Rubrica contatti

### Priorità Bassa:
7. **Audit Log Model** - Solo se serve tracciamento avanzato
8. **Notifications Model** - Sistema notifiche
9. **Payments Model** - Se serve gestione pagamenti avanzata

## 🔧 Convenzioni Applicate

### Naming:
- **Database:** `snake_case` (es. `postal_code`, `created_at`)
- **Dart:** `camelCase` (es. `postalCode`, `createdAt`)

### Struttura Modelli:
- Tutti i modelli includono metodi standard: `fromJson`, `toInsertJson`, `toUpdateJson`, `copyWith`
- Costanti per nomi colonne (es. `static const colClientId = 'client_id'`)
- Gestione corretta dei tipi nullable/non-nullable
- Conversioni DateTime appropriate per Supabase

### Sicurezza:
- Nessuna esposizione di credenziali o URL completi
- Uso esclusivo di `$SUPABASE_DB_URL` per connessioni
- Query read-only per introspezione

## 📊 Statistiche

- **Tabelle totali nel DB:** 15
- **Modelli Dart esistenti:** 2 (matters, tasks)
- **Modelli Dart aggiornati:** 1 (clients)
- **Modelli Dart creati:** 3 (time_entries, expenses, hearings)
- **Modelli Dart mancanti:** 9
- **Copertura attuale:** 40% (6/15)

---

*Report generato automaticamente durante l'analisi dello schema database e l'allineamento dei modelli Dart.*