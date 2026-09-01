#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH= cd -- "$script_directory/../.." && pwd)
test_database=linkso_test

cd "$repository_directory"

echo '==> Starting PostgreSQL'
docker compose up -d --wait postgres

database_user=$(docker compose exec -T postgres printenv POSTGRES_USER)
if [ -z "$database_user" ]; then
  echo 'Failed to read POSTGRES_USER from the PostgreSQL container.' >&2
  exit 1
fi

echo "==> Preparing test database $test_database"
docker compose exec -T postgres psql \
  -v ON_ERROR_STOP=1 \
  -v "test_database=$test_database" \
  -v "database_user=$database_user" \
  -U "$database_user" \
  -d postgres < "$script_directory/../sql/prepare_test_database.sql"

docker compose exec -T postgres psql \
  -v ON_ERROR_STOP=1 \
  -U "$database_user" \
  -d "$test_database" \
  -c 'SELECT current_database(), current_user;'

if [ ! -f "$repository_directory/linkso_server/.env.test" ]; then
  cp \
    "$repository_directory/linkso_server/.env.test.example" \
    "$repository_directory/linkso_server/.env.test"
fi

echo "Test database $test_database is ready."
