-- Schemi non di sistema
select nspname as schema
from pg_namespace
where nspname not in ('pg_catalog','information_schema')
order by 1;

-- Tabelle dello schema public
select table_name
from information_schema.tables
where table_schema='public' and table_type='BASE TABLE'
order by 1;

-- Colonne per ogni tabella
select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema='public'
order by table_name, ordinal_position;

-- Foreign Keys
select
  tc.table_name as table,
  kcu.column_name as column,
  ccu.table_name as ref_table,
  ccu.column_name as ref_column,
  rc.update_rule||'/'||rc.delete_rule as on_update_delete
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name=kcu.constraint_name and tc.table_schema=kcu.table_schema
join information_schema.referential_constraints rc
  on tc.constraint_name=rc.constraint_name and tc.table_schema=rc.constraint_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name=rc.constraint_name and ccu.constraint_schema=rc.constraint_schema
where tc.constraint_type='FOREIGN KEY' and tc.table_schema='public'
order by table, column;

-- Indici
select
  t.relname as table,
  i.relname as index,
  pg_get_indexdef(ix.indexrelid) as definition
from pg_class t
join pg_index ix on t.oid=ix.indrelid
join pg_class i on ix.indexrelid=i.oid
join pg_namespace n on n.oid=t.relnamespace
where n.nspname='public'
order by t.relname, i.relname;

-- Tabelle con RLS attiva
select n.nspname as schema, c.relname as table, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and c.relrowsecurity
order by 1,2;
