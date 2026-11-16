# Local document processing and limits

There are no accounts, AI, upload endpoints, processing servers, telemetry SDKs,
or document-content logs. Inputs are read as bytes and passed only to the local
PDFium worker. The engine receives synthetic source IDs rather than filenames
or filesystem paths. The application never uses PDFium's URL-loading APIs.

Web bundles its PDF WASM and CanvasKit, uses a same-origin Content Security
Policy, and creates outputs as local Blob downloads. The generated offline
worker caches only a fixed build-time list of static application resources;
it does not cache document blobs, dynamic requests or query strings. Hosting
must serve the WASM MIME type and must not inject third-party scripts. The
initial app download is required; offline availability requires a completed
service-worker install and must be certified with the manual checklist.

Android's release manifest has no INTERNET or broad storage permission. Its own
SAF reader bounds input streams without temporary cache copies. SAF import and
export request a local provider and creates a new document; filenames are
suggestions, not paths. A third-party OS document provider remains outside the
app's control. Debug/profile manifests permit development networking. Windows
creates outputs exclusively and refuses existing destinations. Browser downloads
are managed by the browser; the UI reports download initiation, not a confirmed
save. Original input paths are never used for export.

Before parsing, inputs must have a PDF header/trailer and satisfy limits:
10 source files, 20 MiB per file, 50 MiB aggregate, 500 source/output pages.
Stream reads enforce byte limits even if file metadata changes. Exports over
100 MiB are rejected. Parsing determines structural validity; extension/MIME
filters alone are not trusted. Imports are transactional: a failed/cancelled
batch closes its provisional document handles. Exports are reopened and page
count/rotation-checked before the save dialog is shown. All encrypted documents,
including those with an empty user password, are rejected. No password is stored
or permission restriction removed.

These are admission limits, not a hard memory/CPU sandbox: compressed malicious
PDFs can expand during parsing before page counts are available. PDFium remains
native code on Android/Windows. Keep its security updates current; do not claim
hostile-input safety solely from these limits. The UI avoids automatic thumbnails
or rendering of imported pages. Cancellation is cooperative between tasks; an
active parser/encoder call cannot be interrupted. Failed/cancelled operations
never start saving. Once an OS save dialog/write starts, use its cancellation
behavior; the app does not claim to abort an in-flight filesystem write.

Page assembly is not sanitization, redaction, signature preservation or archival
validation. Forms, signatures, bookmarks, attachments, metadata, accessibility
structure and interactive actions are not certified to survive. Treat the
export as untrusted PDF content and verify visually before sharing. Rendering,
OCR, Office conversion and full PDF editing are outside this phase.

Clear releases imported document handles. Workspace state is held in memory
and is not restored after process death. OS/browser caches, downloaded files,
provider storage and crash dumps remain under platform control. The app cannot
promise forensic erasure or zero copies in runtime memory.
