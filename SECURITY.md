# Security

## Current Boundary

Stage 2A encrypted transport and a Flutter Android 11+ local preview are implemented. Three debug APKs built successfully; local Flutter tests and analysis passed. See `docs/ANDROID_PREVIEW.md` for artifact inspection and `docs/VERIFICATION.md` for final-run evidence. No physical-device or emulator tests ran. The preview is not a complete production E2EE app and must not hold important private data. Production identity, sync, recovery, rate/storage quotas, attachment processing, and cloud deployment are absent. Ordinary CI uses synthetic data and no deployment secrets. No remote CI or GitHub artifact success is claimed.

Private routes validate hashed, expiring, revocable sessions and bind note access to the owner. Updates/deletes use atomic expected-version checks. Unexpected storage failures return generic errors. A session authorizes transport; it is not a decryption key. OAuth account recovery will not recover encrypted data.

## Required E2EE

Android-only and E2EE are confirmed requirements, not pending options. Private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments must be encrypted on the client before upload. OCR, search, and reminder scheduling must run locally. Workers AI and other server-side processors must not receive private content. TLS and provider storage encryption alone are not E2EE.

Future Durable Objects may relay/store encrypted CRDT updates, not merge plaintext. Authorized clients decrypt and merge. Encrypted sharing, device pairing, and key authentication are not implemented. Public sharing requires a future reviewed key-delivery flow; keys must never be placed in URL query parameters sent to a server. No public-share flow is shipped.

The server can see owner/document/key IDs, revisions, timestamps, lengths, and network/access metadata. This is not full anonymity or a promise of malicious-server rollback defense. AEAD and compare-and-swap alone do not establish trusted freshness. Revocation cannot recall downloaded/exported data.

## Transport Reference

`packages/protocol/src/note-envelope.ts` validates envelope shape. `packages/crypto/src/notes.ts` provides `generateNoteKey()`, `encryptNote(key, context, plaintext Uint8Array)`, and `decryptNote(key, context, envelope)` using WebCrypto AES-256-GCM, a random 12-byte nonce, and a 128-bit tag. Context is `{ownerId,noteId,keyId,revision}`; AAD is exactly the UTF-8 encoding of `JSON.stringify(['bcommend.note',1,ownerId,noteId,keyId,revision])`. See `docs/API.md` for canonical encoding and size constraints.

The server checks shape and versions, not cryptographic validity. It cannot determine whether a buggy client placed base64-encoded plaintext in the ciphertext field. Only the client verifies AEAD authentication. Storing envelopes does not establish complete application E2EE.

## Key Loss Warning

**Do not store important data. Explicitly save before app termination; there is no autosave. Uninstall, clearing app data, or losing the key makes saved notes unrecoverable. No backup, recovery codes, or trusted-device recovery exists.** Mobile keys now persist across ordinary restarts. The separate TypeScript `generateNoteKey()` reference still generates a nonexportable memory-only key and does not provide durable storage.

Proposed next gates are a reviewed vault root, wrapped per-document keys, a user-held offline recovery code, and trusted-device transfer, with no server master key. These are not delivered features. Recovery UX needs approval. Independent crypto/security review and broader interoperability/failure testing remain launch gates; the Dart crypto tests already pass a fixed Node AES-GCM interoperability vector.

## Android Local Storage

`EncryptedNoteRepository` stores encrypted files under the `path_provider` app-private directory's `encrypted-notes` folder. Writes use serialized atomic encrypted-file replacement. One app-wide repository is intended; serialization is not multiprocess locking. Corrupt note loads report failure with retry, not an empty notebook. Missing/corrupt key material fails closed without silently rekeying or wiping existing files.

Initial partial `vault.meta.pending` recovery is allowed only with a valid existing key and no other files; it never rekeys. Native MethodChannel directory fsync uses `Os.open` with `O_RDONLY` after validating a filesystem directory under app data. Work is queued off the UI thread after atomic rename/unlink and parent-directory creation. `SaveUncertain` carries the written revision so the UI retains the draft and can retry; `DeleteUncertain` explicitly reports uncertainty, not that the note was preserved. Fake filesystem-failure branches and fake key storage tests do not prove power-loss durability across OEM filesystems or secure preferences.

