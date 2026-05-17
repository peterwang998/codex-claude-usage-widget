#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AI Usage Widget"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILT_APP="$("$ROOT/scripts/build-xcode-app.sh" | tail -n 1)"
INSTALLED_APP="/Applications/$APP_NAME.app"
EXTENSION_PATH="$INSTALLED_APP/Contents/PlugIns/AIUsageWidgetExtension.appex"
BUILT_EXTENSION_PATH="$BUILT_APP/Contents/PlugIns/AIUsageWidgetExtension.appex"
EXTENSION_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILT_EXTENSION_PATH/Contents/Info.plist")"

pkill -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
pkill -f "$INSTALLED_APP/Contents/MacOS/ai-usage-widget" 2>/dev/null || true
pluginkit -r "$EXTENSION_PATH" 2>/dev/null || true
pluginkit -r "$BUILT_EXTENSION_PATH" 2>/dev/null || true
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALLED_APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$INSTALLED_APP"
pluginkit -a "$EXTENSION_PATH"
pluginkit -e use -i "$EXTENSION_BUNDLE_ID"

open -n "$INSTALLED_APP"
echo "$INSTALLED_APP"
