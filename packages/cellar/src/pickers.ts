import {
  addLocation,
  addTerm,
  type Location,
  locations,
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
  reload: () => Promise<void>;
};

type PickerOptions = {
  label: string;
  stickyKey?: string;
  allowEmpty?: boolean;
  emptyLabel?: string;
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

  const name = field({
    label: `New ${options.label.toLowerCase()}`,
    placeholder: "Name",
  });
  const save = button("Save and select", async () => {
    const label = name.value();
    if (!label) return;
    try {
      const created: Term = await addTerm(kind, label);
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
    const rows = await terms(kind);
    const wanted =
      selectId ??
      select.value ??
      (options.stickyKey ? stickyValue(options.stickyKey) : "");
    select.replaceChildren(
      ...(options.allowEmpty
        ? [el("option", { value: "", text: options.emptyLabel ?? "None" })]
        : rows.length === 0
          ? [el("option", { value: "", text: "Nothing here yet, add one below" })]
          : []),
      ...rows.map((row) => el("option", { value: row.id, text: row.label })),
    );
    if (wanted && rows.some((row) => row.id === wanted)) select.value = wanted;
    if (rows.length === 0) toggle(true);
  }

  on(select, "change", () => {
    if (options.stickyKey) remember(options.stickyKey, select.value);
  });

  const root = shell(options, select, addForm, addToggle);
  return {
    root,
    value: () => select.value,
    label: () => select.selectedOptions[0]?.text ?? "",
    reload: () => load(),
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
              text: rows.length === 0 ? "Nothing here yet, add one below" : "None",
            }),
          ]
        : []),
      ...rows.map((row) => el("option", { value: row.id, text: row.name })),
    );
    if (wanted && rows.some((row) => row.id === wanted)) select.value = wanted;
    if (rows.length === 0) toggle(true);
  }

  on(select, "change", () => {
    if (options.stickyKey) remember(options.stickyKey, select.value);
  });

  const root = shell(options, select, addForm, addToggle);
  return {
    root,
    value: () => select.value,
    label: () => select.selectedOptions[0]?.text ?? "",
    reload: () => load(),
  };
}
