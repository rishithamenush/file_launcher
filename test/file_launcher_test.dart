import 'package:file_launcher/file_launcher.dart';
import 'package:file_launcher/file_launcher_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLauncher extends FileLauncherPlatform {
  int calls = 0;
  bool fail = false;
  @override
  Future<OpenFileResult> open(
    String filePath, {
    String? title,
    String? mimeType,
  }) async {
    calls++;
    if (fail) throw StateError('failure');
    return const OpenFileResult(OpenFileStatus.done, 'ok');
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
  test('mobile calls delegate', () async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      expect((await FileLauncher.open('/file.txt')).isSuccess, isTrue);
    }
    expect(fake.calls, 2);
  });
  test(
    'desktop platforms return unsupported without invoking native code',
    () async {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          (await FileLauncher.open('/file.txt')).status,
          OpenFileStatus.unsupportedPlatform,
        );
      }
      expect(fake.calls, 0);
    },
  );
  test('invalid paths never reach native code', () async {
    for (final path in ['', 'relative.txt', 'file:///file.txt', '/a\u0000b']) {
      expect((await FileLauncher.open(path)).status, OpenFileStatus.error);
    }
    expect(fake.calls, 0);
  });
  test('exceptions from replacement implementations are contained', () async {
    fake.fail = true;
    expect((await FileLauncher.open('/file.txt')).status, OpenFileStatus.error);
  });
  test('result decoding permits an absent message', () {
    final result = OpenFileResult.fromMap({'status': 'shareSheet'});
    expect(result.isSuccess, isTrue);
    expect(result.message, isEmpty);
    expect(result.toString(), contains('shareSheet'));
  });
}
