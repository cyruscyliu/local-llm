#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v openwebui_user="$OPENWEBUI_DB_USER" \
  -v openwebui_pass="$OPENWEBUI_DB_PASSWORD" \
  -v openwebui_db="$OPENWEBUI_DB_NAME" <<'SQL'
DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'openwebui_user') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', :'openwebui_user', :'openwebui_pass');
  END IF;
END
$do$;

DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'openwebui_db') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I', :'openwebui_db', :'openwebui_user');
  END IF;
END
$do$;
SQL
