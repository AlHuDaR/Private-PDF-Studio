# Phase 1 architecture

`core/model.dart` defines the engine interface, immutable page references,
bounded inputs, stable error codes and cancellation. `LocalPdfEngine` implements
it with pdfrx. Imported handles remain alive until clear; an import batch commits
only after every file succeeds. The output is a fresh document assembled from
page references. Sources are never modified. Encoding is followed by a reopen
check before saving; failure or cancellation discards output bytes.

`platform/files.dart` imports through Flutter's file selector on Windows/Web and
bounds stream reads. Android imports use a bounded SAF channel without temporary
copies, avoiding the plugin's unbounded pre-read copying. Conditional imports choose browser Blob export or native export.
Android implements a minimal SAF MethodChannel: bounded local reads and new local
documents only, I/O off the UI thread, no broad storage permission. Desktop output uses exclusive
creation and refuses replacement. Browser download initiation is reported
separately from successful native saving.

`ui/studio_app.dart` serializes operations, disables editing during work and
retains page selection/order/rotation independently from source documents. The
UI uses localized semantic Material controls and buttons for keyboard page
reordering. `strings.dart` contains both languages; Flutter localization delegates
supply standard controls and directionality. There are no placeholder tool
buttons. The workspace is memory-only and not restored after app termination.

The web loader uses local CanvasKit and pdfrx's bundled PDFium worker/WASM. The
post-build offline cache enumerates only static build outputs. Document bytes
are never cache keys or HTTP payloads. Hosting and initial cache installation
are separate from document processing.

Tests separate core-engine round trips from UI wiring. Native tests initialize
the native engine without Flutter plugin channels; integration tests initialize
the actual Flutter backend, including browser WASM. Synthetic fixture data is
embedded in test-only Dart source so tests do not ship user documents or require
an HTTP fixture API. Platform runners derive from Flutter 3.50.0 templates;
their BSD notice is in `docs/FLUTTER_TEMPLATE_LICENSE`.
