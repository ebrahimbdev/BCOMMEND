import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { access } from "node:fs/promises";
import { randomUUID } from "node:crypto";

// Run only against disposable local D1 in CI/Docker, never a deployed service.
await access(new URL("../dist/api/index.js", import.meta.url));
const provision = spawnSync(process.execPath, ["scripts/create-local-session.mjs"], { encoding: "utf8" });
assert.equal(provision.status, 0, "Local session provisioning failed");
const token = provision.stdout.trim().split(/\r?\n/).at(-1);
assert.match(token, /^[A-Za-z0-9_-]{43}$/);
const unsafe = spawnSync(process.execPath, ["scripts/create-local-session.mjs", "--remote"], { encoding: "utf8" });
assert.equal(unsafe.status, 1, "Provisioning must reject remote flags");

const child = spawn(process.execPath, [
  "node_modules/wrangler/bin/wrangler.js", "dev", "--config", "apps/api/wrangler.jsonc",
  "--local", "--ip", "127.0.0.1", "--port", "8789",
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
  const path = `/v1/notes/${randomUUID()}`;
  const saved = await fetch(origin + path, { method: "PUT", headers, body: JSON.stringify({ title: "Smoke test", content: "Synthetic data", expectedVersion: 0 }) });
  assert.equal(saved.status, 201);
  await saved.arrayBuffer();
  const fetched = await fetch(origin + path, { headers });
  assert.equal(fetched.status, 200);
  assert.equal((await fetched.json()).note.content, "Synthetic data");
  const revoked = await fetch(`${origin}/v1/session`, { method: "DELETE", headers });
  assert.equal(revoked.status, 200);
  await revoked.arrayBuffer();
  const denied = await fetch(origin + path, { headers });
  assert.equal(denied.status, 401);
  await denied.arrayBuffer();
  console.log("Local build artifact, provisioning, HTTP CRUD, and revocation smoke checks passed. No credentials printed.");
} finally {
  if (child.pid) {
    if (process.platform === "win32") spawnSync("taskkill", ["/pid", String(child.pid), "/T", "/F"], { stdio: "ignore" });
    else {
      try { process.kill(-child.pid, "SIGTERM"); } catch (error) { if (error.code !== "ESRCH") throw error; }
    }
  }
}
