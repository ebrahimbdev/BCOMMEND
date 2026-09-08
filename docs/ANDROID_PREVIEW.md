# Android Local Preview

## Status and Scope

The Flutter client in `apps/mobile` is implemented for Android 11+ (`minSdk 30`, confirmed). The intended product is publicly available across compatible phones and tablets, not designed for one required handset. Android-only and finger-only input are settled; iOS, stylus, pressure, and palm rejection are excluded. The full future product remains in [PRD](PRD.md).

Current preview: Persian RTL warm-paper Material 3 light/dark phone/tablet UI, local CRUD and string search, typed text and fixed 1000 x 1400 ink in separate tabs, explicit draw/navigation modes, one-finger drawing, two-finger pan/zoom, undo and three colors. This is not a full mixed-content free canvas. Save is explicit, not autosave; back navigation offers save/discard, and a failed save retains edits.

Three split-ABI debug APKs built successfully, all 45 Flutter tests passed, and `flutter analyze` reported zero issues. The final APK verifier passed for all three files. No physical-device or emulator tests ran. Exact evidence and hashes are in [Verification](VERIFICATION.md).

Backup, recovery, sync, OAuth, UI reminders, OCR, PDF, audio, export, and collaboration are not implemented. This is a local encrypted preview, not a complete production E2EE app.

## Data Safety

**Use disposable notes only. Manually save before killing the app. Uninstall, clearing app data, or key loss makes saved notes unrecoverable. There are no recovery codes, backups, or export yet.** A back-navigation guard cannot save edits after forced termination.

`EncryptedNoteRepository` uses `path_provider` app-private storage under `encrypted-notes`, serialized atomic encrypted-file replacement, and one intended app-wide repository instance, not multiprocess locking. Missing/corrupt key material fails closed without silently rekeying or wiping disk. Corrupt note loading reports failure with retry rather than an empty notebook.

Partial initial `vault.meta.pending` recovery requires a valid existing key and no other files, without rekeying. Native MethodChannel directory fsync uses `Os.open`/`O_RDONLY` on validated filesystem directories under app data, queued off the UI thread after atomic rename/unlink and parent-directory creation. `SaveUncertain` carries the written revision; the UI retains the draft for retry. `DeleteUncertain` explicitly reports uncertainty rather than claiming the note was preserved. Tests use fake filesystem-failure branches and fake key storage, not proof of power-loss durability across OEM filesystems or secure preferences.

`Note.fitsStorage` checks complete UTF-8 JSON within 65,520 bytes, reserving maximum revision/timestamp space before text or strokes are accepted. Limits remain 256 strokes, 2,048 total points, and 512 points per stroke. Active canvas gestures block Save, back, delete, and tab changes until all fingers lift.

A random per-installation AES-256-GCM key is reused across notes with fresh random nonces. It persists only through `FlutterSecureStorage` 9.2.4, using `AndroidOptions(encryptedSharedPreferences: true, resetOnError: false)` with Android Keystore-backed storage, not a hardcoded Dart key. Saved notes and the key survive ordinary app restart. The separate TypeScript `generateNoteKey()` reference remains memory-only.

The loaded Dart `SecretKey` can be exported within the process: secure storage protects at rest, not through a hardware-only AES handle. No guarantee covers rooted devices, unlocked-device malware, compromised app processes, or untrusted keyboards. Android sets `allowBackup=false`, XML cloud/device-transfer exclusions for all domains, and `FLAG_SECURE` for screenshots/recents; editor and search request disabled IME personalized learning. These controls still need device validation and are not recovery mechanisms. Cloud recovery and encrypted-file export are absent.

The AES-GCM envelope and AAD exactly match the TypeScript/Node contract; Dart crypto tests have passed a fixed Node vector. File metadata exposes owner UUID and key ID. The local random owner UUID is not a backend account. Future account enrollment and re-encryption are required before sync; authentication sessions are not encryption keys. See [Security](../SECURITY.md).

## Docker Workflow

