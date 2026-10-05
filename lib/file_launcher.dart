import 'package:flutter/foundation.dart';
import 'file_launcher_platform_interface.dart';
import 'src/open_file_result.dart';
export 'src/open_file_result.dart';

/// Opens app-readable local files using the platform's native UI.
class FileLauncher {
  FileLauncher._();

  /// Opens an absolute [filePath]. Never waits for the user to close the UI.
  ///
  /// [title] labels the iOS preview. [mimeType] overrides Android type detection.
  /// Unsupported platforms and failures return a result instead of throwing.
  /// Android stages a private cache copy, so large files can take time to open.
  static Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return const OpenFileResult(
        OpenFileStatus.unsupportedPlatform,
        'file_launcher supports iOS and Android only',
      );
    }
    if (!filePath.startsWith('/') || filePath.contains('\u0000')) {
      return const OpenFileResult(
        OpenFileStatus.error,
        'Provide an absolute local file path',
      );
    }
    try {
      return await FileLauncherPlatform.instance.open(
        filePath,
        title: title,
        mimeType: mimeType,
      );
    } catch (error) {
      return OpenFileResult(
        OpenFileStatus.error,
        'Could not open file: $error',
      );
    }
  }
}
