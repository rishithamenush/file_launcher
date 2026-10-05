# Acceptance and release testing

Record date, hardware, OS, Flutter version, result status, response time and observed UI for each combination. Do not mark a row passed based on compilation alone.

| Setup | Status |
| --- | --- |
| iPhone with UIScene, current iOS | Pending |
| iOS 13–15, legacy AppDelegate lifecycle | Pending |
| iPad: share popover, Split View, Stage Manager, dialog already open | Pending |
| Two iPad windows / multiple Flutter engines | Pending |
| Apple silicon Mac running Designed for iPad | Pending |
| Android API 24 AOSP without Google apps | Pending |
| Current Android Pixel | Pending |
| Samsung Android 13 / 14 | Pending |
| Android tablet / foldable, rotation and Activity recreation | Pending |
| ChromeOS | Pending |

For each row, open PDF, PNG/JPG, DOCX, XLSX, MP4, MP3, M4A, WAV, AAC, FLAC, Ogg Vorbis, Ogg Opus, TXT, CSV, JSON, ZIP, an unknown extension and an extensionless file. The example bundles fixtures for these cases. Verify titles, filenames, dismissal and subsequent calls. iOS Quick Look capability and installed Android apps decide the result.

Additional checks:

- Missing paths and directories return fileNotFound; relative paths return error.
- Unreadable paths and APK launch attempts return error.
- Paths containing spaces and Unicode work.
- A file in path_provider's application documents directory opens on Android.
- The Android recipient can actually read the URI, with read-only grants.
- No permissions dialog appears. Inspect the merged manifest for unwanted permissions.
- A device without a suitable viewer gets a share chooser; an empty chooser is still shareSheet.
- Background calls, UI transitions, rapid repeated calls and engine detachment return an error without crashes.
- On iOS, returning from the preview allows a second file to open correctly.
- On Android, the source is never changed; stale staged copies are removed on later calls.
- Large files do not block the Android UI thread; low disk space returns error.
- Web returns unsupportedPlatform without loading dart:io in the package itself.

For small files, target a response within one second. The API does not impose a hard timeout: staging large files or OS work can take longer. Success means presentation / launch accepted, not that a recipient read or saved anything.

Release gates: complete the matrix, test both CocoaPods and SPM in consumer apps, validate the minimum advertised Flutter version, add repository metadata and genuine screenshots, run publish dry-run, and review the package archive. Keep version 0.1.0 until these gates have evidence.

## Local validation — 4 October 2026

- Flutter 3.44.8 / Dart 3.12.2: analysis clean; formatting clean.
- Dart package tests: 10 passed; example widget test: 1 passed.
- Unsigned iOS release example: built successfully using Xcode 27 and SPM.
- The example targets iOS 15 because Xcode 27 rejects deployment target 13. The plugin still declares iOS 13; validation on an older compatible toolchain is pending.
- Publication dry run: one warning, missing real homepage/repository metadata. Nothing published.
- No physical-device preview or share-sheet acceptance results are claimed.
- Android debug example APK: built successfully with the generated AGP 9.0.1 / Gradle 9.1 toolchain.
- iOS native XCTest target: unsigned `build-for-testing` succeeded; execution is pending a simulator/device test run.
- Android native Robolectric tests: 4 passed (invalid path, directory, APK rejection, unknown method).

## File gallery and routing validation — 5 October 2026

- Dart package tests: 10 passed. Example tests: 3 passed, including Audio filtering and loading all 19 bundled fixtures.
- Android native tests: 14 passed, including PDF/audio MIME selection, normalized overrides, locale independence, read-only intent grants, missing-viewer fallback and failed launches.
- All seven audio fixtures and the MP4 decoded successfully with FFmpeg. This validates the sample data, not playback by an iOS/Android viewer.
- README banner and actual Flutter gallery rendering were visually inspected. The gallery image was captured from the Flutter widget renderer, not a physical device.
- Publication dry run accepts the new screenshot and assets; the existing missing-homepage/repository warning remains.
- Real-device PDF rendering and audio playback remain pending. For each audio sample, listen to the tone, check play/pause/seek where available, close the player, and reopen another file. Record the receiving app and codec; a successful launch result alone is not a playback pass.
- Updated Android debug APK and unsigned iOS release example both built successfully. Analysis and formatting checks are clean.
