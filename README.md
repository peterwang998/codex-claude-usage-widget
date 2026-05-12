# AI Usage Widget

Small SwiftUI macOS menu-bar app for monitoring Claude and Codex usage limits from the real web dashboards:

- Claude: `https://claude.ai/settings/usage`
- Codex cloud analytics: `https://chatgpt.com/codex/cloud/settings/analytics`

It uses embedded WebKit pages, not local token estimates. Sign in once through each `Show Page` button; WebKit keeps those cookies for the app and later background polls reuse them.

## Features

- Menu-bar status view with minimal and detailed modes.
- Floating app-owned desktop panel.
- Claude current session and weekly usage limit display.
- Codex 5-hour and weekly usage limit display.
- Optional detailed rows from each provider's usage page.
- Conservative polling so dashboard pages are not refreshed aggressively.

## Build

```sh
./scripts/build-app.sh
```

The build script compiles the Swift source directly with `swiftc`.

The app bundle is written to:

```text
build/AI Usage Widget.app
```

## Refresh Policy

- Automatic polling: every 10 minutes per dashboard.
- Startup polling is staggered by 20 seconds so both dashboards are not hit at exactly the same time.
- Manual refresh is throttled to once per minute.
- Failed polls back off to 20 minutes.

This is intentionally conservative for dashboard pages whose underlying usage windows are measured in hours, not seconds.

## Notes

- A standalone WebKit app cannot safely import Chrome or Safari auth cookies. Use `Show Page` and sign in inside the widget once for each service.
- The dashboards are private, dynamic web apps. The parser reads rendered text, headings, and accessibility progress metadata. If either provider changes its page text, the card may show `Loaded, parser unsure`; use `Show Page` to inspect the current dashboard and adjust the parser keywords.
- The desktop button in the app opens an app-owned floating panel. macOS `Add Widgets` only lists WidgetKit extensions packaged inside an app bundle under `Contents/PlugIns/*.appex`. The current direct `swiftc` build does not package a WidgetKit extension, so it will not appear in the system widget gallery.
- No API keys or OAuth secrets are stored by this app.
- Normal logs avoid raw dashboard text. Launch with `AI_USAGE_WIDGET_DEBUG_LOGS=1` only when debugging parser changes, because that mode can include rendered dashboard text in the local log file.

## License

MIT
