// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The shop, as a periphery of its own: machines, what they are, and
//           everything done to them."
// Depends on: [supabase/migrations/0105_a_machine_is_a_departure_from_its_model.sql]
// Depended on by: [packages/shop/src/index.ts]
// ---------------------------------------------------------------------------
//
// The winemaker: *"I think the shop periphery, because I think two peripheries
// will run into problems and find good solutions better than one."*
//
// That is the argument for this file existing at all. One periphery can lean on
// knowledge it never wrote down; the second one cannot, and what it trips over
// is a gap in the contract rather than a gap in itself.
//
// May import from `core`. May never import from `cellar`. scripts/verify.sh
// checks that now, and until this module existed the check passed only because
// there was no sibling to violate it with.

import {
  addNote,
  banner,
  button,
  documentText,
  el,
  empty,
  field,
  lede,
  type MachineDetail,
  type MachinePaper,
  type ModelPart,
  machine,
  machineModels,
  machinePapers,
  machines,
  machineWork,
  modelParts,
  on,
  recordMachineWork,
  registerMachine,
  registerMachineModel,
  rows,
  screens,
  summaryRow,
  vessels,
} from "core";
import { PLACES } from "./places.ts";

let root: HTMLElement | null = null;

// Which screen is on, so a note can point at it. Kept here rather than in the
// URL because the shop has no router yet, which is S-93 and a different gap.
let here = "machines";

// The shop's own chrome. Not cellar's `screen()`: there is no practice band
// here because the shop has one of everything and no sandbox to confuse it
// with, and the header says which machine you are on rather than carrying a
// note button. Different app, different chrome, which is the point.
function screen(
  place: string,
  title: string,
  ...body: (Node | string | null | false)[]
): HTMLElement {
  if (!PLACES.has(place)) {
    // A place this module does not admit to having. scripts/screens.sh checks
    // that list against the registry; this checks the code against the list.
    throw new Error(`${place} is not a shop screen`);
  }
  here = place;
  const note = el("button", {
    class: "btn btn-quiet note-here",
    type: "button",
    "aria-label": "Take a note about what is on this screen",
    title: "Take a note",
    text: "Note",
  });
  on(note, "click", () => void takeNote());
  return el(
    "section",
    { class: "screen" },
    el("div", { class: "screen-head" }, el("h1", { text: title }), note),
    ...body.filter((b): b is Node | string => b !== null && b !== false),
  );
}

// "Matt will probably be one of the biggest users of this and he can give me
// good feedback." This is where that feedback goes, and it goes against the
// screen he is standing on, so it comes back filed under the thing it is about
// rather than as a sentence in a list.
//
// Deliberately the plainest thing that works. The cellar has a sheet with a
// subject picker and the last three notes already said; copying that here before
// anybody has written a single note would be building the second version of
// something with no evidence about the first.
async function takeNote(): Promise<void> {
  const body = window.prompt("A note about this screen");
  if (!body?.trim()) return;
  try {
    const known = await screens();
    const screenRow = known.find((r) => r.key === here);
    if (!screenRow) {
      window.alert(
        `This screen is not registered, so a note has nowhere to go. (${here})`,
      );
      return;
    }
    await addNote({
      subjectType: "screen",
      subjectId: screenRow.id,
      body: body.trim(),
    });
    window.alert("Noted.");
  } catch (error) {
    window.alert((error as Error).message);
  }
}

// replaceChildren does not take nulls, and half the rows here are conditional.
// One helper rather than a filter at every call site.
function put(target: HTMLElement, ...items: (Node | string | null | false)[]): void {
  target.replaceChildren(
    ...items.filter((i): i is Node | string => i !== null && i !== false),
  );
}

function show(node: HTMLElement): void {
  if (!root) return;
  root.replaceChildren(node);
  window.scrollTo(0, 0);
}

// What a machine is, rendered from whatever keys the specification happens to
// have. Deliberately not a fixed list of fields: a press and a forklift have
// nothing in common, and 0105 keeps the specification free-form for exactly
// that reason.
function specRows(spec: Record<string, unknown>): HTMLElement[] {
  return Object.entries(spec)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) =>
      summaryRow(key.replace(/_/g, " "), value === null ? "not said" : String(value)),
    );
}

