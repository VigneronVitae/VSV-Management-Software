// The service worker. It exists for one reason the winemaker asked for directly
// and one that follows from it.
//
// **Installability.** Chrome will only build a real WebAPK, with its own entry
// in the task switcher and its own window, for a site that has a service worker
// with a fetch handler. Without one, "Add to Home screen" makes a shortcut that
// runs as a browser tab and is evicted exactly as readily as before, which was
// the original complaint: leaving the app to take a photo and coming back to the
// home screen.
//
// **A shell that survives a dead server.** The database and the dev server both
// live on one desktop. When that is asleep, the app used to show a connection
// error with no way to tell whether the phone or the winery was at fault.
//
// **The thing this must never do is serve stale code.** Fixes go out during
// harvest by reloading, and a cache-first worker would quietly pin yesterday's
// build with no obvious way to clear it. So: network first for anything that is
// the program, cache only as the fallback, and the cache is only ever consulted
// when the network actually failed. Being slightly slower on a good connection
// is the correct trade when the alternative is being wrong on a bad one.
//
// It is deliberately not an offline story. `S-47` stays open: writes still go
// straight to the kernel and there is no queue, and a cold start with no signal
// will get the shell and then fail to sign in. What this buys is that the
// failure happens inside the app, where a screen can say so, rather than as the
// browser's own error page.

const VERSION = "v1";
const SHELL = `vsv-shell-${VERSION}`;

// Only what is genuinely static. The program itself is deliberately absent:
// under the dev server it is dozens of modules with changing query strings, and
// precaching a partial graph would produce an app that loads and does not run,
// which is worse than one that says it cannot reach the winery.
// Relative to this worker's own scope, which is /cellar/ since 0109 moved the
// app off the root and gave the root to the front door. Absolute paths here
// would precache the launcher's index as the cellar's shell, and then serve it
// for every cellar navigation while offline: the app would open on somebody
// else's page and look like it had lost its mind.
const ALWAYS = [
  "./",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable-512.png",
  "./apple-touch-icon.png",
].map((p) => new URL(p, self.registration.scope).toString());

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL);
      // Individually, because one 404 in addAll rejects the whole install and
      // leaves the worker never activating, which is a hard failure for a
      // missing icon.
      await Promise.all(ALWAYS.map((url) => cache.add(url).catch(() => undefined)));
      // Take over immediately rather than waiting for every tab to close. A fix
      // shipped during harvest should arrive on the next reload, not whenever
      // the phone happens to have no page open.
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(names.filter((n) => n !== SHELL).map((n) => caches.delete(n)));
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;

  // Reads only. A write that the worker replayed or answered from a cache would
  // be a write nobody made, and this app has no queue: every write is meant to
  // reach the kernel or visibly fail.
  if (request.method !== "GET") return;

  // The kernel is a different origin, and its answers are the live state of the
  // cellar. Caching those would mean showing a bin as unweighed after it was
  // weighed, which is the one thing intake must never do.
  if (new URL(request.url).origin !== self.location.origin) return;

  event.respondWith(
    (async () => {
      try {
        const fresh = await fetch(request);
        // Only what came back whole. An error page cached under the app's own
        // URL is how a site becomes permanently broken for one person.
        if (fresh?.ok && fresh.type === "basic") {
          const cache = await caches.open(SHELL);
          cache.put(request, fresh.clone());
        }
        return fresh;
      } catch (offline) {
        const hit = await caches.match(request);
        if (hit) return hit;
        // A navigation with nothing cached for it still wants the shell, so the
        // app itself can say what is wrong in its own words.
        if (request.mode === "navigate") {
          const shell = await caches.match("/");
          if (shell) return shell;
        }
        throw offline;
      }
    })(),
  );
});
