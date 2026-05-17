#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/build/XcodeAutoDerivedData}"
SIGNING_MODE="${SIGNING_MODE:-automatic}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Apple Development}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
APP_GROUP_ID="${APP_GROUP_ID:-${DEVELOPMENT_TEAM}.ai-usage-widget}"
SHOW_TIP_LINK="${AI_USAGE_WIDGET_SHOW_TIP_LINK:-${AI_USAGE_WIDGET_SHOW_SUPPORT_LINK:-1}}"
if [[ -n "${AI_USAGE_WIDGET_TIP_LINK_SWIFT_FLAG+x}" ]]; then
  TIP_LINK_SWIFT_FLAG="$AI_USAGE_WIDGET_TIP_LINK_SWIFT_FLAG"
elif [[ "$SHOW_TIP_LINK" == "0" ]]; then
  TIP_LINK_SWIFT_FLAG=""
else
  TIP_LINK_SWIFT_FLAG="-D AI_USAGE_WIDGET_SHOW_TIP_LINK"
fi

if [[ -z "$DEVELOPMENT_TEAM" && "$SIGNING_MODE" == "automatic" ]]; then
  echo "DEVELOPMENT_TEAM is required for automatic WidgetKit signing." >&2
  echo "Example: DEVELOPMENT_TEAM=TEAMID ./scripts/build-xcode-app.sh" >&2
  exit 1
fi

xcodebuild_args=(
  -project "$ROOT/AIUsageWidget.xcodeproj"
  -scheme AIUsageWidget
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
  AI_USAGE_WIDGET_APP_GROUP_ID="$APP_GROUP_ID"
  AI_USAGE_WIDGET_TIP_LINK_SWIFT_FLAG="$TIP_LINK_SWIFT_FLAG"
)

if [[ "$SIGNING_MODE" == "automatic" ]]; then
  xcodebuild_args+=(
    -allowProvisioningUpdates
    CODE_SIGN_STYLE=Automatic
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES
  )
else
  xcodebuild_args+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
  )
fi

xcodebuild "${xcodebuild_args[@]}" build

echo "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/AI Usage Widget.app"