The locally available image `ghcr.io/cirruslabs/flutter:3.35.7` contains Flutter 3.35.7 but SDK 35 only. Install SDK 36, build tools, and NDK as below. No host Flutter or Android SDK installation is needed. Docker Desktop must use Linux containers. Run PowerShell from `E:\Remmember`; the existing repository root is mounted at `/workspace`. Dependency downloads need network access. Named caches are not note backups; the separate debug-key volume preserves the local debug signing identity.

First check the existing paths. Proceed only if both return `True`; stop on any failed Docker command.

```powershell
Test-Path -LiteralPath "E:\Remmember"
Test-Path -LiteralPath "E:\Remmember\apps\mobile"
```

Normal networks need no CDN override:

```powershell
docker run --rm --volume bcommend-android-sdk:/opt/android-sdk-linux ghcr.io/cirruslabs/flutter:3.35.7 sdkmanager 'ndk;27.0.12077973' 'platforms;android-36' 'build-tools;36.0.0'
$dockerArgs = @(
  'run', '--rm',
  '--mount', 'type=bind,source=E:\Remmember,target=/workspace',
  '--volume', 'bcommend-pub-cache:/root/.pub-cache',
  '--volume', 'bcommend-gradle-cache:/root/.gradle',
  '--volume', 'bcommend-android-debug-key:/root/.android',
  '--volume', 'bcommend-android-sdk:/opt/android-sdk-linux',
  '--env', 'PUB_CACHE=/root/.pub-cache',
  '--env', 'GRADLE_USER_HOME=/root/.gradle',
  '--workdir', '/workspace/apps/mobile'
)
$networkArgs = @()
```

Only on a network blocking Google's normal download endpoints, use this optional SDK installation command instead of the one above, and set the optional build arguments below. This is the locally tested workaround:

```powershell
Test-Path -LiteralPath "E:\Remmember\scripts\android-google-cdn.init.gradle"
docker run --rm --volume bcommend-android-sdk:/opt/android-sdk-linux --env SDK_TEST_BASE_URL=https://redirector.gvt1.com/edgedl/android/repository/ ghcr.io/cirruslabs/flutter:3.35.7 sdkmanager 'ndk;27.0.12077973' 'platforms;android-36' 'build-tools;36.0.0'
$networkArgs = @(
  '--env', 'SDK_TEST_BASE_URL=https://redirector.gvt1.com/edgedl/android/repository/',
  '--mount', 'type=bind,source=E:\Remmember\scripts\android-google-cdn.init.gradle,target=/root/.gradle/init.d/google-cdn.gradle,readonly'
)
```

Proceed only if the script path check returns `True`. The Gradle init mount is optional and only rewrites `dl.google.com` Maven repositories to Google's official CDN. It does not add a third-party repository or disable TLS. Leave `$networkArgs` empty on nonblocked networks.

With the chosen network arguments, run each command separately and stop on failure:

```powershell
docker @dockerArgs @networkArgs ghcr.io/cirruslabs/flutter:3.35.7 flutter pub get --enforce-lockfile
docker @dockerArgs @networkArgs ghcr.io/cirruslabs/flutter:3.35.7 flutter analyze
docker @dockerArgs @networkArgs ghcr.io/cirruslabs/flutter:3.35.7 flutter test --reporter expanded
docker @dockerArgs @networkArgs ghcr.io/cirruslabs/flutter:3.35.7 flutter build apk --debug --split-per-abi
docker @dockerArgs @networkArgs ghcr.io/cirruslabs/flutter:3.35.7 bash /workspace/scripts/verify-android-apks.sh
```

The build includes the root mount, pub/Gradle caches, debug-key volume, SDK volume, and optional Google CDN arguments. The verifier checks each APK's min SDK 30, target SDK 36, debug preview ID/debuggable flag, signature, 16 KB ZIP alignment, and prints SHA-256 hashes. It passed against the final local build recorded in `VERIFICATION.md`. Never commit APKs, generated build output, or signing keys to Git.

## Install Safety

