import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

// Use an absolute path: Wrangler changes directory when loading a nested config.
const root = fileURLToPath(new URL("../", import.meta.url));
const output = fileURLToPath(new URL("../dist/api/", import.meta.url));
const result = spawnSync(process.execPath, [
  "node_modules/wrangler/bin/wrangler.js", "deploy", "--dry-run",
  "--config", "apps/api/wrangler.jsonc", "--outdir", output,
], { cwd: root, stdio: "inherit", shell: false });
if (result.error) console.error("Could not start the local Worker bundler");
process.exit(result.status ?? 1);
