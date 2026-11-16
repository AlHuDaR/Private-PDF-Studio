import 'dart:io';
import 'dart:typed_data';
import '../core/model.dart';

/// Refuse existing paths even when a save dialog has confirmed replacement.
Future<void> writeNewPdf(String path, Uint8List bytes) async {
  final file = File(path);
  try {
    await file.create(exclusive: true);
  } on PathExistsException {
    throw const StudioException(Failure.existingFile);
  }
  try {
    await file.writeAsBytes(bytes, flush: true);
  } catch (_) {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Preserve the underlying write failure; cleanup is best effort.
    }
    rethrow;
  }
}
