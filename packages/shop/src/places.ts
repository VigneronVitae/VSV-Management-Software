// Where you are in the shop, written down.
//
// Two reasons this exists, and only the second one is built yet.
//
// **A note has to point at something.** 0101 made every screen a row so that
// "this wording is wrong" lands on the screen whose wording it is. The cellar's
// forty one screens are registered; these are the shop's, and without them Matt
// taps Note and is told that nothing in this system is that, which reads as the
// feature being broken rather than as a missing row. scripts/screens.sh checks
// this list against the registry.
//
// **A phone discards a backgrounded tab.** The cellar learned that the hard way,
// halfway through registering a tank, and answered it by putting the place in
// the URL so a cold start lands where you were. The shop does not do that yet
// and it has the same phone and the same problem. That is S-93.

export type ShopPlace =
  | { at: "machines" }
  | { at: "machine"; id: string }
  | { at: "machine-work"; id: string }
  | { at: "machine-new" }
  | { at: "model-new" };

// The keys, as a plain list, because a shell script reads this file.
export const PLACES = new Set([
  "machines",
  "machine",
  "machine-work",
  "machine-new",
  "model-new",
]);