function ago(date: string | null): string {
  if (!date) return "nothing recorded";
  const days = Math.round((Date.now() - Date.parse(date)) / 86400000);
  if (days <= 0) return "today";
  if (days === 1) return "yesterday";
  if (days < 60) return `${days} days ago`;
  return `${Math.round(days / 30)} months ago`;
}

// --- the list --------------------------------------------------------------

function listScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "machines",
    "Machines",
    lede("Everything that needs fixing, diagnosing, or designing around."),
    body,
  );

  void (async () => {
    try {
      const all = await machines();
      if (all.length === 0) {
        body.replaceChildren(
          empty("No machines yet."),
          button("Add the first one", () => show(addMachineScreen())),
        );
        return;
      }
      body.replaceChildren(
        rows(
          ...all.map((m) => {
            const open = el("button", { class: "link", text: m.name });
            on(open, "click", () => show(detailScreen(m.id)));
            return el(
              "div",
              { class: "row" },
              el(
                "div",
                { class: "row-main" },
                open,
                el("span", {
                  class: "row-note",
                  text: [
                    m.model_name ?? "no model",
                    m.vessel_name ? `also the vessel ${m.vessel_name}` : null,
                    `worked on ${ago(m.last_worked_on)}`,
                  ]
                    .filter(Boolean)
                    .join(", "),
                }),
              ),
            );
          }),
        ),
        button("Add a machine", () => show(addMachineScreen()), "secondary"),
        button("Add a model", () => show(addModelScreen()), "quiet"),
      );
    } catch (error) {
      body.replaceChildren(banner((error as Error).message, "error"));
    }
  })();

  return view;
}

// --- one machine -----------------------------------------------------------

// --- what it is made of ----------------------------------------------------

// The tree as nested <details>, shut. Seventy two parts is the right amount of
// detail to have and the wrong amount to be shown at once on a phone: the top
// level is eight groups, and you open the one you are standing in front of.
//
// Each row carries the maker and the part number on it, because the question a
// parts list gets asked is "what do I order" and an answer that needs a second
// tap is an answer somebody writes on their hand instead.
function partTree(parts: ModelPart[]): HTMLElement {
  const byParent = new Map<string, ModelPart[]>();
  for (const part of parts) {
    const key = part.parent_id ?? "";
    byParent.set(key, [...(byParent.get(key) ?? []), part]);
  }

  function line(part: ModelPart): HTMLElement {
    const bits: (Node | string | null)[] = [];
    if (part.maker) bits.push(el("span", { class: "row-note", text: part.maker }));
    if (part.part_number) {
      bits.push(el("span", { class: "row-title", text: part.part_number }));
    }
    if (part.quantity && Number(part.quantity) !== 1) {
      bits.push(el("span", { class: "row-note", text: `qty ${part.quantity}` }));
    }
    if (part.wear) {
      bits.push(
        el("span", {
          class: "tag tag-inherited",
          text: part.wear_life ? `wears: ${part.wear_life}` : "wears",
        }),
      );
    }
    return el("div", { class: "row-main" }, ...bits.filter((b) => b !== null));
  }

  function node(part: ModelPart): HTMLElement {
    const kids = byParent.get(part.id) ?? [];
    const head = el(
      "div",
      { class: "row-main" },
      el("span", { class: "row-title", text: part.name }),
      part.domain_label
        ? el("span", { class: "row-note", text: part.domain_label })
        : null,
    );
    const inner: (Node | string | null)[] = [line(part)];
    if (part.note) {
      inner.push(el("p", { class: "field-hint", text: part.note }));
    }
    if (part.url) {
      const a = el("a", { class: "link", href: part.url, text: "Datasheet" });
      a.setAttribute("target", "_blank");
      a.setAttribute("rel", "noreferrer");
      inner.push(a);
    }
    // Who says so. Every part here came out of a research report and not off the
    // machine, and a parts list that does not say that invites somebody to order
    // from it as though it were a catalogue.
    if (part.document_source) {
      inner.push(
        el("p", {
          class: "field-hint",
          text: `${part.provenance === "inferred" ? "Inferred by" : "From"} ${part.document_source}. Not checked against the machine.`,
        }),
      );
    }
    for (const kid of kids) inner.push(node(kid));

    if (kids.length === 0 && !part.note && !part.url) {
      return el("div", { class: "row" }, head, line(part));
    }
    return el(
      "details",
      // `part` as well as `more`, for the chevron. Everywhere else in these apps
      // a fold is one of two or three on a screen and its summary reads as a
      // heading you might tap. Here there are seventy two, and `summary` is
      // display:flex app-wide which suppresses the browser's own marker, so
      // without this nothing on the row says it opens. Scoped rather than fixed
      // globally: changing the chrome of every existing fold is a bigger change
      // than this screen should make on its own.
      { class: "more part" },
      el("summary", {}, head),
      rows(...inner.filter((b) => b !== null)),
    );
  }

  const top = byParent.get("") ?? [];
  return rows(...top.map(node));
}

