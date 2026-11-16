# Private PDF Studio

Free, privacy-first PDF toolkit for Android, Windows, and Web.

## Product constraints
- Fully free; no account, subscription, paid feature gates, advertising SDKs, or generative AI.
- Offline-first: never upload document content to a server. Web processing must happen in-browser.
- Arabic and English with accessible RTL/LTR UI.
- Supported targets: Android APK, Windows desktop, browser/PWA.
- Never promise feature parity with iLovePDF until measured and tested.

## Development
The implementation is planned in phases. See [AGENTS.md](AGENTS.md) for coding rules and GitHub issues for scoped tasks.

## Phase 1 acceptance
- Functional PDF import, merge, split/extract, reorder, and rotate.
- Automated tests with valid, encrypted, malformed, and Arabic-language sample PDFs.
- Flutter analyze/test pass on supported environments.
- CI checks and downloadable build artifacts where supported.
- No network request containing document bytes.
