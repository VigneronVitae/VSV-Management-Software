import { defineConfig } from "vite";

// No plugins. The screens are plain TypeScript against the DOM, so there is
// nothing to transform beyond what vite does by default.
export default defineConfig({
  server: { host: true, port: 5173 },
  build: { target: "es2022", outDir: "dist" },
});
