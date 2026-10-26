import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'file_launcher_method_channel.dart';
import 'src/open_file_result.dart';

/// Interface implemented by native file launchers.
///
/// Arguments arrive validated and normalized by `FileLauncher`.
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
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) async => _unsupported;

  /// Presents the system share sheet for a local file.
  Future<OpenFileResult> share(
    String filePath, {
    String? title,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) async => _unsupported;

  /// Writes [bytes] to a private cache file named [fileName], then opens it.
  Future<OpenFileResult> openBytes(
    Uint8List bytes, {
    required String fileName,
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) async => _unsupported;

  /// Deletes the copies this plugin created. Returns whether it succeeded.
  Future<bool> clearCache() async => false;

  static const _unsupported = OpenFileResult(
    OpenFileStatus.unsupportedPlatform,
    'No file launcher implementation',
  );
}
