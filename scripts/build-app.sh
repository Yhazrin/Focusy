#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release

APP_DIR="$ROOT/.build/release/Focus Capsule.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
mkdir -p "$MACOS_DIR"

cp "$ROOT/.build/release/FocusCapsule" "$MACOS_DIR/FocusCapsule"
cp "$ROOT/.build/release/focuscapsule-bridge" "$MACOS_DIR/focuscapsule-bridge"
chmod +x "$MACOS_DIR/FocusCapsule" "$MACOS_DIR/focuscapsule-bridge"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>FocusCapsule</string>
  <key>CFBundleIdentifier</key>
  <string>app.focuscapsule.FocusCapsule</string>
  <key>CFBundleName</key>
  <string>Focus Capsule</string>
  <key>CFBundleDisplayName</key>
  <string>Focus Capsule</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Focus Capsule reads browser tab metadata and activates apps for quick jump actions.</string>
  <key>NSSystemAdministrationUsageDescription</key>
  <string>Focus Capsule installs optional local CLI hooks for Claude, Codex, and Cursor.</string>
</dict>
</plist>
PLIST

echo "$APP_DIR"
