import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import '../core/model.dart';
import 'files.dart';
import 'write_new_file.dart';

Future<SaveResult> savePdf(Uint8List bytes, String name) async {
  if (Platform.isAndroid) {
    final saved = await const MethodChannel(
      'private_pdf_studio/files',
    ).invokeMethod<bool>('savePdf', {'name': name, 'bytes': bytes});
    return saved == true ? SaveResult.saved : SaveResult.cancelled;
  }
  final location = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: [LocalFiles.pdfType],
  );
  if (location == null) {
    return SaveResult.cancelled;
  }
  await writeNewPdf(location.path, bytes);
  return SaveResult.saved;
}

Future<List<PdfInput>?> pickAndroid(
  int remainingFiles,
  int remainingBytes,
) async {
  if (!Platform.isAndroid) {
    return null;
  }
  try {
    final selected =
        await const MethodChannel(
          'private_pdf_studio/files',
        ).invokeListMethod<dynamic>('openPdfs', {
          'remainingFiles': remainingFiles,
          'remainingBytes': remainingBytes,
        }) ??
        [];
    return selected
        .map((entry) {
          final file = entry as Map;
          final bytes = file['bytes'] as Uint8List;
          validatePdfBytes(bytes);
          return PdfInput(safePdfName(file['name'] as String), bytes);
        })
        .toList(growable: false);
  } on PlatformException catch (error) {
    throw StudioException(switch (error.code) {
      'too_large' => Failure.tooLarge,
      'too_many_files' => Failure.tooManyFiles,
      'busy' => Failure.busy,
      _ => Failure.fileAccess,
    });
  }
}
