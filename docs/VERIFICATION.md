# Validation and release certification

## Evidence from the implementation environment

- GitHub Git read access: succeeded; GitHub Issue/API access: HTTP 403.
- Flutter SDK source: 3.50.0 cloned, commit
  `ab2912035e160d9cad6306df307576da6128ebdb`.
- Flutter/Dart startup: blocked by HTTP 403 at `storage.googleapis.com`.
- Dart sources: syntax parsed and formatted using the MIT-licensed
  `@wasm-fmt/dart_fmt` 0.4.0 port of dart_style. This is not type analysis.
- See `backend-smoke.json` for direct Chromium/PDFium WASM backend evidence.
  This bypasses Flutter and does not certify the Flutter application. It passed
  eight checks with Chromium 156.0.8078.79 after networking was disabled.
  To repeat against built assets: `npm ci --ignore-scripts --prefix tool/browser`,
  then `CHROME_EXECUTABLE=/path/to/chrome node tool/browser/wasm_smoke.mjs`.
  The recorded run used the exact reviewed pdfrx package assets rather than a
  Flutter build. `PDFIUM_ASSETS` can point to that package's assets directory.
- Flutter analyze, Flutter tests, app builds, Android execution and Windows
  execution have **not** succeeded or been certified in this environment.
- CI defines required checks; writing a workflow is not evidence that it ran.

## Required automated checks

Use Flutter 3.50.0 and a C toolchain. Native PDFium assets are fetched during
build/test dependency preparation, never in response to a document operation.

```sh
flutter pub get
# Commit the resulting pubspec.lock after dependency/license review.
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze --fatal-infos
flutter test --reporter expanded
tool/build_web.sh
flutter build apk --release
# On Windows with the Visual Studio Desktop development with C++ workload:
flutter build windows --release
```

Real-engine tests cover merge order, complementary split/extract, reorder,
additive rotation, Arabic embedded text and rendering, malformed/encrypted PDF
rejection, selection/file/page/byte limits, rollback, cancellation and reset.
Widget tests use explicit fakes to verify UI wiring and Arabic/English direction;
they are not used as PDF correctness evidence.

For the browser real-engine integration suite, start a compatible ChromeDriver
on port 4444 and run:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/pdf_engine_test.dart \
  -d web-server --browser-name=chrome --headless
```

For device integration (not automatically run by the APK build job):

```sh
flutter test integration_test/pdf_engine_test.dart -d DEVICE_ID
```

## Manual certification (required before claiming a platform works)

Use only synthetic fixtures from `test/fixtures` for network inspection.

For **each** Android device, Windows machine, and browser under certification:

1. Record OS/browser/device, app commit and toolchain versions. Install the
   artifact from CI. Windows needs the entire portable bundle, not only the EXE.
   APK artifacts use debug signing for evaluation and are not store releases.
2. Disable connectivity. Import valid.pdf and arabic.pdf from local storage.
   Confirm filenames, counts and readable Arabic labels. Import picker cancel
   must leave the workspace unchanged.
3. Merge all pages. Open the saved result in an independent offline PDF viewer;
   verify the page sequence and visually shaped Arabic text.
4. Select pages 1 and 3 of valid.pdf, extract, and inspect the two-page result.
   Extract page 2 separately and confirm complementary partitions.
5. Reorder, rotate pages by 90/180/270°, export and inspect every page. Repeat
   using rotated.pdf to verify rotation adds to the existing angle.
6. Reject encrypted.pdf, empty-password.pdf, malformed.pdf and a >20 MiB input.
   Confirm existing pages remain usable after every failure. Cancel processing
   and confirm there is no save dialog or partial output from that operation.
7. Cancel the save dialog; verify workspace preservation. Windows: try the
   original and an existing output path; both must be refused. Android: use
   local SAF storage, duplicate names and a revoked/unwritable destination;
   confirm safe failure and no original modification. Browser: verify the
   downloaded PDF, duplicate-name behavior and cancelled/blocked downloads.
8. Switch languages before/after imports and errors. Test RTL/LTR, Arabic font,
   screen-reader labels, Tab/Shift-Tab/Space/Enter operation of all controls,
   200% text scaling, phone portrait and a narrow desktop window. The up/down
   buttons provide a keyboard alternative to dragging.
9. Check process logs for absence of document bytes, filenames and passwords.
   Verify source hashes have not changed. Clear and confirm memory handles are
   released; reopen the app and confirm no document state is restored.

Additional **Web offline/PWA** checks:

1. Serve the complete `build/web` directory over localhost/HTTPS after
   `tool/build_web.sh`; no runtime CDN or external font configuration.
2. Wait for the service worker to finish installing. Reload until controlled.
   Install the PWA if offered. Disable networking, close and reopen the app,
   and repeat import/edit/export. Check `/assets/packages/pdfrx/assets/` and
   CanvasKit load from the local cache with no CSP violations.
3. Inspect Network while importing synthetic PDFs and exporting: no POST,
   PUT, WebSocket, beacon or cross-origin document request. PDF bytes must
   travel only inside the browser worker. Inspect Cache Storage/IndexedDB to
   ensure the app did not persist document data.
4. Test Chrome/Edge and Firefox separately. Safari, mobile browsers, private
   browsing, quota eviction and denied storage remain uncertified until tested.
5. Deploy a new build, allow its worker to finish, close all tabs and reopen;
   verify version update and offline operation. Do not certify an interrupted
   first install or an evicted cache as offline ready.

Complete release signing, the resolved dependency audit and all platform
checklists before calling an artifact production-ready.
