#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../.."
if [ -n "${LINKSO_ENV_FILE:-}" ]; then
  exec docker compose --env-file "$LINKSO_ENV_FILE" -f "${LINKSO_COMPOSE_FILE:-docker-compose.yaml}" "$@"
fi
exec docker compose -f "${LINKSO_COMPOSE_FILE:-docker-compose.yaml}" "$@"
