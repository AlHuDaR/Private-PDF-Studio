import 'dart:typed_data';

/// Stable codes only: backend messages and document contents never reach logs/UI.
enum Failure {
  invalidPdf,
  encrypted,
  tooLarge,
  tooManyFiles,
  tooManyPages,
  emptySelection,
  invalidPage,
  cancelled,
  busy,
  exportFailed,
  fileAccess,
  existingFile,
  engineUnavailable,
}

class StudioException implements Exception {
  const StudioException(this.code);
  final Failure code;
}

class Limits {
  static const fileBytes = 20 * 1024 * 1024;
  static const totalBytes = 50 * 1024 * 1024;
  static const files = 10;
  static const pages = 500;
  static const outputBytes = 100 * 1024 * 1024;
}

class Cancellation {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) {
      throw const StudioException(Failure.cancelled);
    }
  }
}

class PdfInput {
  PdfInput(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class SourceInfo {
  const SourceInfo(this.id, this.name, this.byteLength, this.pageCount);
  final int id;
  final String name;
  final int byteLength;
  final int pageCount;
}

class PageRef {
  const PageRef(this.sourceId, this.index, [this.turns = 0]);
  final int sourceId;
  final int index;
  final int turns;
  PageRef rotate() => PageRef(sourceId, index, (turns + 1) % 4);
}

typedef Progress = void Function(int completed, int total);

abstract interface class PdfEngine {
  Future<List<SourceInfo>> import(
    List<PdfInput> files,
    Cancellation cancellation,
    Progress progress,
  );
  Future<Uint8List> export(
    List<PageRef> pages,
    Cancellation cancellation,
    Progress progress,
  );
  Future<void> clear();
}

/// Names are display/download suggestions, never interpreted as paths.
String safePdfName(String raw) {
  var name = raw
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(
        RegExp(r'[\x00-\x1f\x7f<>:"|?*\u202a-\u202e\u2066-\u2069]'),
        '_',
      )
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  if (name.toLowerCase().endsWith('.pdf')) {
    name = name.substring(0, name.length - 4);
  }
  name = name.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (name.isEmpty) {
    name = 'document';
  }
  if (RegExp(
    r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(name)) {
    name = '_$name';
  }
  // Count Unicode scalar values so truncation cannot split a surrogate pair.
  name = String.fromCharCodes(name.runes.take(80));
  return '$name.pdf';
}

void validatePdfBytes(Uint8List bytes) {
  if (bytes.length > Limits.fileBytes) {
    throw const StudioException(Failure.tooLarge);
  }
  if (bytes.length < 16 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
    throw const StudioException(Failure.invalidPdf);
  }
  final tail = bytes.skip(bytes.length > 2048 ? bytes.length - 2048 : 0);
  if (!String.fromCharCodes(tail).contains('%%EOF')) {
    throw const StudioException(Failure.invalidPdf);
  }
}
