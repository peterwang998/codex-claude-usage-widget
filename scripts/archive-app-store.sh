#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/AIUsageWidget-AppStore.xcarchive}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.peterwang.aiusagewidget}"
EXTENSION_BUNDLE_ID="${EXTENSION_BUNDLE_ID:-$APP_BUNDLE_ID.widget}"
APP_GROUP_ID="${APP_GROUP_ID:-group.$APP_BUNDLE_ID}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
SHOW_TIP_LINK="${AI_USAGE_WIDGET_SHOW_TIP_LINK:-1}"

if [[ -z "$DEVELOPMENT_TEAM" ]]; then
  echo "DEVELOPMENT_TEAM is required for App Store archiving." >&2
  echo "Example: DEVELOPMENT_TEAM=TEAMID ./scripts/archive-app-store.sh" >&2
  exit 1
fi

if [[ "$APP_GROUP_ID" != group.* ]]; then
  echo "APP_GROUP_ID should use a registered group.* identifier for App Store builds." >&2
  echo "Current APP_GROUP_ID: $APP_GROUP_ID" >&2
  exit 1
fi

if [[ "$SHOW_TIP_LINK" == "0" ]]; then
  TIP_LINK_SWIFT_FLAG=""
else
  TIP_LINK_SWIFT_FLAG="-D AI_USAGE_WIDGET_SHOW_TIP_LINK"
fi

echo "Archiving AI Usage Widget for App Store Connect"
echo "  App bundle ID:       $APP_BUNDLE_ID"
echo "  Extension bundle ID: $EXTENSION_BUNDLE_ID"
echo "  App group ID:        $APP_GROUP_ID"
echo "  Tip link enabled:    $SHOW_TIP_LINK"
xcodebuild_args=(
  -project "$ROOT/AIUsageWidget.xcodeproj" \
  -scheme AIUsageWidget \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  AI_USAGE_WIDGET_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
  AI_USAGE_WIDGET_EXTENSION_BUNDLE_ID="$EXTENSION_BUNDLE_ID" \
  AI_USAGE_WIDGET_APP_GROUP_ID="$APP_GROUP_ID" \
  AI_USAGE_WIDGET_TIP_LINK_SWIFT_FLAG="$TIP_LINK_SWIFT_FLAG" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
)

if [[ -n "$SIGN_IDENTITY" ]]; then
  xcodebuild_args+=(CODE_SIGN_IDENTITY="$SIGN_IDENTITY")
fi

echo "  Archive path:        $ARCHIVE_PATH"

xcodebuild "${xcodebuild_args[@]}" archive

echo "$ARCHIVE_PATH"
