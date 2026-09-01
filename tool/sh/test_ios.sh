#!/usr/bin/env sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
device=${1:?Usage: sh tool/sh/test_ios.sh <simulator-or-device-id> [host] [flutter test arguments...]}
host=${2:-127.0.0.1}
api_port=${LINKSO_ACCEPTANCE_API_PORT:-8080}
web_port=${LINKSO_ACCEPTANCE_WEB_PORT:-8088}
mailpit_port=${LINKSO_ACCEPTANCE_MAILPIT_PORT:-8025}
shift
if [ "$#" -gt 0 ]; then shift; fi

cd "$script_directory/../../linkso_client"
flutter test integration_test/native_acceptance_test.dart integration_test/native_qr_share_test.dart -d "$device" \
  --dart-define="API_BASE_URL=http://$host:$api_port" \
  --dart-define="ACCEPTANCE_WEB_BASE_URL=http://$host:$web_port" \
  --dart-define="ACCEPTANCE_MAILPIT_BASE_URL=http://$host:$mailpit_port" \
  --dart-define=ALLOW_LOCAL_ACCEPTANCE=true --reporter expanded "$@"
