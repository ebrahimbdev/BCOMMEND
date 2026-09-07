import type { Env as ApiEnv } from "../apps/api/src/index";

declare global {
  namespace Cloudflare {
    interface Env extends ApiEnv {
      TEST_MIGRATIONS: import("cloudflare:test").D1Migration[];
    }
    interface GlobalProps {
      mainModule: typeof import("../apps/api/src/index");
    }
  }
}
