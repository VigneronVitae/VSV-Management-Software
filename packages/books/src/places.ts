// ---------------------------------------------------------------------------
// Type: source
// Purpose: "Where you are in the books, written down, so the phone discarding
//           the tab does not send you back to the top of eight hundred rows."
// Depends on: [packages/books/src/books.ts,
//              supabase/migrations/0127_the_books_have_a_door.sql]
// Depended on by: [packages/books/src/books.ts, scripts/screens.sh]
// ---------------------------------------------------------------------------
//
// Same reasoning as the vineyard's router and the same shape. S-93 is the shop
// losing your place; it was survivable there because the shop has few screens.
// Here the work is a list of eight hundred transactions worked through one at a
// time on a phone, and losing your position in it is the whole job again.

export type BookPlace =
  | { at: "money" }
  | { at: "pile"; id: string }
  | { at: "line"; id: string }
  | { at: "merchants" }
  | { at: "papers" }
  // `id` is a paper's uuid, or "new" for one not yet written. 0144.
  | { at: "paper"; id: string };

// The keys, as a plain list, because a shell script reads this file.
export const PLACES = new Set([
  "money",
  "pile",
  "line",
  "merchants",
  "papers",
  "paper",
]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// A pile is named rather than identified, and the names are the four the
// kernel's `money_queue` computes. Listed here so a hash somebody typed cannot
// ask for a pile that does not exist.
export const PILES = ["unexplained", "unconfirmed", "disputed", "settled"];

export function encode(place: BookPlace): string {
  return "id" in place && place.id ? `#/${place.at}/${place.id}` : `#/${place.at}`;
}

export function decode(hash: string): BookPlace {
  const parts = hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  const [at, id] = parts;
  if (at === "money" && parts.length === 1) return { at: "money" };
  if (at === "merchants" && parts.length === 1) return { at: "merchants" };
  if (at === "papers" && parts.length === 1) return { at: "papers" };
  if (at === "paper" && id && (id === "new" || UUID.test(id))) return { at, id };
  if (at === "pile" && id && PILES.includes(id)) return { at, id };
  if (at === "line" && id && UUID.test(id)) return { at, id };
  return { at: "money" };
}
