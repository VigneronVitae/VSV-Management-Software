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

export function screen(title: string, ...body: Child[]): HTMLElement {
  return el("section", { class: "screen" }, el("h1", { text: title }), ...body);
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
