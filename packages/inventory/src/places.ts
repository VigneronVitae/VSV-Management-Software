// ---------------------------------------------------------------------------
// Type: source
// Purpose: "Where you are in the stores, written down, so that walking to a
//           shelf and coming back to the phone does not lose your place."
// Depends on: [supabase/migrations/0136_the_stores_have_a_door.sql,
//              packages/inventory/src/inventory.ts]
// Depended on by: [packages/inventory/src/inventory.ts, scripts/screens.sh]
// ---------------------------------------------------------------------------
//
// A router, like the cellar's and the vineyard's and unlike the shop's. The
// reason here is physical: this is the one app you use while walking away from
// the phone's last screen to a different building, and S-93 is the shop losing
// your place when the tab is discarded.

export type StorePlace =
  | { at: "stock" }
  | { at: "thing"; id: string }
  | { at: "places" }
  | { at: "place"; id: string };

// The keys, as a plain list, because a shell script reads this file.
export const PLACES = new Set(["stock", "thing", "places", "place"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function encode(place: StorePlace): string {
  return "id" in place && place.id ? `#/${place.at}/${place.id}` : `#/${place.at}`;
}

export function decode(hash: string): StorePlace {
  const parts = hash.replace(/^#\/?/, "").split("/").filter(Boolean);
  const [at, id] = parts;
  if (at === "stock" && parts.length === 1) return { at: "stock" };
  if (at === "places" && parts.length === 1) return { at: "places" };
  if ((at === "thing" || at === "place") && id && UUID.test(id)) {
    return { at, id } as StorePlace;
  }
  return { at: "stock" };
}
