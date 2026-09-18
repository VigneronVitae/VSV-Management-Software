import { defineConfig } from "vite";

// Relative, like the other three. Served under /vineyard/ through a proxy that
// strips the prefix, so an absolute base resolves against the root and reaches
// the front door instead. See the shop's config for the loop that causes.
export default defineConfig({
  base: "./",
  server: { host: true, allowedHosts: [".ts.net", ".trycloudflare.com"], port: 5180 },
  build: { target: "es2022", outDir: "dist" },
});
