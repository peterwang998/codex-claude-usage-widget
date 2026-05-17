# App Review Notes

AI Usage Widget is a local macOS menu-bar app and WidgetKit extension. It lets the user sign in to Claude and ChatGPT/Codex in an embedded local WebKit view, reads rendered usage-limit text locally, and stores a local sanitized usage summary for the widget extension.

The app is not affiliated with Anthropic or OpenAI.

The developer does not operate a server for this app and does not receive account information, cookies, usage values, logs, or dashboard contents. The app does not use analytics, advertising, tracking, or third-party SDKs.

For App Store builds prepared with `APP_STORE_BUILD=1` or `scripts/archive-app-store.sh`, the in-app Buy Me a Coffee link is hidden by default.

If a submitted build enables the Buy Me a Coffee link, the link appears only in the app's About section. It is an optional person-to-person tip under App Review Guideline 3.2.1(vii). 100% of the tip goes to the developer. AI Usage Widget is free. Optional tips do not unlock features, content, services, updates, support priority, or any other benefit. No app behavior changes after opening the link or leaving a tip.

Suggested reviewer steps:

1. Launch AI Usage Widget from the menu bar.
2. Use each provider's `Show Page` button to sign in to Claude and ChatGPT/Codex.
3. Use `Refresh` or wait for the automatic poll.
4. Open macOS Edit Widgets and add the AI Usage widget.
