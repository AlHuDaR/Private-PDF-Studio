import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'model.dart';

/// The same PDFium API uses a native worker on Android/Windows and a bundled
/// WASM worker in browsers. No URI, remote-file, viewer or scripting API is used.
class LocalPdfEngine implements PdfEngine {
  final Map<int, PdfDocument> _documents = {};
  final Map<int, SourceInfo> _sources = {};
  int _nextId = 0;
  bool _busy = false;

  void _enter() {
    if (_busy) {
      throw const StudioException(Failure.busy);
    }
    _busy = true;
  }

  @override
  Future<List<SourceInfo>> import(
    List<PdfInput> files,
    Cancellation cancellation,
    Progress progress,
  ) async {
    _enter();
    final pending = <int, PdfDocument>{};
    final infos = <SourceInfo>[];
    try {
      cancellation.check();
      if (_documents.length + files.length > Limits.files) {
        throw const StudioException(Failure.tooManyFiles);
      }
      var byteCount = _sources.values.fold(0, (n, s) => n + s.byteLength);
      var pageCount = _sources.values.fold(0, (n, s) => n + s.pageCount);
      // Validate the whole batch before invoking the parser.
      for (final file in files) {
        validatePdfBytes(file.bytes);
        byteCount += file.bytes.length;
        if (byteCount > Limits.totalBytes) {
          throw const StudioException(Failure.tooLarge);
        }
      }
      for (final file in files) {
        cancellation.check();
        final id = _nextId++;
        final doc = await PdfDocument.openData(
          file.bytes,
          sourceName: 'source:$id',
          passwordProvider: () => null,
        );
        pending[id] = doc;
        cancellation.check();
        // Includes encryption with an empty user password / owner restrictions.
        if (doc.isEncrypted) {
          throw const StudioException(Failure.encrypted);
        }
        if (doc.pages.isEmpty) {
          throw const StudioException(Failure.invalidPdf);
        }
        pageCount += doc.pages.length;
        if (pageCount > Limits.pages) {
          throw const StudioException(Failure.tooManyPages);
        }
        infos.add(
          SourceInfo(
            id,
            safePdfName(file.name),
            file.bytes.length,
            doc.pages.length,
          ),
        );
        progress(infos.length, files.length);
        await Future<void>.delayed(Duration.zero);
      }
      cancellation.check();
      _documents.addAll(pending);
      for (final info in infos) {
        _sources[info.id] = info;
      }
      pending.clear(); // ownership transferred atomically
      return infos;
    } on StudioException {
      rethrow;
    } on PdfPasswordException {
      throw const StudioException(Failure.encrypted);
    } catch (_) {
      throw const StudioException(Failure.invalidPdf);
    } finally {
      try {
        for (final doc in pending.values) {
          await doc.dispose();
        }
      } finally {
        _busy = false;
      }
    }
  }

  @override
  Future<Uint8List> export(
    List<PageRef> pages,
    Cancellation cancellation,
    Progress progress,
  ) async {
    _enter();
    PdfDocument? output;
    PdfDocument? verification;
    try {
      cancellation.check();
      if (pages.isEmpty) {
        throw const StudioException(Failure.emptySelection);
      }
      if (pages.length > Limits.pages) {
        throw const StudioException(Failure.tooManyPages);
      }
      final selected = <PdfPage>[];
      for (final ref in pages) {
        cancellation.check();
        final doc = _documents[ref.sourceId];
        if (doc == null ||
            ref.index < 0 ||
            ref.index >= doc.pages.length ||
            ref.turns < 0 ||
            ref.turns > 3) {
          throw const StudioException(Failure.invalidPage);
        }
        final page = doc.pages[ref.index];
        selected.add(page.rotatedBy(PdfPageRotation.values[ref.turns]));
        progress(selected.length, pages.length + 2);
        await Future<void>.delayed(Duration.zero);
      }
      output = await PdfDocument.createNew(sourceName: 'output');
      output.pages = selected;
      cancellation.check();
      // encodePdf assembles once internally while all source handles are alive.
      progress(pages.length + 1, pages.length + 2);
      final bytes = await output.encodePdf();
      cancellation.check();
      if (bytes.length > Limits.outputBytes) {
        throw const StudioException(Failure.tooLarge);
      }
      // Verify encoded output before offering it for saving.
      verification = await PdfDocument.openData(
        bytes,
        sourceName: 'verification',
        passwordProvider: () => null,
      );
      if (verification.pages.length != selected.length) {
        throw const StudioException(Failure.exportFailed);
      }
      for (var i = 0; i < selected.length; i++) {
        if (verification.pages[i].rotation != selected[i].rotation) {
          throw const StudioException(Failure.exportFailed);
        }
      }
      cancellation.check();
      progress(pages.length + 2, pages.length + 2);
      return bytes;
    } on StudioException {
      rethrow;
    } catch (_) {
      throw const StudioException(Failure.exportFailed);
    } finally {
      try {
        await verification?.dispose();
        await output?.dispose();
      } finally {
        _busy = false;
      }
    }
  }

  @override
  Future<void> clear() async {
    _enter();
    try {
      for (final document in _documents.values) {
        await document.dispose();
      }
      _documents.clear();
      _sources.clear();
    } finally {
      _busy = false;
    }
  }
}
