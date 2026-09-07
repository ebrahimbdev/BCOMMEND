import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => ({
  plugins: [cloudflareTest({
    wrangler: { configPath: "./apps/api/wrangler.jsonc" },
    miniflare: { bindings: { TEST_MIGRATIONS: await readD1Migrations("./apps/api/migrations") } },
  })],
  test: { include: ["tests/**/*.test.ts"] },
}));
