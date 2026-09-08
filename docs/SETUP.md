# User Preparation and Deployment Gates

## Needed Now

1. Use the locally available `ghcr.io/cirruslabs/flutter:3.35.7` Docker image to check/build the implemented mobile preview. Host Flutter and Android SDK are absent, but installing them is not required for the Docker path. Exact commands are in `ANDROID_PREVIEW.md`.
2. Plan physical phone/tablet testing across Android 11 through current versions. Android 11+ (`minSdk 30`) is confirmed; no particular handset is required to define scope. Three debug APKs built successfully; physical-device and emulator tests have not run. Artifact compatibility does not guarantee every phone works.
3. Before release, choose a production OAuth provider, a project license, and Play Store versus APK distribution. Privately create and protect a stable release signing key; do not send it in chat. Public source is not automatically open source.
4. Approve the future recovery UX: user-held offline recovery code, trusted-device transfer, and an explicit warning that loss of all trusted devices and recovery material means permanent content loss. This is not a preview feature.

Android ONLY, Android 11+ (`minSdk 30`), finger handwriting WITHOUT a stylus, and E2EE REQUIRED are already confirmed. The intended public app serves compatible phones/tablets, not one handset. Do not reopen these decisions. iOS, APNs, macOS workflows, pressure, palm rejection, and stylus support are out of scope. The preview uses explicit draw/navigation modes, one-finger ink and two-finger pan/zoom; ambiguous gesture transitions still require physical tests.

No Cloudflare account ID, API token, payment method, or cloud resource is needed now. Resource provisioning is a later authorized gate, not a current user task.

## Data Safety Before Startup

**Do not use important data. Manually save before killing the app; there is no autosave. Uninstall, clearing app data, or key loss makes saved notes unrecoverable, with no recovery codes, backup, or export.** Mobile encrypted notes and its per-installation key now persist across restart using app-private files and Android Keystore-backed secure storage. A failed save retains edits; corrupt loads offer retry and missing/corrupt keys fail closed rather than silently reset disk. The Dart key is exportable within the process, not a hardware-only AES handle. The separate WebCrypto `generateNoteKey()` reference remains nonexportable and memory-only. A session does not decrypt notes; OAuth account recovery is not data recovery.

Local owner UUIDs are not backend accounts. Sync requires future enrollment and re-encryption. Preview APKs use debug signing and `dev.bcommend.bcommend_mobile.preview`; a changed debug certificate may prevent an in-place update. Do not blindly uninstall to fix that error: it destroys local data. Preserve the matching signing environment or explicitly accept loss of disposable data. Release signing has no debug-key fallback.

Local Docker signing keys persist in the `bcommend-android-debug-key` named volume, not Git. The base Flutter image has SDK 35 only: follow `ANDROID_PREVIEW.md` to install SDK 36/build tools and NDK into `bcommend-android-sdk`. Optional official Google CDN workarounds are documented separately; no host Flutter installation is needed. Never commit generated APKs.

The proposed production design uses a reviewed vault root, wrapped per-document keys, a user-held offline recovery code, and trusted-device transfer, with no server master key. Those are next gates, not shipped functionality; current Keystore-backed persistence is not a complete recovery vault. A fixed Node/Dart crypto vector has passed, but independent crypto/security review and broader interoperability tests remain required before launch. See `architecture/0001-android-e2ee.md` and `../SECURITY.md`.

Migration `0002` creates a separate encrypted-notes table; old plaintext notes remain untouched and unreachable through the API. This is not automatic encryption or secure purge: plaintext can remain on disk and in backups. No shipped consumers require a legacy fallback. Do not delete development data without authorization.

Private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments must be encrypted before upload. OCR/search/reminders run locally; Workers AI must not receive private content. Server shape validation does not prove that bytes are encrypted; only clients verify AEAD. Server-visible IDs, revisions, timestamps, lengths, and network/access metadata mean this is not full anonymity or malicious-server rollback defense.

Do not send passwords, API tokens, signing keys, session tokens, or private documents in chat or GitHub issues. When credentials become necessary, use interactive login or local/managed secret storage. Do not grant administrator access just to run tests.

## GitHub

The owner has authorized stage-by-stage commits and pushes to `ebrahimbdev/BCOMMEND`. Git operations use the machine's credential manager; source code must never embed GitHub credentials. If push authentication fails, sign into the correct GitHub account using Git Credential Manager or `gh auth login`, then retry. Avoid personal tokens in remote URLs.

Enable GitHub secret scanning/push protection where available. After the first successful Actions run, enable branch protection/rulesets for the default branch with the verification check required. Keep workflow permissions read-only and never provide production secrets to fork pull requests.

`.github/workflows/android.yml` now configures locked pub get, formatting, analysis, tests, SDK installation, split-ABI debug builds, artifact checks, and preview artifact upload. Remote run success and GitHub artifact availability are not yet verified; configured uploads are not public production release publication.

GitHub CLI is useful for checking runs, but its absence does not prevent ordinary authenticated `git push`. Installation may require Windows administrator approval.

## Before Cloudflare Deployment

This foundation is deliberately **not ready for public deployment**. A public repository does not require a public, unprotected API.

Complete the reviewed E2EE vault/recovery and interoperability gates, production authentication, request/storage quotas, safe logging, and account lifecycle first. Then:

1. Authenticate Wrangler locally using `npx wrangler login` (not a token pasted into this repository).
2. Create a dedicated D1 database in the intended account after approving that deployment step.
3. Create an ignored environment-specific Wrangler configuration with the real database binding and chosen routes. Do not replace the committed local database placeholder casually.
4. Review migrations, take an appropriate backup, and explicitly choose the remote target. All existing npm migration/provisioning commands are local-only.
5. Configure production identity secrets through Wrangler/Cloudflare managed secrets. There is no deployed manual provisioning endpoint.
6. Apply remote migrations and deploy only after explicit environment confirmation. No CI deployment token is configured by this stage.
7. Test cross-user access, session revocation, quotas, and recovery on the deployed environment before adding real private notes.

R2 is not required in Stage 1. Later attachment support needs a private bucket, short-lived authorized access, object limits, and billing controls. Its included free usage is not a guaranteed hard spending cap. Do not activate a paid service or accept overage exposure without an explicit decision.

## Later Platform Setup

- Android private reminders run locally. Any future content-free FCM wake-up requires Firebase configuration; keep service credentials private and never send private rules/content.
- OAuth requires registered mobile redirect URIs/application IDs; production sign-in must use an appropriate secure native flow.
- Android distribution, app signing, and domain registration are separate from Cloudflare hosting. Local OCR engines require licensing and device-budget review, not private-content cloud processing.
- Public APK publication is a separate release decision, not implied by authorized git commits/pushes or future GitHub Actions preview artifacts. Validate merged manifest, supported ABIs, permissions, 16 KB pages, artifact metadata, and current target-SDK/store policy before claiming Play readiness. The local preview needs no camera, microphone, or GMS dependency.
- Set measured upload/audio/OCR limits for the 10-user workload; do not promise an unlimited allowance.

## Verification Status

Repeatable backend commands are in the README; mobile Docker commands and completed artifact inspections are in `ANDROID_PREVIEW.md`. Linux Docker works around the Windows-native workerd access violation; it does not repair the host runtime. Final test counts, rebuild evidence, verifier-script results, and hashes belong in `VERIFICATION.md`. Local Flutter tests/analysis and three debug APK builds passed. Remote CI/artifacts, physical-device/emulator validation, and 16 KB device boot remain unverified. No notification test, OCR quality benchmark, production load test, production APK publication, or cloud deployment is claimed.
