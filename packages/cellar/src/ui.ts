import type { Child } from "core";
import { currentBackend, el } from "core";

export type { Attrs, Child, Field, FieldOptions, Variant } from "core";
// The cellar's own chrome is `screen()`, below. Everything generic moved to core
// when the shop module arrived and needed the same text inputs.
//
// Re-exported by name rather than with a wildcard, so that every
// `from "./ui.ts"` in this module keeps meaning what it meant and this file
// still says what it offers.
export {
  banner,
  button,
  checkbox,
  el,
  empty,
  field,
  lede,
  on,
  rows,
  summaryRow,
  variantSwitch,
} from "core";

// Every screen, so there is no screen without it.
//
// Practice mode's entire safety rests on somebody always knowing which stack
// they are in, and the way that fails is a screen somebody forgot to mark. So
// the mark is not something a screen opts into: it is in the one function every
// screen is built from, and a new screen gets it without its author knowing it
// exists.
//
// A13 in its plainest form: a real cellar and a practice one must not look
// alike. In practice mode the band is at the top of the page, it says what
// practice mode means rather than just naming it, and the body carries a class
// so a skin can make the whole page unmistakable.
// "Maybe a permanent top right block to select something on any screen to take
// a note of?" Every screen is built by screen(), so the control goes here and
// exists once rather than being remembered on each of forty one screens.
//
// ui.ts cannot reach the kernel without inverting the layering, so the walk
// registers what the button does and this only knows that there is one. When
// nothing has registered, no button is drawn, which is what keeps a test host
// and a non-browser host working.
let noteWanted: (() => void) | null = null;

export function whenNoteWanted(fn: () => void): void {
  noteWanted = fn;
}

export function screen(title: string, ...body: Child[]): HTMLElement {
  const practising = currentBackend() === "practice";
  try {
    document.body.classList.toggle("practising", practising);
  } catch {
    // No document is a test or a non-browser host. The band below is still
    // built; only the page-level styling hook is unavailable.
  }
  return el(
    "section",
    { class: "screen" },
    practising
      ? el("p", {
          class: "practice-band",
          role: "status",
          text: "PRACTICE. Nothing here is real and all of it can be thrown away.",
        })
      : null,
    noteWanted
      ? el("div", { class: "screen-head" }, el("h1", { text: title }), noteButton())
      : el("h1", { text: title }),
    ...body,
  );
}

function noteButton(): HTMLElement {
  const b = el("button", {
    class: "btn btn-quiet note-here",
    type: "button",
    // Said out loud for anybody not looking at the glyph, and because the glyph
    // alone is a guess about what this does.
    "aria-label": "Take a note about what is on this screen",
    title: "Take a note",
    text: "Note",
  });
  b.addEventListener("click", () => noteWanted?.());
  return b;
}
