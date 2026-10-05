# Platform notes

## Requirements and compatibility

| Target | Behavior |
| --- | --- |
| iPhone / iPad, iOS 13+ | In-app Quick Look; share sheet when Quick Look cannot preview |
| iPad popovers | Anchored to the presenting view |
| UIScene apps | Looks up the calling Flutter engine's current window on each call |
| Legacy AppDelegate apps | Uses the current registrar window, then a key-window fallback |
| Multi-window apps | Prefers the engine's window; refuses an ambiguous fallback |
| Android API 24+ | External viewer, then Android share chooser |
| Tablets / foldables / ChromeOS | Same Android implementation; device testing pending |
| Web / macOS / Windows / Linux | Returns `unsupportedPlatform` |

Current build baseline: **Flutter 3.44+ / Dart 3.12+**, Android compile SDK 36, Java 17 and the generated AGP 9 toolchain. iOS includes Swift Package Manager and CocoaPods definitions. The example targets iOS 15 for Xcode 27; the plugin itself declares iOS 13, which still needs an older-toolchain check. Lower Dart/Flutter bounds from the initial proposal are intentionally not claimed: older host build systems need separate compatibility work and testing. Run native presentation while the app is foregrounded. On Android, a detached Activity produces `error`; retry when visible.

## File types

| Type | iOS | Android |
| --- | --- | --- |
| PDF, images, plain text | Quick Look when supported | Installed viewer |
| DOCX, XLSX, PPTX, iWork | Quick Look when supported | Installed Office-compatible app, otherwise share chooser |
| Audio / video | Quick Look when supported | Installed media app |
| 3D / AR | Quick Look when supported by device and format | Installed viewer or share chooser |
| Archives, unknown types, VCF, ICS | Quick Look's runtime decision, otherwise share sheet | Installed viewer or share chooser |
| No extension | Runtime Quick Look decision; often share sheet | Supply `mimeType` |
| APK | No installation support | Explicitly rejected with `error` |

Support depends on the OS, file contents and installed apps. The example includes 19 samples, including seven audio encodings. See the [gallery](../README.md#try-the-file-gallery).

## Results

| Status | Meaning |
| --- | --- |
| `done` | Native preview presented, or Android accepted the viewer intent |
| `shareSheet` | System accepted the share-sheet presentation |
| `fileNotFound` | Path does not identify an existing regular file |
| `noAppToOpen` | Android could not launch either a viewer or a chooser |
| `noViewController` | iOS has no active presentation screen |
| `unsupportedPlatform` | Current platform is unsupported |
| `error` | Invalid input, unreadable file, busy presentation, missing plugin, or another failure |

`OpenFileResult.message` is a diagnostic, not a stable identifier. `isSuccess` is true for `done` and `shareSheet`. `open()` catches failures and returns a result; it never waits for dismissal. Android cannot confirm another app rendered the file, and its chooser can open even if it has no eligible recipients. `noAppToOpen` means the chooser itself could not launch.

On iOS, close the previous preview or share sheet before opening another. Calls during presentation transitions return `error` so they can be retried. Android rejects concurrent calls while preparing a file.

## Permissions and cache behavior

No storage, package-installation or package-query permissions are declared. No iOS Info.plist keys are required. Android grants read access to one `content://` URI through the plugin's own FileProvider.

Android copies each selected file into `cache/file_launcher/<unique-id>/` on a background worker, then exposes only that directory. This also supports app documents folders outside `filesDir`, without a broad filesystem-root provider mapping. Copies retain the original filename and extension; space and copy time scale with file size. Copies older than seven days are removed on a subsequent call; the OS can evict cache files earlier. Copies remain after cancellation, so apps handling sensitive material should account for cache retention. Original files are never modified or deleted.

This follows [Android's FileProvider guidance](https://developer.android.com/privacy-and-security/risks/file-providers) to avoid broad root paths. Do not pass secrets your app does not intend to share.

## Migration from open_file / open_filex / open_file_plus

Replace `OpenFile.open(path)` or `OpenFilex.open(path)` with `FileLauncher.open(path)`. Replace checks against `ResultType.done` with `result.isSuccess`, and switch on `result.status` for failures. Android MIME overrides use `mimeType` rather than `type`.

This package focuses on explicit outcomes, in-app Quick Look on iOS, share fallback and a narrow Android provider. Android viewing happens in another app. It does not claim broader format support than existing packages. Remove old plugin-specific provider overrides only after checking that no other feature relies on them.

## Develop and validate

```sh
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test
flutter test
cd example
flutter test
flutter run
```

Native builds and tests:

```sh
cd example
flutter build apk --debug
flutter build ios --no-codesign
cd android
./gradlew :file_launcher:testDebugUnitTest
```

Run `flutter test integration_test/plugin_integration_test.dart -d <device-id>` from `example` on a connected mobile device. Manual preview tests and release requirements are in [TESTING.md](../TESTING.md). CI runs Dart checks, Android unit tests, Android builds and unsigned iOS builds.

## Release status

Version 0.1.0 is the initial development release. See the [GitHub repository](https://github.com/rishithamenush/file_launcher) and [issue tracker](https://github.com/rishithamenush/file_launcher/issues).

Physical-device acceptance, older-iOS verification and CocoaPods consumer checks remain pending. See [TESTING.md](../TESTING.md) before relying on a particular device/format combination. Complete these checks before a 1.0.0 release.
