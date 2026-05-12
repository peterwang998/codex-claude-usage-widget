# AI Usage Widget

Small SwiftUI macOS menu-bar app for monitoring Claude and Codex usage limits from the real web dashboards:

- Claude: `https://claude.ai/settings/usage`
- Codex cloud analytics: `https://chatgpt.com/codex/cloud/settings/analytics`

It uses embedded WebKit pages, not local token estimates. Sign in once through each `Show Page` button; WebKit keeps those cookies for the app and later background polls reuse them.

## Features

- Menu-bar status view with minimal and detailed modes.
- Floating app-owned desktop panel.
- WidgetKit extension for macOS Desktop widgets.
- Claude current session and weekly usage limit display.
- Codex 5-hour and weekly usage limit display.
- Optional detailed rows from each provider's usage page.
- Configurable automatic refresh interval, clamped to 5-60 minutes.
- Percentage display normalization: native dashboard wording, percent used, or percent remaining.
- Conservative polling so dashboard pages are not refreshed aggressively.

## Build

```sh
./scripts/build-app.sh
```

The build script compiles the Swift source directly with `swiftc` and packages a WidgetKit extension at `Contents/PlugIns/AIUsageWidgetExtension.appex`. By default it uses ad-hoc signing for local app testing.

The app bundle is written to:

```text
build/AI Usage Widget.app
```

### Signed Build For Desktop Widgets

The system Desktop widget gallery needs the app and WidgetKit extension to be signed by a valid Apple signing identity. First confirm that macOS can see your certificate:

```sh
security find-identity -v -p codesigning
```

If it lists an `Apple Development` or `Developer ID Application` identity, build with that identity and a Team-ID-prefixed macOS app group:

```sh
DEVELOPMENT_TEAM=TEAMID \
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
./scripts/build-app.sh
```

The script will use `TEAMID.ai-usage-widget` as the shared app group. You can also set it explicitly:

```sh
APP_GROUP_ID=TEAMID.ai-usage-widget \
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
./scripts/build-app.sh
```

The `TEAMID.` app group style is macOS-only and avoids needing a provisioning profile for the shared container. For a `group.`-prefixed App Group, register it in your Apple Developer account and make sure both the app and widget extension provisioning profiles include it.

## Install

```sh
./scripts/install-app.sh
```

The install script replaces `/Applications/AI Usage Widget.app`, registers the WidgetKit extension with LaunchServices and PluginKit, and launches the app.

After installing, use the menu-bar app's `Show Page` buttons to sign in to Claude and Codex. The main app polls the web dashboards and writes a sanitized cache for the WidgetKit extension to render. The WidgetKit extension does not scrape webpages itself.

If macOS already has the widget gallery open, close and reopen Edit Widgets after installing.

### Desktop Widget Signing

The `build-app.sh` script uses ad-hoc codesigning so the menu-bar app can run locally without a developer certificate. On current macOS builds, the system Desktop widget gallery may reject or hide ad-hoc signed third-party WidgetKit extensions. Local logs show this as `amfid` reporting an ad-hoc or unknown signing chain and `chronod` purging the widget descriptor.

For the system Desktop widget to appear reliably in Edit Widgets, build and sign the app plus extension with a valid Apple Development or Developer ID identity and a matching App Group entitlement. The app-owned floating desktop panel still works from the ad-hoc script build. After installing a signed build, launch the app once before reopening Edit Widgets.

## Settings

Open the gear button in the menu-bar window to change:

- View mode: minimal or detailed.
- Auto-refresh interval: 5-60 minutes, in 5-minute steps.
- Percent display: native, used, or remaining. This normalizes Claude and Codex when their dashboards use opposite wording.

## Refresh Policy

- Automatic polling: every 10 minutes per dashboard by default.
- Startup polling is staggered by 20 seconds so both dashboards are not hit at exactly the same time.
- Manual refresh is throttled to once per minute.
- Failed polls back off to 20 minutes.

This is intentionally conservative for dashboard pages whose underlying usage windows are measured in hours, not seconds.

## Notes

- A standalone WebKit app cannot safely import Chrome or Safari auth cookies. Use `Show Page` and sign in inside the widget once for each service.
- The dashboards are private, dynamic web apps. The parser reads rendered text, headings, and accessibility progress metadata. If either provider changes its page text, the card may show `Loaded, parser unsure`; use `Show Page` to inspect the current dashboard and adjust the parser keywords.
- The desktop button in the app opens an app-owned floating panel. The system Desktop widget is provided separately by the bundled WidgetKit extension.
- No API keys or OAuth secrets are stored by this app.
- Normal logs avoid raw dashboard text. Launch with `AI_USAGE_WIDGET_DEBUG_LOGS=1` only when debugging parser changes, because that mode can include rendered dashboard text in the local log file.

## License

MIT
