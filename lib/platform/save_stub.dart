import 'dart:typed_data';
import '../core/model.dart';
import 'files.dart';

Future<SaveResult> savePdf(Uint8List bytes, String name) async =>
    throw const StudioException(Failure.fileAccess);

Future<List<PdfInput>?> pickAndroid(
  int remainingFiles,
  int remainingBytes,
) async => null;
