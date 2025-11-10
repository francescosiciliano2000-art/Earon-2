-- Migration: add 'type' column to tasks with CHECK constraint and default
-- Purpose: support UI field "Tipo" with values 'onere' or 'scrivere'
-- Safe to run once in production.

BEGIN;

-- 1) Add column if missing
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS type TEXT;

-- 2) Set default to 'onere' (UI default)
ALTER TABLE public.tasks
  ALTER COLUMN type SET DEFAULT 'onere';

-- 3) Add CHECK constraint to allow only accepted values (or NULL)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tasks_type_check'
      AND conrelid = 'public.tasks'::regclass
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_type_check
      CHECK (type IN ('onere', 'scrivere') OR type IS NULL);
  END IF;
END$$;

-- 4) Optional backfill: set missing values to default
UPDATE public.tasks SET type = COALESCE(type, 'onere') WHERE type IS NULL;

-- 5) Documentation
COMMENT ON COLUMN public.tasks.type IS 'Tipo attività: onere/scrivere';

COMMIT;