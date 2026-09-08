# ADR 0001: Android Finger Input and Required E2EE

## Status

Product constraints accepted: publicly available Android 11+ (`minSdk 30`) on compatible phones/tablets, finger handwriting WITHOUT a stylus, and E2EE REQUIRED. Stage 2A encrypted transport is locally verified and a Flutter local preview is implemented with passing local tests/analysis and three successfully built debug APKs. See `../ANDROID_PREVIEW.md` for artifact inspection and `../VERIFICATION.md` for final-run evidence. Full mixed-canvas, vault/recovery, and sharing designs below remain proposed gates. No physical-device/emulator tests ran; no remote CI/artifact success or complete production Android E2EE implementation is claimed.

Flutter 3.35.7 is available in the locally present `ghcr.io/cirruslabs/flutter:3.35.7` Docker image; host Flutter/Android SDK are absent. There are no cloud deployment resources. This decision does not authorize deployment, public APK publication, paid resources, or deletion of development data. Prior stage-by-stage git commit/push authorization remains subject to verification and review.

## Scope and Input

Preserve the full product: notebook hierarchy, mixed-content free canvas, Persian/English rich text, vector ink, PDF annotation, audio/time anchors, recurring Jalali/time-zone-aware reminders, offline editing, OCR, search, collaboration/roles/comments, history/trash, portable/PDF export, and browser clipping. E2EE changes where processing occurs; it does not silently remove features.

Android is the only application platform. iOS, APNs, macOS workflows, stylus input, pressure features, and palm rejection are out of scope, not pending. The browser clipper remains a scoped companion, not a complete browser/desktop editor.

Finger input needs explicit draw/navigation modes: one finger draws ink in draw mode; navigation mode cannot ink; two fingers pan/zoom. Real-device tests must cover second-finger arrival during a stroke, accidental touches, finger lift/cancellation, transitions back to one finger, and mode changes. Define deterministic stroke commit/cancel rules and prevent stray ink during navigation. No pressure support is promised.

The current preview implements these modes on a fixed 1000 x 1400 ink surface, with undo and three colors. Typed text and ink occupy separate tabs, not a mixed free canvas. Persian RTL warm-paper Material 3 light/dark layouts target phones/tablets. Local CRUD and string search work without backend integration. Save is explicit, not automatic; back navigation offers save/discard, and failed saves retain edits. Full organization, PDF/audio, OCR, UI reminders, export, sync, and collaboration remain future requirements.

## Private Content and Threat Boundary

Encrypt private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments on clients before upload. OCR, search, and reminders run locally. Workers AI or other cloud processors must not receive private content. Local engine quality and device resource limits still need evidence, particularly Persian/English handwriting.

Future Durable Objects may authenticate access and relay/store encrypted CRDT updates. They do not merge plaintext; authorized clients decrypt, validate, and merge. Collaboration requires reviewed membership, recipient-key authentication, key distribution/rotation, and revoked-offline-edit behavior. These are not implemented. Browser clipping also needs reviewed key access and encryption before upload; plaintext exports require explicit user choice.

Public sharing is not shipped. A future reviewed key-delivery flow must never place sharing keys in URL query parameters sent to a server. This ADR does not approve an alternative link scheme as secure or implemented.

The service still sees owner/document/key IDs, revisions, timestamps, lengths, and network/access information. This is not full anonymity and does not promise malicious-server rollback defense. AEAD context binding and server CAS alone cannot prove freshness against an evil server. Compromised endpoints, downloaded copies, and recipients' exports are not recalled by revocation. TLS/provider storage encryption are necessary layers, not substitutes for E2EE.

## Stage 2A Transport Contract

`packages/protocol/src/note-envelope.ts` validates envelope shape. `packages/crypto/src/notes.ts` is a WebCrypto client reference with `generateNoteKey()`, `encryptNote(key,context,plaintext Uint8Array)`, and `decryptNote(key,context,envelope)`.

- Encryption: AES-256-GCM with a random 12-byte nonce and a 128-bit tag.
- Generate a new nonce for every encryption attempt, including competing offline edits at the same revision. Re-send the identical stored envelope for a transport retry instead of re-encrypting with an old nonce. The reviewed vault must bound usage per document key and rotate keys well before 2^32 encryptions; this reference does not implement a persistent key-usage counter or rotation. The server cannot enforce correct nonce generation by a client.
- Context: `{ownerId,noteId,keyId,revision}`.
- AAD: exactly UTF-8 encoded `JSON.stringify(['bcommend.note',1,ownerId,noteId,keyId,revision])`.
- Envelope: `{format:1,algorithm:'A256GCM',keyId,revision,nonce,ciphertext}`. `keyId` is a lowercase UUID; revision is a positive safe integer.
- Nonce/ciphertext encoding: canonical URL-safe base64 without padding. Nonce decodes to 12 bytes; ciphertext including tag decodes to 16..65536 bytes. Plaintext maximum is 65,520 bytes.
- PUT `/v1/notes/{id}`: `{envelope,expectedVersion}` with revision equal to expected version plus one. Same-envelope initial retries return `200`; old plaintext payloads return `400`.
- GET note: envelope object plus metadata. List: metadata only, including IDs/versions/timestamps, no title or envelope. Existing authentication, owner isolation, CAS, and deletion semantics remain.
- Authenticated `/v1/reminders/preview` is retired with `410`; private scheduling is local. The pure `schedule.ts` core remains.

