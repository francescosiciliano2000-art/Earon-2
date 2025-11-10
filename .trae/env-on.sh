#!/usr/bin/env bash
# Carica automaticamente le variabili del file .env
set -a
source .env
set +a
echo "✅ Environment loaded (SUPABASE_DB_URL disponibile)"
