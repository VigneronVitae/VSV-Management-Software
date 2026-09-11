// Which skin is on. The word is the repo's own: apps/web/src/index.ts says this
// session "builds one skin over the kernel and a later session builds the thing
// that hosts several", and CLAUDE.md's rule about clients holding no business
// rule is what makes a second one cheap.
//
// What a skin may change is presentation and nothing else. The screens in
// walk.ts decide what a person is asked and in what order, because that order
// is the schema's, not a matter of taste. A skin decides how it looks.
//
// Today a skin is a stylesheet, scoped by a data-skin attribute on the root.
// The class names in walk.ts are already a consistent vocabulary, so that is
// enough for a real change of appearance without touching a screen. If a skin
// ever needs different markup rather than different styling, ui.ts is the seam:
// it is the whole surface the screens build from, and it is small on purpose.
//
// Markup carries data, skins decide what to do with it. A vessel row publishes
// how full it is as a custom property whether or not anything draws it, which
// is why a new skin can add a fill bar and the old one is unaffected.

export type Skin = {
  name: string;
  label: string;
  note: string;
};

export const skins: Skin[] = [
  {
    name: "original",
    label: "Original",
    note: "The first walk. Flat and dense, nothing between you and the field.",
  },
  {
    name: "cellar",
    label: "Cellar",
    note: "Bigger targets, cards, and a fill gauge on every vessel. For a wet glove in a dark room.",
  },
];

const KEY = "vsv.skin";
const FALLBACK = "original";

export function activeSkin(): string {
  let stored: string | null = null;
  try {
    stored = localStorage.getItem(KEY);
  } catch {
    // A private window, or site data switched off. A skin is a preference and
    // losing it is not worth a broken boot.
  }
  return skins.some((s) => s.name === stored) ? (stored as string) : FALLBACK;
}

export function applySkin(name: string): void {
  const chosen = skins.some((s) => s.name === name) ? name : FALLBACK;
  document.documentElement.dataset.skin = chosen;
  try {
    localStorage.setItem(KEY, chosen);
  } catch {
    // As above. The skin still applies for this visit.
  }
}

// Called before the first screen is drawn, so nobody sees one skin repaint into
// another on load.
export function restoreSkin(): void {
  document.documentElement.dataset.skin = activeSkin();
}