Server validation proves shape, not encryption. It cannot know that a buggy client placed base64 plaintext in a structurally valid ciphertext field. Only the client verifies AEAD authentication. Encrypted server records are not a complete E2EE application. See `../API.md` for HTTP behavior and limits.

## Migration and Data Safety

Migration `0002` creates a separate encrypted-notes table and leaves old `notes` untouched and unreachable through the API. There are no shipped consumers requiring a legacy fallback. Migration neither encrypts old records nor securely purges disk/backups; old local data can remain plaintext. Never delete development data without explicit authorization.

**Do not store important data. Save manually before killing the preview; unsaved edits are lost. Uninstall, app-data clearing, or key loss makes saved notes unrecoverable. No backup, recovery codes, or export exists.** The TypeScript `generateNoteKey()` reference remains nonexportable and memory-only. Mobile persistence described below survives ordinary restart, but does not deliver a reviewed production vault, recovery, pairing, key authentication, or encrypted sharing.

An authentication session is separate from content encryption and cannot decrypt notes. OAuth account recovery restores account access, not lost data keys.

## Implemented Local Persistence

`EncryptedNoteRepository` writes to `path_provider` app-private storage under `encrypted-notes`, serializing operations and atomically replacing encrypted files. The intended lifetime is one app-wide repository; there is no multiprocess locking. Corrupt note reads fail visibly with retry rather than appearing as an empty collection. Missing/corrupt key state fails closed, never silently rekeys or wipes existing files.

Partial initial `vault.meta.pending` recovery requires a valid existing key and no other files; it does not generate a replacement key. Native MethodChannel directory fsync opens validated filesystem directories under app data with `Os.open`/`O_RDONLY`, queued off the UI thread after atomic rename/unlink and parent-directory creation. `SaveUncertain` carries the written revision while the UI retains the draft for retry. `DeleteUncertain` reports an uncertain outcome, not preservation. Tests inject fake filesystem failures and key storage; they do not prove power-loss durability across OEM filesystems or secure preferences.

Before accepting text/strokes, `Note.fitsStorage` bounds the complete UTF-8 JSON to 65,520 bytes with space reserved for maximum revision/timestamp values. Limits also remain 256 strokes, 2,048 total points, and 512 points per stroke. Active canvas gestures block Save/back/delete/tab changes until all fingers lift. Both editor and search disable IME personalized learning as a privacy request, not a guarantee against untrusted keyboards.

A random per-installation AES-256-GCM key is reused across notes with a fresh random nonce per encryption and the exact Stage 2A envelope/AAD above. Dart crypto tests pass a fixed Node interoperability vector. File metadata exposes owner UUID and key ID. The owner is a local random UUID, not a backend account, so identical crypto formats do not make the store sync-compatible: future enrollment must re-encrypt into the authenticated owner context.

Only `FlutterSecureStorage` 9.2.4 persists the key, using `AndroidOptions(encryptedSharedPreferences: true, resetOnError: false)` and Android Keystore-backed storage. No hardcoded Dart key is used. This is at-rest device protection: the loaded Dart `SecretKey` is exportable inside the process, not a nonexportable hardware AES handle. Rooted devices, unlocked-device malware, and compromised processes are not protected by this boundary.

Android disables backup with `allowBackup=false` and XML exclusions across cloud/device-transfer domains, applies `FLAG_SECURE` for screenshots/recents, and requests disabled IME personalized learning. Untrusted keyboards and rooted devices remain out of scope; OEM behavior and these controls need physical testing. These restrictions do not provide backup or recovery.

## Proposed Key Gates

Recommend a reviewed vault root and wrapped per-document keys. Extend device protection with a user-held offline recovery code and trusted-device transfer for enrollment. Do not introduce a server master key. Exact formats, algorithms, authentication, lifecycle, and recovery UX require review; current mobile per-installation persistence and the separate memory-only reference do not deliver this architecture.

Recovery UX must explain offline custody, enrollment approval, device loss/revocation, backup/restore, and verification of recovery material without exposing it to the server. If all trusted devices and recovery material are lost, the content cannot be recovered. Do not imply that password reset or support can bypass this boundary.

Before launch require independent cryptographic/security review and Kotlin/Dart interoperability vector tests for the exact AAD, encoding, nonce/tag, bounds, tampering, and wrong-context failures. Also require reviewed durable storage, authenticated device/key enrollment, recovery drills, and encrypted collaboration/sharing gates before advertising those features. Stage 2A tests alone cannot close these gates.

## User Preparation

Android 11+ (`minSdk 30`), Android-only, finger-only input, and E2EE are settled; no single physical model is needed to define scope. Use the available Docker setup in `../ANDROID_PREVIEW.md`, which distinguishes completed manifest/signature/native-alignment inspections from pending physical phone/tablet, 16 KB device boot, renderer, and store-policy validation. No all-phone compatibility is guaranteed. Before public distribution, choose OAuth/license and Play Store versus APK, approve recovery UX, and privately create a stable release signing key. Debug preview ID `dev.bcommend.bcommend_mobile.preview` is distinct; local Docker debug keys persist in `bcommend-android-debug-key`, but release signing has no debug fallback. Cloud provisioning and public APK publication are later explicitly authorized steps.
