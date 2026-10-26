import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_launcher/file_launcher.dart' hide FileLauncherDesktop;
import 'package:file_launcher/src/file_launcher_desktop.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProcess implements Process {
  FakeProcess(Future<int> exit, {String errors = ''})
    : exitCode = exit,
      stderr = Stream.value(errors.codeUnits);
  @override
  final Future<int> exitCode;
  @override
  final Stream<List<int>> stderr;
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late File file;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('file_launcher_desktop_');
    file = File('${temp.path}/Price list.pdf')..writeAsStringSync('%PDF');
  });
  tearDown(() => temp.delete(recursive: true));

  FileLauncherDesktop linux(Future<Process> Function(List<String>) start) =>
      FileLauncherDesktop(
        operatingSystem: 'linux',
        startProcess: (executable, arguments) {
          expect(executable, 'xdg-open');
          return start(arguments);
        },
        cacheDirectory: Directory('${temp.path}/cache'),
        exitTimeout: const Duration(milliseconds: 50),
      );

  test('Linux passes the path as a single argument', () async {
    final sent = <List<String>>[];
    final launcher = linux((arguments) async {
      sent.add(arguments);
      return FakeProcess(Future.value(0));
    });
    final result = await launcher.open(file.path);
    expect(result.status, OpenFileStatus.done);
    expect(sent, [
      [file.path],
    ]);
  });
  test('Linux maps xdg-open exit codes', () async {
    final expected = {
      2: OpenFileStatus.fileNotFound,
      3: OpenFileStatus.noAppToOpen,
      4: OpenFileStatus.noAppToOpen,
      1: OpenFileStatus.error,
    };
    for (final MapEntry(key: code, value: status) in expected.entries) {
      final launcher = linux(
        (_) async => FakeProcess(Future.value(code), errors: 'reason $code'),
      );
      final result = await launcher.open(file.path);
      expect(result.status, status);
      expect(result.message, 'reason $code');
    }
  });
  test('a launcher still running after the timeout is accepted', () async {
    final launcher = linux((_) async => FakeProcess(Completer<int>().future));
    expect((await launcher.open(file.path)).status, OpenFileStatus.done);
  });
  test('missing xdg-open is reported, not thrown', () async {
    final launcher = linux(
      (_) => throw const ProcessException('xdg-open', [], 'missing'),
    );
    expect((await launcher.open(file.path)).status, OpenFileStatus.noAppToOpen);
  });
  test('missing files and directories are rejected before launch', () async {
    final launcher = linux((_) => fail('must not launch'));
    expect(
      (await launcher.open('${temp.path}/absent.pdf')).status,
      OpenFileStatus.fileNotFound,
    );
    expect(
      (await launcher.open(temp.path)).status,
      OpenFileStatus.fileNotFound,
    );
  });
  test('Windows routes through the shell with the chooser flag', () async {
    final sent = <(String, bool)>[];
    final launcher = FileLauncherDesktop(
      operatingSystem: 'windows',
      shellOpen: (path, chooser) async {
        sent.add((path, chooser));
        return const OpenFileResult(OpenFileStatus.done, 'ok');
      },
    );
    await launcher.open(file.path);
    await launcher.open(file.path, showAppChooser: true);
    expect(sent, [(file.path, false), (file.path, true)]);
  });
  test('share is not available on desktop', () async {
    final launcher = linux((_) => fail('must not launch'));
    expect(
      (await launcher.share(file.path)).status,
      OpenFileStatus.unsupportedPlatform,
    );
  });
  test('openBytes writes a private copy and clearCache removes it', () async {
    final opened = <String>[];
    final launcher = linux((arguments) async {
      opened.addAll(arguments);
      return FakeProcess(Future.value(0));
    });
    final result = await launcher.openBytes(
      Uint8List.fromList([1, 2, 3]),
      fileName: 'report.pdf',
    );
    expect(result.status, OpenFileStatus.done);
    final copy = File(opened.single);
    expect(copy.path, startsWith('${temp.path}/cache/'));
    expect(copy.path, endsWith('/report.pdf'));
    expect(copy.readAsBytesSync(), [1, 2, 3]);
    expect(await launcher.clearCache(), isTrue);
    expect(copy.existsSync(), isFalse);
    expect(file.existsSync(), isTrue);
    expect(await launcher.clearCache(), isTrue);
  });
}
