import {
  type AppUser,
  addLocation,
  addParty,
  addVessel,
  bindCode,
  claimAccount,
  createVesselWithWine,
  currentAppUser,
  currentSession,
  facilityParty,
  locations,
  newId,
  nodeEvents,
  type Party,
  parties,
  resolveCode,
  signIn,
  signOut,
  signUp,
  uploadVesselPhoto,
  type VesselState,
  vesselPhotoUrl,
  vessels,
} from "core";
import { locationPicker, termPicker } from "./pickers.ts";
import { codeCapture } from "./scan.ts";
import { remember, stickyValue } from "./sticky.ts";
import {
  banner,
  button,
  checkbox,
  el,
  empty,
  field,
  lede,
  on,
  rows,
  screen,
  summaryRow,
} from "./ui.ts";

// The inventory walk. Its acceptance test is a stranger's first run: empty
// database, fresh account, and you get from sign up to a labelled barrel with
// wine in it without touching SQL.
//
// The order of the screens is not a design preference. It is the order the
// schema enforces: no app_user until an account is claimed, no node until a
// facility party exists, no placement until there is a vessel to place into.

let root: HTMLElement;

export function mountWalk(target: HTMLElement): void {
  root = target;
  void route();
}

function show(node: HTMLElement): void {
  root.replaceChildren(node);
  window.scrollTo(0, 0);
}

function fail(error: unknown): HTMLElement {
  return banner((error as Error).message ?? String(error), "error");
}

// --- the gates ------------------------------------------------------------

async function route(): Promise<void> {
  try {
    const session = await currentSession();
    if (!session) return show(signInScreen());

    const user = await currentAppUser();
    if (!user) return show(claimScreen(session.email));

    const facility = await facilityParty();
    if (!facility) return show(facilityScreen(user));

    show(await homeScreen(user, facility));
  } catch (error) {
    show(
      screen(
        "Something went wrong",
        fail(error),
        button("Try again", () => route()),
      ),
    );
  }
}

// --- sign in --------------------------------------------------------------

function signInScreen(): HTMLElement {
  const email = field({
    label: "Email",
    type: "email",
    attrs: { autocomplete: "email" },
  });
  const password = field({
    label: "Password",
    type: "password",
    attrs: { autocomplete: "current-password" },
    hint: "At least six characters.",
  });
  const message = el("div", {});

  async function attempt(action: () => Promise<void>, note?: string): Promise<void> {
    message.replaceChildren();
    try {
      await action();
      if (note) message.replaceChildren(banner(note, "good"));
      await route();
    } catch (error) {
      message.replaceChildren(fail(error));
    }
  }

  return screen(
    "Vitae Springs",
    lede("Production tracking. Sign in, or make the first account."),
    rows(
      email.root,
      password.root,
      button("Sign in", () => attempt(() => signIn(email.value(), password.value()))),
      button(
        "Create an account",
        () =>
          attempt(
            () => signUp(email.value(), password.value()),
            "Account created. If this instance asks for email confirmation, confirm and sign in.",
          ),
        "secondary",
      ),
      message,
    ),
  );
}

// --- claim ----------------------------------------------------------------

