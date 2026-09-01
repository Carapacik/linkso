#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_directory/../../linkso_server"

echo '==> Cargo format check'
cargo fmt --check

echo '==> Cargo clippy'
cargo clippy --all-targets --all-features -- -D warnings

echo '==> Cargo tests'
cargo test

echo 'Server checks passed.'
