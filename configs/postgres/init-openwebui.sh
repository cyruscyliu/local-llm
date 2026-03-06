#!/usr/bin/env bash
set -euo pipefail

escape_ident() {
  printf '%s' "$1" | sed 's/"/""/g'
}

escape_literal() {
  printf '%s' "$1" | sed "s/'/''/g"
}

OPENWEBUI_DB_USER_IDENT="$(escape_ident "$OPENWEBUI_DB_USER")"
OPENWEBUI_DB_NAME_IDENT="$(escape_ident "$OPENWEBUI_DB_NAME")"
OPENWEBUI_DB_USER_LIT="$(escape_literal "$OPENWEBUI_DB_USER")"
OPENWEBUI_DB_NAME_LIT="$(escape_literal "$OPENWEBUI_DB_NAME")"
OPENWEBUI_DB_PASSWORD_LIT="$(escape_literal "$OPENWEBUI_DB_PASSWORD")"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${OPENWEBUI_DB_USER_LIT}') THEN
    CREATE ROLE "${OPENWEBUI_DB_USER_IDENT}" LOGIN PASSWORD '${OPENWEBUI_DB_PASSWORD_LIT}';
  END IF;
END
\$\$;
SQL

db_exists="$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc \
  "SELECT 1 FROM pg_database WHERE datname = '${OPENWEBUI_DB_NAME_LIT}'")"

if [ "$db_exists" != "1" ]; then
  createdb --username "$POSTGRES_USER" --owner "$OPENWEBUI_DB_USER_IDENT" "$OPENWEBUI_DB_NAME_IDENT"
fi
