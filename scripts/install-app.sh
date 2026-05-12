#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AI Usage Widget"
BUILT_APP="$ROOT/build/$APP_NAME.app"
INSTALLED_APP="/Applications/$APP_NAME.app"
EXTENSION_PATH="$INSTALLED_APP/Contents/PlugIns/AIUsageWidgetExtension.appex"

"$ROOT/scripts/build-app.sh" >/dev/null

pkill -f "$INSTALLED_APP/Contents/MacOS/ai-usage-widget" 2>/dev/null || true
pluginkit -r "$EXTENSION_PATH" 2>/dev/null || true
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALLED_APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED_APP"
pluginkit -a "$EXTENSION_PATH"

open -n "$INSTALLED_APP"
echo "$INSTALLED_APP"
