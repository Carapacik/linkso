#!/usr/bin/env sh
set -eu
if [ "$#" -lt 1 ]; then
  echo "Usage: sh tool/sh/load_test_redirect.sh http://127.0.0.1:8080/Slug [requests] [concurrency] [max_p95_ms]" >&2
  exit 2
fi
cd "$(dirname "$0")/../.."
exec cargo run --quiet --manifest-path linkso_server/Cargo.toml --bin redirect_load -- "$@"
