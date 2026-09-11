import {
  addLocation,
  addParty,
  addTerm,
  type Location,
  locations,
  type Party,
  parties,
  type Term,
  type TermKind,
  terms,
} from "core";
import { isPinned, remember, setPinned, stickyValue } from "./sticky.ts";
import { banner, button, el, field, on } from "./ui.ts";

// T1-1: cellar users select from existing objects. Free text vessel names from
// three people is how the data becomes unusable.
//
// The catch on a fresh install is that "existing objects" is an empty list, and
// a picker with nothing in it and no way to add is a dead end on the first
// screen someone ever sees. Every picker here can add without leaving the form.

export type Picker = {
  root: HTMLElement;
  value: () => string;
  label: () => string;
  // The whole selected term, for a caller that needs its attributes rather
  // than just its id. A vessel type carries the shape of its own form.
  selected: () => Term | null;
  // Relabels the field in place. "Creator of" is one function and its label
  // depends on which contract the vessel type asked for.
  setLabel: (text: string) => void;
  reload: (selectId?: string) => Promise<void>;
};

type PickerOptions = {
  label: string;
  stickyKey?: string;
  allowEmpty?: boolean;
  emptyLabel?: string;
  // Where the options come from, when it is not simply every term of the kind.
  rows?: () => Promise<Term[]>;
  // What to stamp on a term added through this picker. A maker added while a
  // tank is selected is a manufacturer, and if it is saved without saying so it
  // shows up under every vessel type from then on.
  newAttributes?: () => Record<string, unknown>;
};

function pinToggle(key: string, read: () => string): HTMLElement {
  const input = el("input", { type: "checkbox", class: "checkbox" });
  input.checked = isPinned(key);
  on(input, "change", () => setPinned(key, input.checked, read()));
  return el(
    "label",
    { class: "pin", title: "Keep this value for the next one" },
    input,
    el("span", { text: "keep" }),
  );
}

function shell(
  options: PickerOptions,
  select: HTMLSelectElement,
  addForm: HTMLElement,
  addToggle: HTMLElement,
): HTMLElement {
  const head = el(
    "div",
    { class: "field-head" },
    el("span", { class: "field-label", text: options.label }),
    options.stickyKey ? pinToggle(options.stickyKey, () => select.value) : null,
  );
  return el("div", { class: "field" }, head, select, addToggle, addForm);
}

export function termPicker(kind: TermKind, options: PickerOptions): Picker {
  const select = el("select", { class: "input" });
  const message = el("div", {});
  const addForm = el("div", { class: "add-inline", hidden: "hidden" });
  const addToggle = button("Add one", () => toggle(), "quiet");
  let loaded: Term[] = [];

  const name = field({
    label: `New ${options.label.toLowerCase()}`,
    placeholder: "Name",
  });
  const save = button("Save and select", async () => {
    const label = name.value();
    if (!label) return;
    try {
      const created: Term = await addTerm(
        kind,
        label,
        options.newAttributes ? options.newAttributes() : {},
      );
      await load(created.id);
      toggle(false);
      name.input.value = "";
    } catch (error) {
      message.replaceChildren(banner(String((error as Error).message), "error"));
    }
  });
  addForm.append(name.root, save, message);

  function toggle(force?: boolean): void {
    addForm.hidden = force === undefined ? !addForm.hidden : !force;
  }

  async function load(selectId?: string): Promise<void> {
    const rows = await (options.rows ? options.rows() : terms(kind));
    loaded = rows;
    const wanted =
      selectId ??
      select.value ??
      (options.stickyKey ? stickyValue(options.stickyKey) : "");
    select.replaceChildren(
      ...(options.allowEmpty
        ? [el("option", { value: "", text: options.emptyLabel ?? "None" })]
        : rows.length === 0
          ? [el("option", { value: "", text: "Nothing here yet, tap Add one" })]
          : []),
      ...rows.map((row) => el("option", { value: row.id, text: row.label })),
    );
    if (wanted && rows.some((row) => row.id === wanted)) select.value = wanted;
    // Deliberately not force-opening the add form when the list is empty. It
    // used to, so that a fresh install was not a dead end, but inside the
    // vessel form that meant the whole add-a-location block sprang open every
    // time. The empty option now says where the button is instead.
  }

  on(select, "change", () => {
    if (options.stickyKey) remember(options.stickyKey, select.value);
  });

  const root = shell(options, select, addForm, addToggle);
  const labelNode = root.querySelector(".field-label");
  return {
    root,
    value: () => select.value,
    label: () => select.selectedOptions[0]?.text ?? "",
    selected: () => loaded.find((row) => row.id === select.value) ?? null,
    setLabel: (text: string) => {
      if (labelNode) labelNode.textContent = text;
      name.root
        .querySelector(".field-label")
        ?.replaceChildren(document.createTextNode(`New ${text.toLowerCase()}`));
    },
    reload: (selectId?: string) => load(selectId),
  };
}

