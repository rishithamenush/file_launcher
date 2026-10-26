import 'dart:ui' show Rect;
import 'package:file_launcher/file_launcher.dart';
import 'package:file_launcher/file_launcher_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLauncher extends FileLauncherPlatform {
  final calls = <String>[];
  bool fail = false;
  String? lastPath;
  bool? lastChooser;
  Rect? lastOrigin;

  Future<OpenFileResult> _record(String call, String path) async {
    calls.add(call);
    lastPath = path;
    if (fail) throw StateError('failure');
    return const OpenFileResult(OpenFileStatus.done, 'ok');
  }

  @override
  Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) {
    lastChooser = showAppChooser;
    lastOrigin = sharePositionOrigin;
    return _record('open', filePath);
  }

  @override
  Future<OpenFileResult> share(
    String filePath, {
    String? title,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) {
    lastOrigin = sharePositionOrigin;
    return _record('share', filePath);
  }

  @override
  Future<OpenFileResult> openBytes(
    Uint8List bytes, {
    required String fileName,
    String? title,
    String? mimeType,
    bool showAppChooser = false,
    Rect? sharePositionOrigin,
  }) => _record('openBytes', fileName);

  @override
  Future<bool> clearCache() async {
    calls.add('clearCache');
    if (fail) throw StateError('failure');
    return true;
  }
}

void main() {
  late FileLauncherPlatform previous;
  late FakeLauncher fake;
  setUp(() {
    previous = FileLauncherPlatform.instance;
    fake = FakeLauncher();
    FileLauncherPlatform.instance = fake;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    FileLauncherPlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
  });
  test('supported platforms delegate', () async {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect((await FileLauncher.open('/file.txt')).isSuccess, isTrue);
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect((await FileLauncher.open(r'C:\file.txt')).isSuccess, isTrue);
    expect(fake.calls, List.filled(5, 'open'));
  });
  test('unsupported platforms never invoke an implementation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(
      (await FileLauncher.open('/file.txt')).status,
      OpenFileStatus.unsupportedPlatform,
    );
    expect(
      (await FileLauncher.share('/file.txt')).status,
      OpenFileStatus.unsupportedPlatform,
    );
    expect(
      (await FileLauncher.openBytes(Uint8List(1), fileName: 'a.txt')).status,
      OpenFileStatus.unsupportedPlatform,
    );
    expect(await FileLauncher.clearCache(), isFalse);
    expect(fake.calls, isEmpty);
  });
  test('invalid paths never reach native code', () async {
    for (final path in [
      '',
      'relative.txt',
      'file://server/file.txt',
      'file:///a?query',
      '/a\u0000b',
      r'C:\windows-only.txt',
    ]) {
      expect(
        (await FileLauncher.open(path)).status,
        OpenFileStatus.invalidPath,
      );
      expect(
        (await FileLauncher.share(path)).status,
        OpenFileStatus.invalidPath,
      );
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    for (final path in ['/unix.txt', r'C:file.txt', r'relative\file.txt']) {
      expect(
        (await FileLauncher.open(path)).status,
        OpenFileStatus.invalidPath,
      );
    }
    expect(fake.calls, isEmpty);
  });
  test('file URIs become decoded local paths', () async {
    await FileLauncher.open('file:///docs/Price%20list.pdf');
    expect(fake.lastPath, '/docs/Price list.pdf');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await FileLauncher.share('file:///C:/Users/me/a%20b.pdf');
    expect(fake.lastPath, r'C:\Users\me\a b.pdf');
    await FileLauncher.open(r'\\server\share\file.pdf');
    expect(fake.lastPath, r'\\server\share\file.pdf');
  });
  test('options are forwarded', () async {
    const origin = Rect.fromLTWH(10, 20, 30, 40);
    await FileLauncher.open(
      '/a.pdf',
      showAppChooser: true,
      sharePositionOrigin: origin,
    );
    expect(fake.lastChooser, isTrue);
    expect(fake.lastOrigin, origin);
    await FileLauncher.share('/a.pdf', sharePositionOrigin: origin);
    expect(fake.calls, ['open', 'share']);
  });
  test('openBytes requires a single-segment file name', () async {
    for (final name in ['', '.', '..', 'a/b.pdf', r'a\b.pdf', 'a\u0000b']) {
      expect(
        (await FileLauncher.openBytes(Uint8List(1), fileName: name)).status,
        OpenFileStatus.invalidPath,
      );
    }
    expect(fake.calls, isEmpty);
    final result = await FileLauncher.openBytes(
      Uint8List(0),
      fileName: 'Invoice #4.pdf',
    );
    expect(result.isSuccess, isTrue);
    expect(fake.lastPath, 'Invoice #4.pdf');
  });
  test('exceptions from replacement implementations are contained', () async {
    fake.fail = true;
    expect((await FileLauncher.open('/file.txt')).status, OpenFileStatus.error);
    expect(
      (await FileLauncher.share('/file.txt')).status,
      OpenFileStatus.error,
    );
    expect(
      (await FileLauncher.openBytes(Uint8List(1), fileName: 'a.txt')).status,
      OpenFileStatus.error,
    );
    expect(await FileLauncher.clearCache(), isFalse);
  });
  test('result decoding permits an absent message', () {
    final result = OpenFileResult.fromMap({'status': 'shareSheet'});
    expect(result.isSuccess, isTrue);
    expect(result.message, isEmpty);
    expect(result.toString(), contains('shareSheet'));
  });
}
