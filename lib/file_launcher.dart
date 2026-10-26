import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'file_launcher_platform_interface.dart';
import 'src/open_file_result.dart';
export 'src/file_launcher_desktop_stub.dart'
    if (dart.library.io) 'src/file_launcher_desktop.dart'
    show FileLauncherDesktop;
export 'src/open_file_result.dart';

/// Opens app-readable local files using the platform's native UI.
///
/// Supports iOS, Android, macOS, Windows and Linux. No method throws: failures
/// and unsupported platforms are reported as an [OpenFileResult].
class FileLauncher {
  FileLauncher._();

  /// Opens an absolute [filePath] or `file://` URI. Never waits for the user
  /// to close the UI.
  ///
  /// [title] labels the iOS preview. [mimeType] overrides Android type
  /// detection. [showAppChooser] always asks which app to use on Android
  /// ("Open with") and Windows. [sharePositionOrigin] anchors the iPad share
  /// popover, in global logical coordinates, when Quick Look cannot preview.
  /// Android stages a private cache copy, so large files can take time to open.
  static Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) {
    final path = _localPath(filePath);
    return _guard(
      path == null
          ? null
          : () => FileLauncherPlatform.instance.open(
              path,
              title: title,
              mimeType: mimeType,
              showAppChooser: showAppChooser,
              sharePositionOrigin: sharePositionOrigin,
            ),
    );
  }

  /// Presents the system share sheet for [filePath], skipping any viewer.
  ///
  /// Returns [OpenFileStatus.shareSheet] when accepted. [title] is the Android
  /// chooser title. Desktop platforms return `unsupportedPlatform`.
  static Future<OpenFileResult> share(
    String filePath, {
    String? title,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) {
    final path = _localPath(filePath);
    return _guard(
      path == null
          ? null
          : () => FileLauncherPlatform.instance.share(
              path,
              title: title,
              mimeType: mimeType,
              sharePositionOrigin: sharePositionOrigin,
            ),
    );
  }

  /// Opens in-memory [bytes], such as a download or a bundled asset.
  ///
  /// The bytes are written to a private cache file called [fileName], which
  /// must be a single path segment. Keep the real extension, for example
  /// `invoice.pdf`. For very large content, write a file and use [open].
  static Future<OpenFileResult> openBytes(
    Uint8List bytes, {
    required String fileName,
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) {
    final valid =
        fileName.isNotEmpty &&
        fileName != '.' &&
        fileName != '..' &&
        !fileName.contains(RegExp('[/\\\\\u0000]'));
    return _guard(
      valid
          ? () => FileLauncherPlatform.instance.openBytes(
              bytes,
              fileName: fileName,
              title: title,
              mimeType: mimeType,
              showAppChooser: showAppChooser,
              sharePositionOrigin: sharePositionOrigin,
            )
          : null,
      invalid: 'Provide a file name without path separators',
    );
  }

  /// Deletes the private copies created by [open] (Android) and [openBytes].
  ///
  /// Call it when no viewer is showing one of these files, for example after
  /// handling sensitive documents. Returns `false` if a launch is in progress
  /// or the cache could not be deleted. Original files are never touched.
  static Future<bool> clearCache() async {
    if (!_isSupported) return false;
    try {
      return await FileLauncherPlatform.instance.clearCache();
    } catch (_) {
      return false;
    }
  }

  static bool get _isSupported =>
      !kIsWeb &&
      const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform);

  static Future<OpenFileResult> _guard(
    Future<OpenFileResult> Function()? call, {
    String invalid = 'Provide an absolute local file path',
  }) async {
    if (!_isSupported) {
      return const OpenFileResult(
        OpenFileStatus.unsupportedPlatform,
        'file_launcher supports iOS, Android, macOS, Windows and Linux',
      );
    }
    if (call == null) {
      return OpenFileResult(OpenFileStatus.invalidPath, invalid);
    }
    try {
      return await call();
    } catch (error) {
      return OpenFileResult(
        OpenFileStatus.error,
        'Could not open file: $error',
      );
    }
  }

  /// Returns an absolute platform path, or null for anything else.
  static String? _localPath(String input) {
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    var path = input;
    if (path.startsWith('file:')) {
      try {
        path = Uri.parse(path).toFilePath(windows: windows);
      } catch (_) {
        return null;
      }
    }
    if (path.contains('\u0000')) return null;
    final absolute = windows
        ? RegExp(r'^([a-zA-Z]:[\\/]|\\\\[^\\/])').hasMatch(path)
        : path.startsWith('/');
    return absolute ? path : null;
  }
}
