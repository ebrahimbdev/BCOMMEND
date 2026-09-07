import { env, exports } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import worker from "../apps/api/src/index";

// Synthetic credentials exist only in the isolated test database, never production.
const ALICE = "a".repeat(43);
const BOB = "b".repeat(43);
const ID = "10000000-0000-4000-8000-000000000001";
const NOTE = { title: "Meeting", content: "Private text", expectedVersion: 0 };

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
    expect(await response.json()).toMatchObject({ status: "ok" });
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
    expect(await (await call(`/v1/notes/${ID}`)).json()).toMatchObject({ note: { id: ID, title: NOTE.title, content: NOTE.content, version: 1 } });
    expect((await env.DB.prepare("SELECT COUNT(*) AS count FROM notes").first<{ count: number }>())?.count).toBe(1);
  });

  it("preserves mixed RTL text and treats SQL syntax as plain content", async () => {
    const content = "\u0633\u0644\u0627\u0645 English '; DROP TABLE notes; --";
    await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content });
    expect(await (await call(`/v1/notes/${ID}`)).json()).toMatchObject({ note: { content } });
  });

  it("rejects same-ID creation with different content", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content: "different" })).status).toBe(409);
  });

  it("isolates reads, updates, deletes, creates, and lists across owners", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "GET", undefined, BOB)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, expectedVersion: 1 }, BOB)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, BOB, { "if-match": '"1"' })).status).toBe(404);
    const create = await call(`/v1/notes/${ID}`, "PUT", NOTE, BOB);
    expect(create.status).toBe(409);
    expect(await create.text()).not.toContain(NOTE.content);
    expect(await (await call("/v1/notes", "GET", undefined, BOB)).json()).toEqual({ notes: [], nextCursor: null });
  });

  it("atomically rejects a stale update", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content: "new", expectedVersion: 1 })).status).toBe(200);
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content: "stale", expectedVersion: 1 })).status).toBe(409);
    expect(await (await call(`/v1/notes/${ID}`)).json()).toMatchObject({ note: { content: "new", version: 2 } });
  });

  it("allows only one winner among concurrent updates", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    const responses = await Promise.all(["first", "second"].map((content) => call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content, expectedVersion: 1 })));
    expect(responses.map((response) => response.status).sort()).toEqual([200, 409]);
  });

  it("handles concurrent identical creates without duplicate records", async () => {
    const responses = await Promise.all([call(`/v1/notes/${ID}`, "PUT", NOTE), call(`/v1/notes/${ID}`, "PUT", NOTE)]);
    expect(responses.map((response) => response.status).sort()).toEqual([200, 201]);
    expect((await env.DB.prepare("SELECT COUNT(*) AS count FROM notes").first<{ count: number }>())?.count).toBe(1);
  });

  it("prevents both a delete and update from committing the same base version", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    const responses = await Promise.all([
      call(`/v1/notes/${ID}`, "PUT", { ...NOTE, content: "changed", expectedVersion: 1 }),
      call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"1"' }),
    ]);
    expect(responses.filter((response) => response.status === 200)).toHaveLength(1);
    expect(responses.filter((response) => [404, 409].includes(response.status))).toHaveLength(1);
    expect(await env.DB.prepare("SELECT version FROM notes WHERE id = ?").bind(ID).first()).toEqual({ version: 2 });
  });

  it("tombstones a note and prevents stale resurrection", async () => {
    await call(`/v1/notes/${ID}`, "PUT", NOTE);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"2"' })).status).toBe(409);
    expect((await call(`/v1/notes/${ID}`, "DELETE", undefined, ALICE, { "if-match": '"1"' })).status).toBe(200);
    expect((await call(`/v1/notes/${ID}`)).status).toBe(404);
    expect((await call(`/v1/notes/${ID}`, "PUT", NOTE)).status).toBe(409);
    expect((await call(`/v1/notes/${ID}`, "PUT", { ...NOTE, expectedVersion: 1 })).status).toBe(404);
    expect(await (await call("/v1/notes")).json()).toEqual({ notes: [], nextCursor: null });
    expect(await env.DB.prepare("SELECT version, deleted_at FROM notes WHERE id = ?").bind(ID).first()).toMatchObject({ version: 2, deleted_at: expect.any(Number) });
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
    expect(JSON.stringify(first)).not.toContain(NOTE.content);
    expect(await (await call(`/v1/notes?limit=1&cursor=${first.nextCursor}`)).json()).toMatchObject({ notes: [{ id: secondId }], nextCursor: null });
  });

  it.each(["limit=0", "limit=101", "limit=NaN", "cursor=", "cursor=oops"])("rejects bad pagination %s", async (query) => {
    expect((await call(`/v1/notes?${query}`)).status).toBe(400);
  });

  it.each([
    { ...NOTE, title: " " }, { ...NOTE, title: "x".repeat(201) },
    { ...NOTE, content: "x".repeat(20001) }, { ...NOTE, content: "\0" },
    { ...NOTE, expectedVersion: -1 }, { ...NOTE, expectedVersion: 1.5 },
    { ...NOTE, expectedVersion: "0" }, { ...NOTE, owner_id: "bob" }, [], null,
  ])("rejects invalid note input %#", async (input) => {
    expect((await call(`/v1/notes/${ID}`, "PUT", input)).status).toBe(400);
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
  it("previews without persisting or dispatching reminders", async () => {
    const response = await call("/v1/reminders/preview", "POST", {
      schedule: { kind: "interval", startAt: "2026-09-07T09:00:00.000Z", everySeconds: 3600, count: 2 },
      after: "2026-09-07T08:00:00.000Z",
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ occurrences: ["2026-09-07T09:00:00.000Z", "2026-09-07T10:00:00.000Z"] });
  });

  it("rejects unsupported calendar rules and unbounded preview size", async () => {
    expect((await call("/v1/reminders/preview", "POST", { schedule: { kind: "daily" }, after: "2026-09-07T08:00:00.000Z" })).status).toBe(400);
    expect((await call("/v1/reminders/preview", "POST", { schedule: { kind: "once", startAt: "2026-09-07T09:00:00.000Z" }, after: "2026-09-07T08:00:00.000Z", limit: 101 })).status).toBe(400);
  });
});
