// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The shop shell. Mounts one module and holds no domain logic."
// Depends on: [packages/shop/src/index.ts]
// Depended on by: [docs/status-ledger.md]
// ---------------------------------------------------------------------------
// The shop shell. Mounts one module and holds no domain logic, the same way the
// cellar shell does.
//
// This is the second periphery, and the winemaker's reason for wanting it is
// that two peripheries find problems one does not: a single client can lean on
// knowledge it never wrote down, and the second one cannot.
import { loadWhere, MissingConfig, readConfig } from "core";
import { mountShop } from "shop";

const target = document.querySelector<HTMLElement>("#app");

if (!target) {
  throw new Error("#app is missing from index.html");
}

// Where the kernel is, before anything asks it anything. `loadWhere` reads
// `where.json` from beside this app and picks the first route that answers, so
// the same build works over Tailscale and over Cloudflare and neither has to be
// named at build time. Every failure inside it is quiet and lands on what the
// build was given, which is what this app did before.
// The element is passed rather than closed over: the `if (!target) throw`
// above narrows it here and not inside a nested function, which is TypeScript
// being right about a thing that could change between the check and the call.
async function start(into: HTMLElement): Promise<void> {
  // Something on the screen while the routes are tried. Asking where the kernel
  // is happens before anything renders, and a route that has to time out leaves
  // a blank page for as long as it takes. A blank page and a broken app look the
  // same, which is A13 arriving at startup rather than at a refusal.
  const waiting = document.createElement("p");
  waiting.className = "lede";
  waiting.textContent = "Finding the winery.";
  into.append(waiting);

  await loadWhere();
  readConfig();
  mountShop(into);
}

try {
  await start(target);
} catch (error) {
  const message =
    error instanceof MissingConfig
      ? error.message
      : `Could not start: ${(error as Error).message}`;
  const p = document.createElement("p");
  p.className = "banner banner-error";
  p.textContent = message;
  target.append(p);
}
