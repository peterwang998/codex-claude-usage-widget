---
title: Privacy Policy
permalink: /privacy/
---

# Privacy Policy for AI Usage Widget

Effective date: May 14, 2026

AI Usage Widget is designed to run locally on your Mac. The app does not operate a server and does not collect personal information from users.

## Information the App Does Not Collect

AI Usage Widget does not collect, sell, transmit, or store your personal information on developer-operated servers. The app does not use analytics, advertising, tracking, third-party SDKs, API keys, or a developer-operated backend.

The developer does not receive your account information, cookies, usage values, logs, dashboard contents, or sign-in activity.

## Local Dashboard Access

The app loads Claude and ChatGPT/Codex dashboard pages directly in an embedded WebKit view on your Mac. When you sign in, cookies, login sessions, and website data are stored locally by macOS/WebKit for this app.

Those cookies may be sent directly to the relevant service, such as `claude.ai` or `chatgpt.com`, as part of normal webpage loading. They are not sent to the developer of AI Usage Widget.

## Local Processing

AI Usage Widget reads rendered dashboard text locally on your Mac to identify usage limits and reset information. Parsed usage summaries are stored locally so the menu-bar app and WidgetKit extension can display them.

The widget does not scrape webpages. It reads a local cached summary written by the main app through the app group container.

## Logs

Normal logs are stored locally and are intended for troubleshooting app behavior. They avoid raw dashboard text. Debug logging is off by default, but if it is enabled manually with `AI_USAGE_WIDGET_DEBUG_LOGS=1`, it may include rendered dashboard text and should not be used when sharing logs publicly.

## Data Deletion

You can remove locally stored app data by quitting AI Usage Widget and deleting the app's macOS container and app group container. You can also sign out of the embedded dashboard pages or remove the app to stop future local polling.

## Third-Party Services

Claude, ChatGPT, and Codex are third-party services. Their websites and authentication flows are governed by their own terms and privacy policies. AI Usage Widget is not affiliated with Anthropic or OpenAI.

## Contact

For privacy questions or bug reports, open an issue at:

<https://github.com/peterwang998/codex-claude-usage-widget/issues>
