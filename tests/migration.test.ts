import { env } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
import { expect, it } from "vitest";

it("upgrades a populated Stage 1 database without deleting or pretending to encrypt legacy content", async () => {
  // The Workers test runner isolates storage by test file.
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS.slice(0, 1));
  await env.DB.prepare("INSERT INTO users (id, created_at) VALUES ('legacy-owner', 1)").run();
  await env.DB.prepare("INSERT INTO notes (id, owner_id, title, content, version, created_at, updated_at) VALUES ('legacy-note', 'legacy-owner', 'Synthetic legacy title', 'Synthetic legacy content', 3, 1, 2)").run();
  const before = await env.DB.prepare("SELECT * FROM notes WHERE id = 'legacy-note'").first();
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
  expect(await env.DB.prepare("SELECT * FROM notes WHERE id = 'legacy-note'").first()).toEqual(before);
  expect(await env.DB.prepare("SELECT COUNT(*) AS count FROM encrypted_notes").first()).toEqual({ count: 0 });
});
