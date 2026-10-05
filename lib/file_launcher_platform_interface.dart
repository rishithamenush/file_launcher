import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'file_launcher_method_channel.dart';
import 'src/open_file_result.dart';

/// Interface implemented by native file launchers.
abstract class FileLauncherPlatform extends PlatformInterface {
  /// Constructs a platform implementation with a verified token.
  FileLauncherPlatform() : super(token: _token);
  static final Object _token = Object();
  static FileLauncherPlatform _instance = MethodChannelFileLauncher();

  /// The current platform implementation.
  static FileLauncherPlatform get instance => _instance;

  /// Replaces the implementation with a verified subclass.
  static set instance(FileLauncherPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Opens a local file using native presentation.
  Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
  }) async {
    return const OpenFileResult(
      OpenFileStatus.unsupportedPlatform,
      'No file launcher implementation',
    );
  }
}
