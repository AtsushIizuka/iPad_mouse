#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

resolve_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then
    command -v xcodegen
    return
  fi

  local vendored_bin="$ROOT_DIR/.tools/XcodeGen/.build/arm64-apple-macosx/debug/xcodegen"
  if [[ -x "$vendored_bin" ]]; then
    echo "$vendored_bin"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "Installing XcodeGen with Homebrew..."
    brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
    command -v xcodegen
    return
  fi

  echo "XcodeGen was not found. Install it with Homebrew or add it to PATH." >&2
  exit 1
}

require_command xcodebuild
require_command xcrun

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
fi

if [[ -n "${PADTRACK_DEVELOPMENT_TEAM:-}" ]]; then
  "$ROOT_DIR/scripts/set_team.sh" "$PADTRACK_DEVELOPMENT_TEAM"
fi

XCODEGEN_BIN="$(resolve_xcodegen)"

cd "$ROOT_DIR"

echo "Using XcodeGen: $XCODEGEN_BIN"
"$XCODEGEN_BIN" generate --spec "$ROOT_DIR/project.yml"

echo "Running shared tests..."
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift test

if [[ "${PADTRACK_NO_OPEN:-0}" != "1" ]]; then
  open "$ROOT_DIR/iPadMouse.xcodeproj"
fi

cat <<EOF
Bootstrap complete.

Next steps:
  1. Run ./scripts/run_mac_host.sh
  2. Install the iPad app with ./scripts/install_padtrack.sh DEVICE_ID
  3. Follow docs/SETUP_ON_ANOTHER_MAC.md for permissions
EOF