`Note.fitsStorage` checks the complete UTF-8 JSON against 65,520 bytes, reserving maximum revision/timestamp space before the UI accepts text or strokes. Count limits remain 256 strokes, 2,048 total points, and 512 points per stroke. Active canvas gestures block Save, back, delete, and tab changes until all fingers lift.

One random per-installation AES-256-GCM key is reused across notes with a fresh random nonce for each encryption. The envelope and AAD match the TypeScript/Node contract above. File metadata exposes the owner UUID and key ID; encryption does not hide all metadata. The random local owner UUID is not an authenticated backend account. This store cannot simply be synchronized to that account without future enrollment and re-encryption; session credentials and encryption keys are separate.

The stored key is held only through `FlutterSecureStorage` 9.2.4 with `AndroidOptions(encryptedSharedPreferences: true, resetOnError: false)`, backed by Android Keystore, not a hardcoded Dart key. Secure storage protects key material at rest on the device. Once loaded, the Dart `SecretKey` can be exported within the process: this is not a nonexportable, hardware-backed AES operation handle. It does not protect against rooted devices, unlocked-device malware, or a compromised app process.

Android sets `allowBackup=false`, supplies XML exclusions for all cloud-backup and device-transfer domains, and applies `FLAG_SECURE` for screenshots/recents. Both editor and search request disabled IME personalized learning. These controls are not a guarantee against untrusted keyboards, rooted devices, OEM behavior, or external photography; physical validation remains pending. No cloud recovery or encrypted-file export is provided.

ARM64 APK manifest inspection confirmed min SDK 30, target SDK 36, preview ID `dev.bcommend.bcommend_mobile.preview`, `debuggable=true`, `allowBackup=false`, and cleartext traffic disabled. `INTERNET` supports Flutter's debug VM service; application networking/sync is not implemented. The dynamic-receiver permission is signature-protected. All three APK signatures verified with V2 and `CN=Android Debug`; debug signing and a debuggable build are not production security.

## Local Data and Migration

Migration `0002` creates a separate encrypted-notes table. Old `notes` records remain untouched and unreachable through the API; there is no legacy plaintext fallback or shipped consumer requiring one. Migration is neither automatic encryption nor secure purge. Old local data may remain plaintext on disk and in backups. Do not delete development data without explicit authorization. Local SQLite storage is not itself encrypted by this project.

The provisioning command prints a raw development token once to the operator's terminal and stores only its hash. Do not share that output. Each run creates a disposable user, not recovery access to earlier notes.

## Repository and Release

- Never commit secrets, signing keys, local databases, real documents, or recovery material.
- Never put bearer tokens or encryption keys in URLs, logs, screenshots, issues, or chat.
- Keep private content out of analytics; implement redacted diagnostics before production.
- Do not deploy the manual local session workflow as production authentication.
- Preview ID is `dev.bcommend.bcommend_mobile.preview`; install artifacts are debug-signed, not releases. Local Docker debug keys persist in `bcommend-android-debug-key`; CI or other environments may use different certificates. Do not resolve a signature mismatch by blindly uninstalling: uninstall destroys the local data and there is no recovery/export. Never commit APKs or signing keys. Release signing has no debug-key fallback; a private stable release key and an explicit publication decision are required.
- Enable GitHub secret scanning/push protection where available and review dependency licenses.
- Before release, require threat modeling, independent crypto/security review, interoperability tests, production identity, device enrollment/revocation, quotas, file authorization, backup/restore and recovery exercises, privacy disclosures, and account/data deletion procedures. Dependency audit alone is not security review.

## Reporting

Do not open a public issue containing exploitable details, credentials, or personal data. Use GitHub private vulnerability reporting if enabled; otherwise contact the owner privately to arrange a secure channel. No guaranteed response SLA is established.
