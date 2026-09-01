#!/usr/bin/env sh
set -eu
exec sh "$(dirname "$0")/_compose.sh" --profile mail up --detach --wait mailpit
