// Where you are in the vineyard, written down.
//
// This one has a router, which the shop does not: S-93 is the shop losing your
// place when the phone discards the tab, and the reason it was survivable there
// is that the shop has few screens and no deep identifiers. Here a row is one of
// a hundred and ninety, and coming back to the top of the list after looking at
// one vine would make the app unusable in a vineyard. So the place goes in the
// hash, the same answer the cellar reached.

export type VinePlace =
  | { at: "blocks" }
  | { at: "block"; id: string }
  | { at: "row"; id: string };

// The keys, as a plain list, because a shell script reads this file.
export const PLACES = new Set(["blocks", "block", "row"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function encode(place: VinePlace): string {
  return "id" in place && place.id ? `#/${place.at}/${place.id}` : `#/${place.at}`;
}

export function decode(hash: string): VinePlace {
  const parts = hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  const [at, id] = parts;
  if (at === "blocks" && parts.length === 1) return { at: "blocks" };
  if ((at === "block" || at === "row") && id && UUID.test(id)) {
    return { at, id } as VinePlace;
  }
  return { at: "blocks" };
}
