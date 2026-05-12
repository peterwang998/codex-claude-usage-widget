#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AI Usage Widget"
APP_DIR="$ROOT/build/$APP_NAME.app"
BIN_NAME="ai-usage-widget"

cd "$ROOT"

mkdir -p "$ROOT/build-bin" "$ROOT/.build-cache/clang"
env CLANG_MODULE_CACHE_PATH="$ROOT/.build-cache/clang" \
  swiftc \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework WebKit \
  -framework AppKit \
  -framework Combine \
  -o "$ROOT/build-bin/$BIN_NAME" \
  "$ROOT/Sources/UsageWidget/main.swift"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

cp "$ROOT/build-bin/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$BIN_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$BIN_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.peter.ai-usage-widget</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
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
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
  </dict>
</dict>
</plist>
PLIST

echo "$APP_DIR"
