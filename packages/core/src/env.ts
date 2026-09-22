// ---------------------------------------------------------------------------
// Type: source
// Purpose: "Which kernel this app talks to, and which of the two stacks: the
//           cellar that holds the vintage or the practice one where deleting
//           is allowed."
// Depends on: [packages/core/src/where.ts]
// Depended on by: [packages/core/src/where.ts, packages/core/src/index.ts]
// ---------------------------------------------------------------------------
// Vite substitutes these at build time. Declared here rather than pulling in
// vite/client so that core stays buildable by anything, not just by vite.
declare global {
  interface ImportMeta {
    readonly env: Record<string, string | undefined>;
  }
}

import { whereFound } from "./where.ts";

export type KernelConfig = {
  url: string;
  anonKey: string;
};

export class MissingConfig extends Error {}

// --- which stack -----------------------------------------------------------
//
// The winemaker: "how can I have a server or delete things or whatever so I can
// actually play around and try out things and delete them later, but also use
// the app to record". And then, on being asked how the app should know which
// one it is talking to: "a switch inside the app, and maybe it's a debugging
// mode that actually ships?"
//
// **That second sentence is the design.** A developer's toggle and a shipped
// feature are different things: a toggle can be obscure and a feature has to be
// understood by somebody who did not build it. So this is practice mode, every
// winery gets one, and the words for it are a winemaker's rather than a
// programmer's.
//
// The dangerous case is not "the practice stack is hard to reach". It is
// "somebody records a real pick into practice, or deletes a real lot thinking
// they are in practice". Both are the same failure and it is A13's: two states
// that look alike. Everything below exists to make them not look alike.
//
// Which stack is in use lives in `localStorage` under a key this module owns,
// rather than being passed around, because every caller of `kernel()` would
// otherwise have to remember to ask.

const PRACTICE_KEY = "vsv.practice";

export type Backend = "cellar" | "practice";

/** Whether practice mode is configured at all. A build with no practice stack
 * behind it must not offer the switch, or somebody turns it on and every screen
 * fails to load with no explanation. */
export function practiceAvailable(): boolean {
  const found = whereFound();
  if (found?.practice && found.practice.length > 0) return true;
  return Boolean(
    import.meta.env.VITE_PRACTICE_URL && import.meta.env.VITE_PRACTICE_ANON_KEY,
  );
}

export function currentBackend(): Backend {
  // The cellar is the answer to every ambiguous case. A storage read that
  // throws, a value nobody recognises, a practice stack that is no longer
  // configured: all of them land on the real one, because being wrongly in the
  // cellar costs a refusal and being wrongly in practice costs a record.
  if (!practiceAvailable()) return "cellar";
  try {
    return localStorage.getItem(PRACTICE_KEY) === "on" ? "practice" : "cellar";
  } catch {
    return "cellar";
  }
}

export function setBackend(backend: Backend): void {
  try {
    if (backend === "practice") localStorage.setItem(PRACTICE_KEY, "on");
    else localStorage.removeItem(PRACTICE_KEY);
  } catch {
    // A browser that will not store this is a browser that stays in the cellar,
    // which is the safe end of the failure.
  }
}

// Where the kernel is, in the order the answers are trusted.
//
// 1. `where.json`, served beside the app and edited without rebuilding. It is
//    the reason changing transport is a config change rather than a migration.
// 2. What the build was given, which is what every app used before 0141's day
//    and is what a build with no `where.json` beside it still uses.
//
// The key is allowed to come from the build even when the url comes from the
// file, because every route in `where.json` is normally the same Supabase
// instance reached a different way, and repeating the key in each entry would
// be four copies of one string to keep in step.
function fromWhere(which: "cellar" | "practice"): KernelConfig | null {
  const route = whereFound()?.[which]?.[0];
  if (!route) return null;
  const anonKey =
    route.anonKey ??
    (which === "practice"
      ? import.meta.env.VITE_PRACTICE_ANON_KEY
      : import.meta.env.VITE_SUPABASE_ANON_KEY);
  if (!anonKey) return null;
  return { url: route.url, anonKey };
}

export function readConfig(): KernelConfig {
  if (currentBackend() === "practice") {
    const found = fromWhere("practice");
    if (found) return found;
    const url = import.meta.env.VITE_PRACTICE_URL;
    const anonKey = import.meta.env.VITE_PRACTICE_ANON_KEY;
    // Checked rather than assumed, because `currentBackend` already refuses to
    // say practice without these and a second reader should not depend on that.
    if (!url || !anonKey) {
      throw new MissingConfig(
        "Practice mode is on and no practice stack is configured. Set " +
          "VITE_PRACTICE_URL and VITE_PRACTICE_ANON_KEY, or turn practice off.",
      );
    }
    return { url, anonKey };
  }

  const found = fromWhere("cellar");
  if (found) return found;

  const url = import.meta.env.VITE_SUPABASE_URL;
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    // Both sources named, because "it is not configured" is useless when there
    // are two places it could have been.
    throw new MissingConfig(
      "No kernel to talk to. Either serve a where.json beside this app listing " +
        "at least one route, or set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY " +
        "in the app's .env.local. See apps/web/.env.example and " +
        "docs/moving-off-tailscale.md.",
    );
  }
  return { url, anonKey };
}
