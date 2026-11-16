# Private PDF Studio

A completely free, offline-first Flutter PDF toolkit. No accounts, subscriptions,
advertising, AI, document uploads or remote processing. Arabic and English UI
with RTL/LTR support and a locally bundled Arabic font.

## Phase 1 implementation

- Import local PDFs; merge all displayed pages into a new PDF.
- Split/extract selected pages into a separate PDF; repeat for each partition.
- Reorder pages with accessible up/down buttons; remove pages from the output.
- Rotate pages clockwise in 90° steps, preserving the original page angle.
- Export a new copy through Android's document picker, Windows' save dialog or
  a browser download. Windows refuses existing destinations.
- Local progress, cooperative cancellation and localized errors. Imports are
  transactional; clear releases loaded documents.
- Encrypted PDFs are explicitly unsupported, including empty-password files.

The backend is PDFium, using native workers on Android/Windows and bundled WASM
in browsers. There is no server component. This phase edits pages, not text or
images; OCR, Office conversion, redaction and signature preservation are outside
scope. See [security limits](docs/SECURITY.md).

**Validation status:** direct Chromium/PDFium WASM backend tests passed, including
merge, extract, reorder, rotation and Arabic text preservation offline. The
Flutter application has not yet compiled or passed its tests in this environment:
the Dart SDK download is blocked by network policy. Android and Windows app
behavior and Web/PWA installation are not certified. See the exact
[evidence and certification checklist](docs/VERIFICATION.md).

## Develop

Use Flutter **3.50.0** and Dart >=3.13. Native builds need a C toolchain. Read
[AGENTS.md](AGENTS.md) before editing and use a separate feature branch.

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test --reporter expanded
flutter run -d chrome     # development only
# Android: flutter devices, then flutter run -d DEVICE_ID
# Windows host: flutter run -d windows
```

The first successful dependency resolution must be committed as `pubspec.lock`
after review. It is currently absent because the SDK could not start. Direct
dependencies are pinned; full reproducibility is pending that lockfile.

For a self-contained Web/PWA bundle:

```sh
tool/build_web.sh
# Serve the complete build/web directory over localhost or HTTPS.
```

This bundles CanvasKit, the PDFium worker/WASM, font and a versioned static-only
offline cache. Initial installation needs an application download; verify a
completed cache install before relying on offline startup. Development mode is
not an offline-PWA certification build.

```sh
flutter build apk --release
# Windows host with Visual Studio's Desktop development with C++ workload:
flutter build windows --release
```

The APK is debug-signed for evaluation, not a store release. CI builds Android,
Windows and Web artifacts, runs native tests and browser integration tests; CI
results are pending execution. It does not automatically merge or deploy.

[Dependency/platform/license review](docs/DEPENDENCIES.md) ·
[Security design](docs/SECURITY.md) ·
[Tests and manual platform certification](docs/VERIFICATION.md)
