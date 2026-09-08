# Security

## Current Boundary

Stage 2A encrypted transport is implemented and locally verified; see `docs/VERIFICATION.md`. This local-only foundation is not a complete E2EE app and must not hold production private data. No Android app, production identity, rate/storage quotas, attachment processing, or cloud deployment exists. Ordinary CI uses synthetic data and no deployment secrets. No remote CI success is claimed.

Private routes validate hashed, expiring, revocable sessions and bind note access to the owner. Updates/deletes use atomic expected-version checks. Unexpected storage failures return generic errors. A session authorizes transport; it is not a decryption key. OAuth account recovery will not recover encrypted data.

## Required E2EE

Android-only and E2EE are confirmed requirements, not pending options. Private titles, bodies, ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments must be encrypted on the client before upload. OCR, search, and reminder scheduling must run locally. Workers AI and other server-side processors must not receive private content. TLS and provider storage encryption alone are not E2EE.

Future Durable Objects may relay/store encrypted CRDT updates, not merge plaintext. Authorized clients decrypt and merge. Encrypted sharing, device pairing, and key authentication are not implemented. Public sharing requires a future reviewed key-delivery flow; keys must never be placed in URL query parameters sent to a server. No public-share flow is shipped.

The server can see owner/document/key IDs, revisions, timestamps, lengths, and network/access metadata. This is not full anonymity or a promise of malicious-server rollback defense. AEAD and compare-and-swap alone do not establish trusted freshness. Revocation cannot recall downloaded/exported data.

## Transport Reference

`packages/protocol/src/note-envelope.ts` validates envelope shape. `packages/crypto/src/notes.ts` provides `generateNoteKey()`, `encryptNote(key, context, plaintext Uint8Array)`, and `decryptNote(key, context, envelope)` using WebCrypto AES-256-GCM, a random 12-byte nonce, and a 128-bit tag. Context is `{ownerId,noteId,keyId,revision}`; AAD is exactly the UTF-8 encoding of `JSON.stringify(['bcommend.note',1,ownerId,noteId,keyId,revision])`. See `docs/API.md` for canonical encoding and size constraints.

The server checks shape and versions, not cryptographic validity. It cannot determine whether a buggy client placed base64-encoded plaintext in the ciphertext field. Only the client verifies AEAD authentication. Storing envelopes does not establish complete application E2EE.

## Key Loss Warning

**`generateNoteKey()` generates a nonexportable key in memory only. Content can become unrecoverable after the process ends. Do not use this reference with important data.** There is no reviewed vault, secure persistence, key wrapping, recovery, trusted-device transfer, or device-key authentication yet.

Proposed next gates are a random vault root, wrapped per-document keys, Android Keystore device wrapping, a user-held offline recovery code, and trusted-device transfer, with no server master key. These are recommendations, not delivered features. Recovery UX needs approval. If all trusted devices and the recovery material are lost, content cannot be recovered. Independent cryptographic/security review and Kotlin/Dart interoperability vector tests are required before launch.

## Local Data and Migration

Migration `0002` creates a separate encrypted-notes table. Old `notes` records remain untouched and unreachable through the API; there is no legacy plaintext fallback or shipped consumer requiring one. Migration is neither automatic encryption nor secure purge. Old local data may remain plaintext on disk and in backups. Do not delete development data without explicit authorization. Local SQLite storage is not itself encrypted by this project.

The provisioning command prints a raw development token once to the operator's terminal and stores only its hash. Do not share that output. Each run creates a disposable user, not recovery access to earlier notes.

## Repository and Release

- Never commit secrets, signing keys, local databases, real documents, or recovery material.
- Never put bearer tokens or encryption keys in URLs, logs, screenshots, issues, or chat.
- Keep private content out of analytics; implement redacted diagnostics before production.
- Do not deploy the manual local session workflow as production authentication.
- Enable GitHub secret scanning/push protection where available and review dependency licenses.
- Before release, require threat modeling, independent crypto/security review, interoperability tests, production identity, device enrollment/revocation, quotas, file authorization, backup/restore and recovery exercises, privacy disclosures, and account/data deletion procedures. Dependency audit alone is not security review.

## Reporting

Do not open a public issue containing exploitable details, credentials, or personal data. Use GitHub private vulnerability reporting if enabled; otherwise contact the owner privately to arrange a secure channel. No guaranteed response SLA is established.
