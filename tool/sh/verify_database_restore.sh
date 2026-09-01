#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "Usage: sh tool/sh/verify_database_restore.sh path/to/backup.dump" >&2
  exit 2
fi
backup_path="$1"
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

compose() {
  sh "$script_directory/_compose.sh" "$@"
}
cleanup() {
  compose exec -T postgres sh -ceu 'dropdb -U "$POSTGRES_USER" --if-exists linkso_restore_test' >/dev/null
}
trap cleanup EXIT HUP INT TERM

echo "==> Restoring into isolated database linkso_restore_test"
compose exec -T postgres sh -ceu 'dropdb --if-exists -U "$POSTGRES_USER" linkso_restore_test; createdb -U "$POSTGRES_USER" linkso_restore_test'
compose exec -T postgres sh -ceu 'pg_restore -U "$POSTGRES_USER" -d linkso_restore_test --no-owner --no-privileges' <"$backup_path"
compose exec -T postgres sh -ceu 'source_count=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT COUNT(*) FROM _sqlx_migrations WHERE success"); restored_count=$(psql -U "$POSTGRES_USER" -d linkso_restore_test -Atc "SELECT COUNT(*) FROM _sqlx_migrations WHERE success"); test "$source_count" = "$restored_count"; psql -U "$POSTGRES_USER" -d linkso_restore_test -Atc "SELECT current_database(), COUNT(*) FROM links GROUP BY current_database()"'
echo "Restore verification passed."
