import { env, exports } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import worker from "../apps/api/src/index";
import { decryptNote, encryptNote, generateNoteKey } from "../packages/crypto/src/notes";

// Synthetic credentials exist only in the isolated test database, never production.
const ALICE = "a".repeat(43);
const BOB = "b".repeat(43);
const ID = "10000000-0000-4000-8000-000000000001";
const ENVELOPE = { format: 1, algorithm: "A256GCM", keyId: "30000000-0000-4000-8000-000000000003",
  revision: 1, nonce: "AAAAAAAAAAAAAAAA", ciphertext: "AAAAAAAAAAAAAAAAAAAAAA" };
const NOTE = { envelope: ENVELOPE, expectedVersion: 0 };
const UPDATE = { envelope: { ...ENVELOPE, revision: 2, ciphertext: "AQAAAAAAAAAAAAAAAAAAAA" }, expectedVersion: 1 };

async function hash(token: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function call(path: string, method = "GET", data?: unknown, token = ALICE, headers: Record<string, string> = {}) {
  return exports.default.fetch(`https://api.example.test${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, ...(data !== undefined ? { "content-type": "application/json" } : {}), ...headers },
    ...(data !== undefined ? { body: JSON.stringify(data) } : {}),
  });
}

beforeAll(async () => { await applyD1Migrations(env.DB, env.TEST_MIGRATIONS); });
beforeEach(async () => {
  await env.DB.batch([
    env.DB.prepare("DELETE FROM encrypted_notes"),
    env.DB.prepare("DELETE FROM notes"),
    env.DB.prepare("DELETE FROM sessions"),
    env.DB.prepare("DELETE FROM users"),
  ]);
  const now = Date.now();
  for (const [user, token] of [["alice", ALICE], ["bob", BOB]] as const) {
    await env.DB.batch([
      env.DB.prepare("INSERT INTO users (id, created_at) VALUES (?, ?)").bind(user, now),
      env.DB.prepare("INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)")
        .bind(await hash(token), user, now, now + 60000),
    ]);
  }
});

describe("authentication and failure safety", () => {
  it("offers a public health endpoint without querying D1", async () => {
    const response = await worker.fetch(new Request("https://api.example.test/health"), {} as typeof env);
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ status: "ok", version: "0.2.0" });
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it.each(["", "invalid", "c".repeat(43)])("rejects missing, malformed, and unknown credentials: %s", async (token) => {
    expect((await call("/v1/notes", "GET", undefined, token)).status).toBe(401);
  });

  it("rejects expired sessions", async () => {
    await env.DB.prepare("UPDATE sessions SET created_at = ?, expires_at = ? WHERE user_id = 'alice'")
      .bind(Date.now() - 10000, Date.now() - 1).run();
    expect((await call("/v1/me")).status).toBe(401);
  });

  it("returns the user, revokes the session, then rejects reuse", async () => {
    expect(await (await call("/v1/me")).json()).toEqual({ id: "alice" });
    expect((await call("/v1/session", "DELETE")).status).toBe(200);
    expect((await call("/v1/me")).status).toBe(401);
    expect((await call("/v1/me", "GET", undefined, BOB)).status).toBe(200);
  });

  it("persists only hashes and never echoes the bearer token", async () => {
    const rows = await env.DB.prepare("SELECT * FROM sessions").all();
    expect(JSON.stringify(rows)).not.toContain(ALICE);
    expect(JSON.stringify(rows)).toContain(await hash(ALICE));
    expect(await (await call("/v1/me")).text()).not.toContain(ALICE);
  });

  it("fails closed without disclosing database errors", async () => {
    const response = await worker.fetch(new Request("https://api.example.test/v1/me", { headers: { authorization: `Bearer ${ALICE}` } }), {} as typeof env);
    expect(response.status).toBe(503);
    expect(await response.text()).not.toMatch(/TypeError|SELECT|token_hash/);
  });
});

describe("private versioned notes", () => {
  it("creates a note, reads it, and retries initial creation safely", async () => {
    expect((await call(`/v1/notes/${ID}`, "PUT", NOTE)).status).toBe(201);
    expect((await call(`/v1/notes/${ID}`, "PUT", NOTE)).status).toBe(200);
    const reordered = { ciphertext: ENVELOPE.ciphertext, nonce: ENVELOPE.nonce, revision: 1,
      keyId: ENVELOPE.keyId, algorithm: ENVELOPE.algorithm, format: 1 };
    expect((await call(`/v1/notes/${ID}`, "PUT", { envelope: reordered, expectedVersion: 0 })).status).toBe(200);
    expect(await (await call(`/v1/notes/${ID}`)).json()).toMatchObject({ note: { id: ID, owner_id: "alice", envelope: ENVELOPE, version: 1 } });
    expect((await env.DB.prepare("SELECT COUNT(*) AS count FROM encrypted_notes").first<{ count: number }>())?.count).toBe(1);
  });

  it("round-trips real E2EE without storing plaintext or key material", async () => {
    const payload = { title: "Private meeting title", content: "\u0633\u0644\u0627\u0645 English '; DROP TABLE notes; --" };
    const key = await generateNoteKey();
    const context = { ownerId: "alice", noteId: ID, keyId: ENVELOPE.keyId, revision: 1 };
    const plaintext = new TextEncoder().encode(JSON.stringify(payload));
    const envelope = await encryptNote(key, context, plaintext);
    expect((await call(`/v1/notes/${ID}`, "PUT", { envelope, expectedVersion: 0 })).status).toBe(201);
    const result = await (await call(`/v1/notes/${ID}`)).json<{ note: { envelope: unknown } }>();
    expect(await decryptNote(key, context, result.note.envelope)).toEqual(plaintext);
    const dump = JSON.stringify(await env.DB.prepare("SELECT * FROM encrypted_notes").all());
    expect(dump).not.toContain(payload.title);
    expect(dump).not.toContain(payload.content);
    expect(dump).not.toContain('"title"');
    expect(dump).not.toContain('"content"');
    // An independently known key also makes absence of raw key bytes testable.
    const raw = crypto.getRandomValues(new Uint8Array(32));
    const knownKey = await crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
    const nextEnvelope = await encryptNote(knownKey, { ...context, revision: 2 }, plaintext);
    expect((await call(`/v1/notes/${ID}`, "PUT", { envelope: nextEnvelope, expectedVersion: 1 })).status).toBe(200);
    const nextDump = JSON.stringify(await env.DB.prepare("SELECT * FROM encrypted_notes").all());
    const encodedKey = btoa(String.fromCharCode(...raw)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    expect(nextDump).not.toContain(encodedKey);
    expect(nextDump).not.toContain(Array.from(raw).join(","));
    expect(nextDump).not.toContain(payload.title);
    expect(nextDump).not.toContain(payload.content);
  });

  it("never exposes or mutates legacy plaintext rows", async () => {
    await env.DB.prepare("INSERT INTO notes (id, owner_id, title, content, version, created_at, updated_at) VALUES (?, 'alice', 'Legacy title', 'Legacy body', 1, 1, 1)").bind(ID).run();
    expect((await call(`/v1/notes/${ID}`)).status).toBe(404);
    expect(await (await call("/v1/notes")).json()).toEqual({ notes: [], nextCursor: null });
    expect((await call(`/v1/notes/${ID}`, "PUT", UPDATE)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"1"' })).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "PUT", NOTE)).status).toBe(201);
    expect(await env.DB.prepare("SELECT title, content, version FROM notes WHERE id = ?").bind(ID).first()).toEqual({ title: "Legacy title", content: "Legacy body", version: 1 });
  });

  it.each(["{", "null", JSON.stringify({ ...ENVELOPE, revision: 2 })])("fails safely on corrupted stored envelopes: %s", async (stored) => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    await env.DB.prepare("UPDATE encrypted_notes SET envelope = ? WHERE id = ?").bind(stored, ID).run();
    const response = await call(`/v1/notes/${ID}`);
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: { code: "service_unavailable", message: "Request could not be completed; retain local changes and retry later" } });
  });

  it("rejects same-ID creation with different content", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, envelope: { ...ENVELOPE, ciphertext: UPDATE.envelope.ciphertext } })).status).toBe(409);
  });

  it("isolates reads, updates, deletes, creates, and lists across owners", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "GET", undefined, BOB)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "PUT", UPDATE, BOB)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, BOB, { "if-match": '"1"' })).status).toBe(404);
    const create = await call(`/v1/notes/${ID}`, "PUT", NOTE, BOB);
    expect(create.status).toBe(409);
    expect(await create.text()).not.toContain(ENVELOPE.ciphertext);
    expect(await (await call("/v1/notes", "GET", undefined, BOB)).json()).toEqual({ notes: [], nextCursor: null });
  });

  it("atomically rejects a stale update", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "PUT", UPDATE)).status).toBe(200);
    expect((await call(`/v1/notes/${ID}`, "PUT", UPDATE)).status).toBe(409);
    expect(await (await call(`/v1/notes/${ID}`)).json()).toMatchObject({ note: { envelope: UPDATE.envelope, version: 2 } });
  });

  it("allows only one winner among concurrent updates", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    const responses = await Promise.all([ENVELOPE.ciphertext, UPDATE.envelope.ciphertext].map((ciphertext) => call(`/v1/notes/${ID}`, "PUT", { ...UPDATE, envelope: { ...UPDATE.envelope, ciphertext } })));
    expect(responses.map((response) => response.status).sort()).toEqual([200, 409]);
  });

  it("handles concurrent identical creates without duplicate records", async () => {
    const responses = await Promise.all([call(`/v1/notes/${ID}`, "PUT", NOTE), call(`/v1/notes/${ID}`, "PUT", NOTE)]);
    expect(responses.map((response) => response.status).sort()).toEqual([200, 201]);
    expect((await env.DB.prepare("SELECT COUNT(*) AS count FROM encrypted_notes").first<{ count: number }>())?.count).toBe(1);
  });

  it("prevents both a delete and update from committing the same base version", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    const responses = await Promise.all([
      call(`/v1/notes/${ID}`, "PUT", UPDATE),
      call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"1"' }),
    ]);
    expect(responses.filter((response) => response.status === 200)).toHaveLength(1);
    expect(responses.filter((response) => [404, 409].includes(response.status))).toHaveLength(1);
    expect(await env.DB.prepare("SELECT version FROM encrypted_notes WHERE id = ?").bind(ID).first()).toEqual({ version: 2 });
  });

  it("tombstones a note and prevents stale resurrection", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"2"' })).status).toBe(409);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"1"' })).status).toBe(200);
    expect((await call(`/v1/notes/${ID}`)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "PUT", NOTE)).status).toBe(409);
    expect((await call(`/v1/notes/${ID}`, "PUT", UPDATE)).status).toBe(404);
    expect(await (await call("/v1/notes")).json()).toEqual({ notes: [], nextCursor: null });
    expect(await env.DB.prepare("SELECT version, deleted_at FROM encrypted_notes WHERE id = ?").bind(ID).first()).toMatchObject({ version: 2, deleted_at: expect.any(Number) });
  });

  it("requires a version for deletion", async () => {
    expect((await call(`/v1/notes/${ID}`, "DELETE")).status).toBe(400);
  });

  it("paginates without exposing note bodies in the list", async () => {
    const secondId = "20000000-0000-4000-8000-000000000002";
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    await call(`/v1/notes/${secondId}`, "PUT", NOTE);
    const first = await (await call("/v1/notes?limit=1")).json<{ notes: { id: string }[]; nextCursor: string }>();
    expect(first.notes.map((note) => note.id)).toEqual([ID]);
    expect(first.nextCursor).toBe(ID);
    expect(Object.keys(first.notes[0]!).sort()).toEqual(["created_at", "id", "updated_at", "version"]);
    expect(await (await call(`/v1/notes?limit=1&cursor=${first.nextCursor}`)).json()).toMatchObject({ notes: [{ id: secondId }], nextCursor: null });
  });

  it.each(["limit=0", "limit=101", "limit=NaN", "cursor=", "cursor=oops"])("rejects bad pagination %s", async (query) => {
    expect((await call(`/v1/notes?${query}`)).status).toBe(400);
  });

  it.each([
    { title: "Plaintext", content: "Forbidden", expectedVersion: 0 },
    { ...NOTE, title: "Forbidden" }, { ...NOTE, content: "Forbidden" }, { ...NOTE, key: "Forbidden" },
    { ...NOTE, envelope: null }, { expectedVersion: 0 },
    { ...NOTE, expectedVersion: -1 }, { ...NOTE, expectedVersion: 1.5 },
    { ...NOTE, expectedVersion: Number.MAX_SAFE_INTEGER }, { ...NOTE, expectedVersion: 1 },
    { ...NOTE, expectedVersion: "0" }, { ...NOTE, owner_id: "bob" }, [], null,
  ])("rejects invalid note input %#", async (input) => {
    expect((await call(`/v1/notes/${ID}`, "PUT", input)).status).toBe(400);
  });

  it.each([
    { format: 2 }, { algorithm: "none" }, { keyId: "invalid" }, { keyId: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA" },
    { revision: 0 }, { revision: 1.5 }, { revision: Number.MAX_SAFE_INTEGER + 1 },
    { nonce: "AAAAAAAAAAAAAAAA=" }, { nonce: "AA" }, { nonce: "!!!!!!!!!!!!!!!!" },
    { ciphertext: "AA" }, { ciphertext: "AAAAAAAAAAAAAAAAAAAAAB" },
    { ciphertext: "AAAAAAAAAAAAAAAAAAAAAA==" }, { ciphertext: "A".repeat(87384) },
    { title: "Forbidden" }, { ownerId: "alice" }, { noteId: ID }, { key: "Forbidden" },
  ])("rejects malformed or extended envelopes %#", async (invalid) => {
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, envelope: { ...ENVELOPE, ...invalid } })).status).toBe(400);
  });

  it("bounds the actual body, regardless of Content-Length", async () => {
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content: "x".repeat(140000) })).status).toBe(413);
  });

  it("bounds streaming input without a Content-Length header", async () => {
    let chunks = 0;
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (chunks++ < 20) controller.enqueue(new Uint8Array(16384).fill(32));
        else controller.close();
      },
      cancel() { cancelled = true; },
    });
    const request = new Request(`https://api.example.test/v1/notes/${ID}`, { method: "PUT", headers: { authorization: `Bearer ${ALICE}`, "content-type": "application/json" }, body: stream });
    expect(request.headers.has("content-length")).toBe(false);
    expect((await worker.fetch(request, env)).status).toBe(413);
    expect(cancelled).toBe(true);
    expect(chunks).toBeLessThan(20);
  });

  it("rejects malformed JSON and incorrect content type", async () => {
    const response = await exports.default.fetch(`https://api.example.test/v1/notes/${ID}`, { method: "PUT", headers: { authorization: `Bearer ${ALICE}`, "content-type": "application/json" }, body: "{" });
    expect(response.status).toBe(400);
    expect((await call(`/v1/notes/${ID}`, "PUT", NOTE, ALICE, { "content-type": "text/plain" })).status).toBe(415);
  });
});

describe("schedule preview API", () => {
  it("requires local processing without accepting plaintext schedules", async () => {
    const response = await call("/v1/reminders/preview", "POST", {
      schedule: { kind: "interval", startAt: "2026-09-07T09:00:00.000Z", everySeconds: 3600, count: 2 },
      after: "2026-09-07T08:00:00.000Z",
    });
    expect(response.status).toBe(410);
    expect(await response.json()).toMatchObject({ error: { code: "local_processing_required" } });
  });

  it("authenticates before rejecting the retired endpoint", async () => {
    expect((await call("/v1/reminders/preview", "POST", undefined, "invalid")).status).toBe(401);
    expect((await call("/v1/reminders/preview", "POST")).status).toBe(410);
  });
});
