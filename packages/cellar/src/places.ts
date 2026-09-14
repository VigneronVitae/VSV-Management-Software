// Where you are, written down. Two problems, one cause.
//
// A phone discards a backgrounded tab under memory pressure. Leaving the app to
// take a photo and coming back is therefore not "switching back", it is a cold
// start, and this client had nothing to start from: every screen was reached by
// calling a function from a closure on the screen before it, so a restart could
// only land at `route()`, which means the home screen, with whatever had been
// typed gone. The winemaker found this the obvious way, halfway through
// registering a tank, needing the photo that was the reason to leave.
//
// So two records, deliberately separate because they have different lifetimes.
//
// **A place is in the URL.** It survives a restart, it gives the phone's back
// button something to do other than leave the app, and it is a thing a person
// can send to somebody else. It holds an identifier and never a value: a place
// is resolved by asking the kernel again, so a stale link shows what is true now
// rather than what was true when the link was made.
//
// **A draft is in local storage.** It is what was typed and not yet saved, it
// belongs to one device and one screen, and it is deleted the moment the write
// it was standing in for succeeds. It is not a queue and it is not an offline
// story: nothing here makes a write happen later. It only means that coming back
// to a screen finds the typing still in it. S-47 is the offline gap that this
// does not close.

export type Place =
  | { at: "home" }
  | { at: "vessels" }
  | { at: "vessel-new" }
  | { at: "vessel-wine" }
  | { at: "rack" }
  | { at: "scan" }
  | { at: "locations" }
  | { at: "clients" }
  | { at: "vessel-types" }
  | { at: "vessel-type"; id: string }
  | { at: "vessel"; id: string }
  | { at: "vessel-edit"; id: string }
  | { at: "vessel-fill"; id: string }
  // Intake. `pick-bins` is the one place whose identifier is optional: the
  // tapping screen is reachable before the pick exists, because the pick is
  // created by its first bin. Once the first bin lands the screen rewrites its
  // own place to carry the id, so a restart after that resumes on the pick.
  | { at: "intake" }
  | { at: "pick-new" }
  | { at: "pick-bins"; id?: string }
  | { at: "scale" }
  // Photographs of a pick and of a vessel. Two places rather than one generic
  // one, because a place carries a single identifier and a subject type plus an
  // id is two. Two lines of union is cheaper than a second segment in every
  // link, and these are the only two subjects anybody photographs today.
  | { at: "pick-photos"; id: string }
  | { at: "vessel-photos"; id: string }
  | { at: "press" }
  | { at: "bins-to-return" }
  | { at: "export" }
  | { at: "vineyards" }
  | { at: "block"; id: string }
  // The only place whose identifier is not a uuid: a day is named by its date,
  // because a link to a day somebody can read and type is worth more than one
  // that resolves faster.
  | { at: "day"; id?: string }
  | { at: "paper" }
  | { at: "makers" }
  | { at: "stores" }
  // Lots that predate 0049 and say neither a year nor NV. Nothing new can join
  // the list, so this place empties and stops being offered.
  | { at: "vintages" }
  | { at: "additions" };

export const HOME: Place = { at: "home" };

// A uuid and nothing else. The identifier in a place is about to be handed to
// the kernel, and a place is the one input to this client that a person can
// type, so it is checked rather than trusted. Anything else resolves to home.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const WITHOUT_ID = new Set([
  "home",
  "vessels",
  "vessel-new",
  "vessel-wine",
  "rack",
  "scan",
  "locations",
  "clients",
  "vessel-types",
  "intake",
  "pick-new",
  "pick-bins",
  "scale",
  "press",
  "bins-to-return",
  "export",
  "vineyards",
  "day",
  "paper",
  "makers",
  "stores",
  "vintages",
  "additions",
]);

// A calendar day, which is what the day log is addressed by.
const DAY = /^\d{4}-\d{2}-\d{2}$/;

const WITH_ID = new Set([
  "vessel-type",
  "vessel",
  "vessel-edit",
  "vessel-fill",
  "pick-bins",
  "pick-photos",
  "vessel-photos",
  "block",
]);

export function encode(place: Place): string {
  return "id" in place && place.id ? `#/${place.at}/${place.id}` : `#/${place.at}`;
}

export function decode(hash: string): Place {
  const parts = hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  const [at, id] = parts;
  if (!at) return HOME;
  if (WITHOUT_ID.has(at) && parts.length === 1) return { at } as Place;
  if (at === "day" && id && DAY.test(id)) return { at, id } as Place;
  if (WITH_ID.has(at) && id && UUID.test(id)) return { at, id } as Place;
  return HOME;
}

export function samePlace(a: Place, b: Place): boolean {
  return encode(a) === encode(b);
}

// --- drafts ----------------------------------------------------------------

// Keyed by place, so the draft for the tank you were editing is not the draft
// for the one you were registering. A draft is a plain object and this module
// does not know what is in it: the screen that wrote it is the only thing that
// knows how to read it back, which keeps the shape of a form out of here.

const PREFIX = "vsv.draft.";

// Old enough that it is no longer what you meant to be doing. A shift is the
// unit, not a day: coming back to a barn the next morning and finding yesterday
// afternoon's half-typed tank in front of you is worse than finding a blank
// form, because you cannot tell by looking which parts you typed.
const STALE_AFTER_MS = 12 * 60 * 60 * 1000;

type Stored = { at: number; value: unknown };

export function saveDraft(place: Place, value: unknown): void {
  try {
    const wrapped: Stored = { at: Date.now(), value };
    localStorage.setItem(PREFIX + encode(place), JSON.stringify(wrapped));
  } catch {
    // Private window, site data switched off, or the quota is full. A draft is
    // an improvement on losing the typing and never a reason to fail a screen.
  }
}

export function readDraft(place: Place): unknown | null {
  let raw: string | null = null;
  try {
    raw = localStorage.getItem(PREFIX + encode(place));
  } catch {
    return null;
  }
  if (!raw) return null;
  try {
    const wrapped = JSON.parse(raw) as Stored;
    if (typeof wrapped?.at !== "number") return null;
    if (Date.now() - wrapped.at > STALE_AFTER_MS) {
      clearDraft(place);
      return null;
    }
    return wrapped.value ?? null;
  } catch {
    // Written by an older version of this client, or truncated. Not something
    // to show somebody, and not something to keep.
    clearDraft(place);
    return null;
  }
}

export function clearDraft(place: Place): void {
  try {
    localStorage.removeItem(PREFIX + encode(place));
  } catch {
    // As above.
  }
}

// Sign-out. A phone in a barn is shared, and an unsaved vessel belongs to
// whoever typed it, so it does not survive the next person signing in.
export function clearAllDrafts(): void {
  try {
    const doomed: string[] = [];
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i);
      if (key?.startsWith(PREFIX)) doomed.push(key);
    }
    for (const key of doomed) localStorage.removeItem(key);
  } catch {
    // As above.
  }
}
