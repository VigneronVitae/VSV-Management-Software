// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The smallest possible contract: a file served beside the app saying
//           where its kernel can be reached, so that changing how the winery is
//           reached is an edit rather than five rebuilds."
// Depends on: [packages/core/src/env.ts, docs/moving-off-tailscale.md]
// Depended on by: [packages/core/src/env.ts,
//                  packages/core/src/index.ts,
//                  docs/status-ledger.md]
// ---------------------------------------------------------------------------
//
// "So how about while we are swapping we make it easier to swap in the future,
// so those are derived from the contract. Although also the idea of multiple
// working sounds great for the next month."
//
// **The problem this fixes.** `VITE_SUPABASE_URL` is read at build time, so the
// hostname the winery is reached on is compiled into all five bundles as a
// literal string. Changing how anybody gets to the barn, from Tailscale to
// Cloudflare or back, therefore means editing five env files, rebuilding five
// apps and getting the order right, which is most of why that swap is a
// migration rather than a config change.
//
// **The fix is one indirection, and it has to be exactly one.** The app cannot
// ask the kernel where the kernel is, so something outside the kernel has to
// say. That something is a static file served next to the app, `where.json`,
// which is the smallest contract in the system: it says where the real contract
// lives and nothing else. Editing it and reloading is the whole of a transport
// change.
//
// **Several at once, which is the half he asked for.** `where.json` carries a
// list rather than a value, and the app uses the first one that answers. So
// Tailscale and Cloudflare can both be live through the changeover, a phone on
// the tailnet takes the tailnet and a phone on cellular takes Cloudflare, and
// neither needs to know which it is on. When one is turned off, nothing is
// rebuilt and nobody is told.
//
// What it deliberately does not do is discover anything. There is no scanning
// and no guessing at hostnames from `window.location`: a convention like "the
// api is the same host with api. in front" works until the day it does not, and
// fails by connecting to something unexpected rather than by saying so.

export type KernelRoute = {
  /** What to call it when something has to be said out loud. */
  name: string;
  url: string;
  /** Optional. Absent means the one the build was given, which is the usual
   * case because every route here is the same Supabase instance reached a
   * different way. */
  anonKey?: string;
};

export type Where = {
  cellar?: KernelRoute[];
  practice?: KernelRoute[];
};

// Which route answered last time, per device. Trying it first is what keeps the
// common case to one request rather than a race every time the app opens.
const LAST_GOOD = "vsv.route";

let loaded: Where | null = null;

/** What was found, or null when nothing was. Synchronous, so `readConfig` stays
 * synchronous and every caller of `kernel()` is unchanged. */
export function whereFound(): Where | null {
  return loaded;
}

function remember(url: string): void {
  try {
    localStorage.setItem(LAST_GOOD, url);
  } catch {
    // A browser that will not remember simply races again next time, which
    // costs a request and is not worth a branch anywhere else.
  }
}

function lastGood(): string | null {
  try {
    return localStorage.getItem(LAST_GOOD);
  } catch {
    return null;
  }
}

/** Does this route answer? PostgREST replies to an unauthenticated GET on its
 * root with something rather than nothing, which is all this needs to know: the
 * question is whether the barn is reachable this way, not whether the caller may
 * read anything. */
async function answers(route: KernelRoute, ms: number): Promise<boolean> {
  const stop = AbortSignal.timeout(ms);
  try {
    // `no-cors` is deliberately not used: an opaque response cannot be
    // distinguished from a failure, which is the A13 shape, and every route here
    // is a Supabase instance that sends CORS headers.
    const r = await fetch(new URL("/rest/v1/", route.url).toString(), {
      method: "GET",
      signal: stop,
      cache: "no-store",
    });
    // Any answer at all, including a refusal. A 401 means the barn is reachable
    // and this caller has no key, which is a different thing from the barn being
    // unreachable and is the whole point of asking.
    return r.status > 0;
  } catch {
    return false;
  }
}

/** Reads `where.json` from beside the app and picks a route that answers.
 *
 * Every failure is quiet and lands on the build-time configuration, because a
 * winery whose app will not start is worse than a winery reached the old way.
 * The one thing that must not happen is starting up pointed at nothing while
 * appearing to work, and that cannot happen here: `readConfig` throws
 * `MissingConfig` when there is no route at all, from either source. */
// Six seconds, not two and a half. The first request over the tailnet includes
// the TLS handshake and took 2.4 s from the desktop itself on 2026-09-24; from a
// phone on cellular it took longer, the probe gave up on a route that was
// working, and the app fell through to a Cloudflare route that did not exist
// yet. Books and shop stopped working on the phone and nothing said why. A slow
// start is a nuisance; a wrong route is an outage.
export async function loadWhere(timeoutMs = 6000): Promise<void> {
  let doc: Where;
  try {
    const at = new URL("where.json", document.baseURI).toString();
    const res = await fetch(at, { cache: "no-store" });
    if (!res.ok) return;
    doc = (await res.json()) as Where;
  } catch {
    return;
  }

  const routes = doc.cellar ?? [];
  if (routes.length === 0) {
    loaded = doc;
    return;
  }

  // The one that worked last time goes first, so a phone that has been on this
  // network before spends one request rather than racing.
  const preferred = lastGood();
  const ordered = preferred
    ? [
        ...routes.filter((r) => r.url === preferred),
        ...routes.filter((r) => r.url !== preferred),
      ]
    : routes;

  for (const route of ordered) {
    if (await answers(route, timeoutMs)) {
      loaded = { ...doc, cellar: [route, ...ordered.filter((r) => r !== route)] };
      remember(route.url);
      return;
    }
  }

  // Nothing answered in time. The route that worked last on this device goes
  // first, because a slow answer from a route known to work is far likelier
  // than the barn having moved. Only with no history does the list's own order
  // decide. This used to take the first entry unconditionally, which is how a
  // phone that had used Tailscale every day was pointed at a hostname that did
  // not exist.
  loaded = { ...doc, cellar: ordered };
}
