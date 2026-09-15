// Vite substitutes these at build time. Declared here rather than pulling in
// vite/client so that core stays buildable by anything, not just by vite.
declare global {
  interface ImportMeta {
    readonly env: Record<string, string | undefined>;
  }
}

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

export function readConfig(): KernelConfig {
  if (currentBackend() === "practice") {
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

  const url = import.meta.env.VITE_SUPABASE_URL;
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new MissingConfig(
      "Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in apps/web/.env.local. " +
        "See apps/web/.env.example.",
    );
  }
  return { url, anonKey };
}
