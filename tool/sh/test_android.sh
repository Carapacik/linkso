#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
device=${1:-emulator-5554}
if [ "$#" -gt 0 ]; then shift; fi

# ADB reconnects can remove reverse rules; reapply them before every run.
for port in 8080 8088 8025; do
  adb -s "$device" reverse "tcp:$port" "tcp:$port"
done

cd "$script_directory/../../linkso_client"
flutter test integration_test/native_acceptance_test.dart -d "$device" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=ALLOW_LOCAL_ACCEPTANCE=true --reporter expanded "$@"
