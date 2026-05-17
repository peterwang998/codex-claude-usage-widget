# Mac App Store Submission Checklist

This file tracks the App Store submission path for AI Usage Widget.

## Proposed App Store Identifiers

- App name: `AI Usage Widget`
- App bundle ID: `com.peterwang.aiusagewidget`
- Widget extension bundle ID: `com.peterwang.aiusagewidget.widget`
- App group ID: `group.com.peterwang.aiusagewidget`
- Version: `1.0`
- Build: `1`
- Privacy policy URL: `https://peterwang998.github.io/codex-claude-usage-widget/privacy/`
- Support URL: `https://github.com/peterwang998/codex-claude-usage-widget/issues`

Confirm these identifiers before creating the App Store Connect app record. Bundle IDs cannot be changed after the app is created.

## Local Preparation Done In Repo

- Xcode build settings can now accept app, extension, and app-group identifiers from build settings.
- `scripts/archive-app-store.sh` archives a Release build with App Store-style defaults.
- App Store archive builds include the About-only Buy Me a Coffee link by default, with conservative optional-tip wording.
- `APP_REVIEW_NOTES.md` contains reviewer notes for privacy, login flow, affiliation, and optional-tip handling.
- Public privacy policy and project page are already in `docs/`.

## Apple Developer Actions

Do these in the Apple Developer portal before archiving for upload:

1. Create the app bundle ID: `com.peterwang.aiusagewidget`.
2. Create the widget extension bundle ID: `com.peterwang.aiusagewidget.widget`.
3. Create the app group ID: `group.com.peterwang.aiusagewidget`.
4. Enable the App Groups capability on both bundle IDs.
5. Add `group.com.peterwang.aiusagewidget` to both bundle IDs.
6. Make sure Xcode is signed in to the Apple Developer account for your team.
7. Make sure Xcode can manage signing, including creating or using an Apple Distribution certificate.

## Archive Command

After the Apple Developer identifiers and app group exist:

```sh
DEVELOPMENT_TEAM=TEAMID ./scripts/archive-app-store.sh
```

Use the actual Apple Developer Team ID in place of `TEAMID`.

The script defaults to:

```sh
APP_BUNDLE_ID=com.peterwang.aiusagewidget
EXTENSION_BUNDLE_ID=com.peterwang.aiusagewidget.widget
APP_GROUP_ID=group.com.peterwang.aiusagewidget
AI_USAGE_WIDGET_SHOW_TIP_LINK=1
```

The optional Buy Me a Coffee link appears only in the in-app About section. The app shows this disclaimer near the link: `AI Usage Widget is free. Optional tips do not unlock features, content, updates, support priority, or any other benefit.`

If Apple rejects the external optional-tip link, resubmit with it hidden:

```sh
AI_USAGE_WIDGET_SHOW_TIP_LINK=0 DEVELOPMENT_TEAM=TEAMID ./scripts/archive-app-store.sh
```

## App Store Connect Metadata

Create the app in App Store Connect after the app bundle ID exists.

Suggested metadata:

- Category: Developer Tools or Productivity.
- Price: Free.
- Privacy policy URL: `https://peterwang998.github.io/codex-claude-usage-widget/privacy/`
- Support URL: `https://github.com/peterwang998/codex-claude-usage-widget/issues`
- Copyright: `2026 Peter Wang`

Suggested description:

```text
AI Usage Widget is a local macOS menu-bar app and Desktop widget for monitoring Claude and ChatGPT/Codex usage limits from the official web dashboards.

Sign in once in the embedded local WebKit views, then the app periodically reads the rendered dashboard text and displays a compact usage summary in the menu bar and macOS Desktop widget.
```

Suggested keywords:

```text
AI,Claude,Codex,usage,widget,menu bar,developer tools
```

## Privacy Nutrition Label Draft

Based on the current implementation:

- Data collected by developer: No.
- Data used for tracking: No.
- Third-party advertising/analytics SDKs: No.
- Account credentials/cookies: stored locally by WebKit for this app; not collected by the developer.
- Usage values: processed and stored locally on the Mac; not collected by the developer.
- Network requests: direct requests from the app's WebKit view to the services the user signs in to, such as `claude.ai` and `chatgpt.com`.

Verify these answers in App Store Connect before submission.

## Required Review Notes

Paste or adapt `APP_REVIEW_NOTES.md` into App Store Connect's App Review Information field.

If Apple requires reviewer access, provide reviewer-safe Claude and ChatGPT/Codex accounts or explain that reviewers may use their own accounts to verify the app. Do not include personal credentials in this repository.

## Screenshots

Mac App Store screenshots must be exact 16:10 screenshots, such as:

- `1280x800`
- `1440x900`
- `2560x1600`
- `2880x1800`

The README images are useful examples but are not App Store-ready screenshot sizes.

## Submission Steps

1. Register identifiers and app group in Apple Developer.
2. Create the App Store Connect app record using the production app bundle ID.
3. Run `scripts/archive-app-store.sh`.
4. Open Xcode Organizer and upload the archive to App Store Connect.
5. Complete App Store metadata, privacy, age rating, screenshots, and review notes.
6. Select the processed build.
7. Add for Review and submit.

## Current Blockers For Codex

- Apple Developer portal access is required to create bundle IDs and the app group.
- App Store Connect access is required to create the app record and submit for review.
- Reviewer credentials may be required if Apple will not use its own Claude/ChatGPT accounts.
