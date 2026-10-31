import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: {
    include: ["tests/**/*.test.ts", "tests/**/*.test.tsx"],
    exclude: ["tests/fixtures/**", "tests/setup/**", "node_modules/**"],
    // check:specs reads this report to see which rules have passing tests.
    reporters: ["default", "json"],
    outputFile: { json: ".cache/test-results.json" },
  },
});
