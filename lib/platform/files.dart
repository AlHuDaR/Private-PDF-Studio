import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import '../core/model.dart';
import 'save_stub.dart'
    if (dart.library.io) 'save_native.dart'
    if (dart.library.js_interop) 'save_web.dart'
    as platform;

enum SaveResult { saved, cancelled, downloadStarted }

abstract interface class Files {
  Future<List<PdfInput>> pick({
    required int remainingFiles,
    required int remainingBytes,
  });
  Future<SaveResult> save(Uint8List bytes, String suggestedName);
}

class LocalFiles implements Files {
  static const pdfType = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
    uniformTypeIdentifiers: ['com.adobe.pdf'],
  );

  @override
  Future<List<PdfInput>> pick({
    required int remainingFiles,
    required int remainingBytes,
  }) async {
    final androidFiles = await platform.pickAndroid(
      remainingFiles,
      remainingBytes,
    );
    if (androidFiles != null) {
      return androidFiles;
    }
    final selected = await openFiles(acceptedTypeGroups: [pdfType]);
    if (selected.length > remainingFiles) {
      throw const StudioException(Failure.tooManyFiles);
    }
    final result = <PdfInput>[];
    var total = 0;
    for (final file in selected) {
      final length = await file.length();
      if (length > Limits.fileBytes || total + length > remainingBytes) {
        throw const StudioException(Failure.tooLarge);
      }
      final builder = BytesBuilder(copy: false);
      // Enforce limits during reads too: file metadata can be stale/untrusted.
      await for (final chunk in file.openRead()) {
        if (builder.length + chunk.length > Limits.fileBytes ||
            total + builder.length + chunk.length > remainingBytes) {
          throw const StudioException(Failure.tooLarge);
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      total += bytes.length;
      validatePdfBytes(bytes);
      result.add(PdfInput(safePdfName(file.name), bytes));
    }
    return result;
  }

  @override
  Future<SaveResult> save(Uint8List bytes, String suggestedName) =>
      platform.savePdf(bytes, safePdfName(suggestedName));
}
