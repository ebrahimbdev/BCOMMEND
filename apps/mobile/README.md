# BCOMMEND Android Preview

Flutter local notebook preview for publicly available Android 11+ phones and tablets (`minSdk 30`, confirmed), not one handset. iOS and stylus/pressure/palm-rejection features are out of scope.

## Implemented Scope

- Persian RTL warm-paper Material 3 UI, light/dark themes and phone/tablet layouts.
- Local note create/read/update/delete and string search.
- Typed text and fixed 1000 x 1400 finger ink in separate tabs, not a full mixed-content free canvas.
- Explicit draw/navigation modes, one-finger drawing, two-finger pan/zoom, undo and three colors.
- Explicit Save, no autosave; back save/discard guard and edits retained on failed save.
- Complete UTF-8 JSON size validation before text/stroke acceptance (65,520 bytes with reserved maximum revision/timestamp space); limits of 256 strokes, 2,048 total points, and 512 points per stroke remain.
- Active canvas gestures block Save/back/delete/tab changes until all fingers lift; editor and search request disabled IME personalized learning.
- App-private encrypted files, serialized atomic replacement, and a persisted per-installation AES-256-GCM key through Android Keystore-backed secure storage.

**Use disposable data only. Save before killing the app. Uninstall, app-data clearing, or key loss makes saved notes unrecoverable. No backup, recovery codes, or export is implemented.** Ordinary restart preserves saved notes and the key; this differs from the separate TypeScript memory-only crypto reference.

The Dart key is exportable inside the process, not a hardware-only AES handle. Local owner UUIDs are not backend accounts; future sync requires enrollment and re-encryption. Missing/corrupt keys fail closed without resetting disk; corrupt note loads offer retry, not an empty notebook. One app-wide repository is intended, not multiprocess locking. See [security](../../SECURITY.md) for the exact key-storage configuration and device threat boundary.

Backup/recovery, sync, OAuth, UI reminders, OCR, PDF, audio, export, and collaboration are absent. The full future scope remains in [PRD](../../docs/PRD.md); this is not a complete production E2EE app.

## Build and Validation

Flutter 3.35.7 is available inside the locally present `ghcr.io/cirruslabs/flutter:3.35.7` Docker image; host Flutter and Android SDK are absent. Follow the exact root-mount and named-cache commands in [Android preview](../../docs/ANDROID_PREVIEW.md).

Debug preview application ID: `dev.bcommend.bcommend_mobile.preview`. Built output under `build/app/outputs/flutter-apk/`: `app-arm64-v8a-debug.apk` (most modern phones), `app-armeabi-v7a-debug.apk` (legacy 32-bit ARM), and `app-x86_64-debug.apk` (primarily emulators). Never commit these artifacts. Release signing is intentionally unconfigured, with no debug fallback. Local debug keys persist in Docker volume `bcommend-android-debug-key`; other environments may use different certificates. Do not blindly uninstall on a signature mismatch because that deletes local data.

Local Flutter tests, including a fixed Node interoperability vector, and analysis passed; three split-ABI debug APKs built successfully. [Android preview](../../docs/ANDROID_PREVIEW.md) records manifest/signature/alignment inspections and exact SDK 36 Docker setup. No physical-device/emulator tests or 16 KB device boot ran, and remote Actions/artifacts are unverified. Final-run counts, rebuild hashes, and verifier-script results belong in [verification](../../docs/VERIFICATION.md). Public APK publication is a separate release decision, and no all-phone compatibility is promised.

Repository hardening includes partial `vault.meta.pending` recovery only with a valid existing key and no other files, never rekeying; native directory fsync queued off the UI thread after rename/unlink and parent creation; and explicit uncertain outcomes. `SaveUncertain` supplies the written revision while retaining the draft for retry; `DeleteUncertain` does not claim preservation. Fake storage-failure/key-storage tests do not establish OEM power-loss durability. Cloud recovery and encrypted-file export remain absent.
