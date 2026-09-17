import { defineConfig } from "vite";

// Served under /shop/ so it shares an origin with the cellar app, which is what
// makes one sign-in serve both: supabase-js keeps the session in localStorage,
// and localStorage is per origin. A different port or host would mean signing in
// twice, which for an intern in a barn means not signing in at all.
//
// Port 5174 in development, where the two are necessarily separate origins and
// a second sign-in is a development inconvenience rather than a barn one.
export default defineConfig({
  // Relative, not "/shop/". The app is reached at /shop/ through a proxy that
  // strips that prefix before forwarding, so a base of "/shop/" makes Vite
  // redirect "/" to "/shop/", which the proxy strips again: a loop. Relative
  // URLs resolve against whatever prefix the document was served under, so the
  // same build works at /shop/, at the root, or anywhere else.
  base: "./",
  server: { host: true, allowedHosts: [".ts.net", ".trycloudflare.com"], port: 5174 },
  build: { target: "es2022", outDir: "dist" },
});
