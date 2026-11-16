import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_pdf_studio/core/model.dart';
import 'fixtures/fixtures.dart';

void main() {
  test(
    'sanitize paths, controls, bidi overrides, reserved names and suffix',
    () {
      expect(safePdfName('../../CON.pdf'), '_CON.pdf');
      expect(safePdfName(r'C:\private\report.pdf'), 'report.pdf');
      expect(safePdfName('a\u202eb\u0000.pdf'), 'a_b_.pdf');
      expect(safePdfName('...'), 'document.pdf');
      expect(safePdfName('تقرير.pdf'), 'تقرير.pdf');
      expect(safePdfName('X.PDF'), 'X.pdf');
      expect(safePdfName('a' * 200).length, 84);
    },
  );
  test('reject non-PDF, truncated and oversized input before parser', () {
    expect(
      () => validatePdfBytes(Uint8List(12)),
      throwsA(isA<StudioException>()),
    );
    expect(
      () => validatePdfBytes(fixture('valid.pdf').sublist(0, 100)),
      throwsA(isA<StudioException>()),
    );
    expect(
      () => validatePdfBytes(Uint8List(Limits.fileBytes + 1)),
      throwsA(
        isA<StudioException>().having((e) => e.code, 'code', Failure.tooLarge),
      ),
    );
    validatePdfBytes(fixture('valid.pdf'));
  });
  test('rotation is additive and cycles after four turns', () {
    var ref = const PageRef(2, 3);
    for (var i = 0; i < 4; i++) {
      ref = ref.rotate();
    }
    expect(ref.turns, 0);
    expect(ref.index, 3);
    expect(ref.sourceId, 2);
  });
}
