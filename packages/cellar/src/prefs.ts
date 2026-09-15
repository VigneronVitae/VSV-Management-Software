// How somebody likes to look at a screen, on this phone, surviving a reload.
//
// Three stores now and each has a different lifetime, which is the reason there
// are three rather than one that tries to be all of them.
//
// `sticky.ts` is in memory, pin-gated, and gone on reload. It remembers what you
// typed into a field so that registering fifty barrels does not mean typing the
// same room fifty times, and it deliberately forgets, because a value that
// outlives the session it was typed in starts arriving in forms nobody meant.
//
// A draft in `places.ts` is what was typed and not yet saved. It is per screen,
// it is deleted the moment the write it stood in for succeeds, and it exists
// because a phone discards a backgrounded tab.
//
// **This is neither.** A preference is not data and it is not typing: it is how
// somebody wants a screen arranged, it should survive a reload, and losing it
// costs nothing but a tap. That is the one thing the other two stores must not
// do, so it is its own store.
//
// This was written after the vessel sort and filter shipped against `sticky.ts`,
// where `stickyValue` returns nothing for a key nobody pinned and `remember`
// writes nothing for one. The controls worked and forgot everything, silently,
// which is the shape of bug this repository exists to refuse: it looked exactly
// like it was working.

const PREFIX = "vsv.pref.";

// Every read and write is wrapped. A private window, cleared site data, or a
// browser set to block storage makes `localStorage` throw on access rather than
// return null, and a preference is never worth failing a screen over.
export function pref(key: string, fallback = ""): string {
  try {
    return localStorage.getItem(PREFIX + key) ?? fallback;
  } catch {
    return fallback;
  }
}

export function setPref(key: string, value: string): void {
  try {
    if (value === "") localStorage.removeItem(PREFIX + key);
    else localStorage.setItem(PREFIX + key, value);
  } catch {
    // A preference that cannot be saved is a preference that does not persist,
    // which is the same as not having set one. Nothing downstream depends on it.
  }
}

/** A set of values, stored as one string. Used for "which types are hidden". */
export function prefSet(key: string): Set<string> {
  return new Set(pref(key).split("|").filter(Boolean));
}

export function setPrefSet(key: string, values: Iterable<string>): void {
  setPref(key, [...values].join("|"));
}