// --- the papers ------------------------------------------------------------

function paperList(papers: MachinePaper[]): HTMLElement {
  return rows(
    ...papers.map((d) => {
      const opened = el("div", {});
      const head = el(
        "div",
        { class: "row-main" },
        el("span", { class: "row-title", text: d.title }),
        el("span", {
          class: "row-note",
          text:
            `${d.kind_label}${d.source ? `, ${d.source}` : ""}, ${d.at}` +
            (d.about_what === "machine" ? ", about this one" : ", about the model"),
        }),
        d.provenance === "inferred"
          ? el("span", { class: "tag tag-inherited", text: "inferred" })
          : null,
      );
      const parts: (Node | string | null)[] = [];
      if (d.url) {
        const a = el("a", { class: "link", href: d.url, text: "Open the original" });
        a.setAttribute("target", "_blank");
        a.setAttribute("rel", "noreferrer");
        parts.push(a);
      }
      if (d.has_text) {
        parts.push(
          button(
            `Read it here (${Math.round(d.text_length / 1000)}k)`,
            async () => {
              opened.replaceChildren(empty("Loading."));
              try {
                const text = await documentText(d.id);
                opened.replaceChildren(el("pre", { class: "paper-text", text }));
              } catch (error) {
                opened.replaceChildren(banner((error as Error).message, "error"));
              }
            },
            "quiet",
          ),
        );
      }
      parts.push(opened);
      return el(
        "details",
        { class: "more" },
        el("summary", {}, head),
        rows(...parts.filter((b) => b !== null)),
      );
    }),
  );
}

function detailScreen(id: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("machine", "Machine", body);

  async function load(): Promise<void> {
    try {
      const [m, history] = await Promise.all([machine(id), machineWork(id)]);
      if (!m) {
        body.replaceChildren(banner("That machine is not here any more.", "error"));
        return;
      }
      // The decomposition belongs to the model and the papers to either, so both
      // wait on knowing which model this is.
      const [parts, papers] = await Promise.all([
        m.model_id ? modelParts(m.model_id) : Promise.resolve([] as ModelPart[]),
        machinePapers({ modelId: m.model_id, machineId: m.id }),
      ]);
      view.querySelector("h1")?.replaceChildren(document.createTextNode(m.name));

      const departures = history.filter((w) => w.changed_it);

      put(
        body,
        el(
          "div",
          { class: "summary" },
          summaryRow("Model", m.model_name ?? "not said"),
          m.serial ? summaryRow("Serial", m.serial) : null,
          m.location_name ? summaryRow("Where", m.location_name) : null,
          // The bridge, said out loud. Somebody standing at the press should
          // know the app already knows it as a vessel.
          m.vessel_name ? summaryRow("Also the vessel", m.vessel_name) : null,
        ),

        el("h2", { class: "section-head", text: "What it is" }),
        Object.keys(m.spec).length === 0
          ? empty("Nothing said about what it is. The model is where that starts.")
          : el("div", { class: "summary" }, ...specRows(m.spec)),
        departures.length > 0
          ? el("p", {
              class: "field-hint",
              text:
                `${departures.length} of this is not how it shipped. ` +
                "Everything above is the model with the modifications applied over it.",
            })
          : null,

        el("h2", { class: "section-head", text: "What has been done to it" }),
        history.length === 0
          ? empty("Nothing recorded yet.")
          : rows(
              ...history.map((w) =>
                el(
                  "div",
                  { class: "row" },
                  el(
                    "div",
                    { class: "row-main" },
                    el("span", {
                      class: "row-title",
                      text: `${w.at}  ${w.kind_label}${w.changed_it ? "  (changed it)" : ""}`,
                    }),
                    el("span", { class: "row-note", text: w.body }),
                    w.by_whom
                      ? el("span", { class: "row-note", text: w.by_whom })
                      : null,
                  ),
                ),
              ),
            ),

        el("h2", { class: "section-head", text: "What it is made of" }),
        parts.length === 0
          ? empty("Nothing said yet about what this model is made of.")
          : rows(
              partTree(parts),
              el("p", {
                class: "field-hint",
                text:
                  `${parts.length} parts, ${parts.filter((p) => p.wear).length} of which wear out. ` +
                  "Everything here came out of a document rather than off the machine.",
              }),
            ),

        el("h2", { class: "section-head", text: "Papers" }),
        papers.length === 0
          ? empty("No manuals, schematics or reports filed.")
          : paperList(papers),

        button("Record work", () => show(workScreen(m))),
        button("Back", () => show(listScreen()), "quiet"),
      );
    } catch (error) {
      body.replaceChildren(banner((error as Error).message, "error"));
    }
  }

  void load();
  return view;
}

