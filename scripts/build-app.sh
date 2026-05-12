#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AI Usage Widget"
APP_DIR="$ROOT/build/$APP_NAME.app"
BIN_NAME="ai-usage-widget"
EXTENSION_NAME="AIUsageWidgetExtension"
EXTENSION_DIR="$APP_DIR/Contents/PlugIns/$EXTENSION_NAME.appex"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP_ENTITLEMENTS="$ROOT/Resources/AIUsageWidgetApp.entitlements"
EXTENSION_ENTITLEMENTS="$ROOT/Resources/AIUsageWidgetExtension.entitlements"

cd "$ROOT"

mkdir -p "$ROOT/build-bin" "$ROOT/.build-cache/clang"
env CLANG_MODULE_CACHE_PATH="$ROOT/.build-cache/clang" \
  swiftc \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  -sdk "$SDK_PATH" \
  -framework SwiftUI \
  -framework WebKit \
  -framework AppKit \
  -framework Combine \
  -framework WidgetKit \
  -o "$ROOT/build-bin/$BIN_NAME" \
  "$ROOT/Sources/Shared/WidgetUsageSnapshotStore.swift" \
  "$ROOT/Sources/UsageWidget/UsageWidgetApp.swift"

env CLANG_MODULE_CACHE_PATH="$ROOT/.build-cache/clang" \
  swiftc \
  -parse-as-library \
  -application-extension \
  -target arm64-apple-macosx14.0 \
  -sdk "$SDK_PATH" \
  -framework SwiftUI \
  -framework WidgetKit \
  -o "$ROOT/build-bin/$EXTENSION_NAME" \
  "$ROOT/Sources/Shared/WidgetUsageSnapshotStore.swift" \
  "$ROOT/Sources/UsageWidgetExtension/AIUsageWidgetExtension.swift"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$EXTENSION_DIR/Contents/MacOS"

cp "$ROOT/build-bin/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$BIN_NAME"

cp "$ROOT/build-bin/$EXTENSION_NAME" "$EXTENSION_DIR/Contents/MacOS/$EXTENSION_NAME"
chmod +x "$EXTENSION_DIR/Contents/MacOS/$EXTENSION_NAME"

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

cat > "$EXTENSION_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXTENSION_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.peter.ai-usage-widget.widget</string>
  <key>CFBundleName</key>
  <string>$EXTENSION_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>AI Usage</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
PLIST

codesign --force --sign - --entitlements "$EXTENSION_ENTITLEMENTS" "$EXTENSION_DIR"
codesign --force --sign - --entitlements "$APP_ENTITLEMENTS" "$APP_DIR"

echo "$APP_DIR"
