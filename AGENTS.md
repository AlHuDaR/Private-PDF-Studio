# Codex instructions — Private PDF Studio

## Mission
Build a production-grade, **fully free**, **offline-first** PDF toolkit for Android, Windows, and Web. No AI, subscriptions, accounts, advertisement trackers, or remote document processing.

## Mandatory workflow
1. Inspect repository status and dependencies before editing.
2. Work in a dedicated feature branch; open a PR; NEVER merge automatically.
3. Make the smallest complete functional increment, with tests and clear evidence.
4. Validate architecture and licenses before introducing any dependency. Prefer permissive licenses; flag copyleft obligations explicitly. Do not assert that a dependency supports all targets without proving it.
5. Run available Flutter static checks, tests, and builds; report any test not run.
6. Do not add mock buttons marketed as working tools. Unimplemented functionality must be labelled clearly.
7. Never send files, PDF content, personal data or telemetry to external services. For web use browser-only processing via WASM/JS, not an upload API.
8. Keep Arabic/English translations and RTL/LTR support from the outset, with keyboard accessibility.
9. Do not change other repositories.

## Phase 1
- Bootstrap a Flutter multi-platform project for Android, Windows and Web.
- Establish an abstraction for PDF operations with per-platform adapters.
- Implement verified basic PDF editing operations using genuinely offline libraries.
- Provide file picker, operation controls, output save/export, clear errors, progress state, and cancellation if supported.
- Add unit and integration tests and GitHub Actions CI for analyze/test, plus platform builds where supported.
- Document exact manual verification required to certify the APK, Windows binary and Web offline PWA.
- Security: sanitize filenames and paths, protect against malicious or oversized PDF inputs, avoid logs with content, do not accidentally overwrite originals.
- Do not add Office conversion or OCR in phase 1.

## Definition of done
Functional code rather than scaffolding only, passing automated tests, documented exact commands, PR description listing implemented features, and known limitations. Never claim a successful build without its logs.