// --- recording work --------------------------------------------------------

function workScreen(m: MachineDetail): HTMLElement {
  const said = el("div", {});

  const kind = el("select", { class: "input" });
  kind.replaceChildren(
    el("option", { value: "repair", text: "Repair" }),
    el("option", { value: "service", text: "Service" }),
    el("option", {
      value: "modification",
      text: "Modification, it changed the machine",
    }),
    el("option", { value: "diagnosis", text: "Diagnosis" }),
    el("option", { value: "inspection", text: "Inspection" }),
    el("option", { value: "quirk", text: "Quirk, something to know" }),
  );

  const what = field({
    label: "What was done",
    hint: "Plainly, the way you would tell somebody.",
  });
  // The date is the point. The VFDs went in months before this app could record
  // them, and a history that can only say today is one nobody can enter.
  const when = field({
    label: "When",
    type: "date",
    value: new Date().toISOString().slice(0, 10),
    hint: "Today unless you say otherwise. Past dates are the point of this.",
  });

  // Only meaningful for a modification, and the kernel refuses it on anything
  // else rather than ignoring it, so the form says so before you get there.
  const changedKey = field({ label: "What it changed", placeholder: "power" });
  const changedTo = field({ label: "To what", placeholder: "three phase via VFD" });
  const changeBlock = el(
    "div",
    { class: "rows" },
    el("p", {
      class: "field-hint",
      text: "A modification may say what it changed about the machine. Leave blank if it just says it in words.",
    }),
    changedKey.root,
    changedTo.root,
  );

  function sync(): void {
    changeBlock.hidden = kind.value !== "modification";
  }
  on(kind, "change", sync);
  sync();

  return screen(
    "machine-work",
    `Work on ${m.name}`,
    rows(
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "Kind of work" }),
        kind,
      ),
      what.root,
      when.root,
      changeBlock,
      button("Record it", async () => {
        if (!what.value()) {
          said.replaceChildren(banner("Say what was done.", "error"));
          return;
        }
        const key = changedKey.value();
        const to = changedTo.value();
        if (kind.value === "modification" && Boolean(key) !== Boolean(to)) {
          said.replaceChildren(
            banner(
              "A change needs both what it changed and what it changed to.",
              "error",
            ),
          );
          return;
        }
        try {
          const out = await recordMachineWork({
            machineId: m.id,
            kind: kind.value,
            body: what.value(),
            at: when.value() || null,
            specChange: key && to ? { [key]: to } : null,
          });
          said.replaceChildren(
            banner(
              out.changed_it
                ? `Recorded, and ${m.name} is now ${Object.entries(out.spec_now)
                    .map(([k, v]) => `${k.replace(/_/g, " ")} ${String(v)}`)
                    .join(", ")}.`
                : "Recorded.",
              "good",
            ),
          );
          what.input.value = "";
          changedKey.input.value = "";
          changedTo.input.value = "";
        } catch (error) {
          said.replaceChildren(banner((error as Error).message, "error"));
        }
      }),
      button("Back", () => show(detailScreen(m.id)), "quiet"),
      said,
    ),
  );
}

// --- adding things ---------------------------------------------------------

