#!/usr/bin/env bash
# Repair corrupted Gradle state and build a School Bajar Flutter Android app.
# Usage: ./scripts/repair-android-build.sh partner|customer|admin
#
# Builds one app at a time to avoid exhausting RAM (do not run multiple in parallel).
set -euo pipefail

APP="${1:-partner}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT/schoolbajar-${APP}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Unknown app: $APP" >&2
  exit 1
fi

echo "==> Repairing Android build for schoolbajar-${APP}"

# Stop Gradle daemons that may hold corrupted locks.
if [[ -x "$APP_DIR/android/gradlew" ]]; then
  (cd "$APP_DIR/android" && ./gradlew --stop) || true
fi
pkill -f 'GradleDaemon' 2>/dev/null || true

# Clear project-local Gradle/Flutter build output only.
rm -rf \
  "$APP_DIR/android/.gradle" \
  "$APP_DIR/build" \
  "$APP_DIR/.dart_tool"

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/tmp/gradle-schoolbajar-$(whoami)}"
mkdir -p "$GRADLE_USER_HOME"
echo "==> Using GRADLE_USER_HOME=$GRADLE_USER_HOME"

cd "$APP_DIR"
flutter pub get
flutter build apk --debug

echo "==> Build OK: $APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
echo "==> Run on emulator: ./scripts/run-mobile-app.sh $APP"
