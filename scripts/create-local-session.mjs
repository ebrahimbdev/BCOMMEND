import { randomBytes, randomUUID, createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

// Intentionally accepts no options: this command must never provision remote accounts.
if (process.argv.length !== 2) {
  console.error("No arguments supported. This command provisions local development only.");
  process.exit(1);
}
const root = fileURLToPath(new URL("../", import.meta.url));
const token = randomBytes(32).toString("base64url");
const hash = createHash("sha256").update(token).digest("hex");
const userId = randomUUID();
const now = Date.now();
const expires = now + 7 * 24 * 60 * 60 * 1000;
const sql = `INSERT INTO users (id, created_at) VALUES ('${userId}', ${now}); INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES ('${hash}', '${userId}', ${now}, ${expires});`;
const result = spawnSync(process.execPath, [
  "node_modules/wrangler/bin/wrangler.js", "d1", "execute", "DB", "--local",
  "--config", "apps/api/wrangler.jsonc", "--command", sql,
], { cwd: root, stdio: "inherit", shell: false });
if (result.error || result.status !== 0) {
  console.error("Local provisioning failed. Apply local migrations first.");
  process.exit(1);
}
console.log(`Local user: ${userId}\nExpires: ${new Date(expires).toISOString()}\nLocal bearer token (shown once; do not commit or share):\n${token}`);
