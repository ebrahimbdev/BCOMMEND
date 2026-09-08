# Verification History

## Stage 3A: Android Local Preview

Date: 2026-09-08. Flutter 3.35.7 in Linux Docker, Android SDK 36 and NDK 27.0.12077973. This is a debug-signed local-only preview, not a production release or complete mobile E2EE/sync system.

Passed:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 45 tests covering Dart/Node crypto interoperability, tampering/context binding, encrypted-file reopening with fake secure storage, missing/corrupt key safety, initialization interruption, uncertain save/delete retries, aggregate byte limits, held-finger save/back guards, one/two-finger transitions, and RTL/dark layouts at 375x812, 812x375, and 1200x800 with 2x text scaling.
- `flutter build apk --debug --split-per-abi --no-pub`: built ARMv7, ARM64, and x86-64 APKs.
- `scripts/verify-android-apks.sh`: all three APKs have min SDK 30, target SDK 36, preview ID `dev.bcommend.bcommend_mobile.preview`, the debug flag, a valid APK signature, and valid 16 KB ZIP alignment.
- ARM64 merged-manifest inspection confirms `allowBackup=false`, backup exclusion resources, cleartext disabled, and no camera/microphone permission. The Flutter debug variant includes INTERNET permission for development; no app networking/sync is implemented.
- All three signatures verify using APK Signature Scheme v2. Local certificate SHA-256: `a2f3cfe0dc8bf5ff657f1725d767161e5b46f6f68f3c646e4f006d3c54978851` (`CN=Android Debug`). This is a public certificate fingerprint, not a private signing key.
- ARM64 merged native libraries inspected with `llvm-readelf`: `libdartjni.so` LOAD alignment 0x4000; `libflutter.so` and `libVkLayer_khronos_validation.so` LOAD alignment 0x10000. This is not a 16 KB emulator/device boot test.
- Backend regression Docker verification: 117 tests, TypeScript, bundle, migration replay, and encrypted HTTP smoke test passed again.

Final local APK SHA-256 values (under `apps/mobile/build/app/outputs/flutter-apk/`, intentionally not committed):

```text
068e7417b92519688e902d0caededf8247243f61d99aeac18446e26570f66ad3  app-armeabi-v7a-debug.apk
eac191fa5637e7fe8019f890c02972d3d0d3e7bcbef645f49f50e32a064c1ba8  app-arm64-v8a-debug.apk
09579f4fd1f829a355b85efc8b1136725b5d5dbb9e8bc7ab2ccd363337e12f16  app-x86_64-debug.apk
```

Review findings addressed before final build: complete serialized-byte admission, recovery of an interrupted initial marker with the same existing key, active-ink navigation/save blocking, search IME privacy settings, and native off-UI-thread directory fsync with uncertain-outcome handling. This is a source review, not an independent cryptographic audit.

Not verified: installation or runtime on a physical device/emulator; native Keystore and directory-fsync behavior across process death/power loss/OEMs; screenshots/recents/backup exclusion on devices; release signing, store submission, remote Actions results, recovery, server enrollment/sync, OCR, notifications, or full mixed canvas. Passing unit/widget tests with fake key storage is not hardware verification. Use disposable notes only.

Build network notes: this environment returned 404 for Google's ordinary download endpoints. The optional init script and SDK_TEST_BASE_URL used Google's official redirector, not a third-party mirror or disabled TLS. Details are in `ANDROID_PREVIEW.md`. Host Flutter/Android SDK were not installed globally.

## Stage 2A: Encrypted Transport

Date: 2026-09-08. Android-only, finger input, and required E2EE scope decisions are recorded. Finger input UI and the Android application are not yet implemented.

Passed `docker build --file Dockerfile.verify --tag bcommend-verify .` in Linux containers:

- 117 tests in the Workers runtime: 65 API/D1, 21 client crypto, 30 pure scheduling, and one populated-database migration test.
- TypeScript checks and dry-run Worker bundle; local HTTP smoke test runs `dist/api/index.js` with `--no-bundle`, not the TypeScript source.
- Node client encrypts a note with AES-256-GCM, uploads only its envelope, fetches it, authenticates/decrypts it, revokes its session, and confirms subsequent denial.
- Both migrations applied, followed by a no-op second application. The migration test preserves populated Stage 1 plaintext records without claiming to encrypt or purge them.
- Tests reject plaintext payload fields, malformed/oversized/noncanonical envelopes, wrong revisions, wrong keys, modified ciphertext/nonce/tag, and ciphertext moved to another owner/document/key/revision.
- A fixed Node/OpenSSL fixture is decrypted by the WebCrypto reference. This is not Kotlin/Dart interoperability or Android device verification.
- Locked Linux dependency install reported zero known vulnerabilities at verification time.

A separate source review found no actionable confidentiality/integrity bugs in this transport scope. It is not an external cryptographic audit. Android key persistence, wrapping, recovery, trusted device enrollment, sharing, local OCR, client CRDT merging, and release security review remain open gates. Memory-only reference keys must not be used for important data.

GitHub Actions is configured but its remote result has not been verified from this environment. No live Cloudflare resource was created or deployed. Native Windows workerd remains unsupported on this machine due to the previously observed access violation; Linux Docker is the verified path.

## Stage 1: Historical Foundation

Date: 2026-09-07. This report covers local foundation code, not the full product or a deployed service.

## Passed

- `npm run typecheck` on Windows.
- `npm audit --audit-level=moderate`: zero known vulnerabilities at the time of verification.
- `docker build --file Dockerfile.verify --tag bcommend-verify .` on Docker Desktop Linux containers with Node 22.
- 69 tests inside the actual Workers runtime: 39 API/D1 tests and 30 deterministic schedule tests.
- Dry-run Worker bundle with its artifact verified under repository-local `dist/api/index.js`.
- Local D1 migrations followed by a second application with no pending migrations.
- Real local HTTP Worker smoke test: local credential provisioning, identity, note creation/read, session revocation, and subsequent denial.
- Provisioning rejects `--remote`; smoke verification does not print generated tokens.

Coverage includes missing/invalid/expired/revoked sessions, cross-owner access, concurrent writes/create/delete, stale versions, tombstone resurrection prevention, request limits including streaming input, pagination, malformed JSON, SQL-like content, mixed RTL text, counted recurrence, exclusive cursor/inclusive end boundaries, large gaps, and date validation.

## Review

An independent code review examined authentication, owner isolation, SQL, request limits, recurrence, and scripts. A concern about nested-config build output was addressed by using an absolute repository-local output directory and asserting the build artifact in the smoke test. Additional create/update/delete concurrency and streaming-body regression tests passed.

## Not Verified or Delivered

- GitHub-hosted Actions result: pending first push/run at the time this report was authored.
- Native Windows workerd: fails to start with access violation `0xc0000005`; use the documented Linux Docker path.
- Flutter/device builds, editor/ink performance, OCR quality, calendar/Jalali recurrence, notifications, CRDT, attachments, production identity, deployed latency/quota behavior, and production backup recovery are future stages.

Passing tests and a clean dependency audit do not establish production readiness or eliminate all security risks. Development accounts/data are disposable; no live Cloudflare resource was created.
