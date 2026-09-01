#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_directory/../../linkso_client"

echo '==> Dart format check'
if [ -d test ]; then
  dart format --output=none --set-exit-if-changed lib test
else
  dart format --output=none --set-exit-if-changed lib
fi

echo '==> Flutter analyze'
flutter analyze

echo '==> Flutter tests'
if [ -d test ] && find test -type f -name '*_test.dart' -print -quit | grep -q .; then
  flutter test
else
  echo 'Skipped: no Flutter tests yet.'
fi

echo 'Client checks passed.'
