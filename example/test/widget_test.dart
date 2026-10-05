import 'package:file_launcher_example/main.dart';
import 'package:file_launcher_example/samples.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the file gallery and real sample count', (tester) async {
    await tester.pumpWidget(const FileLauncherExample());
    expect(find.text('file_launcher'), findsOneWidget);
    expect(find.text('${fileSamples.length} samples'), findsOneWidget);
    expect(find.text('PDF document'), findsOneWidget);
    expect(
      find.text('Choose a sample to open on this device.'),
      findsOneWidget,
    );
  });
  testWidgets('Audio filter shows audio samples without documents', (
    tester,
  ) async {
    await tester.pumpWidget(const FileLauncherExample());
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Audio'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Audio'));
    await tester.pumpAndSettle();
    expect(find.text('MP3 audio'), findsOneWidget);
    expect(find.text('M4A audio'), findsOneWidget);
    expect(find.text('PDF document'), findsNothing);
  });
  testWidgets('every gallery entry has a nonempty bundled fixture', (
    tester,
  ) async {
    for (final sample in fileSamples) {
      final bytes = await rootBundle.load('assets/${sample.name}');
      expect(bytes.lengthInBytes, greaterThan(0), reason: sample.name);
    }
  });
}
