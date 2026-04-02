#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED_DATA_DIR="$ROOT_DIR/.xcodebuild/DerivedData"
APP_SOURCE="$DERIVED_DATA_DIR/Build/Products/Debug/MacPointerHost.app"
APP_TARGET="$HOME/Applications/MacPointerHost.app"

mkdir -p "$HOME/Applications"

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  -project "$ROOT_DIR/iPadMouse.xcodeproj" \
  -scheme MacPointerHost \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

rm -rf "$APP_TARGET"
ditto "$APP_SOURCE" "$APP_TARGET"
(osascript -e 'tell application "MacPointerHost" to quit' >/dev/null 2>&1 || true)
open "$APP_TARGET"

echo "MacPointerHost is running from:"
echo "  $APP_TARGET"
