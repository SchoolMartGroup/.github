#!/usr/bin/env bash
# Run a School Bajar Flutter mobile app with emulator-safe API URLs and a clean Gradle cache.
# Usage: ./scripts/run-mobile-app.sh partner|customer|admin [extra flutter run args...]
set -euo pipefail

APP="${1:?Usage: $0 partner|customer|admin [flutter run args...]}"
shift || true

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$ROOT/schoolbajar-${APP}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Unknown app: $APP" >&2
  exit 1
fi

# Avoid corrupted ~/.gradle caches ("Truncated class file") and RAM spikes from parallel daemons.
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/tmp/gradle-schoolbajar-$(whoami)}"
mkdir -p "$GRADLE_USER_HOME"

cd "$APP_DIR"
exec flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001 \
  "$@"