function claimScreen(email: string): HTMLElement {
  const name = field({
    label: "Your name",
    placeholder: "How the board should show you",
    hint: "This is the name on tasks you claim and events you record.",
  });
  const message = el("div", {});

  return screen(
    "One more thing",
    lede(
      `Signed in as ${email}. The cellar needs a name to put against what you record. ` +
        "The first account to do this becomes the administrator, which is decided by the " +
        "database rather than here.",
    ),
    rows(
      name.root,
      button("Continue", async () => {
        if (!name.value()) return;
        try {
          await claimAccount(name.value());
          await route();
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      message,
    ),
  );
}

// --- first run: the facility party ---------------------------------------

function facilityScreen(user: AppUser): HTMLElement {
  const name = field({
    label: "Facility name",
    placeholder: "Vitae Springs",
    hint: "The legal entity that owns the wine you make for yourselves.",
  });
  const message = el("div", {});

  const explanation = el(
    "div",
    { class: "explain" },
    el("p", {
      text:
        "Nothing can be created yet, and that is deliberate rather than a bug. Every lot " +
        "has an owner, because ownership is what drives TTB reporting, cost allocation, " +
        "and what a custom crush client is allowed to see.",
    }),
    el("p", {
      text:
        "The facility is a party like any other, so a lot you own and a lot a client owns " +
        "are the same shape. Lots default to this one. Client parties come later, when " +
        "there is wine to attach them to.",
    }),
  );

  if (user.role !== "admin") {
    return screen(
      "Waiting on an administrator",
      lede(
        "The facility party has to exist before anything else can, and only an " +
          "administrator can create it. Ask whoever set this up to sign in first.",
      ),
      explanation,
      button("Check again", () => route(), "secondary"),
    );
  }

  return screen(
    "Name the facility",
    lede("This is the first thing, because everything else refers to it."),
    explanation,
    rows(
      name.root,
      button("Create the facility", async () => {
        if (!name.value()) return;
        try {
          await addParty(name.value(), "facility");
          await route();
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      message,
    ),
  );
}

// --- home -----------------------------------------------------------------

async function homeScreen(user: AppUser, facility: Party): Promise<HTMLElement> {
  const [places, kit] = await Promise.all([locations(), vessels()]);
  const filled = kit.filter((v) => !v.is_empty).length;

  return screen(
    facility.name,
    lede(`${user.name}, ${user.role}. The walk, in the order the schema allows.`),
    el(
      "div",
      { class: "summary" },
      summaryRow("Locations", String(places.length)),
      summaryRow("Vessels", String(kit.length)),
      summaryRow("Vessels with wine in them", String(filled)),
    ),
    rows(
      button("Add a vessel and put wine in it", () => show(vesselWineScreen())),
      button("Add an empty vessel", () => show(vesselScreen()), "secondary"),
      button("Scan a code", () => show(scanScreen()), "secondary"),
      button("Add a location", () => show(locationScreen()), "secondary"),
    ),
    kit.length === 0
      ? empty(
          "No vessels yet. The first one is the longest; the rest remember your answers.",
        )
      : vesselList(kit),
    button(
      "Sign out",
      async () => {
        await signOut();
        await route();
      },
      "quiet",
    ),
  );
}

function vesselList(kit: VesselState[]): HTMLElement {
  return el(
    "ul",
    { class: "vessel-list" },
    ...kit.map((v) =>
      el(
        "li",
        { class: "vessel-row" },
        el("span", { class: "vessel-name", text: `${v.name} (${v.type})` }),
        el("span", {
          class: "vessel-detail",
          text: v.is_empty
            ? "empty"
            : `${v.lot_name ?? "unnamed lot"}, ${v.current_volume_l ?? "?"} L`,
        }),
        el("span", {
          class: "vessel-codes",
          text: (v.codes ?? []).join(", ") || "no codes",
        }),
      ),
    ),
  );
}

// --- locations ------------------------------------------------------------

function locationScreen(): HTMLElement {
  const name = field({ label: "Name", placeholder: "Barrel room" });
  const kind = termPicker("location_kind", {
    label: "Kind",
    allowEmpty: true,
    emptyLabel: "Unspecified",
  });
  const controlled = checkbox("Temperature controlled");
  const ambient = field({
    label: "Ambient temperature, C",
    type: "number",
    placeholder: "13.5",
    hint: "A jacketed vessel overrides this with its own setpoint.",
  });
  const message = el("div", {});

  void kind.reload();

  return screen(
    "Add a location",
    lede("Where vessels live. Add them as you walk into them."),
    rows(
      name.root,
      kind.root,
      controlled.root,
      ambient.root,
      button("Save", async () => {
        if (!name.value()) {
          message.replaceChildren(banner("A location needs a name.", "error"));
          return;
        }
        try {
          await addLocation({
            name: name.value(),
            kind_id: kind.value() || null,
            controlled: controlled.input.checked,
            ambient_c: ambient.value() ? Number(ambient.value()) : null,
          });
          await route();
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button("Back", () => route(), "quiet"),
      message,
    ),
  );
}

// --- vessel fields, shared by both vessel screens -------------------------

type VesselForm = {
  nodes: HTMLElement[];
  read: () => {
    type_id: string;
    name: string;
    capacity_l: number | null;
    location_id: string | null;
    owner_id: string | null;
    attributes: Record<string, unknown>;
  };
  photoFile: () => File | null;
  ready: () => string | null;
  reload: () => Promise<void>;
};

function vesselFields(partyRows: Party[]): VesselForm {
  const type = termPicker("vessel_type", { label: "Type", stickyKey: "vessel_type" });
  const name = field({
    label: "Name",
    placeholder: "B23",
    hint: "What is written on it.",
  });
  const capacity = field({
    label: "Capacity, litres",
    type: "number",
    value: stickyValue("capacity"),
    placeholder: "228",
  });
  const place = locationPicker({
    label: "Location",
    stickyKey: "location",
    allowEmpty: true,
  });

  const owner = el("select", { class: "input" });
  owner.replaceChildren(
    el("option", { value: "", text: "Facility owned" }),
    ...partyRows
      .filter((p) => p.kind === "client")
      .map((p) => el("option", { value: p.id, text: `${p.name} (client owned)` })),
  );
  const ownerField = el(
    "div",
    { class: "field" },
    el("span", { class: "field-label", text: "Owner" }),
    owner,
    el("span", {
      class: "field-hint",
      text: "Facility owned unless the client brought their own equipment.",
    }),
  );

  const cooper = termPicker("cooper", {
    label: "Cooper",
    stickyKey: "cooper",
    allowEmpty: true,
  });
  const wood = termPicker("wood", {
    label: "Wood",
    stickyKey: "wood",
    allowEmpty: true,
  });
  const fillCount = field({
    label: "Fill count",
    type: "number",
    value: stickyValue("fill_count"),
    hint: "How many wines this barrel has held, this one included.",
  });
  const toast = field({
    label: "Toast",
    value: stickyValue("toast"),
    placeholder: "medium",
  });

  const photo = el("input", {
    class: "input",
    type: "file",
    accept: "image/*",
    capture: "environment",
  });
  const photoField = el(
    "div",
    { class: "field" },
    el("span", { class: "field-label", text: "Photo" }),
    photo,
    el("span", {
      class: "field-hint",
      text: "Optional. Useful when the label falls off.",
    }),
  );

  on(capacity.input, "change", () => remember("capacity", capacity.value()));
  on(fillCount.input, "change", () => remember("fill_count", fillCount.value()));
  on(toast.input, "change", () => remember("toast", toast.value()));

  return {
    nodes: [
      type.root,
      name.root,
      capacity.root,
      place.root,
      ownerField,
      cooper.root,
      wood.root,
      fillCount.root,
      toast.root,
      photoField,
    ],
    read: () => ({
      type_id: type.value(),
      name: name.value(),
      capacity_l: capacity.value() ? Number(capacity.value()) : null,
      location_id: place.value() || null,
      owner_id: owner.value || null,
      attributes: {
        cooper: cooper.value() || null,
        cooper_label: cooper.label() || null,
        wood: wood.value() || null,
        wood_label: wood.label() || null,
        fill_count: fillCount.value() ? Number(fillCount.value()) : null,
        toast: toast.value() || null,
      },
    }),
    photoFile: () => photo.files?.[0] ?? null,
    ready: () => {
      if (!type.value()) return "Pick a vessel type, or add one.";
      if (!name.value()) return "A vessel needs a name.";
      return null;
    },
    reload: async () => {
      await Promise.all([
        type.reload(),
        place.reload(),
        cooper.reload(),
        wood.reload(),
      ]);
    },
  };
}

// --- an empty vessel ------------------------------------------------------

function vesselScreen(): HTMLElement {
  const message = el("div", {});
  const holder = el("div", { class: "rows" });
  const capture = codeCapture({ label: "Codes on this vessel" });
  const view = screen(
    "Add an empty vessel",
    lede("A vessel with nothing in it yet. Wine can go in later."),
    holder,
  );

  void (async () => {
    const partyRows = await parties();
    const form = vesselFields(partyRows);
    await form.reload();
    holder.append(
      ...form.nodes,
      capture.root,
      button("Save vessel", async () => {
        const problem = form.ready();
        if (problem) {
          message.replaceChildren(banner(problem, "error"));
          return;
        }
        try {
          const id = newId();
          const values = form.read();
          const file = form.photoFile();
          const attributes = { ...values.attributes };
          if (file) attributes.photo_path = await uploadVesselPhoto(id, file);

          await addVessel({ id, ...values, attributes });
          for (const row of capture.codes()) await bindOne(id, row);
          capture.stop();
          await route();
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button(
        "Back",
        () => {
          capture.stop();
          void route();
        },
        "quiet",
      ),
      message,
    );
  })();

  return view;
}

async function bindOne(vesselId: string, row: { code: string; label: string | null }) {
  await bindCode(vesselId, row.code, row.label);
}

// --- a vessel with wine in it, one action ---------------------------------

function vesselWineScreen(): HTMLElement {
  const message = el("div", {});
  const holder = el("div", { class: "rows" });
  const capture = codeCapture({ label: "Codes on this vessel" });

  const view = screen(
    "Vessel and wine",
    lede(
      "One action. It creates the vessel, the lot and the placement together, and asks " +
        "the kernel for whatever history the variety template implies.",
    ),
    holder,
  );

  void (async () => {
    const partyRows = await parties();
    const form = vesselFields(partyRows);

    const variety = termPicker("variety", { label: "Variety", stickyKey: "variety" });
    const vintage = field({
      label: "Vintage",
      type: "number",
      value: stickyValue("vintage"),
      placeholder: String(new Date().getFullYear()),
    });
    const productType = termPicker("product_type", {
      label: "Product type",
      stickyKey: "product_type",
    });
    const volume = field({
      label: "Volume in the vessel, litres",
      type: "number",
      placeholder: "220",
    });
    const lotName = field({
      label: "Lot name",
      hint: "Filled in from the variety and vintage. Change it if it is wrong.",
    });

    on(vintage.input, "change", () => {
      remember("vintage", vintage.value());
      autoName();
    });

    function autoName(): void {
      if (lotName.input.dataset.touched === "true") return;
      const parts = [variety.label(), vintage.value()].filter(Boolean);
      lotName.input.value = parts.join(" ");
    }
    on(lotName.input, "input", () => {
      lotName.input.dataset.touched = "true";
    });
    on(variety.root, "change", () => autoName());

    await Promise.all([form.reload(), variety.reload(), productType.reload()]);
    autoName();

    holder.append(
      el("h2", { class: "section-head", text: "The vessel" }),
      ...form.nodes,
      capture.root,
      el("h2", { class: "section-head", text: "The wine" }),
      variety.root,
      vintage.root,
      productType.root,
      lotName.root,
      volume.root,
      button("Create vessel and wine", async () => {
        const problem = form.ready();
        if (problem) {
          message.replaceChildren(banner(problem, "error"));
          return;
        }
        if (!lotName.value()) {
          message.replaceChildren(banner("The lot needs a name.", "error"));
          return;
        }
        try {
          const vesselId = newId();
          const values = form.read();
          const file = form.photoFile();
          const attributes = { ...values.attributes };
          if (file) attributes.photo_path = await uploadVesselPhoto(vesselId, file);

          const result = await createVesselWithWine({
            vessel: { id: vesselId, ...values, attributes },
            node: {
              id: newId(),
              stage: "maturation",
              name: lotName.value(),
              variety_id: variety.value() || null,
              vintage: vintage.value() ? Number(vintage.value()) : null,
              product_type_id: productType.value() || null,
              unit: "L",
              quantity: volume.value() ? Number(volume.value()) : null,
            },
            volumeL: volume.value() ? Number(volume.value()) : null,
            codes: capture.codes(),
          });
          capture.stop();
          show(
            await resultScreen(
              result.vessel_id,
              result.node_id,
              result.events_generated,
            ),
          );
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button(
        "Back",
        () => {
          capture.stop();
          void route();
        },
        "quiet",
      ),
      message,
    );
  })();

  return view;
}

// --- what just happened ---------------------------------------------------

async function resultScreen(
  vesselId: string,
  nodeId: string,
  generated: number,
): Promise<HTMLElement> {
  const kit = await vessels();
  const vessel = kit.find((v) => v.id === vesselId);
  const events = await nodeEvents(nodeId);

  const photoPath = vessel?.attributes?.photo_path;
  const photo = el("div", {});
  if (typeof photoPath === "string") {
    const url = await vesselPhotoUrl(photoPath);
    if (url) photo.append(el("img", { class: "photo", src: url, alt: "The vessel" }));
  }

  return screen(
    vessel ? `${vessel.name} is on the books` : "Saved",
    lede(
      generated === 0
        ? "No template exists for this variety yet, so no history was generated. That is " +
            "an honest zero rather than a failure: see sorry S-17."
        : `${generated} events generated from the variety template, every one marked inferred.`,
    ),
    photo,
    el(
      "div",
      { class: "summary" },
      summaryRow("Vessel", vessel ? `${vessel.name} (${vessel.type})` : "unknown"),
      summaryRow("Location", vessel?.location_name ?? "unassigned"),
      summaryRow("Lot", vessel?.lot_name ?? "unknown"),
      summaryRow(
        "Wine",
        [vessel?.variety, vessel?.vintage].filter(Boolean).join(" ") || "unspecified",
      ),
      summaryRow(
        "Volume",
        vessel?.current_volume_l ? `${vessel.current_volume_l} L` : "unrecorded",
      ),
      summaryRow(
        "Owner",
        vessel?.facility_owned ? "Facility" : (vessel?.owner_name ?? "unknown"),
      ),
      summaryRow("Codes", (vessel?.codes ?? []).join(", ") || "none bound"),
    ),
    events.length === 0
      ? empty("No history on this lot.")
      : el(
          "ul",
          { class: "event-list" },
          ...events.map((e) =>
            el(
              "li",
              { class: "event-row" },
              el("span", { class: "event-op", text: e.label }),
              el("span", {
                class: "event-at",
                text: new Date(e.at).toLocaleDateString(),
              }),
              el("span", { class: `tag tag-${e.provenance}`, text: e.provenance }),
            ),
          ),
        ),
    rows(
      button("Add another", () => show(vesselWineScreen())),
      button("Back to the cellar", () => route(), "secondary"),
    ),
  );
}

// --- scanning -------------------------------------------------------------

function scanScreen(): HTMLElement {
  const result = el("div", { class: "scan-result" });
  const capture = codeCapture({
    label: "Scan or type a code",
    collect: false,
    onCode: async (code) => {
      try {
        const vessel = await resolveCode(code);
        result.replaceChildren(
          vessel
            ? el(
                "div",
                { class: "summary" },
                summaryRow("Vessel", `${vessel.name} (${vessel.type})`),
                summaryRow("Location", vessel.location_name ?? "unassigned"),
                summaryRow(
                  "Holding",
                  vessel.is_empty ? "empty" : (vessel.lot_name ?? "unknown"),
                ),
                summaryRow(
                  "Wine",
                  [vessel.variety, vessel.vintage].filter(Boolean).join(" ") ||
                    "unspecified",
                ),
                summaryRow(
                  "Volume",
                  vessel.current_volume_l
                    ? `${vessel.current_volume_l} L`
                    : "unrecorded",
                ),
                summaryRow("Every code on it", (vessel.codes ?? []).join(", ")),
              )
            : banner(`Nothing is bound to ${code} yet.`, "note"),
        );
      } catch (error) {
        result.replaceChildren(fail(error));
      }
    },
  });

  return screen(
    "Scan a code",
    lede(
      "Any active code on a barrel lands on the same barrel. Scanning one you have " +
        "already bound tells you what is in it rather than complaining.",
    ),
    capture.root,
    result,
    button(
      "Back",
      () => {
        capture.stop();
        void route();
      },
      "quiet",
    ),
  );
}
