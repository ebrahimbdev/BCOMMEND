# Stage 2A Development API

**Encrypted transport foundation: implemented and locally verified.** This is not a stable external API or a complete E2EE application. Current test evidence is recorded in [VERIFICATION.md](VERIFICATION.md); remote CI remains unverified.

All `/v1/` routes require `Authorization: Bearer <local-session-token>`. `/health` is public liveness, not D1 readiness. Responses use JSON and `Cache-Control: no-store`. There is no browser CORS policy yet; use native/CLI clients. Query-string tokens are unsupported. No production login, Android app, durable key vault, full notebook model, reminder persistence, or CRDT protocol is shipped.

## Errors and Identity

Errors use `{ "error": { "code": "conflict", "message": "Version changed; fetch before retrying" } }` with the appropriate code/message.

Relevant statuses: `400` invalid input (including old plaintext payloads), `401` invalid/expired/revoked session, `404` absent/inaccessible note, `409` version or ID conflict, `410` retired reminder preview, `413` body limit, `415` content type, and `503` unexpected service/storage failure. Retain unsaved changes on every failure. Do not blindly retry conflicts using the latest version.

- `GET /v1/me`: returns `{ "id": "..." }` for the authenticated owner.
- `DELETE /v1/session`: revokes this session; subsequent use returns `401`.

Provisioning has no HTTP endpoint and the local CLI rejects remote operation. Authentication permits transport access but cannot decrypt content.

## Envelope and Client Reference

`packages/protocol/src/note-envelope.ts` validates this exact envelope shape:

```ts
{
  format: 1,
  algorithm: 'A256GCM',
  keyId: string,      // Lowercase UUID.
  revision: number,   // Positive safe integer.
  nonce: string,      // Canonical unpadded base64url: exactly 12 decoded bytes.
  ciphertext: string  // Canonical unpadded base64url: 16..65536 decoded bytes.
}
```

Base64url must use the URL-safe alphabet, no padding, and canonical encoding. The ciphertext includes the 128-bit authentication tag. Plaintext is at most 65,520 bytes. The WebCrypto reference in `packages/crypto/src/notes.ts` uses AES-256-GCM and a fresh random 12-byte nonce on encryption:

```ts
generateNoteKey()
encryptNote(key, context, plaintext /* Uint8Array */)
decryptNote(key, context, envelope)
```

Context is `{ownerId,noteId,keyId,revision}`. Additional authenticated data (AAD) is exactly the UTF-8 bytes of:

```js
JSON.stringify(['bcommend.note',1,ownerId,noteId,keyId,revision])
```

Private titles and bodies belong inside the client-encrypted plaintext, not top-level transport fields. The envelope is opaque bytes, not a final canvas schema. The server validates shape and revision relationships; it cannot detect a buggy client uploading base64 plaintext instead of actual ciphertext. AEAD authentication is verified only on the client. CAS is not malicious-server rollback defense.

**Startup warning: `generateNoteKey()` creates a nonexportable, memory-only reference key. No vault, persistence, wrapping, or recovery is implemented. Encrypted data can be unrecoverable after process exit. Do not store important data.** Session renewal or OAuth recovery does not recover encryption keys. See `architecture/0001-android-e2ee.md` for proposed, unimplemented key-management gates.

## Notes

`PUT /v1/notes/{id}` uses a client-generated lowercase UUID and accepts only `{envelope,expectedVersion}`. Creation uses `expectedVersion: 0` and envelope revision `1`. Replacement sends the full envelope and last fetched positive expected version. In every PUT, `envelope.revision` must equal `expectedVersion + 1`.

- Creation returns `201` with `{ "note": ... }`. An initial creation retry with the same envelope and owner returns `200`; other reused IDs return a generic `409` without exposing another owner's data.
- Replacement atomically checks/increments the stored version and returns `200`, or `409` on conflict. Update retries are not automatically idempotent: after a lost response, fetch and compare before resolving or retrying. Re-encryption for a new revision must use that revision's context/AAD and a fresh nonce.
- `GET /v1/notes/{id}` returns `{ "note": ... }` containing the envelope object plus metadata: `id`, `owner_id`, `version`, `created_at`, `updated_at`, and `deleted_at`. Timestamps are Unix milliseconds.
- `GET /v1/notes?limit=25&cursor={id}` returns `{ "notes": [...], "nextCursor": null }` with metadata only (IDs, versions, timestamps), no title and no envelope. Limit is 1-100; omit cursor initially. UUID-ordered lists are not snapshots or sync feeds; newly inserted IDs before the cursor require a fresh listing.
- `DELETE /v1/notes/{id}` requires the quoted current version in `If-Match`, for example `If-Match: "2"`. It soft-deletes and increments the version. Stale deletes return `409`; deleted/inaccessible notes return `404`.

Owner isolation, authentication, CAS, and deletion semantics remain. Deleted IDs cannot be recreated; there is no restore/purge endpoint or retained version history. Old `{title,content,expectedVersion}` requests return `400`; there are no shipped consumers and no legacy fallback. Unknown fields are rejected. JSON bodies are limited to 128 KiB of actual UTF-8 input regardless of Content-Length. Per-user rate/storage quotas are not implemented; do not expose this foundation publicly.

Migration `0002` creates a separate encrypted-notes table and leaves old `notes` data untouched and unreachable through the API. It does not encrypt old records or securely purge plaintext from disks/backups. Do not delete development data without authorization.

## Retired Reminder Preview

`POST /v1/reminders/preview` is retired and returns `410` after authentication; invalid sessions still return `401`. Do not send private reminder rules to the server. The pure `schedule.ts` once/fixed-interval core remains, but the client must perform private scheduling locally. Calendar/Jalali recurrence, durable reminders, and notification delivery are not implemented.

## Future Content Boundaries

Private ink, OCR indexes/results, reminder rules, audio, filenames, attachments, and comments also require encryption before upload. OCR/search/reminders run locally, not through Workers AI on private content. Future Durable Objects relay encrypted CRDT updates; clients decrypt and merge, never the server. Encrypted sharing is not shipped; public-share keys must never use query parameters sent to a server and require a future reviewed delivery flow.

Owner/document/key IDs, revisions, timestamps, lengths, and network/access metadata remain visible. This contract promises neither full anonymity nor malicious-server rollback defense. Independent crypto/security review and Kotlin/Dart interoperability vector tests are launch gates, not current verification claims.
