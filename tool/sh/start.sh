#!/usr/bin/env sh
set -eu
exec sh "$(dirname "$0")/_compose.sh" --profile app up --detach --build --wait
