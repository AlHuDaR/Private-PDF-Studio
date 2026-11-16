import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'core/pdfrx_engine.dart';
import 'platform/files.dart';
import 'ui/studio_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'Noto Sans / Noto Sans Arabic': 'Noto-OFL.txt',
      'pdfrx / pdfrx_engine': 'pdfrx-MIT.txt',
      'file_selector': 'file-selector-BSD.txt',
      'PDFium': 'PDFium-BSD.txt',
      'PDFium third-party components': 'PDFium-third-party.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString('assets/licenses/${entry.value}'));
    }
  });
  runApp(
    StudioApp(
      engine: LocalPdfEngine(),
      files: LocalFiles(),
      initialize: pdfrxFlutterInitialize,
    ),
  );
}
