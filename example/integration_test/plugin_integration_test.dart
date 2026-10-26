import 'dart:io';
import 'dart:typed_data';
import 'package:file_launcher/file_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native plugin returns missing-file result without a viewer', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'file_launcher_test_',
    );
    try {
      final result = await FileLauncher.open(
        '${directory.path}/absent.pdf',
      ).timeout(const Duration(seconds: 5));
      expect(result.status, OpenFileStatus.fileNotFound);
      expect(
        (await FileLauncher.open(directory.path)).status,
        OpenFileStatus.fileNotFound,
      );
      expect(
        (await FileLauncher.share('${directory.path}/absent.pdf')).status,
        OpenFileStatus.fileNotFound,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
  testWidgets('native plugin validates names and clears its cache', (
    tester,
  ) async {
    final result = await FileLauncher.openBytes(
      Uint8List(1),
      fileName: 'nested/file.pdf',
    );
    expect(result.status, OpenFileStatus.invalidPath);
    expect(await FileLauncher.clearCache(), isTrue);
  });
}
