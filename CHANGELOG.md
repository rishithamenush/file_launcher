## 0.2.0

**New**

* `FileLauncher.share()` opens the system share sheet directly, skipping the viewer.
* `FileLauncher.openBytes()` opens in-memory content such as downloads or assets, with no `path_provider` needed.
* `FileLauncher.clearCache()` deletes the plugin's private copies immediately.
* `showAppChooser` always asks which app to use on Android ("Open with") and Windows.
* `sharePositionOrigin` anchors iPad and macOS share popovers to the tapped widget.
* `file://` URIs are accepted wherever a path is.
* macOS support: default app through `NSWorkspace`, `NSSharingServicePicker` for sharing and as the fallback.
* Windows (`ShellExecuteW`, "Open with" dialog) and Linux (`xdg-open`) support, written in Dart.
* Android no longer copies a file that is already in the plugin's staging cache.

**Breaking**

* New statuses split out of `error`: `invalidPath`, `fileNotReadable` and `busy`. Exhaustive `switch` statements over `OpenFileStatus` need the new cases.
* `FileLauncherPlatform` gained `share`, `openBytes`, `clearCache` and new `open` parameters. Custom platform implementations must update their `open` override.
* macOS, Windows and Linux now launch files instead of returning `unsupportedPlatform`.

## 0.1.0

* Added explicit common-format Android MIME routing and normalized MIME overrides.
* Added tests for PDF/audio intents, read grants and viewer-to-share fallback.
* Added seven audio samples and a categorized, 19-file example gallery.
* Redesigned documentation with a visual introduction and usage recipes.

* Initial development release for iOS 13+ and Android API 24+.
* Quick Look preview on iOS and external native viewers on Android.
* System share-sheet fallback and structured, non-throwing Dart results.
* Scene-aware iOS presentation and anchored iPad popovers.
* Read-only Android URI grants through a dedicated staging cache.
* CocoaPods and Swift Package Manager integration, example and tests.
