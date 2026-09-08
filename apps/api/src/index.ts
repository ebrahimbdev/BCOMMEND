import { validateEnvelope } from "../../../packages/protocol/src/note-envelope";

export interface Env { DB: D1Database }

interface Note {
  id: string;
  owner_id: string;
  envelope: string;
  version: number;
  created_at: number;
  updated_at: number;
  deleted_at: number | null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const MAX_BODY = 128 * 1024;

class HttpError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) { super(message); }
}

function json(data: unknown, status = 200): Response {
  return Response.json(data, { status, headers: {
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
  } });
}

async function body(request: Request): Promise<Record<string, unknown>> {
  if (request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase() !== "application/json") {
    throw new HttpError(415, "unsupported_media_type", "Use application/json");
  }
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(400, "invalid_body", "A JSON object is required");
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY) {
      await reader.cancel();
      throw new HttpError(413, "body_too_large", "Maximum request size is 128 KiB");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try {
    const parsed: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error();
    return parsed as Record<string, unknown>;
  } catch { throw new HttpError(400, "invalid_body", "A valid JSON object is required"); }
}

function fields(data: Record<string, unknown>, allowed: string[]) {
  if (Object.keys(data).some((key) => !allowed.includes(key))) {
    throw new HttpError(400, "invalid_body", "Unknown request field");
  }
}

async function authenticate(request: Request, db: D1Database) {
  const token = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(request.headers.get("authorization") ?? "")?.[1];
  if (!token) throw new HttpError(401, "unauthorized", "A valid session is required");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  const hash = Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
  const session = await db.prepare("SELECT user_id FROM sessions WHERE token_hash = ? AND expires_at > ? AND revoked_at IS NULL")
    .bind(hash, Date.now()).first<{ user_id: string }>();
  if (!session) throw new HttpError(401, "unauthorized", "A valid session is required");
  return { userId: session.user_id, hash };
}

function validateNote(data: Record<string, unknown>) {
  fields(data, ["envelope", "expectedVersion"]);
  if (!Number.isSafeInteger(data.expectedVersion) || (data.expectedVersion as number) < 0 || (data.expectedVersion as number) >= Number.MAX_SAFE_INTEGER) {
    throw new HttpError(400, "invalid_version", "expectedVersion must be a nonnegative safe integer");
  }
  let envelope;
  try { envelope = validateEnvelope(data.envelope); }
  catch { throw new HttpError(400, "invalid_envelope", "A valid encrypted note envelope is required"); }
  const version = data.expectedVersion as number;
  if (envelope.revision !== version + 1) {
    throw new HttpError(400, "invalid_revision", "Envelope revision must equal expectedVersion + 1");
  }
  // Fixed field order makes initial-create retries independent of JSON key order.
  return { envelope: JSON.stringify({ format: envelope.format, algorithm: envelope.algorithm, keyId: envelope.keyId,
    revision: envelope.revision, nonce: envelope.nonce, ciphertext: envelope.ciphertext }), version };
}

