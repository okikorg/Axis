#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Axis"
DIST_DIR="$ROOT_DIR/dist"

cd "$ROOT_DIR"

echo "Building $APP_NAME (release)..."
swift package clean
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
APP_DIR="$DIST_DIR/$APP_NAME.app"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "Build output not found at $BIN_PATH"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "App bundle created at: $APP_DIR"
