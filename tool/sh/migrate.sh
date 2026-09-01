#!/usr/bin/env sh
set -eu
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$script_directory/_compose.sh" up --detach --wait postgres
exec sh "$script_directory/_compose.sh" --profile app run --rm --no-deps --build server migrate