function addModelScreen(): HTMLElement {
  const said = el("div", {});
  const make = field({ label: "Make", placeholder: "Bucher" });
  const model = field({ label: "Model", placeholder: "XPlus 12" });
  const kind = el("select", { class: "input" });
  kind.replaceChildren(
    el("option", { value: "", text: "Not said" }),
    ...["press", "tractor", "implement", "sorting", "pump", "chiller", "other"].map(
      (k) => el("option", { value: k, text: k }),
    ),
  );
  const specKey = field({ label: "A specification", placeholder: "power" });
  const specValue = field({ label: "Its value", placeholder: "single phase 230V" });

  return screen(
    "model-new",
    "Add a model",
    lede(
      "What one of these is as the manufacturer ships it. Everything a particular " +
        "machine differs by is measured against this.",
    ),
    rows(
      make.root,
      model.root,
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "Kind" }),
        kind,
      ),
      el("p", {
        class: "field-hint",
        text: "One specification to start with. More can be added by modifying a machine later.",
      }),
      specKey.root,
      specValue.root,
      button("Add it", async () => {
        if (!make.value() || !model.value()) {
          said.replaceChildren(banner("A model is a make and a model.", "error"));
          return;
        }
        try {
          await registerMachineModel({
            make: make.value(),
            model: model.value(),
            kind: kind.value || null,
            spec:
              specKey.value() && specValue.value()
                ? { [specKey.value()]: specValue.value() }
                : {},
          });
          show(listScreen());
        } catch (error) {
          said.replaceChildren(banner((error as Error).message, "error"));
        }
      }),
      button("Back", () => show(listScreen()), "quiet"),
      said,
    ),
  );
}

function addMachineScreen(): HTMLElement {
  const said = el("div", {});
  const name = field({ label: "Called", placeholder: "The press" });
  const serial = field({ label: "Serial number", placeholder: "optional" });
  const model = el("select", { class: "input" });
  const asVessel = el("select", { class: "input" });
  const body = el("div", { class: "rows" }, empty("Loading."));

  void (async () => {
    // 0108. Models read from their own list, so one registered a minute ago and
    // not yet used is there. Until that readable existed this screen built the
    // list out of the machines that already had a model, which left out exactly
    // the model somebody had just made. That was S-92.
    const [all, kit, models] = await Promise.all([
      machines(),
      vessels(),
      machineModels(),
    ]);
    // "First model number is just a list with 0 selections and no way to add a
    // selection." An empty picker with no way out is a dead end, and the model
    // is the thing worth filling in first: it is the baseline every departure is
    // measured against.
    model.replaceChildren(
      el("option", {
        value: "",
        text: models.length === 0 ? "No models registered yet" : "No model",
      }),
      ...models.map((mm) =>
        el("option", {
          value: mm.id,
          text: mm.machines > 0 ? `${mm.name} (${mm.machines})` : mm.name,
        }),
      ),
    );
    // The bridge. A machine that is already a vessel claims it rather than
    // becoming a second copy of the same press.
    const claimed = new Set(all.map((m) => m.vessel_id).filter(Boolean));
    asVessel.replaceChildren(
      el("option", { value: "", text: "Not a vessel" }),
      ...kit
        .filter((v) => !claimed.has(v.id))
        .map((v) => el("option", { value: v.id, text: v.name })),
    );

    body.replaceChildren(
      name.root,
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "Model" }),
        model,
      ),
      serial.root,
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "It is also this vessel" }),
        asVessel,
      ),
      // A way out of the empty picker, from the screen where it is empty. The
      // list screen has this button too, and somebody who got here first should
      // not have to find their way back to it.
      el(
        "p",
        { class: "field-hint" },
        models.length === 0
          ? "No models yet. A model is what one of these is as it shipped, and everything this machine differs by is measured against it."
          : "The model is the baseline. What this particular machine differs by is recorded as work on it.",
      ),
      button(
        models.length === 0 ? "Add the first model" : "Add a model",
        () => show(addModelScreen()),
        "quiet",
      ),
      el("p", {
        class: "field-hint",
        text: "The press is already a vessel in the cellar. Saying so here keeps it one thing rather than two.",
      }),
      button("Add it", async () => {
        if (!name.value()) {
          said.replaceChildren(banner("Give it a name.", "error"));
          return;
        }
        try {
          await registerMachine({
            name: name.value(),
            modelId: model.value || null,
            serial: serial.value() || null,
            vesselId: asVessel.value || null,
          });
          show(listScreen());
        } catch (error) {
          said.replaceChildren(banner((error as Error).message, "error"));
        }
      }),
      button("Back", () => show(listScreen()), "quiet"),
      said,
    );
  })();

  return screen("machine-new", "Add a machine", body);
}

export function mountShop(target: HTMLElement): void {
  root = target;
  show(listScreen());
}