// Locations are rows rather than terms, and they carry a kind that is a term,
// so this picker holds a picker.
export function locationPicker(options: PickerOptions): Picker {
  const select = el("select", { class: "input" });
  const message = el("div", {});
  const addForm = el("div", { class: "add-inline", hidden: "hidden" });
  const addToggle = button("Add one", () => toggle(), "quiet");

  const name = field({ label: "Location name", placeholder: "Barrel room" });
  const kind = termPicker("location_kind", {
    label: "Kind",
    allowEmpty: true,
    emptyLabel: "Unspecified",
  });
  const ambient = field({
    label: "Ambient temperature, C",
    type: "number",
    placeholder: "13.5",
  });
  const controlledInput = el("input", { type: "checkbox", class: "checkbox" });
  const controlled = el(
    "label",
    { class: "field field-inline" },
    controlledInput,
    el("span", { class: "field-label", text: "Temperature controlled" }),
  );

  const save = button("Save and select", async () => {
    if (!name.value()) return;
    try {
      const created: Location = await addLocation({
        name: name.value(),
        kind_id: kind.value() || null,
        controlled: controlledInput.checked,
        ambient_c: ambient.value() ? Number(ambient.value()) : null,
      });
      await load(created.id);
      toggle(false);
      name.input.value = "";
    } catch (error) {
      message.replaceChildren(banner(String((error as Error).message), "error"));
    }
  });
  addForm.append(name.root, kind.root, controlled, ambient.root, save, message);

  function toggle(force?: boolean): void {
    addForm.hidden = force === undefined ? !addForm.hidden : !force;
  }

  async function load(selectId?: string): Promise<void> {
    const rows = await locations();
    const wanted =
      selectId ??
      select.value ??
      (options.stickyKey ? stickyValue(options.stickyKey) : "");
    select.replaceChildren(
      ...(options.allowEmpty || rows.length === 0
        ? [
            el("option", {
              value: "",
              text: rows.length === 0 ? "Nothing here yet, tap Add one" : "None",
            }),
          ]
        : []),
      ...rows.map((row) => el("option", { value: row.id, text: row.name })),
    );
    if (wanted && rows.some((row) => row.id === wanted)) select.value = wanted;
    // Stays closed. This is the one that used to spring open inside the vessel
    // form on a fresh install, where it buried the vessel fields under a whole
    // second form for a location nobody had asked to create yet.
  }

  on(select, "change", () => {
    if (options.stickyKey) remember(options.stickyKey, select.value);
  });

  const root = shell(options, select, addForm, addToggle);
  const labelNode = root.querySelector(".field-label");
  return {
    root,
    selected: () => null,
    setLabel: (text: string) => {
      if (labelNode) labelNode.textContent = text;
    },
    value: () => select.value,
    label: () => select.selectedOptions[0]?.text ?? "",
    reload: (selectId?: string) => load(selectId),
  };
}

// Who owns the wine. The facility is the default and stays first, because most
// lots are the winery's own; a custom crush client is the exception that has to
// be possible without leaving the form you are already filling in.
//
// This is a picker over rows rather than terms, like locationPicker, because a
// party is a party: it carries a login link and an ownership meaning that the
// term vocabulary has nothing to do with.
export function partyPicker(options: PickerOptions): Picker {
  const select = el("select", { class: "input" });
  const message = el("div", {});
  const addForm = el("div", { class: "add-inline", hidden: "hidden" });
  const addToggle = button("Add a client", () => toggle(), "quiet");

  const name = field({
    label: "Client name",
    placeholder: "Amica Luna",
    hint: "The legal entity whose wine this is. They can be given a login later.",
  });

  const save = button("Save and select", async () => {
    if (!name.value()) return;
    try {
      const created: Party = await addParty(name.value(), "client");
      await load(created.id);
      toggle(false);
      name.input.value = "";
      message.replaceChildren();
    } catch (error) {
      message.replaceChildren(banner(String((error as Error).message), "error"));
    }
  });
  addForm.append(name.root, save, message);

  function toggle(force?: boolean): void {
    addForm.hidden = force === undefined ? !addForm.hidden : !force;
  }

  async function load(selectId?: string): Promise<void> {
    const rows = await parties();
    const facility = rows.find((p) => p.kind === "facility");
    const clients = rows.filter((p) => p.kind === "client");
    const wanted =
      selectId ??
      select.value ??
      (options.stickyKey ? stickyValue(options.stickyKey) : "");

    select.replaceChildren(
      // Empty means the facility, which is what the kernel defaults to anyway.
      // Naming it rather than leaving a blank is the difference between a
      // default and an omission.
      el("option", {
        value: "",
        text: facility ? `${facility.name} (us)` : "The facility",
      }),
      ...clients.map((p) => el("option", { value: p.id, text: p.name })),
    );
    if (wanted && clients.some((p) => p.id === wanted)) select.value = wanted;
  }

  on(select, "change", () => {
    if (options.stickyKey) remember(options.stickyKey, select.value);
  });

  const root = shell(options, select, addForm, addToggle);
  const labelNode = root.querySelector(".field-label");
  return {
    root,
    selected: () => null,
    setLabel: (text: string) => {
      if (labelNode) labelNode.textContent = text;
    },
    value: () => select.value,
    label: () => select.selectedOptions[0]?.text ?? "",
    reload: (selectId?: string) => load(selectId),
  };
}
