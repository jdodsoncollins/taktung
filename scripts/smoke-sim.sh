#!/bin/zsh
set -euo pipefail
# Build and launch Taktung on the iPhone 17 Pro Max (iOS 27) simulator.
# Pass TAKT_DEMO_MODE=1 (default) or TAKT_UI_TOKEN for a live PAT smoke.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${UDID:-A9B54D96-8995-43FD-AF0C-A1EFFB1393CC}"
SCHEME="${SCHEME:-Taktung}"
DEST="platform=iOS Simulator,id=${UDID}"

cd "$ROOT"
xcrun simctl boot "$UDID" 2>/dev/null || true

xcodebuild \
  -project Taktung.xcodeproj \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -derivedDataPath "$ROOT/build/DerivedData" \
  -configuration Debug \
  build

APP=$(find "$ROOT/build/DerivedData/Build/Products" -name Taktung.app -maxdepth 4 | head -n 1)
if [[ -z "$APP" ]]; then
  echo "Taktung.app not found" >&2
  exit 1
fi

xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" com.jcollins.takt 2>/dev/null || true

ARGS=()
if [[ "${TAKT_DEMO_MODE:-1}" == "1" ]]; then
  ARGS+=(-TAKT_DEMO_MODE)
fi
if [[ -n "${TAKT_UI_TOKEN:-}" ]]; then
  xcrun simctl launch --terminate-running-process "$UDID" com.jcollins.takt "${ARGS[@]}"
else
  xcrun simctl launch --terminate-running-process "$UDID" com.jcollins.takt "${ARGS[@]}"
fi

echo "Launched com.jcollins.takt on $UDID"
