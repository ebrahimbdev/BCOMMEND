# Stage 1 API

All `/v1/` routes require `Authorization: Bearer <local-session-token>`. `/health` is public liveness only and does not test D1 readiness. API responses use JSON and `Cache-Control: no-store`. There is no browser CORS policy yet; use native/CLI clients. Tokens in query strings are not supported.

This is a development contract, not a stable external API. No production login, full notebook model, reminder persistence, or synchronization protocol is shipped.

## Errors

```json
{
  "error": {
    "code": "conflict",
    "message": "Version changed; fetch before retrying"
  }
}
```

Relevant status codes: `400` invalid input, `401` invalid/expired/revoked session, `404` absent/inaccessible note, `409` version or ID conflict, `413` body limit, `415` content type, `503` unexpected service/storage failure. Clients must retain unsaved changes on every failure. Do not blindly retry `409` with the newest version: let the user resolve content differences.

## Identity

- `GET /v1/me`: returns `{ "id": "..." }` for the current user.
- `DELETE /v1/session`: revokes the current session. A subsequent request with it returns `401`.

Provisioning has no HTTP endpoint and the local CLI explicitly refuses arguments such as `--remote`.

## Notes

`PUT /v1/notes/{id}` uses a client-generated lowercase UUID. To create, send:

```json
{
  "title": "Meeting notes",
  "content": "Plain text for the first development stage.",
  "expectedVersion": 0
}
```

The response is `201` with `{ "note": ... }`. A note contains `id`, `owner_id`, `title`, `content`, `version`, `created_at`, `updated_at`, and `deleted_at`. Numeric timestamps are Unix milliseconds. A creation retry returns the original version-1 note with `200` only when the same owner, normalized title, and content match. Other reused IDs return a generic `409` without disclosing another owner's content.

To replace a note, send the complete title/content and the last fetched positive `expectedVersion`. The database checks and increments the version atomically. The response is `200` with the new note, or `409` if a newer version exists. Update retries are not automatically idempotent: after a lost response, fetch and compare before resolving or retrying.

- `GET /v1/notes/{id}`: returns one active, owned note.
- `GET /v1/notes?limit=25&cursor={id}`: UUID-ordered summaries without content; response `{ "notes": [...], "nextCursor": null }`. Limit is 1-100; omit cursor for the first page. Lists are not snapshots or sync feeds; new IDs sorting before an existing cursor appear on a fresh listing.
- `DELETE /v1/notes/{id}`: requires a quoted current version in `If-Match`, for example `If-Match: "2"`. Soft-deletes and increments the version. Stale deletes return `409`; already deleted/inaccessible notes return `404`.

Deleted IDs cannot be recreated. Tombstones are retained in this stage, with no restore or purge endpoint. Notes are text only: consumers must treat content as text, not trusted HTML.

Validation: title is trimmed and must be nonempty and at most 200 JavaScript UTF-16 code units before trimming; content is at most 20,000 code units; NUL is rejected. Unknown fields are rejected. JSON bodies are limited to 128 KiB of actual UTF-8 input regardless of Content-Length. There is no per-user storage/rate quota yet; do not expose this development foundation publicly.

## Schedule Preview

`POST /v1/reminders/preview`:

```json
{
  "schedule": {
    "kind": "interval",
    "startAt": "2026-09-07T09:00:00.000Z",
    "everySeconds": 3600,
    "count": 3
  },
  "after": "2026-09-07T09:00:00.000Z",
  "limit": 10
}
```

Response:

```json
{
  "occurrences": [
    "2026-09-07T10:00:00.000Z",
    "2026-09-07T11:00:00.000Z"
  ]
}
```

Rules:

- `once` accepts only `kind` and `startAt`.
- `interval` uses elapsed seconds, not a named time zone or calendar day.
- `everySeconds` is an integer from 60 to 31,536,000.
- Optional `count` is 1-10,000 and includes the original start, not just the returned results.
- Optional `until` is inclusive and cannot precede the start. Choose count or until, not both.
- Omit both count/until for a rule without an explicit end. A preview still returns at most 100 occurrences.
- `after` is exclusive; `limit` defaults to 10 and must be 1-100.
- Timestamps must be valid canonical UTC strings with milliseconds and `Z`, using four-digit years.
- Calendar, Jalali, DST, snooze, completion, and monthly rules are not yet implemented. Unsupported fields/rules fail validation rather than silently using interval semantics.

The preview **does not persist a reminder, enqueue work, or deliver an alert**.
