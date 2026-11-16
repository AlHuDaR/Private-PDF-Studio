// Shared real-engine assertions for native and browser integration runners.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:private_pdf_studio/core/model.dart';
import 'package:private_pdf_studio/core/pdfrx_engine.dart';
import 'fixtures/fixtures.dart';

void registerEngineTests(
  Future<void> Function() initialize, {
  bool integration = false,
}) {
  void check(String name, Future<void> Function() body) {
    if (integration) {
      testWidgets(name, (tester) async {
        await body();
      });
    } else {
      test(name, body);
    }
  }

  late LocalPdfEngine engine;
  void noop(int completed, int total) {}
  Matcher failure(Failure code) =>
      isA<StudioException>().having((e) => e.code, 'code', code);
  Future<List<SourceInfo>> load(String name) =>
      engine.import([PdfInput(name, fixture(name))], Cancellation(), noop);
  Future<PdfDocument> output(List<PageRef> refs) async {
    final bytes = await engine.export(refs, Cancellation(), noop);
    return PdfDocument.openData(bytes, sourceName: 'test-output');
  }

  setUpAll(initialize);
  setUp(() => engine = LocalPdfEngine());
  tearDown(() => engine.clear());

  check('real merge preserves page order across two source PDFs', () async {
    final a = (await load('valid.pdf')).single;
    final b = (await load('valid.pdf')).single;
    final doc = await output([
      for (final source in [a, b])
        for (var i = 0; i < source.pageCount; i++) PageRef(source.id, i),
    ]);
    try {
      expect(doc.pages.map((p) => p.width).toList(), [
        200,
        300,
        400,
        200,
        300,
        400,
      ]);
    } finally {
      await doc.dispose();
    }
  });

  check(
    'split/extract produces complementary partitions without changing source',
    () async {
      final source = (await load('valid.pdf')).single;
      final first = await output([PageRef(source.id, 1)]);
      final rest = await output([PageRef(source.id, 0), PageRef(source.id, 2)]);
      try {
        expect(first.pages.single.width, 300);
        expect(rest.pages.map((p) => p.width).toList(), [200, 400]);
      } finally {
        await first.dispose();
        await rest.dispose();
      }
    },
  );

  check(
    'reorder and rotate survive encoding; pre-existing rotation is additive',
    () async {
      final source = (await load('rotated.pdf')).single;
      final doc = await output([
        PageRef(source.id, 2, 1),
        PageRef(source.id, 0, 1),
      ]);
      try {
        expect(doc.pages[0].rotation, PdfPageRotation.clockwise90);
        expect(doc.pages[1].rotation, PdfPageRotation.clockwise180);
        expect(doc.pages[0].height, 400);
        expect(doc.pages[1].width, 200);
      } finally {
        await doc.dispose();
      }
    },
  );

  check('Arabic embedded text survives extract and rotate', () async {
    final source = (await load('arabic.pdf')).single;
    final doc = await output([PageRef(source.id, 0, 1)]);
    try {
      final text = (await doc.pages.single.loadText())!.fullText;
      expect(
        RegExp(r'[\u0600-\u06ff\ufb50-\ufdff\ufe70-\ufeff]').hasMatch(text),
        isTrue,
      );
      final image = await doc.pages.single.render(
        fullWidth: 200,
        fullHeight: 140,
      );
      expect(image, isNotNull);
      try {
        expect(image!.pixels.any((v) => v < 240), isTrue);
      } finally {
        image?.dispose();
      }
    } finally {
      await doc.dispose();
    }
  });

  for (final name in ['encrypted.pdf', 'empty-password.pdf']) {
    check('reject $name', () async {
      await expectLater(load(name), throwsA(failure(Failure.encrypted)));
    });
  }

  check(
    'malformed batch rolls back; previously loaded source remains usable',
    () async {
      final source = (await load('valid.pdf')).single;
      await expectLater(
        engine.import(
          [
            PdfInput('valid.pdf', fixture('valid.pdf')),
            PdfInput('malformed.pdf', fixture('malformed.pdf')),
          ],
          Cancellation(),
          noop,
        ),
        throwsA(failure(Failure.invalidPdf)),
      );
      final doc = await output([PageRef(source.id, 0)]);
      try {
        expect(doc.pages.length, 1);
      } finally {
        await doc.dispose();
      }
    },
  );

  check(
    'reject file count, page count, oversized and invalid selection',
    () async {
      await expectLater(
        engine.import(
          List.generate(11, (_) => PdfInput('valid.pdf', fixture('valid.pdf'))),
          Cancellation(),
          noop,
        ),
        throwsA(failure(Failure.tooManyFiles)),
      );
      await expectLater(
        engine.import(
          [PdfInput('huge.pdf', Uint8List(Limits.fileBytes + 1))],
          Cancellation(),
          noop,
        ),
        throwsA(failure(Failure.tooLarge)),
      );
      final source = (await load('valid.pdf')).single;
      await expectLater(output([]), throwsA(failure(Failure.emptySelection)));
      await expectLater(
        output([PageRef(source.id, -1)]),
        throwsA(failure(Failure.invalidPage)),
      );
      await expectLater(
        output([PageRef(source.id, 3)]),
        throwsA(failure(Failure.invalidPage)),
      );
      await expectLater(
        output(List.filled(501, PageRef(source.id, 0))),
        throwsA(failure(Failure.tooManyPages)),
      );
    },
  );

  check(
    'cancel import rolls back and cancel export leaves engine reusable',
    () async {
      final cancelled = Cancellation()..cancel();
      await expectLater(
        engine.import(
          [PdfInput('valid.pdf', fixture('valid.pdf'))],
          cancelled,
          noop,
        ),
        throwsA(failure(Failure.cancelled)),
      );
      final source = (await load('valid.pdf')).single;
      final token = Cancellation();
      await expectLater(
        engine.export([PageRef(source.id, 0), PageRef(source.id, 1)], token, (
          done,
          total,
        ) {
          token.cancel();
        }),
        throwsA(failure(Failure.cancelled)),
      );
      final doc = await output([PageRef(source.id, 0)]);
      try {
        expect(doc.pages.length, 1);
      } finally {
        await doc.dispose();
      }
    },
  );

  check(
    'source page limit rejects a structurally valid 501-page PDF',
    () async {
      await expectLater(
        load('too-many-pages.pdf'),
        throwsA(failure(Failure.tooManyPages)),
      );
    },
  );

  check(
    'mid-import cancellation rolls back and concurrent clear is refused',
    () async {
      final token = Cancellation();
      final pending = engine.import(
        [
          PdfInput('valid.pdf', fixture('valid.pdf')),
          PdfInput('arabic.pdf', fixture('arabic.pdf')),
        ],
        token,
        (done, total) {
          token.cancel();
        },
      );
      await expectLater(engine.clear(), throwsA(failure(Failure.busy)));
      await expectLater(pending, throwsA(failure(Failure.cancelled)));
      final source = (await load('valid.pdf')).single;
      await expectLater(
        output([PageRef(source.id - 1, 0)]),
        throwsA(failure(Failure.invalidPage)),
      );
    },
  );

  check('clearing invalidates old references', () async {
    final source = (await load('valid.pdf')).single;
    await engine.clear();
    await expectLater(
      output([PageRef(source.id, 0)]),
      throwsA(failure(Failure.invalidPage)),
    );
  });
}
