import 'package:file_launcher/file_launcher.dart';
import 'package:file_launcher/file_launcher_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelFileLauncher();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  void answer(Object? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(
      platform.methodChannel,
      (call) async => handler(call),
    );
  }

  tearDown(
    () => messenger.setMockMethodCallHandler(platform.methodChannel, null),
  );

  test('forwards all arguments and maps success', () async {
    late MethodCall sent;
    answer((call) {
      sent = call;
      return {'status': 'done', 'message': 'ok'};
    });
    final result = await platform.open(
      '/Price list.pdf',
      title: 'Price list',
      mimeType: 'application/pdf',
    );
    expect(sent.method, 'open');
    expect(sent.arguments, {
      'path': '/Price list.pdf',
      'title': 'Price list',
      'mimeType': 'application/pdf',
    });
    expect(result.status, OpenFileStatus.done);
    expect(result.message, 'ok');
  });
  test('maps all native statuses and their success semantics', () async {
    for (final status in OpenFileStatus.values) {
      answer((_) => {'status': status.name, 'message': 'message'});
      final result = await platform.open('/a');
      expect(result.status, status);
      expect(
        result.isSuccess,
        [OpenFileStatus.done, OpenFileStatus.shareSheet].contains(status),
      );
    }
  });
  test('malformed replies never escape as exceptions', () async {
    for (final reply in <Object?>[
      null,
      'bad',
      42,
      <String, Object?>{},
      {'status': 'unknown'},
      {'status': 2},
      {'status': 'done', 'message': 42},
    ]) {
      answer((_) => reply);
      expect((await platform.open('/a')).status, OpenFileStatus.error);
    }
  });
  test('platform errors become diagnostic results', () async {
    answer(
      (_) => throw PlatformException(code: 'denied', message: 'Not readable'),
    );
    final result = await platform.open('/a');
    expect(result.status, OpenFileStatus.error);
    expect(result.message, 'Not readable');
  });
  test('missing plugin returns an actionable error', () async {
    expect((await platform.open('/a')).status, OpenFileStatus.error);
  });
}
