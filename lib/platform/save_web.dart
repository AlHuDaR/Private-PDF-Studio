import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../core/model.dart';
import 'files.dart';

Future<SaveResult> savePdf(Uint8List bytes, String name) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Keep the blob alive while the browser consumes the initiated download.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  // Browsers do not expose whether the user ultimately saved the download.
  return SaveResult.downloadStarted;
}

Future<List<PdfInput>?> pickAndroid(
  int remainingFiles,
  int remainingBytes,
) async => null;
