#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Axis"
DIST_DIR="$ROOT_DIR/dist"
RUN_AFTER_BUILD=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --run) RUN_AFTER_BUILD=true ;;
    --dmg) CREATE_DMG=true ;;
  esac
done

cd "$ROOT_DIR"

# --- Determine version ---
if [[ -n "${AXIS_VERSION:-}" ]]; then
  VERSION="$AXIS_VERSION"
elif git describe --tags --abbrev=0 &>/dev/null; then
  VERSION="$(git describe --tags --abbrev=0 | sed 's/^v//')"
else
  VERSION="dev"
fi
echo "Version: $VERSION"

# --- Clean ---
echo "Cleaning build cache..."
swift package clean
rm -rf .build/release

# --- Build ---
echo "Building $APP_NAME (release)..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
BUNDLE_PATH="$BIN_DIR/Axis_AxisCore.bundle"
APP_DIR="$DIST_DIR/$APP_NAME.app"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "Error: Build output not found at $BIN_PATH"
  exit 1
fi

# --- Assemble .app bundle ---
echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

# Executable
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Info.plist
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Stamp version into plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_DIR/Contents/Info.plist"

# App icon
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  echo "  Copied AppIcon.icns"
else
  echo "  Warning: AppIcon.icns not found - run 'swift scripts/generate_icon.swift' first"
fi

# Font bundle (SPM resource bundle)
if [[ -d "$BUNDLE_PATH" ]]; then
  cp -R "$BUNDLE_PATH" "$APP_DIR/Contents/Resources/Axis_AxisCore.bundle"
  echo "  Copied Axis_AxisCore.bundle (fonts)"
else
  echo "  Warning: Font bundle not found at $BUNDLE_PATH"
fi

# --- Code signing ---
echo "Code signing..."
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$SIGN_IDENTITY" \
  --entitlements "$ROOT_DIR/Resources/Axis.entitlements" \
  --options runtime \
  "$APP_DIR"
echo "  Signed with identity: $SIGN_IDENTITY"

echo ""
echo "App bundle created at: $APP_DIR"

# --- Optional DMG ---
if [[ "${CREATE_DMG:-false}" == "true" ]]; then
  DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
  echo "Creating DMG..."
  rm -f "$DMG_PATH"
  hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"
  echo "DMG created at: $DMG_PATH"
fi

# --- Optional run ---
if [[ "$RUN_AFTER_BUILD" == "true" ]]; then
  echo "Launching $APP_NAME..."
  open "$APP_DIR"
fi
