# Release And Upgrade Plan

## Mac App Store Updates

Use this path for normal App Store releases.

1. Make code changes locally.
2. Test the app on your Mac.
3. Bump versions:
   - `MARKETING_VERSION`: user-facing version, such as `1.0.1`, `1.1`, or `2.0`.
   - `CURRENT_PROJECT_VERSION`: build number. This must increase for every upload, such as `2`, `3`, or `4`.
4. Rebuild an App Store archive.
5. Upload the archive from Xcode Organizer.
6. In App Store Connect, create a new app version.
7. Select the uploaded build.
8. Add "What's New" release notes.
9. Confirm privacy and export compliance answers if prompted.
10. Submit for App Review.
11. Release manually or automatically after approval.

Keep these identifiers stable:

```text
com.peterwang.aiusagewidget
com.peterwang.aiusagewidget.widget
group.com.peterwang.aiusagewidget
```

Changing bundle IDs or the app group would break continuity for existing users.

## Auto Updates

For the Mac App Store version, do not add a custom updater. The App Store handles updates, and users can enable automatic app updates in macOS.

A future "Check for Updates" action can open the app's Mac App Store page after the app has an App Store ID.

## Direct Download Track

If a non-App-Store direct download is added later, keep it separate from the App Store build.

1. Keep the App Store build free of custom updater code.
2. Add Sparkle only for non-App-Store builds.
3. Use a build flag such as `APP_STORE_BUILD=1` to exclude Sparkle from App Store archives.
4. Sign and notarize direct-download releases separately.
5. Publish direct-download updates through GitHub Releases and a Sparkle appcast.

