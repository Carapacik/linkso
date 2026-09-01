#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sh "$script_directory/prepare_test_database.sh"

cd "$script_directory/../../linkso_server"

echo '==> Database integration tests'
cargo test --test database_health -- --ignored --test-threads=1

echo 'Server integration tests passed.'
