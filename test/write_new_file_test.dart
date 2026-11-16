import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_pdf_studio/core/model.dart';
import 'package:private_pdf_studio/platform/write_new_file.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pdf-output-test-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test(
    'exclusive output creation preserves an existing original byte for byte',
    () async {
      final path = '${temp.path}${Platform.pathSeparator}original.pdf';
      final original = Uint8List.fromList([1, 2, 3]);
      await File(path).writeAsBytes(original);
      await expectLater(
        writeNewPdf(path, Uint8List.fromList([9])),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            Failure.existingFile,
          ),
        ),
      );
      expect(await File(path).readAsBytes(), original);
    },
  );
  test('new output is fully written and refuses a second export', () async {
    final path = '${temp.path}${Platform.pathSeparator}new.pdf';
    final bytes = Uint8List.fromList([4, 5, 6]);
    await writeNewPdf(path, bytes);
    expect(await File(path).readAsBytes(), bytes);
    await expectLater(
      writeNewPdf(path, Uint8List.fromList([7])),
      throwsA(isA<StudioException>()),
    );
    expect(await File(path).readAsBytes(), bytes);
  });
}
