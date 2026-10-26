import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Rect;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../file_launcher_platform_interface.dart';
import 'open_file_result.dart';

/// Starts a process; replaceable in tests.
typedef ProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

/// Opens a file through the Windows shell; replaceable in tests.
typedef ShellOpener =
    Future<OpenFileResult> Function(String path, bool showAppChooser);

/// Windows and Linux implementation, written in Dart. Registered
/// automatically; apps do not need to use it.
///
/// Windows uses `ShellExecuteW` (or the "Open with" dialog) and Linux uses
/// `xdg-open`. Both open the file in another app; there is no share sheet.
class FileLauncherDesktop extends FileLauncherPlatform {
  /// Creates a launcher. Parameters exist for tests.
  FileLauncherDesktop({
    @visibleForTesting String? operatingSystem,
    @visibleForTesting ProcessStarter? startProcess,
    @visibleForTesting ShellOpener? shellOpen,
    @visibleForTesting Directory? cacheDirectory,
    @visibleForTesting this.exitTimeout = const Duration(seconds: 5),
  }) : _os = operatingSystem ?? Platform.operatingSystem,
       _start = startProcess ?? Process.start,
       _shellOpen = shellOpen ?? _windowsOpen,
       _cache =
           cacheDirectory ??
           Directory('${Directory.systemTemp.path}/file_launcher');

  /// Registers this implementation; called by the generated registrant.
  static void registerWith() {
    FileLauncherPlatform.instance = FileLauncherDesktop();
  }

  /// How long to wait for `xdg-open` to report a failure. A launcher that is
  /// still running after this is treated as accepted.
  final Duration exitTimeout;
  final String _os;
  final ProcessStarter _start;
  final ShellOpener _shellOpen;
  final Directory _cache;

  @override
  Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) async {
    final problem = await _check(filePath);
    if (problem != null) return problem;
    if (_os == 'windows') return _shellOpen(filePath, showAppChooser);
    return _xdgOpen(filePath);
  }

  @override
  Future<OpenFileResult> share(
    String filePath, {
    String? title,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) async => const OpenFileResult(
    OpenFileStatus.unsupportedPlatform,
    'No system share sheet on this platform',
  );

  @override
  Future<OpenFileResult> openBytes(
    Uint8List bytes, {
    required String fileName,
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) async {
    final String path;
    try {
      await _cache.create(recursive: true);
      final directory = await _cache.createTemp();
      path = '${directory.path}${Platform.pathSeparator}$fileName';
      await File(path).writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (error) {
      return OpenFileResult(
        OpenFileStatus.error,
        'Could not prepare file: ${error.message}',
      );
    }
    return open(path, showAppChooser: showAppChooser);
  }

  @override
  Future<bool> clearCache() async {
    try {
      if (await _cache.exists()) await _cache.delete(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<OpenFileResult?> _check(String path) async {
    if (await FileSystemEntity.type(path) != FileSystemEntityType.file) {
      return OpenFileResult(
        OpenFileStatus.fileNotFound,
        'No regular file at: $path',
      );
    }
    try {
      await (await File(path).open()).close();
    } on FileSystemException {
      return const OpenFileResult(
        OpenFileStatus.fileNotReadable,
        'File is not readable',
      );
    }
    return null;
  }

  Future<OpenFileResult> _xdgOpen(String path) async {
    final Process process;
    try {
      process = await _start('xdg-open', [path]);
    } on ProcessException {
      return const OpenFileResult(
        OpenFileStatus.noAppToOpen,
        'xdg-open is not installed',
      );
    }
    unawaited(process.stdout.drain<void>());
    final errors = process.stderr.transform(utf8.decoder).join();
    // Some desktops keep xdg-open running while the app starts.
    final code = await process.exitCode
        .then<int?>((code) => code)
        .timeout(exitTimeout, onTimeout: () => null);
    if (code == null || code == 0) {
      return const OpenFileResult(
        OpenFileStatus.done,
        'Default app launch accepted',
      );
    }
    final detail = (await errors).trim();
    // Exit codes from the xdg-utils documentation.
    final status = switch (code) {
      2 => OpenFileStatus.fileNotFound,
      3 || 4 => OpenFileStatus.noAppToOpen,
      _ => OpenFileStatus.error,
    };
    return OpenFileResult(
      status,
      detail.isEmpty ? 'xdg-open exited with code $code' : detail,
    );
  }
}

/// Runs the shell call on a background isolate: it can block on slow
/// handlers, and the "Open with" dialog stays open until the user chooses.
Future<OpenFileResult> _windowsOpen(String path, bool showAppChooser) =>
    Isolate.run(() => _shellOpenSync(path, showAppChooser));

OpenFileResult _shellOpenSync(String path, bool showAppChooser) {
  final ole32 = DynamicLibrary.open('ole32.dll');
  final shell32 = DynamicLibrary.open('shell32.dll');
  final coInitializeEx = ole32
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int)
      >('CoInitializeEx');
  final coUninitialize = ole32.lookupFunction<Void Function(), void Function()>(
    'CoUninitialize',
  );
  // COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE, as ShellExecute asks.
  final initialized = coInitializeEx(nullptr, 0x2 | 0x4) >= 0;
  final file = path.toNativeUtf16();
  try {
    if (showAppChooser) {
      final dialog = shell32
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<_OpenAsInfo>),
            int Function(int, Pointer<_OpenAsInfo>)
          >('SHOpenWithDialog');
      final info = calloc<_OpenAsInfo>()
        ..ref.file = file
        ..ref.flags = 0x4; // OAIF_EXEC: open with the chosen app.
      try {
        final result = dialog(0, info);
        // 0x800704C7 is HRESULT_FROM_WIN32(ERROR_CANCELLED).
        if (result >= 0 || result == 0x800704C7.toSigned(32)) {
          return const OpenFileResult(
            OpenFileStatus.done,
            'Open-with dialog completed',
          );
        }
        return OpenFileResult(
          OpenFileStatus.error,
          'Open-with dialog failed: 0x${result.toUnsigned(32).toRadixString(16)}',
        );
      } finally {
        calloc.free(info);
      }
    }
    final shellExecute = shell32
        .lookupFunction<
          IntPtr Function(
            IntPtr,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Int32,
          ),
          int Function(
            int,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            int,
          )
        >('ShellExecuteW');
    // A null verb uses the default action, unlike "open", which can fail
    // for file types that define a different default verb.
    final code = shellExecute(0, nullptr, file, nullptr, nullptr, 1);
    // Values above 32 mean success; the rest are documented SE_ERR_* codes.
    return switch (code) {
      > 32 => const OpenFileResult(
        OpenFileStatus.done,
        'Default app launch accepted',
      ),
      2 || 3 => OpenFileResult(
        OpenFileStatus.fileNotFound,
        'No regular file at: $path',
      ),
      5 => const OpenFileResult(
        OpenFileStatus.fileNotReadable,
        'Access denied',
      ),
      27 || 31 => const OpenFileResult(
        OpenFileStatus.noAppToOpen,
        'No app is associated with this file type',
      ),
      _ => OpenFileResult(
        OpenFileStatus.error,
        'ShellExecute failed with code $code',
      ),
    };
  } finally {
    malloc.free(file);
    if (initialized) coUninitialize();
  }
}

/// Windows OPENASINFO.
final class _OpenAsInfo extends Struct {
  external Pointer<Utf16> file;
  external Pointer<Utf16> fileClass;
  @Uint32()
  external int flags;
}
