#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../.."
node tool/brand/generate.cjs "$@"
dart format linkso_client/lib/src/core/widgets/linkso_logo_paths.g.dart
