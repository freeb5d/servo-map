import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: {
      // Mirror the tsconfig `@/*` -> `./src/*` alias so tests import like app code.
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      // Resolve the workspace package to its TS source so `--filter web test`
      // runs without pre-building shared (CI builds it first; this is for local).
      "@servo-map/shared": fileURLToPath(
        new URL("../shared/src/index.ts", import.meta.url),
      ),
      // Tokens ship as TS source, so tests read them without a build step.
      "@servo-map/design-tokens": fileURLToPath(
        new URL("../design-tokens/src/index.ts", import.meta.url),
      ),
    },
  },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
    globals: false,
  },
});
