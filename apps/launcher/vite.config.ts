import { defineConfig } from "vite";

// Relative, like the other two, so this works wherever it is mounted. It happens
// to be mounted at the root.
export default defineConfig({
  base: "./",
  server: { host: true, allowedHosts: [".ts.net", ".trycloudflare.com"], port: 5178 },
  build: { target: "es2022", outDir: "dist" },
});
