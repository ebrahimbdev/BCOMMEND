import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { access } from "node:fs/promises";
import { randomUUID, webcrypto } from "node:crypto";
import { fileURLToPath } from "node:url";

// Run only against disposable local D1 in CI/Docker, never a deployed service.
const bundle = new URL("../dist/api/index.js", import.meta.url);
await access(bundle);
const provision = spawnSync(process.execPath, ["scripts/create-local-session.mjs"], { encoding: "utf8" });
assert.equal(provision.status, 0, "Local session provisioning failed");
const token = provision.stdout.trim().split(/\r?\n/).at(-1);
assert.ok(typeof token === "string" && /^[A-Za-z0-9_-]{43}$/.test(token), "Local provisioning returned an invalid credential");
const unsafe = spawnSync(process.execPath, ["scripts/create-local-session.mjs", "--remote"], { encoding: "utf8" });
assert.equal(unsafe.status, 1, "Provisioning must reject remote flags");

const child = spawn(process.execPath, [
  "node_modules/wrangler/bin/wrangler.js", "dev", fileURLToPath(bundle), "--config", "apps/api/wrangler.jsonc",
  "--no-bundle", "--local", "--ip", "127.0.0.1", "--port", "8789",
], { stdio: "ignore", detached: process.platform !== "win32" });
const origin = "http://127.0.0.1:8789";
try {
  let ready = false;
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      const response = await fetch(`${origin}/health`, { signal: AbortSignal.timeout(500) });
      ready = response.ok;
      await response.arrayBuffer();
      if (ready) break;
    } catch { /* Startup may take a few seconds on CI. */ }
    if (child.exitCode !== null) break;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  assert.ok(ready, "Local Worker did not become ready; check native workerd requirements");
  const headers = { authorization: `Bearer ${token}`, "content-type": "application/json" };
  const me = await fetch(`${origin}/v1/me`, { headers });
  assert.equal(me.status, 200);
  const user = await me.json();
  assert.equal(typeof user.id, "string");
  const noteId = randomUUID();
  const path = `/v1/notes/${noteId}`;
  const keyId = randomUUID();
  const revision = 1;
  const key = await webcrypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
  const nonce = webcrypto.getRandomValues(new Uint8Array(12));
  const additionalData = new TextEncoder().encode(JSON.stringify(["bcommend.note", 1, user.id, noteId, keyId, revision]));
  const plaintext = new TextEncoder().encode(JSON.stringify({ title: "Smoke test", content: "Synthetic data" }));
  const ciphertext = await webcrypto.subtle.encrypt({ name: "AES-GCM", iv: nonce, additionalData, tagLength: 128 }, key, plaintext);
  const envelope = { format: 1, algorithm: "A256GCM", keyId, revision,
    nonce: Buffer.from(nonce).toString("base64url"), ciphertext: Buffer.from(ciphertext).toString("base64url") };
  const saved = await fetch(origin + path, { method: "PUT", headers, body: JSON.stringify({ envelope, expectedVersion: 0 }) });
  assert.equal(saved.status, 201);
  await saved.arrayBuffer();
  const fetched = await fetch(origin + path, { headers });
  assert.equal(fetched.status, 200);
  const stored = (await fetched.json()).note;
  assert.ok(JSON.stringify(stored.envelope) === JSON.stringify(envelope), "Encrypted envelope changed");
  const decrypted = await webcrypto.subtle.decrypt({ name: "AES-GCM", iv: Buffer.from(stored.envelope.nonce, "base64url"), additionalData, tagLength: 128 }, key,
    Buffer.from(stored.envelope.ciphertext, "base64url"));
  assert.ok(Buffer.from(decrypted).equals(Buffer.from(plaintext)), "Encrypted note round-trip failed");
  const revoked = await fetch(`${origin}/v1/session`, { method: "DELETE", headers });
  assert.equal(revoked.status, 200);
  await revoked.arrayBuffer();
  const denied = await fetch(origin + path, { headers });
  assert.equal(denied.status, 401);
  await denied.arrayBuffer();
  console.log("Local build artifact, provisioning, encrypted note round-trip, and revocation smoke checks passed. No credentials printed.");
} finally {
  if (child.pid) {
    if (process.platform === "win32") spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore" });
    else {
      try { process.kill(-child.pid, "SIGTERM"); } catch (error) { if (error.code !== "ESRCH") throw error; }
    }
  }
}
