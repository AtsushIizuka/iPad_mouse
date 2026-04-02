#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED_DATA_DIR="$ROOT_DIR/.xcodebuild/DerivedData"
DEVICE_ID="${1:-}"
SHOULD_LAUNCH="${2:-}"

if [[ -z "$DEVICE_ID" ]]; then
  cat <<EOF >&2
Usage: ./scripts/install_padtrack.sh DEVICE_ID [--launch]

Find device IDs with:
  xcrun devicectl list devices
EOF
  exit 1
fi

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  -project "$ROOT_DIR/iPadMouse.xcodeproj" \
  -scheme PadTrack \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build install

if [[ "$SHOULD_LAUNCH" == "--launch" ]]; then
  DEVELOPER_DIR="$DEVELOPER_DIR" xcrun devicectl device process launch \
    --device "$DEVICE_ID" \
    com.atsushi.PadTrack || true
fi

echo "PadTrack installed for device:"
echo "  $DEVICE_ID"