Debug preview application ID is `dev.bcommend.bcommend_mobile.preview`, separate from the production base identity. Three locally built files exist under `apps/mobile/build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-debug.apk`: recommended for most modern phones, not all phones.
- `app-armeabi-v7a-debug.apk`: legacy 32-bit ARM devices meeting the Android minimum.
- `app-x86_64-debug.apk`: primarily x86-64 emulators.

Only use an APK from a verified successful build and inspect its identity, certificate, and final-report hash first. Device installation has not been tested. GitHub Actions preview artifacts must be tied to a successful run and commit; remote availability is not verified.

The local Docker volume `bcommend-android-debug-key` preserves `/root/.android/debug.keystore`; pub/Gradle caches alone do not. Other containers or CI may use a different key. Android will reject an in-place update signed by a different certificate. **Do not blindly uninstall to fix a signature mismatch: uninstall deletes local notes and their key, with no recovery/export.** Prefer a build signed by the same trusted debug key; otherwise change installations only after explicitly accepting loss of disposable preview data. Never commit or share signing keys.

Release signing is intentionally absent and the template's debug-signing fallback for release is removed. A debug-signed preview is not a production release. Public APK publication is not automatic and is not authorized by prior stage-by-stage source commits/pushes.

## Compatibility Gates

Android 11 (`API 30`) is the confirmed minimum, with Android 11 through current versions as the OS validation baseline. Debug APKs were built for ARMv7 (`armeabi-v7a`), ARM64 (`arm64-v8a`), and x86-64 (`x86_64`). Completed ARM64 `aapt` inspection confirmed min SDK 30, target SDK 36, application ID `dev.bcommend.bcommend_mobile.preview`, `debuggable=true`, `allowBackup=false`, and cleartext traffic disabled. The `INTERNET` permission supports the Flutter debug VM service; the app implements no networking/sync. The dynamic-receiver permission is signature-protected.

All three APK signature verifications passed with V2 and certificate `CN=Android Debug`. ARM64 `zipalign` with 16 KB page alignment passed. Inspected merged native libraries have ELF LOAD alignment `0x4000` for `libdartjni.so` and `0x10000` for Flutter/VkValidation, supporting 16 KB alignment. These are artifact inspections, not a 16 KB device boot or proof of runtime compatibility.

No camera, microphone, or GMS dependency is required for this local preview. That does not guarantee every Android 11+ phone works: available storage, Keystore/OEM behavior, rendering and any SDK/WebView constraints, screen size, accessibility, and background/process behavior require validation. No single physical model is a scope prerequisite, but physical testing is a release gate.

Before broad distribution or any Google Play-ready claim, require stable private release signing, production identity/recovery, license and Play Store versus APK decisions, a phone/tablet OS/ABI test matrix, permission review, merged min/target SDK and artifact metadata checks, native-library 16 KB page-size validation, and compliance with the then-current target-SDK/store policy. Check offline CRUD, saved-note restart, storage/key failure, explicit save/back guards, RTL/light/dark layout, screenshots/recents controls, and ambiguous one/two-finger transitions on physical devices.

## Evidence and Gates

- Local Flutter tests, including fixed Node interoperability, and analysis: **PASSED**; completed-run count in the root README, final-run evidence in [Verification](VERIFICATION.md).
- Three debug APK builds/files, signature verification, and the final verifier script: **PASSED**. Final hashes are in the verification report.
- ARM64 manifest and 16 KB ZIP/native LOAD alignment inspection: **PASSED** as detailed above, not device boot validation.
- Physical phone/tablet and emulator install, restart, gestures, accessibility, privacy controls, and 16 KB boot: **NOT RUN**.
- Remote GitHub Actions run and preview artifact availability: **PENDING**.
- Production signing, recovery/identity, license/distribution decision, and public publication: **NOT RELEASED**.

`.github/workflows/android.yml` now configures locked pub get, formatting, analysis, tests, SDK/NDK installation, split-ABI debug builds, the artifact verifier, and artifact upload. This is configuration, not remote success or production publication. No cloud deployment occurred. Record final evidence in `VERIFICATION.md`; do not infer verifier success, remote artifacts, or device behavior from configuration or the earlier individual checks.
