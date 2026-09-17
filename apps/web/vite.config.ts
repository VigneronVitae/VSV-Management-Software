import { defineConfig } from "vite";

// No plugins. The screens are plain TypeScript against the DOM, so there is
// nothing to transform beyond what vite does by default.
export default defineConfig({
  // Relative, since 0109 moved this app from the root to /cellar/ and the front
  // door took its place. The proxy strips the prefix before forwarding, so an
  // absolute /src/ would resolve against the root and reach the launcher.
  base: "./",
  server: { host: true, allowedHosts: [".ts.net", ".trycloudflare.com"], port: 5173 },
  build: { target: "es2022", outDir: "dist" },
});
