# Dependency and platform review

Reviewed upstream package archives and their source APIs before implementation.
This is a source and license review; it is **not platform certification**.

| Component | Version | License | Intended use / evidence |
| --- | --- | --- | --- |
| Flutter / Dart | Flutter 3.50.0 stable, SDK source `ab2912035e160d9cad6306df307576da6128ebdb` | BSD-3-Clause | Android, Windows and Web runners; CI pins this Flutter version. |
| pdfrx | 2.12.1 | MIT | `PdfDocument.openData`, `createNew`, `pages`, `PdfPage.rotatedBy`, `encodePdf`. Its archive includes native dispatch and bundled Web PDFium WASM/client/worker assets. Requires Dart >=3.13 and Flutter >=3.47. |
| pdfrx_engine | 0.9.2 reviewed | MIT | Native worker implementation and platform-neutral document API. |
| pdfium_flutter / pdfium_dart | 0.4.2 reviewed | MIT (wrappers); PDFium BSD plus third-party licenses | Native assets downloaded at build time; Android and Windows targets are declared by the package build hook. A C toolchain is required. No runtime PDF upload API is used. |
| file_selector | 1.1.0 | BSD-3-Clause | Windows/browser imports and desktop save dialog. Android uses our bounded SAF channel for both import and export: the reviewed plugin copies inputs before Dart size checks, so its Android picker is intentionally not invoked. |
| web | 1.1.1 | BSD-3-Clause | Browser Blob downloads; conditional import excludes it from native builds. |
| Noto Sans / Noto Sans Arabic | bundled upstream regular TTF | SIL OFL 1.1 | Locally bundled Arabic and Latin UI fonts. No font CDN. |
| Playwright | 1.58.2 | Apache-2.0 | Development-only browser backend validation; npm lockfile included under tool/browser. |
| flutter_lints | 6.0.0 | BSD-3-Clause | Development-only analysis rules. Flutter test/integration packages are SDK dependencies. |
| Gradle wrapper | 9.5.0 | Apache-2.0 | Build tooling only. Official upstream wrapper; distribution SHA-256 pinned. |

Primary evidence:

- https://pub.dev/packages/pdfrx/versions/2.12.1
- https://pub.dev/packages/pdfrx_engine/versions/0.9.2
- https://pub.dev/packages/pdfium_dart/versions/0.4.2
- https://pub.dev/packages/file_selector/versions/1.1.0
- https://github.com/bblanchon/pdfium-binaries/releases/tag/chromium%2F8125
- https://github.com/notofonts/noto-fonts

The reviewed native PDFium build is chromium/8125. Its published build arguments
disable V8 and XFA. This application does not invoke document JavaScript, form
callbacks, URI loaders or remote font resolution. The Web engine ships its own
WASM binary; its packaging and browser behavior must be validated separately.

The complete notices from the reviewed PDFium binary archive are bundled in
`assets/licenses/PDFium-third-party.txt`, alongside MIT, BSD and OFL notices.
PDFium's dependencies include FreeType (use its permissive FreeType License
option), ICU, HarfBuzz, libjpeg, libpng, OpenJPEG, LCMS, zlib and others listed
in that notice file. No mandatory GPL/AGPL commercial-license gate was found
in the reviewed selection. Preserve the notices in distributed artifacts and
re-review binary notices when upgrading PDFium. Flutter's license registry
also exposes resolved Dart package licenses through the About dialog.

Native binaries come from upstream release assets, not this repository. The
upstream native build hook downloads via HTTPS; it does not independently pin
a binary digest. A release audit should pin/mirror and verify those binaries
and inspect the final artifact's dependencies. TLS/package verification has
not been disabled.

## Reproducibility limitation

Direct app dependencies are version-pinned. The Flutter SDK download was blocked
in the implementation environment, so `flutter pub get` could not run and a
`pubspec.lock` could not be generated honestly. CI uploads its resolved lockfile
for review. Before merging/releasing, run `flutter pub get` with the pinned SDK,
commit `pubspec.lock`, and review the full resolved dependency/license graph.
The reviewed transitive versions above are not a substitute for that lockfile.
