import { defineConfig } from "vite";

// Served under /shop/ so it shares an origin with the cellar app, which is what
// makes one sign-in serve both: supabase-js keeps the session in localStorage,
// and localStorage is per origin. A different port or host would mean signing in
// twice, which for an intern in a barn means not signing in at all.
//
// Port 5174 in development, where the two are necessarily separate origins and
// a second sign-in is a development inconvenience rather than a barn one.
export default defineConfig({
  base: "/shop/",
  server: { host: true, allowedHosts: [".ts.net", ".trycloudflare.com"], port: 5174 },
  build: { target: "es2022", outDir: "dist" },
});
