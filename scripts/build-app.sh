#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AI Usage Widget"
APP_DIR="$ROOT/build/$APP_NAME.app"
BIN_NAME="ai-usage-widget"
EXTENSION_NAME="AIUsageWidgetExtension"
EXTENSION_DIR="$APP_DIR/Contents/PlugIns/$EXTENSION_NAME.appex"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
HOST_ARCH="$(uname -m)"
SWIFT_TARGET="${SWIFT_TARGET:-$HOST_ARCH-apple-macosx14.0}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-local.peter.ai-usage-widget}"
EXTENSION_BUNDLE_ID="${EXTENSION_BUNDLE_ID:-$APP_BUNDLE_ID.widget}"
APP_GROUP_ID="${APP_GROUP_ID:-${DEVELOPMENT_TEAM:-}.ai-usage-widget}"
if [[ "$APP_GROUP_ID" == ".ai-usage-widget" ]]; then
  APP_GROUP_ID="group.local.peter.ai-usage-widget"
fi
TIP_SWIFT_FLAGS=()
SHOW_TIP_LINK="${AI_USAGE_WIDGET_SHOW_TIP_LINK:-${AI_USAGE_WIDGET_SHOW_SUPPORT_LINK:-1}}"
if [[ "$SHOW_TIP_LINK" != "0" ]]; then
  TIP_SWIFT_FLAGS=(-D AI_USAGE_WIDGET_SHOW_TIP_LINK)
fi
ENTITLEMENTS_DIR="$ROOT/build/entitlements"
APP_ENTITLEMENTS="$ENTITLEMENTS_DIR/AIUsageWidgetApp.entitlements"
EXTENSION_ENTITLEMENTS="$ENTITLEMENTS_DIR/AIUsageWidgetExtension.entitlements"

cd "$ROOT"

mkdir -p "$ROOT/build-bin" "$ROOT/.build-cache/clang" "$ENTITLEMENTS_DIR"
env CLANG_MODULE_CACHE_PATH="$ROOT/.build-cache/clang" \
  swiftc \
  -parse-as-library \
  -target "$SWIFT_TARGET" \
  -sdk "$SDK_PATH" \
  -framework SwiftUI \
  -framework WebKit \
  -framework AppKit \
  -framework Combine \
  -framework WidgetKit \
  ${TIP_SWIFT_FLAGS[@]+"${TIP_SWIFT_FLAGS[@]}"} \
  -o "$ROOT/build-bin/$BIN_NAME" \
  "$ROOT/Sources/Shared/WidgetUsageSnapshotStore.swift" \
  "$ROOT/Sources/UsageWidget/UsageWidgetApp.swift"

env CLANG_MODULE_CACHE_PATH="$ROOT/.build-cache/clang" \
  swiftc \
  -parse-as-library \
  -application-extension \
  -target "$SWIFT_TARGET" \
  -sdk "$SDK_PATH" \
  -framework SwiftUI \
  -framework WidgetKit \
  -o "$ROOT/build-bin/$EXTENSION_NAME" \
  "$ROOT/Sources/Shared/WidgetUsageSnapshotStore.swift" \
  "$ROOT/Sources/UsageWidgetExtension/AIUsageWidgetExtension.swift"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$EXTENSION_DIR/Contents/MacOS"

cp "$ROOT/build-bin/$BIN_NAME" "$APP_DIR/Contents/MacOS/$BIN_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$BIN_NAME"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

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
  <string>$APP_BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$CURRENT_PROJECT_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSUIElement</key>
  <true/>
  <key>AIUsageWidgetAppGroupIdentifier</key>
  <string>$APP_GROUP_ID</string>
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
  <string>$EXTENSION_BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$EXTENSION_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>AI Usage</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$CURRENT_PROJECT_VERSION</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>AIUsageWidgetAppGroupIdentifier</key>
  <string>$APP_GROUP_ID</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
PLIST

cat > "$APP_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>$APP_GROUP_ID</string>
  </array>
</dict>
</plist>
PLIST

cat > "$EXTENSION_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>$APP_GROUP_ID</string>
  </array>
</dict>
</plist>
PLIST

codesign --force --sign "$SIGN_IDENTITY" --entitlements "$EXTENSION_ENTITLEMENTS" "$EXTENSION_DIR"
codesign --force --sign "$SIGN_IDENTITY" --entitlements "$APP_ENTITLEMENTS" "$APP_DIR"

echo "$APP_DIR"
