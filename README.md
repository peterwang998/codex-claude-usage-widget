# AI Usage Widget

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Source Code](https://img.shields.io/badge/Source-GitHub-24292f?logo=github&logoColor=white)](https://github.com/peterwang998/codex-claude-usage-widget)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-optional%20tip-ffdd00?logo=buymeacoffee&logoColor=000000)](https://buymeacoffee.com/peterwang)

Small SwiftUI macOS menu-bar app for monitoring Claude and Codex usage limits from the real web dashboards:

- Claude: `https://claude.ai/settings/usage`
- Codex cloud analytics: `https://chatgpt.com/codex/cloud/settings/analytics`

It uses embedded WebKit pages, not local token estimates. Sign in once through each `Show Page` button; WebKit keeps those cookies for the app and later background polls reuse them.

## Features

- Menu-bar status view with minimal and detailed modes.
- Menu-bar-only app behavior; the app does not stay in the Dock while running.
- Floating app-owned desktop panel.
- WidgetKit extension for macOS Desktop widgets.
- Generated meter-style app icon.
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

The direct build script compiles the Swift source with `swiftc` and packages a local app bundle. It is useful for quick menu-bar app testing, but the system Desktop widget gallery is stricter than a normal app launch.

The app bundle is written to:

```text
build/AI Usage Widget.app
```

To regenerate the app icon:

```sh
env CLANG_MODULE_CACHE_PATH="$PWD/.build-cache/clang" swift scripts/generate-app-icon.swift
```

### Signed Build For Desktop Widgets

The reliable path for macOS Desktop widgets is the Xcode project build. It lets Xcode perform the WidgetKit build steps and signs both the app and extension with your Apple Development identity.

First confirm that macOS can see your certificate:

```sh
security find-identity -v -p codesigning
```

If it lists an `Apple Development` identity, install the Xcode-built app with your team ID:

```sh
DEVELOPMENT_TEAM=TEAMID ./scripts/install-xcode-app.sh
```

The script will use `TEAMID.ai-usage-widget` as the shared app group. You can also set it explicitly:

```sh
APP_GROUP_ID=TEAMID.ai-usage-widget \
DEVELOPMENT_TEAM=TEAMID \
./scripts/install-xcode-app.sh
```

The `TEAMID.` app group style is macOS-only and avoids needing a provisioning profile for the shared container. For a `group.`-prefixed App Group, register it in your Apple Developer account and make sure both the app and widget extension provisioning profiles include it.

## Install

```sh
DEVELOPMENT_TEAM=TEAMID ./scripts/install-xcode-app.sh
```

The Xcode install script replaces `/Applications/AI Usage Widget.app`, registers the WidgetKit extension with LaunchServices and PluginKit, and launches the app. It also unregisters the temporary DerivedData copy so macOS only sees the installed app extension.

For menu-bar-only testing without system Desktop widgets, you can still use:

```sh
./scripts/install-app.sh
```

After installing, use the menu-bar app's `Show Page` buttons to sign in to Claude and Codex. The main app polls the web dashboards and writes a sanitized cache for the WidgetKit extension to render. The WidgetKit extension does not scrape webpages itself.

If macOS already has the widget gallery open, close and reopen Edit Widgets after installing.

### Desktop Widget Signing

The `build-app.sh` script uses ad-hoc codesigning by default so the menu-bar app can run locally without a developer certificate. On current macOS builds, the system Desktop widget gallery may reject or hide ad-hoc signed third-party WidgetKit extensions. Local logs show this as `amfid` reporting an ad-hoc or unknown signing chain and `chronod` purging the widget descriptor.

For the system Desktop widget to appear reliably in Edit Widgets, use `scripts/install-xcode-app.sh` with a valid Apple Development or Developer ID identity and a matching App Group entitlement. The app-owned floating desktop panel still works from the ad-hoc script build. After installing a signed build, launch the app once before reopening Edit Widgets.

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

## Privacy And Tips

- The public privacy policy lives at `docs/privacy.md` and is intended for GitHub Pages at `https://peterwang998.github.io/codex-claude-usage-widget/privacy/`.
- The project landing page lives at `docs/index.md`.
- The in-app About section links to the privacy policy, GitHub repository, and Buy Me a Coffee.
- AI Usage Widget is free. Optional tips do not unlock features, content, updates, support priority, or any other benefit.
- App Review notes for the optional tip link are in `APP_REVIEW_NOTES.md`.

To hide the in-app Buy Me a Coffee link in direct script builds:

```sh
AI_USAGE_WIDGET_SHOW_TIP_LINK=0 ./scripts/build-app.sh
```

For Xcode script builds, use the same `AI_USAGE_WIDGET_SHOW_TIP_LINK=0` setting. In Xcode itself, override `AI_USAGE_WIDGET_TIP_LINK_SWIFT_FLAG` to an empty value.

## License

MIT
