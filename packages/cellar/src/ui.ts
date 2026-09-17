import { currentBackend } from "core";

// Phone first. Single column, large targets, one action per view. There is no
// component model here on purpose: these screens are one skin over the kernel
// and a later session builds the shell.

type Attrs = Record<string, string | number | boolean | null | undefined>;
type Child = Node | string | null | undefined | false;

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Attrs = {},
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null || value === undefined || value === false) continue;
    if (key === "class") node.className = String(value);
    else if (key === "text") node.textContent = String(value);
    else node.setAttribute(key, String(value));
  }
  for (const child of children) {
    if (child === null || child === undefined || child === false) continue;
    node.append(typeof child === "string" ? document.createTextNode(child) : child);
  }
  return node;
}

export function on<E extends keyof HTMLElementEventMap>(
  node: HTMLElement,
  event: E,
  handler: (ev: HTMLElementEventMap[E]) => void,
): void {
  node.addEventListener(event, handler as EventListener);
}

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

export function lede(text: string): HTMLElement {
  return el("p", { class: "lede", text });
}

export function button(
  label: string,
  onClick: () => void | Promise<void>,
  kind: "primary" | "secondary" | "quiet" = "primary",
): HTMLButtonElement {
  const b = el("button", { class: `btn btn-${kind}`, type: "button", text: label });
  on(b, "click", () => {
    void run(b, onClick);
  });
  return b;
}

// A button that is pressed twice because nothing visibly happened is how a
// duplicate barrel gets created. Disable while the write is in flight.
async function run(
  b: HTMLButtonElement,
  action: () => void | Promise<void>,
): Promise<void> {
  if (b.disabled) return;
  const label = b.textContent ?? "";
  b.disabled = true;
  b.textContent = "Working";
  try {
    await action();
  } finally {
    b.disabled = false;
    b.textContent = label;
  }
}

export type FieldOptions = {
  label: string;
  type?: string;
  value?: string;
  placeholder?: string;
  required?: boolean;
  hint?: string;
  attrs?: Attrs;
};

export type Field = {
  root: HTMLElement;
  input: HTMLInputElement;
  value: () => string;
};

export function field(options: FieldOptions): Field {
  const input = el("input", {
    class: "input",
    type: options.type ?? "text",
    // A numeric field gets the numeric keypad. Without this a phone offers the
    // full keyboard for a gross weight, and hunting for the digits with a wet
    // glove is the difference between recording a number and deciding to do it
    // later. `decimal` rather than `numeric` because litres and Brix have
    // decimal points and `numeric` hides the separator on some keyboards.
    //
    // Two hand-rolled inputs in walk.ts already did this and every field built
    // through here did not, which is most of the numbers in the app.
    ...(options.type === "number" ? { inputmode: "decimal" } : {}),
    value: options.value ?? "",
    placeholder: options.placeholder ?? "",
    ...(options.attrs ?? {}),
  });
  const root = el(
    "label",
    { class: "field" },
    el("span", { class: "field-label", text: options.label }),
    input,
    options.hint ? el("span", { class: "field-hint", text: options.hint }) : null,
  );
  return { root, input, value: () => input.value.trim() };
}

export function checkbox(label: string, checked = false): Field {
  const input = el("input", { class: "checkbox", type: "checkbox" });
  input.checked = checked;
  const root = el(
    "label",
    { class: "field field-inline" },
    input,
    el("span", { class: "field-label", text: label }),
  );
  return { root, input, value: () => String(input.checked) };
}

export function banner(
  text: string,
  kind: "error" | "note" | "good" = "note",
): HTMLElement {
  return el("p", { class: `banner banner-${kind}`, role: "status", text });
}

export function rows(...items: Child[]): HTMLElement {
  return el("div", { class: "rows" }, ...items);
}

export function summaryRow(label: string, value: string): HTMLElement {
  return el(
    "div",
    { class: "summary-row" },
    el("span", { class: "summary-label", text: label }),
    el("span", { class: "summary-value", text: value }),
  );
}

export function empty(text: string): HTMLElement {
  return el("p", { class: "empty", text });
}

// --- trying a screen more than one way -------------------------------------

// The winemaker, after using the first press screen on a crush pad: "I want a
// different pressing UI. Maybe try a few different ones I can test out or
// something? That's probably a good idea for a lot of the modules."
//
// He is right, and the reason he is right is that nobody in this project can
// tell which layout is better from here. A screen used with wet hands, a phone
// in one pocket and a hose in the other hand is not a screen anybody designs
// correctly at a desk. So the way to find out is to ship more than one and let
// the person using it choose, and the choice itself is then the finding.
//
// Deliberately not in the URL. A layout is how one person likes to look at a
// screen on one phone, not a place: a link somebody sends should open the press,
// not somebody else's opinion about it. It persists in `prefs.ts`, which is the
// store whose whole job is surviving a reload and costing nothing when it does
// not.
export type Variant<T> = {
  key: string;
  label: string;
  // What this arrangement is for, in a few words. Shown under the switcher,
  // because "Wide" and "Compact" tell somebody nothing about which to pick.
  note: string;
  render: (context: T) => Node;
};

export function variantSwitch<T>(
  variants: Variant<T>[],
  current: string,
  onPick: (key: string) => void,
): HTMLElement {
  const chosen = variants.find((v) => v.key === current) ?? variants[0];
  return el(
    "div",
    { class: "variant-switch" },
    el("span", { class: "field-label", text: "Layout" }),
    el(
      "div",
      { class: "variant-options" },
      ...variants.map((v) =>
        button(
          v.label,
          () => onPick(v.key),
          v.key === chosen?.key ? "primary" : "quiet",
        ),
      ),
    ),
    el("span", { class: "field-hint", text: chosen?.note ?? "" }),
  );
}
