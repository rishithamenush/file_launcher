import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'file_launcher_platform_interface.dart';
import 'src/open_file_result.dart';

/// Native method-channel implementation of [FileLauncherPlatform].
class MethodChannelFileLauncher extends FileLauncherPlatform {
  /// Channel used to communicate with Android and iOS.
  @visibleForTesting
  final methodChannel = const MethodChannel('file_launcher');

  @override
  Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
  }) async {
    try {
      final response = await methodChannel.invokeMethod<Object?>('open', {
        'path': filePath,
        'title': title,
        'mimeType': mimeType,
      });
      if (response is! Map) {
        return const OpenFileResult(
          OpenFileStatus.error,
          'Invalid native response',
        );
      }
      return OpenFileResult.fromMap(response.cast<Object?, Object?>());
    } on PlatformException catch (error) {
      return OpenFileResult(OpenFileStatus.error, error.message ?? error.code);
    } on MissingPluginException {
      return const OpenFileResult(
        OpenFileStatus.error,
        'Plugin not registered; rebuild and restart the app',
      );
    } catch (error) {
      return OpenFileResult(
        OpenFileStatus.error,
        'Could not decode native response: $error',
      );
    }
  }
}
