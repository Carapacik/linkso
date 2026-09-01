#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
backup_dir="${1:-${LINKSO_BACKUP_DIR:-}}"
if [ -z "$backup_dir" ]; then
  echo 'Usage: sh tool/sh/backup_database.sh absolute-output-directory' >&2
  echo 'Or set LINKSO_BACKUP_DIR. Store backups outside the repository.' >&2
  exit 2
fi
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
backup_path="$backup_dir/linkso_$(date -u +%Y%m%d_%H%M%S).dump"

cleanup_failed() {
  rm -f "$backup_path"
}
trap cleanup_failed EXIT HUP INT TERM

echo "==> Creating PostgreSQL backup $backup_path"
sh "$script_directory/_compose.sh" exec -T postgres sh -ceu 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' >"$backup_path"

if [ ! -s "$backup_path" ]; then
  cleanup_failed
  echo "Backup is empty." >&2
  exit 1
fi
chmod 600 "$backup_path"
trap - EXIT HUP INT TERM
echo "Backup created: $backup_path"