function publicNote(note: Note) {
  const envelope = validateEnvelope(JSON.parse(note.envelope));
  if (envelope.revision !== note.version) throw new Error("Stored revision mismatch");
  return { ...note, envelope };
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  if (request.method === "GET" && path === "/health") return json({ status: "ok", service: "bcommend-api", version: "0.2.0" });
  if (!path.startsWith("/v1/")) throw new HttpError(404, "not_found", "Route not found");
  const { userId, hash } = await authenticate(request, env.DB);
  if (path === "/v1/me" && request.method === "GET") return json({ id: userId });
  if (path === "/v1/session" && request.method === "DELETE") {
    await env.DB.prepare("UPDATE sessions SET revoked_at = ? WHERE token_hash = ?").bind(Date.now(), hash).run();
    return json({ revoked: true });
  }
  if (path === "/v1/reminders/preview" && request.method === "POST") {
    throw new HttpError(410, "local_processing_required", "Compute encrypted note reminders locally");
  }
  if (path === "/v1/notes" && request.method === "GET") {
    const cursor = url.searchParams.get("cursor");
    const rawLimit = url.searchParams.get("limit") ?? "25";
    const limit = Number(rawLimit);
    if ((cursor !== null && !UUID.test(cursor)) || !/^\d{1,3}$/.test(rawLimit) || limit < 1 || limit > 100) {
      throw new HttpError(400, "invalid_pagination", "Use a UUID cursor and limit between 1 and 100");
    }
    const { results } = await env.DB.prepare("SELECT id, version, created_at, updated_at FROM encrypted_notes WHERE owner_id = ? AND deleted_at IS NULL AND id > ? ORDER BY id LIMIT ?")
      .bind(userId, cursor ?? "", limit + 1).all<Pick<Note, "id" | "version" | "created_at" | "updated_at">>();
    return json({ notes: results.slice(0, limit), nextCursor: results.length > limit ? results[limit - 1]!.id : null });
  }
  const match = /^\/v1\/notes\/([^/]+)$/.exec(path);
  if (!match || !UUID.test(match[1]!)) throw new HttpError(404, "not_found", "Route not found");
  const id = match[1]!;
  if (request.method === "GET") {
    const note = await env.DB.prepare("SELECT * FROM encrypted_notes WHERE id = ? AND owner_id = ? AND deleted_at IS NULL").bind(id, userId).first<Note>();
    if (!note) throw new HttpError(404, "not_found", "Note not found");
    return json({ note: publicNote(note) });
  }
  if (request.method === "PUT") {
    const data = validateNote(await body(request));
    const now = Date.now();
    if (data.version === 0) {
      const inserted = await env.DB.prepare("INSERT INTO encrypted_notes (id, owner_id, envelope, version, created_at, updated_at) VALUES (?, ?, ?, 1, ?, ?) ON CONFLICT(id) DO NOTHING RETURNING *")
        .bind(id, userId, data.envelope, now, now).first<Note>();
      if (inserted) return json({ note: publicNote(inserted) }, 201);
      const existing = await env.DB.prepare("SELECT * FROM encrypted_notes WHERE id = ? AND owner_id = ? AND deleted_at IS NULL").bind(id, userId).first<Note>();
      const existingNote = existing ? publicNote(existing) : null;
      if (existing?.version === 1 && existing.envelope === data.envelope) return json({ note: existingNote });
      throw new HttpError(409, "conflict", "ID unavailable or content has changed; fetch before retrying");
    }
    const note = await env.DB.prepare("UPDATE encrypted_notes SET envelope = ?, version = version + 1, updated_at = ? WHERE id = ? AND owner_id = ? AND version = ? AND deleted_at IS NULL RETURNING *")
      .bind(data.envelope, now, id, userId, data.version).first<Note>();
    if (note) return json({ note: publicNote(note) });
    const current = await env.DB.prepare("SELECT id FROM encrypted_notes WHERE id = ? AND owner_id = ? AND deleted_at IS NULL").bind(id, userId).first();
    if (!current) throw new HttpError(404, "not_found", "Note not found");
    throw new HttpError(409, "conflict", "Version changed; fetch before retrying");
  }
  if (request.method === "DELETE") {
    const header = request.headers.get("if-match");
    if (!header || !/^"[1-9]\d{0,15}"$/.test(header) || !Number.isSafeInteger(Number(header.slice(1, -1))) || Number(header.slice(1, -1)) >= Number.MAX_SAFE_INTEGER) {
      throw new HttpError(400, "invalid_version", "Provide the current version as a quoted If-Match value");
    }
    const now = Date.now();
    const deleted = await env.DB.prepare("UPDATE encrypted_notes SET deleted_at = ?, updated_at = ?, version = version + 1 WHERE id = ? AND owner_id = ? AND version = ? AND deleted_at IS NULL RETURNING id, version")
      .bind(now, now, id, userId, Number(header.slice(1, -1))).first();
    if (deleted) return json({ deleted });
    const current = await env.DB.prepare("SELECT id FROM encrypted_notes WHERE id = ? AND owner_id = ? AND deleted_at IS NULL").bind(id, userId).first();
    if (!current) throw new HttpError(404, "not_found", "Note not found");
    throw new HttpError(409, "conflict", "Version changed; fetch before deleting");
  }
  throw new HttpError(405, "method_not_allowed", "Method not supported");
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try { return await route(request, env); }
    catch (error) {
      if (error instanceof HttpError) return json({ error: { code: error.code, message: error.message } }, error.status);
      // Never expose database errors, tokens, request bodies, or private note text.
      return json({ error: { code: "service_unavailable", message: "Request could not be completed; retain local changes and retry later" } }, 503);
    }
  },
} satisfies ExportedHandler<Env>;
