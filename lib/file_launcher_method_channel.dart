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
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) => _launch('open', {
    'path': filePath,
    'title': title,
    'mimeType': mimeType,
    'showAppChooser': showAppChooser,
    'origin': _origin(sharePositionOrigin),
  });

  @override
  Future<OpenFileResult> share(
    String filePath, {
    String? title,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) => _launch('share', {
    'path': filePath,
    'title': title,
    'mimeType': mimeType,
    'origin': _origin(sharePositionOrigin),
  });

  @override
  Future<OpenFileResult> openBytes(
    Uint8List bytes, {
    required String fileName,
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) => _launch('openBytes', {
    'bytes': bytes,
    'fileName': fileName,
    'title': title,
    'mimeType': mimeType,
    'showAppChooser': showAppChooser,
    'origin': _origin(sharePositionOrigin),
  });

  @override
  Future<bool> clearCache() async {
    try {
      return await methodChannel.invokeMethod<bool>('clearCache') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<OpenFileResult> _launch(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final response = await methodChannel.invokeMethod<Object?>(
        method,
        arguments,
      );
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

  static Map<String, double>? _origin(Rect? rect) => rect == null
      ? null
      : {
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
        };
}
