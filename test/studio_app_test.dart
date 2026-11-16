import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_pdf_studio/core/model.dart';
import 'package:private_pdf_studio/platform/files.dart';
import 'package:private_pdf_studio/ui/studio_app.dart';
import 'fixtures/fixtures.dart';

class TestEngine implements PdfEngine {
  List<PageRef>? exported;
  Failure? importFailure;
  @override
  Future<List<SourceInfo>> import(
    List<PdfInput> files,
    Cancellation cancellation,
    Progress progress,
  ) async {
    if (importFailure != null) {
      throw StudioException(importFailure!);
    }
    return [const SourceInfo(0, 'تقرير.pdf', 100, 2)];
  }

  @override
  Future<Uint8List> export(
    List<PageRef> pages,
    Cancellation cancellation,
    Progress progress,
  ) async {
    exported = pages;
    return fixture('valid.pdf');
  }

  @override
  Future<void> clear() async {}
}

class TestFiles implements Files {
  int saves = 0;
  @override
  Future<List<PdfInput>> pick({
    required int remainingFiles,
    required int remainingBytes,
  }) async => [PdfInput('تقرير.pdf', fixture('valid.pdf'))];
  @override
  Future<SaveResult> save(Uint8List bytes, String suggestedName) async {
    saves++;
    return SaveResult.cancelled;
  }
}

void main() {
  testWidgets(
    'Arabic/English switch changes direction and localized controls',
    (tester) async {
      await tester.pumpWidget(
        StudioApp(
          engine: TestEngine(),
          files: TestFiles(),
          initialize: () async {},
        ),
      );
      expect(find.text('Import PDFs'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(find.text('استيراد ملفات PDF'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('استيراد ملفات PDF'))),
        TextDirection.rtl,
      );
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.text('Import PDFs'))),
        TextDirection.ltr,
      );
    },
  );

  testWidgets(
    'select, reorder, rotate and extract pass the actual output plan',
    (tester) async {
      final engine = TestEngine();
      final files = TestFiles();
      await tester.pumpWidget(
        StudioApp(engine: engine, files: files, initialize: () async {}),
      );
      await tester.tap(find.text('Import PDFs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move page down').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rotate 90° clockwise').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Split / extract selected'));
      await tester.pumpAndSettle();
      expect(engine.exported!.length, 1);
      expect(engine.exported!.single.index, 1);
      expect(engine.exported!.single.turns, 1);
      expect(files.saves, 1);
      expect(
        find.text('Save cancelled. Your workspace is unchanged.'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNWidgets(2));
    },
  );

  testWidgets('errors stay localized and failed import offers no export', (
    tester,
  ) async {
    final engine = TestEngine()..importFailure = Failure.encrypted;
    await tester.pumpWidget(
      StudioApp(engine: engine, files: TestFiles(), initialize: () async {}),
    );
    await tester.tap(find.text('Import PDFs'));
    await tester.pumpAndSettle();
    expect(
      find.text('Encrypted PDFs are not supported. No files were added.'),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(
      find.text('الملفات المشفرة غير مدعومة. لم تُضف ملفات.'),
      findsOneWidget,
    );
  });

  testWidgets('narrow Arabic layout imports without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StudioApp(
        engine: TestEngine(),
        files: TestFiles(),
        initialize: () async {},
      ),
    );
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استيراد ملفات PDF'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });
}
