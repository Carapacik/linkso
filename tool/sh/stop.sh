#!/usr/bin/env sh
set -eu
# Stop containers without deleting containers or database volumes.
exec sh "$(dirname "$0")/_compose.sh" --profile app stop
