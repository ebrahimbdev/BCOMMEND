# User Preparation and Deployment Gates

## Needed Now

1. Name the real Android test model and choose the minimum Android OS version.
2. Install Flutter stable and the Android SDK/Android Studio; validate with `flutter doctor -v`. Flutter is currently not installed and no Android app exists.
3. Choose a production OAuth provider and a project license. Public source is not automatically open source.
4. Approve the proposed recovery UX: user-held offline recovery code, trusted-device transfer, and an explicit warning that loss of all trusted devices and recovery material means permanent content loss.

Android ONLY, finger handwriting WITHOUT a stylus, and E2EE REQUIRED are already confirmed. Do not reopen these decisions. iOS, APNs, macOS workflows, pressure, palm rejection, and stylus support are out of scope, not pending setup. Finger input will use explicit draw/navigation modes, one-finger ink in draw mode, two-finger pan/zoom, and tests for ambiguous gesture transitions; no pressure promise.

No Cloudflare account ID, API token, payment method, or cloud resource is needed now. Resource provisioning is a later authorized gate, not a current user task.

## Data Safety Before Startup

**Stage 2A encrypted transport is locally verified. Do not use important data.** `generateNoteKey()` in the WebCrypto reference creates a nonexportable memory-only key. Process exit can make ciphertext unrecoverable. No reviewed vault, persistence, wrapping, recovery, device pairing, key authentication, or encrypted sharing is implemented. A session does not decrypt notes; OAuth account recovery is not data recovery.

The proposed design uses a random vault root, wrapped per-document keys, Android Keystore device wrapping, a user-held offline recovery code, and trusted-device transfer, with no server master key. These are next gates, not shipped functionality. Independent crypto/security review and Kotlin/Dart interoperability vector tests are required before launch. See `architecture/0001-android-e2ee.md`.

Migration `0002` creates a separate encrypted-notes table; old plaintext notes remain untouched and unreachable through the API. This is not automatic encryption or secure purge: plaintext can remain on disk and in backups. No shipped consumers require a legacy fallback. Do not delete development data without authorization.

Private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments must be encrypted before upload. OCR/search/reminders run locally; Workers AI must not receive private content. Server shape validation does not prove that bytes are encrypted; only clients verify AEAD. Server-visible IDs, revisions, timestamps, lengths, and network/access metadata mean this is not full anonymity or malicious-server rollback defense.

Do not send passwords, API tokens, signing keys, session tokens, or private documents in chat or GitHub issues. When credentials become necessary, use interactive login or local/managed secret storage. Do not grant administrator access just to run tests.

## GitHub

The owner has authorized stage-by-stage commits and pushes to `ebrahimbdev/BCOMMEND`. Git operations use the machine's credential manager; source code must never embed GitHub credentials. If push authentication fails, sign into the correct GitHub account using Git Credential Manager or `gh auth login`, then retry. Avoid personal tokens in remote URLs.

Enable GitHub secret scanning/push protection where available. After the first successful Actions run, enable branch protection/rulesets for the default branch with the verification check required. Keep workflow permissions read-only and never provide production secrets to fork pull requests.

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
- Set measured upload/audio/OCR limits for the 10-user workload; do not promise an unlimited allowance.

## Verification Status

The repeatable verification commands are in the README and GitHub Actions. The Linux Docker path works around a Windows-native workerd access violation; it does not repair the host runtime. The Stage 1 69-test result is historical, not a Stage 2A count or remote CI result. Main implementation updates `VERIFICATION`; this documentation does not certify current tests. No Flutter build, device notification test, OCR quality benchmark, production load test, or cloud deployment is claimed.
