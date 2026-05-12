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
- Conservative polling so dashboard pages are not refreshed aggressively.

## Build

```sh
./scripts/build-app.sh
```

The build script compiles the Swift source directly with `swiftc` and packages a WidgetKit extension at `Contents/PlugIns/AIUsageWidgetExtension.appex`.

The app bundle is written to:

```text
build/AI Usage Widget.app
```

## Install

```sh
./scripts/install-app.sh
```

The install script replaces `/Applications/AI Usage Widget.app`, registers the WidgetKit extension with LaunchServices and PluginKit, and launches the app.

After installing, use the menu-bar app's `Show Page` buttons to sign in to Claude and Codex. The main app polls the web dashboards and writes a sanitized cache for the WidgetKit extension to render. The WidgetKit extension does not scrape webpages itself.

If macOS already has the widget gallery open, close and reopen Edit Widgets after installing.

## Refresh Policy

- Automatic polling: every 10 minutes per dashboard.
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
