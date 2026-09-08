# ADR 0001: Android Finger Input and Required E2EE

## Status

Product constraints accepted: Android ONLY, finger handwriting WITHOUT a stylus, and E2EE REQUIRED. Stage 2A encrypted transport is implemented and locally verified; see `../VERIFICATION.md`. Vault/recovery, client architecture, and sharing designs below are proposed gates, not delivered functionality. No remote CI success or complete Android E2EE implementation is claimed.

Flutter is not installed and the Android app is absent. There are no cloud deployment resources. This decision does not authorize deployment, paid resources, or deletion of development data. Prior stage-by-stage git commit/push authorization remains subject to verification and review.

## Scope and Input

Preserve the full product: notebook hierarchy, mixed-content free canvas, Persian/English rich text, vector ink, PDF annotation, audio/time anchors, recurring Jalali/time-zone-aware reminders, offline editing, OCR, search, collaboration/roles/comments, history/trash, portable/PDF export, and browser clipping. E2EE changes where processing occurs; it does not silently remove features.

Android is the only application platform. iOS, APNs, macOS workflows, stylus input, pressure features, and palm rejection are out of scope, not pending. The browser clipper remains a scoped companion, not a complete browser/desktop editor.

Finger input needs explicit draw/navigation modes: one finger draws ink in draw mode; navigation mode cannot ink; two fingers pan/zoom. Real-device tests must cover second-finger arrival during a stroke, accidental touches, finger lift/cancellation, transitions back to one finger, and mode changes. Define deterministic stroke commit/cancel rules and prevent stray ink during navigation. No pressure support is promised.

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

**Startup warning: `generateNoteKey()` generates a nonexportable reference key in memory only. Encrypted data can become unrecoverable when the process ends. Do not store important data.** There is no secure persistence, vault, wrapping, recovery, device pairing, key authentication, or encrypted sharing. Nonexportability is not persistence or a recovery strategy.

An authentication session is separate from content encryption and cannot decrypt notes. OAuth account recovery restores account access, not lost data keys.

## Proposed Key Gates

Recommend a random vault root and wrapped per-document keys. Use Android Keystore for device wrapping, a user-held offline recovery code for recovery, and trusted-device transfer for enrollment. Do not introduce a server master key. Exact formats, algorithms, authentication, lifecycle, and recovery UX require review; none of this is delivered by the memory-only reference.

Recovery UX must explain offline custody, enrollment approval, device loss/revocation, backup/restore, and verification of recovery material without exposing it to the server. If all trusted devices and recovery material are lost, the content cannot be recovered. Do not imply that password reset or support can bypass this boundary.

Before launch require independent cryptographic/security review and Kotlin/Dart interoperability vector tests for the exact AAD, encoding, nonce/tag, bounds, tampering, and wrong-context failures. Also require reviewed durable storage, authenticated device/key enrollment, recovery drills, and encrypted collaboration/sharing gates before advertising those features. Stage 2A tests alone cannot close these gates.

## User Preparation

Needed now: Android test model/minimum OS, Flutter and Android SDK installation, OAuth provider and license selection, and recovery UX approval. Do not ask again whether Android-only or E2EE is wanted. Cloud provisioning is a later explicitly authorized step.
