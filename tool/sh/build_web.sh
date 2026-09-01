#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../../linkso_client"
config_file=.env.example
if [ -f .env ]; then config_file=.env; fi
exec flutter build web --release --wasm --no-web-resources-cdn --dart-define-from-file="$config_file" "$@"
