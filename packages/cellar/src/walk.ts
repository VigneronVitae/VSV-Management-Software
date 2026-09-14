import {
  type AppUser,
  addLocation,
  addParty,
  addVessel,
  addVesselTypeNote,
  appUsers,
  bindCode,
  claimAccount,
  createVesselWithWine,
  currentAppUser,
  currentSession,
  facilityParty,
  fillVessel,
  locations,
  type NodePayload,
  newId,
  nodeHistory,
  type Party,
  parties,
  rackPlan,
  rackTransfer,
  resolveCode,
  resolveVesselTypeNote,
  setPartyLogin,
  setVesselTypeFields,
  signIn,
  signOut,
  signUp,
  slug,
  type Term,
  type TermKind,
  type ThermalMode,
  terms,
  termsForVesselField,
  updateVessel,
  uploadVesselPhoto,
  type VesselRow,
  type VesselState,
  type ViewerScope,
  vesselById,
  vesselByIdOrNull,
  vesselPhotoUrl,
  vessels,
  vesselTypeNotes,
  viewerScope,
  writableColumns,
} from "core";
import { locationPicker, partyPicker, termPicker } from "./pickers.ts";
import {
  clearAllDrafts,
  clearDraft,
  decode,
  encode,
  HOME,
  type Place,
  readDraft,
  samePlace,
  saveDraft,
} from "./places.ts";
import { describeEmpty, describeRefusal, mayEnter } from "./refusal.ts";
import { codeCapture } from "./scan.ts";
import { activeSkin, applySkin, skins } from "./skins.ts";
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
  // The phone's back button, and a restart that lands on a real screen. Both
  // are the same mechanism: a place is in the URL, so the browser's own history
  // is the record of where you have been and this client does not keep a
  // second one that could disagree with it.
  window.addEventListener("popstate", () => {
    if (pushes > 0) pushes -= 1;
    void open(decode(window.location.hash), "replace");
  });
  void route();
}

// Work a screen started that outlives its own markup. A draft listens on
// `document` so that it is still there when the phone backgrounds the tab, and
// a listener on `document` does not go away when the element does: without this
// the form you left would keep writing its draft from behind the screen you are
// looking at. Registered by the screen, run by whoever replaces it.
let leaving: Array<() => void> = [];

function whenLeaving(fn: () => void): void {
  leaving.push(fn);
}

function show(node: HTMLElement): void {
  const done = leaving;
  leaving = [];
  for (const fn of done) fn();
  root.replaceChildren(node);
  window.scrollTo(0, 0);
}

// The viewer's standing, as the kernel last answered it. Held here rather than
// threaded through every screen because every screen needs it and none of them
// should be deciding it. Refreshed by route() on each pass, so a sign-out or a
// deactivation is picked up on the next navigation rather than remembered.
let scope: ViewerScope | null = null;

// W-9 phase 4. Every error in this client already arrived here, which is why one
// path was reachable at all; what it did was relay whatever Postgres said. It now
// asks describeRefusal, which is the only place that knows what the three shapes
// are and what to say about each.
function fail(error: unknown): HTMLElement {
  return banner(describeRefusal(error, scope), "error");
}

// --- the gates ------------------------------------------------------------

// Ledger B10's replacement. A signed-in account with no standing used to reach
// every screen and be refused one write at a time; it now stops here and is told
// which of the two reasons applies, because "ask an administrator" is useless
// advice if the answer is that you are looking at the wrong winery.
function noStandingScreen(): HTMLElement {
  return screen(
    "This account cannot work here",
    lede(
      "You are signed in, and this sign-in has nothing to work on here. That is " +
        "not the same as being signed out, so the screen says which it is.",
    ),
    banner(
      scope?.signed_in && !scope.account
        ? "The account exists and has been deactivated. An administrator turns it back on."
        : "This sign-in is not attached to anything at this winery yet.",
      "note",
    ),
    button(
      "Sign out",
      async () => {
        await signOut();
        // A phone in a barn is shared. An unsaved vessel belongs to whoever
        // typed it and does not survive into the next person's sign-in.
        clearAllDrafts();
        window.history.replaceState(null, "", encode(HOME));
        await route();
      },
      "quiet",
    ),
  );
}

// Who is signed in and where they work, as route() last established it. Held
// because a place resolves into a screen and several screens need one or both,
// and re-asking per navigation would be a round trip for an answer that cannot
// have changed without passing back through route().
let standing: { user: AppUser; facility: Party } | null = null;

// Builds the screen a place names, by asking the kernel again. A place holds an
// identifier and never a value, so this is where a bookmark from yesterday
// becomes what is true today, and where an identifier that no longer resolves
// becomes a refusal rather than a blank screen.
async function screenFor(place: Place): Promise<HTMLElement> {
  if (!standing) throw new Error("no standing");
  const { user, facility } = standing;

  switch (place.at) {
    case "home":
      return homeScreen(user, facility);
    case "vessels":
      return vesselListScreen(await vessels());
    case "vessel-new":
      return vesselScreen();
    case "vessel-wine":
      return vesselWineScreen();
    case "rack":
      return rackScreen();
    case "scan":
      return scanScreen();
    case "locations":
      return locationScreen();
    case "clients":
      return clientsScreen();
    case "vessel-types":
      return vesselTypeListScreen(user);
    case "vessel-type": {
      const type = (await terms("vessel_type")).find((t) => t.id === place.id);
      if (!type) throw new GoneError("That vessel type no longer exists.");
      return vesselTypeScreen(user, type);
    }
    case "vessel":
    case "vessel-edit":
    case "vessel-fill": {
      const vessel = await vesselByIdOrNull(place.id);
      // W-9's A13 class, arriving in the router. A link to a vessel that has
      // been removed, or that this sign-in may not read, comes back as nothing,
      // and nothing is not a screen. Saying which of those it is would require
      // knowing, and the kernel does not tell a reader the difference on
      // purpose, so this says the one true thing instead.
      if (!vessel) {
        throw new GoneError(
          "That vessel is not there to open. It may have been removed, or it " +
            "may belong to somebody else.",
        );
      }
      if (place.at === "vessel") return vesselChoiceScreen(vessel.id, vessel.name);
      if (place.at === "vessel-edit") return vesselEditScreen(vessel.id, vessel.name);
      return fillVesselScreen(vessel.id, vessel.name);
    }
  }
}

// A place that resolved to nothing. Separate from a refusal because the
// treatment is different: this one sends you home rather than offering to try
// again, since trying again will fail the same way.
class GoneError extends Error {}

// Paints the screen a place names and records the place, so that a restart
// resumes here. `push` is a navigation a person made and the back button should
// undo; `replace` is arriving somewhere without having moved, which is the
// first paint, a popstate, and the screen after a write that must not be
// repeated by going back to it.
async function open(place: Place, how: "push" | "replace"): Promise<void> {
  try {
    const node = await screenFor(place);
    const url = encode(place);
    if (how === "push" && window.location.hash !== url) {
      window.history.pushState(null, "", url);
      pushes += 1;
    } else {
      window.history.replaceState(null, "", url);
    }
    show(node);
  } catch (error) {
    if (error instanceof GoneError) {
      window.history.replaceState(null, "", encode(HOME));
      const node = standing ? await screenFor(HOME).catch(() => null) : null;
      return show(
        screen(
          "Not there",
          banner(error.message, "note"),
          node ?? button("Back to the cellar", () => go(HOME)),
        ),
      );
    }
    show(
      screen(
        "Something went wrong",
        fail(error),
        button("Try again", () => open(place, "replace")),
      ),
    );
  }
}

// The screen after a write. It is not a place, because a place is resolved by
// asking again and there is nothing to ask: the write happened. What a restart
// should find is the vessel it happened to, so that is what goes in the URL,
// and the result itself lives only as long as the person is looking at it.
function showResult(node: HTMLElement, vesselId: string): void {
  window.history.replaceState(
    null,
    "",
    encode(vesselId ? { at: "vessel", id: vesselId } : HOME),
  );
  show(node);
}

// How many entries this client has pushed since it started. Not for display:
// it is the only way to know whether history.back() lands on a screen of ours
// or walks out of the app, and walking out of the app is what "Back" must never
// do. A cold restart onto a vessel link has no history behind it.
let pushes = 0;

function go(place: Place): void {
  void open(place, "push");
}

// Ends the current screen and returns to the one before it. Named for what it
// does to the history rather than for what it draws, because the back button is
// now a thing a person uses, and a "Back" control that pushed a new entry
// instead of undoing one is the bug everybody ships once.
function goBack(): void {
  if (pushes > 0) {
    window.history.back();
    return;
  }
  go(HOME);
}

async function route(): Promise<void> {
  try {
    const session = await currentSession();
    if (!session) return show(signInScreen());

    scope = await viewerScope();

    const user = await currentAppUser();
    if (!user) return show(claimScreen(session.email));

    // Ledger B10. This used to compare user.role to "admin" and never looked at
    // active, so a deactivated account reached every screen and was refused one
    // write at a time by the kernel. mayEnter asks the kernel instead.
    if (!mayEnter(scope)) return show(noStandingScreen());

    const facility = await facilityParty();
    if (!facility) return show(facilityScreen(user));

    standing = { user, facility };

    // The place comes from the URL, which is how a restart lands where you left
    // off instead of at the top. It is rooted at home first: a restart onto a
    // vessel link would otherwise have nothing behind it, and Back on the first
    // screen you see would leave the application.
    const resuming = decode(window.location.hash);
    await open(HOME, "replace");
    if (!samePlace(resuming, HOME)) await open(resuming, "push");
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
          // A token can outlive the account it names: the JWT secret is fixed
          // in config, so every token minted before a db reset still validates
          // afterwards while auth.users is empty. auth.uid() then returns an id
          // with no row behind it and the foreign key is what notices. Saying
          // so is worth more than the constraint name, because the fix is to
          // sign in again rather than anything to do with this form.
          const text = (error as Error).message ?? String(error);
          message.replaceChildren(
            text.includes("app_user_id_fkey")
              ? banner(
                  "This sign-in belongs to an account the database no longer has. " +
                    "Sign out and sign in again.",
                  "error",
                )
              : fail(error),
          );
        }
      }),
      // Without this the screen is a dead end. Nothing else here leads anywhere,
      // so a session that cannot be claimed leaves you clearing site data.
      button(
        "Sign out",
        async () => {
          await signOut();
          await route();
        },
        "quiet",
      ),
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

type MenuItem = {
  name: string;
  note: string;
  badge?: string;
  go?: () => void;
};

// An item with nowhere to go is not a dead button, it is a statement about
// what this app does not do yet. Showing them is the same instinct as the
// sorry ledger: a named gap is worth more than a blank space, and the order
// they are in is spec.md section 7, which is ordered by how unrecoverable the
// failure is rather than by what would be fun to build.
function menu(items: MenuItem[]): HTMLElement {
  return el(
    "ul",
    { class: "menu" },
    ...items.map((item) => {
      const row = el(
        "li",
        {
          class: `menu-item${item.go ? "" : " menu-soon"}`,
          ...(item.go ? { role: "button", tabindex: "0" } : {}),
        },
        el(
          "span",
          { class: "menu-head" },
          el("span", { class: "menu-name", text: item.name }),
          item.badge ? el("span", { class: "menu-badge", text: item.badge }) : null,
        ),
        el("span", { class: "menu-note", text: item.note }),
      );
      if (item.go) {
        on(row, "click", item.go);
        on(row, "keydown", (ev) => {
          if (ev.key === "Enter" || ev.key === " ") {
            ev.preventDefault();
            item.go?.();
          }
        });
      }
      return row;
    }),
  );
}

async function homeScreen(user: AppUser, facility: Party): Promise<HTMLElement> {
  const [places, kit] = await Promise.all([locations(), vessels()]);
  const filled = kit.filter((v) => !v.is_empty).length;

  return screen(
    facility.name,
    lede(`${user.name}, ${user.role}. What would you like to do?`),
    el("h2", { class: "section-head", text: "In the cellar" }),
    menu([
      {
        name: "Vessel and wine",
        note: "Add a vessel with wine already in it, in one action.",
        go: () => go({ at: "vessel-wine" }),
      },
      {
        name: "Empty vessel",
        note: "Register a vessel now and put wine in it later.",
        go: () => go({ at: "vessel-new" }),
      },
      {
        name: "Rack",
        note: "Move wine between vessels, or blend it. The database works out which.",
        go: () => go({ at: "rack" }),
      },
      {
        name: "Vessels",
        note: "What is in the cellar, and how full.",
        badge: `${filled} of ${kit.length}`,
        go: () => go({ at: "vessels" }),
      },
      {
        name: "Scan a code",
        note: "Find a barrel by the sticker on it.",
        go: () => go({ at: "scan" }),
      },
    ]),
    el("h2", { class: "section-head", text: "Set up" }),
    menu([
      {
        name: "Locations",
        note: "Where vessels live, and what temperature the room is.",
        badge: String(places.length),
        go: () => go({ at: "locations" }),
      },
      {
        name: "Vessel types",
        note: "What each sort of vessel gets asked when you create one.",
        go: () => go({ at: "vessel-types" }),
      },
      {
        name: "Clients",
        note: "Custom crush clients, and which login sees their wine.",
        go: () => go({ at: "clients" }),
      },
    ]),
    el("h2", { class: "section-head", text: "Not built yet" }),
    menu([
      {
        name: "Intake",
        note:
          "Picking bins as they arrive. Build order 2, and the one where a missed " +
          "record cannot be reconstructed afterwards.",
      },
      {
        name: "Press and destem",
        note: "Where lots acquire their identity. Build order 3.",
      },
      {
        name: "Samples and readings",
        note: "Transcribing the Wine Meister by hand. Build order 4.",
      },
      {
        name: "Tasks",
        note: "The board, and who claimed what. Build order 5.",
      },
      {
        name: "Topping",
        note:
          "The kernel already refuses a top from the wrong vintage. The screen " +
          "over it is build order 6, and it needs the codes on the barrels.",
      },
    ]),
    skinPicker(),
    button(
      "Sign out",
      async () => {
        await signOut();
        // A phone in a barn is shared. An unsaved vessel belongs to whoever
        // typed it and does not survive into the next person's sign-in.
        clearAllDrafts();
        window.history.replaceState(null, "", encode(HOME));
        await route();
      },
      "quiet",
    ),
  );
}

function vesselListScreen(kit: VesselState[]): HTMLElement {
  return screen(
    "Vessels",
    lede(
      kit.length === 0
        ? "Nothing yet."
        : `${kit.filter((v) => !v.is_empty).length} of ${kit.length} have wine in them.`,
    ),
    kit.length === 0
      ? empty(
          // W-9 phase 4. "No vessels yet" is only true for somebody who can see
          // all of them. describeEmpty is the one place that difference is said.
          `${describeEmpty("vessels", scope)} The first one is the longest; the rest remember your answers.`,
        )
      : vesselList(kit),
    button("Back", () => goBack(), "quiet"),
  );
}

// Whether the barrel and the wine in it belong to the same party. Both being
// the facility counts as the same; one of each never does.
function sameOwner(v: VesselState): boolean {
  if (v.facility_owned !== v.lot_facility_owned) return false;
  if (v.facility_owned) return true;
  return v.owner_id === v.lot_owner_id;
}

function vesselList(kit: VesselState[]): HTMLElement {
  return el(
    "ul",
    { class: "vessel-list" },
    ...kit.map((v) => {
      // Tappable, because the list is where you are standing when you notice
      // the jacket is wrong. A row is a way into the thing it names.
      // How full it is, published whether or not the skin draws it. Markup
      // carries the fact; presentation is the skin's business.
      // B11 again, in the shape that matters least and reads worst: a vessel
      // holding zero litres had no fill fraction at all rather than a fill of
      // zero, so an emptied barrel drew like one nobody had measured.
      const fill =
        v.capacity_l !== null && v.current_volume_l !== null
          ? Number(v.current_volume_l) / Number(v.capacity_l)
          : null;
      const row = el(
        "li",
        {
          class: `vessel-row vessel-row-tappable${fill !== null && fill > 1 ? " over" : ""}`,
          role: "button",
          tabindex: "0",
          ...(fill === null ? {} : { style: `--fill:${Math.min(fill, 1).toFixed(3)}` }),
        },
        el("span", { class: "vessel-name", text: `${v.name} (${v.type})` }),
        el("span", {
          class: "vessel-detail",
          text: v.is_empty
            ? "empty"
            : `${v.lot_name ?? "unnamed lot"}, ${v.current_volume_l ?? "?"} L`,
        }),
        // Only when it is somebody else's, because on most rows it is ours and
        // saying so on every line would bury the rows where it matters.
        ...(!v.is_empty && !v.lot_facility_owned && v.lot_owner_name
          ? [el("span", { class: "tag tag-owner", text: v.lot_owner_name })]
          : []),
        // And the other direction, which happens just as often: their barrel
        // with our wine in it, or with another client's.
        ...(!v.facility_owned && v.owner_name
          ? [
              el("span", {
                class: "tag tag-vessel-owner",
                text: `${v.owner_name}'s vessel`,
              }),
            ]
          : []),
        el("span", {
          class: "vessel-codes",
          text: (v.codes ?? []).join(", ") || "no codes",
        }),
        // An empty vessel's most likely next action is not editing it, it is
        // putting wine in it. Say so on the row rather than hiding it a screen
        // deeper.
        el("span", {
          class: "vessel-edit-hint",
          text: v.is_empty ? "Fill or edit" : "Edit",
        }),
      );
      // An empty vessel offers the choice; a full one goes straight to the edit
      // screen, because there is only one thing left to do to it.
      const openRow = () =>
        go(v.is_empty ? { at: "vessel", id: v.id } : { at: "vessel-edit", id: v.id });
      on(row, "click", openRow);
      on(row, "keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          ev.preventDefault();
          openRow();
        }
      });
      return row;
    }),
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
      button("Back", () => goBack(), "quiet"),
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
    has_glycol: boolean;
    setpoint_c: number | null;
    mode: ThermalMode;
    attributes: Record<string, unknown>;
  };
  photoFile: () => File | null;
  ready: () => string | null;
  // Renders every control this caller may not write as the value it holds.
  // `null` is no restriction. See 0030 and W-9 phase 6.
  lockTo: (writable: string[] | null) => void;
  reload: () => Promise<void>;
  // Fills the form from a vessel that already exists. Loads the pickers with
  // the current value preselected, so an edit screen opens showing what is
  // true rather than showing blanks that would overwrite it.
  preset: (v: VesselRow) => Promise<void>;
  // Attaches the form to a place so that what has been typed survives the phone
  // discarding the tab. Call after reload() or preset(), because restoring a
  // draft sets picker values and the pickers have to exist first. Resolves to
  // true if there was a draft, which is a thing the screen has to say out loud:
  // restored typing that looks like saved data is the A13 shape.
  draftTo: (place: Place) => Promise<boolean>;
  // The write succeeded, so the draft has nothing left to stand in for.
  draftDone: () => void;
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
    el("span", { class: "field-label", text: "Whose vessel" }),
    owner,
    el("span", {
      class: "field-hint",
      text:
        "Facility owned unless the client brought their own equipment. Whose wine " +
        "goes in it is a separate question, asked with the wine.",
    }),
  );

  // The optional fields are not listed here any more. A vessel type declares
  // its own, in the descriptors 0011 put on the term, so adding "oxygen ingress"
  // to tanks is a row edit rather than a release. Everything below builds a
  // control from a descriptor and puts the value back under the descriptor's
  // key in the vessel's attributes bag.
  type Built = {
    spec: Record<string, unknown>;
    root: HTMLElement;
    read: () => unknown;
    label: () => string | null;
    set: (value: unknown) => Promise<void>;
    missing: () => boolean;
  };
  let built: Built[] = [];

  function buildField(spec: Record<string, unknown>): Built {
    const key = String(spec.key);
    const labelText = String(spec.label ?? key);
    const hint = typeof spec.hint === "string" ? spec.hint : undefined;
    const unit = typeof spec.unit === "string" ? spec.unit : undefined;
    const required = spec.required === true;

    if (spec.kind === "term") {
      const picker = termPicker(String(spec.term_kind) as TermKind, {
        label: labelText,
        stickyKey: key,
        allowEmpty: !required,
        rows: () =>
          type.value() ? termsForVesselField(type.value(), key) : Promise.resolve([]),
        newAttributes: () =>
          typeof spec.contract === "string" ? { contract: spec.contract } : {},
      });
      return {
        spec,
        root: picker.root,
        read: () => picker.value() || null,
        label: () => picker.label() || null,
        set: async (value) => {
          await picker.reload(typeof value === "string" ? value : undefined);
        },
        missing: () => required && !picker.value(),
      };
    }

    const isNumber = spec.kind === "number";
    const control = field({
      label: unit ? `${labelText} (${unit})` : labelText,
      type: isNumber ? "number" : "text",
      value: stickyValue(key),
      ...(hint ? { hint } : {}),
    });
    return {
      spec,
      root: control.root,
      read: () => {
        const raw = control.value();
        if (!raw) return null;
        return isNumber ? Number(raw) : raw;
      },
      label: () => null,
      set: async (value) => {
        control.input.value = value == null ? "" : String(value);
      },
      missing: () => required && !control.value(),
    };
  }

  // Which of these a type opens by default is the type's own business, declared
  // in its term attributes by 0009. Anything not opened is still one tap away
  // rather than gone, because a form that cannot record a true thing is worse
  // than a form with an extra tap in it.
  // Filled below, once the jacket block exists. A jacket on a barrel is
  const openSlot = el("div", {});
  const moreSlot = el("div", {});
  const more = el(
    "details",
    { class: "more" },
    el("summary", { text: "More details" }),
    moreSlot,
  );

  // Rebuilt on every type change, because a tank's fields are not a barrel's
  // and there is nothing sensible to carry across. Values do not survive the
  // switch, which is correct: a tank has no toast level to preserve.
  async function applyTypeShape(preset?: Record<string, unknown>): Promise<void> {
    const chosen = type.selected();
    const bag = (chosen?.attributes ?? {}) as Record<string, unknown>;
    const expand = Array.isArray(bag.expand) ? (bag.expand as string[]) : [];
    const specs = (Array.isArray(bag.fields) ? bag.fields : []) as Array<
      Record<string, unknown>
    >;
    specs.sort((a, b) => Number(a.sort_order ?? 0) - Number(b.sort_order ?? 0));

    built = specs.map(buildField);
    await Promise.all(
      built.map(async (b) => {
        await b.set(preset ? preset[String(b.spec.key)] : undefined);
      }),
    );

    const open = (b: Built) => b.spec.open === true;
    openSlot.replaceChildren(
      ...built.filter(open).map((b) => b.root),
      ...(expand.includes("glycol") ? [glycolBlock] : []),
    );
    moreSlot.replaceChildren(
      ...built.filter((b) => !open(b)).map((b) => b.root),
      ...(expand.includes("glycol") ? [] : [glycolBlock]),
    );
    // No point offering a disclosure with nothing behind it.
    more.hidden = moreSlot.children.length === 0;
    applyAttributeLock();
  }

  on(type.root, "change", () => {
    void applyTypeShape();
  });

  // Every vessel type can carry a jacket. Which ones usually do is a different
  // question, and it is answered by the type's own expand list rather than
  // here: a tank opens this, a barrel keeps it behind More details. Somebody
  // does occasionally jacket a barrel, and the form should not call them wrong.
  const glycol = checkbox("Glycol jacket");
  const mode = el("select", { class: "input" });
  mode.replaceChildren(
    el("option", { value: "off", text: "Off" }),
    el("option", { value: "cooling", text: "Cooling" }),
    el("option", { value: "heating", text: "Heating" }),
  );
  const modeField = el(
    "div",
    { class: "field" },
    el("span", { class: "field-label", text: "Jacket is" }),
    mode,
  );
  const setpoint = field({
    label: "Setpoint, C",
    type: "number",
    placeholder: "12",
    hint: "What the jacket is holding the wine at. Overrides the room.",
  });

  // Presentation only. The database refuses a mode without a jacket and a mode
  // without a setpoint, so hiding these is a courtesy rather than the guard.
  const thermal = el("div", {}, modeField, setpoint.root);
  function syncThermal(): void {
    thermal.hidden = !glycol.input.checked;
    if (!glycol.input.checked) {
      mode.value = "off";
    }
  }
  syncThermal();
  on(glycol.input, "change", syncThermal);

  // The jacket checkbox and its two dependent fields travel together, so they
  // move between open and More details as one thing.
  const glycolBlock = el("div", {}, glycol.root, thermal);

  // Two inputs, one of each, because one input cannot ask both questions.
  //
  // This used to be a single `accept="image/*"` with no `capture`, on the
  // reasoning that the phone would then offer its own chooser. It does not. On
  // Android the bare input opens the system photo picker directly and the
  // camera is behind an icon that is not obviously a way out of it, which the
  // winemaker hit from the other side: he wanted a photo of the tank in front
  // of him and got his gallery. The old comment's reasoning was right and its
  // conclusion was wrong, and both halves are kept here because the wrong turn
  // is the part worth not repeating: leaving `capture` off does not produce a
  // choice, it produces the library. Setting it produces the camera. A choice
  // is two controls.
  //
  // Which of them wrote the file last is the answer, so they share a variable
  // rather than being read in an order that would prefer one.
  let chosen: File | null = null;

  function photoInput(capture: string | null, label: string): HTMLElement {
    const input = el("input", {
      class: "visually-hidden",
      type: "file",
      accept: "image/*",
      ...(capture ? { capture } : {}),
    });
    const name = el("span", { class: "field-hint" });
    on(input, "change", () => {
      chosen = input.files?.[0] ?? null;
      name.textContent = chosen ? chosen.name : "";
      // The other input still holds whatever it took last. Clearing it keeps
      // the form honest about which single file is about to be uploaded.
      for (const other of [fromCamera, fromLibrary]) {
        if (other && other !== input) other.value = "";
      }
    });
    // A label wrapping a hidden input is the whole trick: tapping it opens the
    // right picker, it is reachable from the keyboard, and it needs no script.
    const trigger = el(
      "label",
      { class: "btn btn-secondary photo-trigger" },
      input,
      label,
    );
    return el("div", { class: "photo-choice" }, trigger, name);
  }

  // Declared before photoInput runs so the change handler above can reach both.
  let fromCamera: HTMLInputElement | null = null;
  let fromLibrary: HTMLInputElement | null = null;

  const cameraChoice = photoInput("environment", "Take photo");
  const libraryChoice = photoInput(null, "Choose photo");
  fromCamera = cameraChoice.querySelector("input");
  fromLibrary = libraryChoice.querySelector("input");

  const photoField = el(
    "div",
    { class: "field" },
    el("span", { class: "field-label", text: "Photo" }),
    el("div", { class: "photo-choices" }, cameraChoice, libraryChoice),
    el("span", {
      class: "field-hint",
      text:
        "Optional. Useful when the label falls off. Take one now, or pick one " +
        "already on the phone.",
    }),
  );

  on(capacity.input, "change", () => remember("capacity", capacity.value()));

  // W-9 phase 6. Which of these a given caller may write is the kernel's rule,
  // enforced by the cellar_writable_columns trigger, and the client asks rather
  // than remembering. Hardcoding the three would be R-4 and would drift the day
  // somebody edits the trigger; column privileges cannot answer it, because the
  // distinction between admin and cellar is a row in app_user and not a database
  // role, which is S-45.
  //
  // The pairing of a column to the control that writes it is unavoidably here,
  // because only this function knows which control that is. What is not here is
  // the list of which ones are allowed.
  const guarded: Array<{
    column: string;
    node: HTMLElement;
    label: string;
    show: () => string;
  }> = [
    {
      column: "type_id",
      node: type.root,
      label: "Type",
      show: () => type.label() || "not set",
    },
    {
      column: "name",
      node: name.root,
      label: "Name",
      show: () => name.value() || "not set",
    },
    {
      column: "capacity_l",
      node: capacity.root,
      label: "Capacity",
      show: () => (capacity.value() ? `${capacity.value()} L` : "not recorded"),
    },
    {
      column: "location_id",
      node: place.root,
      label: "Location",
      // Not place.label(): with no locations yet that is the placeholder option's
      // own text, "Nothing here yet, tap Add one", which is an instruction and
      // not a value. A display row has to say what is true, and the truth when
      // nothing is selected is that the vessel is unassigned.
      show: () => (place.value() ? place.label() || "unassigned" : "unassigned"),
    },
    {
      column: "owner_id",
      node: ownerField,
      label: "Whose vessel",
      show: () => owner.selectedOptions[0]?.text.trim() || "Facility owned",
    },
    {
      // A photo is stored in the bucket and remembered in attributes.photo_path,
      // so picking one is a write to a column a cellar hand may not write. Left
      // as an input it would upload the file, be refused on the row, and orphan
      // the object, which is B13 with B23 on top of it.
      column: "attributes",
      node: photoField,
      label: "Photo",
      show: () => "an administrator changes this",
    },
  ];

  // The attributes block is the one that matters and it is the one W-8 met: a
  // cellar hand changed a capacity and was refused with "may not change
  // vessel.attributes".
  //
  // It cannot be locked by container. `openSlot` and `moreSlot` hold the vessel
  // type's own fields **and** the glycol block, and glycol, setpoint and mode are
  // exactly the three columns a cellar hand may write. Replacing either container
  // would take away the only thing they are allowed to do, which is worse than
  // the defect it fixes. So this locks the built fields one at a time and leaves
  // the glycol block where it is.
  //
  // Re-applied from applyTypeShape, which rebuilds `built` from scratch on every
  // type change and would otherwise hand the controls back.
  let lockedColumns: Set<string> | null = null;
  function applyAttributeLock(): void {
    if (!lockedColumns || lockedColumns.has("attributes")) return;
    for (const b of built) {
      const shown = b.label() ?? b.read();
      b.root.replaceChildren(
        summaryRow(
          String(b.spec.label ?? b.spec.key),
          shown === null || shown === "" ? "not set" : String(shown),
        ),
      );
    }
  }

  const formNodes = [
    type.root,
    name.root,
    capacity.root,
    place.root,
    ownerField,
    openSlot,
    photoField,
    more,
  ];

  // Named rather than inline in the object below, because the draft writer and
  // the caller that saves have to read the same thing. Two readers of one form
  // that drifted apart would mean a draft restoring something the save would
  // not have written.
  function readValues() {
    return {
      type_id: type.value(),
      name: name.value(),
      capacity_l: capacity.value() ? Number(capacity.value()) : null,
      location_id: place.value() || null,
      owner_id: owner.value || null,
      has_glycol: glycol.input.checked,
      setpoint_c:
        glycol.input.checked && setpoint.value() ? Number(setpoint.value()) : null,
      mode: (glycol.input.checked ? mode.value : "off") as ThermalMode,
      // Keyed by descriptor. A term field also writes <key>_label so a page can
      // show what was picked without a second round trip, which is the one
      // place a derived value is stored on purpose: it is a caption, not a fact
      // anything computes from.
      attributes: Object.fromEntries(
        built.flatMap((b) => {
          const key = String(b.spec.key);
          const label = b.label();
          return label === null
            ? [[key, b.read()]]
            : [
                [key, b.read()],
                [`${key}_label`, label],
              ];
        }),
      ),
    };
  }

  // A draft has the same shape as a vessel row, so restoring one is the same
  // operation as opening an existing vessel. That is not a coincidence worth
  // hiding: readValues() returns a vessel minus its id, which is exactly what
  // preset() consumes.
  async function presetFrom(v: VesselRow): Promise<void> {
    const bag = (v.attributes ?? {}) as Record<string, unknown>;
    await type.reload(v.type_id ?? undefined);
    await Promise.all([
      place.reload(v.location_id ?? undefined),
      // Builds this type's fields and fills each from the stored bag.
      applyTypeShape(bag),
    ]);
    name.input.value = v.name ?? "";
    capacity.input.value = v.capacity_l == null ? "" : String(v.capacity_l);
    owner.value = v.owner_id ?? "";
    glycol.input.checked = v.has_glycol ?? false;
    mode.value = v.mode ?? "off";
    setpoint.input.value = v.setpoint_c == null ? "" : String(v.setpoint_c);
    syncThermal();
  }

  // --- the draft ----------------------------------------------------------

  let draftPlace: Place | null = null;
  let pending: number | null = null;

  function writeDraft(): void {
    if (!draftPlace) return;
    saveDraft(draftPlace, readValues());
  }

  // Typing is not a reason to touch storage on every keystroke. A quarter of a
  // second is below the point where the loss would matter and above the point
  // where a slow phone notices.
  function scheduleDraft(): void {
    if (pending !== null) window.clearTimeout(pending);
    pending = window.setTimeout(() => {
      pending = null;
      writeDraft();
    }, 250);
  }

  function flushDraft(): void {
    if (pending !== null) {
      window.clearTimeout(pending);
      pending = null;
    }
    writeDraft();
  }

  // Stops writing. Says nothing about whether the draft should still exist,
  // which is the caller's question and has two different answers.
  function detach(): void {
    if (pending !== null) {
      window.clearTimeout(pending);
      pending = null;
    }
    draftPlace = null;
    document.removeEventListener("visibilitychange", flushDraft);
    window.removeEventListener("pagehide", flushDraft);
  }

  return {
    nodes: formNodes,
    /**
     * Replace every control this caller may not write with the value it holds.
     * A cellar hand needs to read the capacity and the type to do the work, so
     * hiding them is wrong; offering them as inputs that cannot be saved is
     * worse, which is what W-8 found. Showing them is the third option.
     *
     * `null` means no restriction and is what an administrator gets.
     */
    lockTo: (writable) => {
      if (writable === null) {
        lockedColumns = null;
        return;
      }
      lockedColumns = new Set(writable);
      for (const g of guarded) {
        if (lockedColumns.has(g.column)) continue;
        g.node.replaceChildren(summaryRow(g.label, g.show()));
      }
      applyAttributeLock();
    },
    read: readValues,
    draftTo: async (place) => {
      draftPlace = place;
      // Delegated, because the optional fields do not exist until a type is
      // picked and a listener per control would have to be re-attached every
      // time the shape changes. An input event bubbles, so the containers are
      // enough and they outlive their contents.
      for (const node of formNodes) {
        node.addEventListener("input", scheduleDraft);
        node.addEventListener("change", scheduleDraft);
      }
      // The last reliable moment. Android fires this when it backgrounds the
      // tab and may never run another line of this program, so the debounce is
      // flushed here rather than trusted to fire.
      document.addEventListener("visibilitychange", flushDraft);
      window.addEventListener("pagehide", flushDraft);
      // Leaving is not saving. The draft stays; only the listening stops, so
      // that the form behind you is not still writing over the one in front.
      whenLeaving(detach);

      const draft = readDraft(place);
      if (!draft || typeof draft !== "object") return false;
      await presetFrom(draft as VesselRow);
      return true;
    },
    draftDone: () => {
      if (draftPlace) clearDraft(draftPlace);
      detach();
    },
    photoFile: () => chosen,
    ready: () => {
      if (!type.value()) return "Pick a vessel type, or add one.";
      if (!name.value()) return "A vessel needs a name.";
      // Says the same thing as vessel_mode_needs_setpoint, earlier and in
      // English. The constraint is still what enforces it.
      if (glycol.input.checked && mode.value !== "off" && !setpoint.value()) {
        return "A jacket that is cooling or heating needs a setpoint.";
      }
      // Says the same thing validate_vessel_attributes says, earlier. The
      // function is still what enforces it.
      const absent = built.find((b) => b.missing());
      if (absent) {
        return `${absent.spec.label ?? absent.spec.key} is needed for this vessel type.`;
      }
      return null;
    },
    reload: async () => {
      // Type first: every optional field's existence depends on it.
      await type.reload();
      await Promise.all([place.reload(), applyTypeShape()]);
    },
    preset: presetFrom,
  };
}

// --- custom crush clients --------------------------------------------------

// A client is a party, the same shape as the facility, which is what lets a lot
// you own and a lot they own be the same row with a different owner_id.
//
// The login link is the part that matters and the part that is easy to forget.
// node_read scopes a client to `owner_id = current_party_id()`, and
// current_party_id() resolves through party.app_user_id. Without the link a
// client party is only a label: their account, if they have one, sees the whole
// cellar like any other cellar user.
function clientsScreen(): HTMLElement {
  const message = el("div", {});
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Clients",
    lede(
      "Whose wine you are holding. A lot owned by a client is the same row as one " +
        "of yours, with their name on it.",
    ),
    body,
  );

  async function draw(): Promise<void> {
    try {
      const [partyRows, accounts] = await Promise.all([parties(), appUsers()]);
      const clients = partyRows.filter((p) => p.kind === "client");
      const taken = new Set(
        partyRows.map((p) => p.app_user_id).filter((id): id is string => !!id),
      );

      const name = field({
        label: "Add a client",
        placeholder: "Amica Luna",
        hint: "The legal entity whose wine it is.",
      });

      const unlinked = clients.filter((p) => !p.app_user_id);

      body.replaceChildren(
        rows(
          // Said here because this is the screen where the mistake is made. An
          // account with no party attached is staff, so the window between a
          // client signing up and being linked is a window in which they read
          // everybody's wine. See S-25.
          unlinked.length > 0
            ? banner(
                `${unlinked.length === 1 ? "One client has" : `${unlinked.length} clients have`} ` +
                  "no login attached. Until you attach one, any account they create is " +
                  "treated as staff and can see every lot in the cellar, including other " +
                  "clients'. Attaching the login is what limits them to their own wine.",
                "error",
              )
            : banner(
                "Every client has a login attached, so each sees only their own wine.",
                "good",
              ),
          clients.length === 0
            ? empty("No clients yet. Wine you hold for somebody else needs one.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...clients.map((p) => {
                  const link = el("select", { class: "input" });
                  link.replaceChildren(
                    el("option", { value: "", text: "No login yet" }),
                    ...accounts
                      // One login resolves to at most one party, so an account
                      // already spoken for is not offered twice.
                      .filter((a) => !taken.has(a.id) || a.id === p.app_user_id)
                      .map((a) =>
                        el("option", { value: a.id, text: `${a.name} (${a.role})` }),
                      ),
                  );
                  link.value = p.app_user_id ?? "";
                  on(link, "change", async () => {
                    try {
                      await setPartyLogin(p.id, link.value || null);
                      message.replaceChildren(
                        banner(
                          link.value
                            ? `${p.name} now sees only their own wine.`
                            : `${p.name} has no login attached.`,
                          "good",
                        ),
                      );
                      await draw();
                    } catch (error) {
                      message.replaceChildren(fail(error));
                    }
                  });

                  return el(
                    "li",
                    { class: "vessel-row" },
                    el("span", { class: "vessel-name", text: p.name }),
                    el("span", {
                      class: "vessel-detail",
                      text: p.app_user_id ? "has a login" : "no login",
                    }),
                    link,
                  );
                }),
              ),
          name.root,
          button("Add the client", async () => {
            if (!name.value()) return;
            try {
              await addParty(name.value(), "client");
              name.input.value = "";
              message.replaceChildren();
              await draw();
            } catch (error) {
              message.replaceChildren(fail(error));
            }
          }),
          button("Back", () => goBack(), "quiet"),
          message,
        ),
      );
    } catch (error) {
      body.replaceChildren(
        fail(error),
        button("Back", () => goBack(), "quiet"),
      );
    }
  }

  void draw();
  return view;
}

// --- how it looks ----------------------------------------------------------

// Every skin gets this for free, because a skin you cannot leave is a trap.
// The list comes from the registry rather than from here, so adding one is a
// row in skins.ts and a block of scoped CSS.
function skinPicker(): HTMLElement {
  const select = el("select", { class: "input" });
  const note = el("p", { class: "skin-note" });

  function describe(): void {
    note.textContent = skins.find((s) => s.name === select.value)?.note ?? "";
  }

  select.replaceChildren(
    ...skins.map((s) => el("option", { value: s.name, text: s.label })),
  );
  select.value = activeSkin();
  describe();

  on(select, "change", () => {
    applySkin(select.value);
    describe();
  });

  return el(
    "div",
    { class: "field skin-picker" },
    el("span", { class: "field-label", text: "Skin" }),
    select,
    note,
  );
}

// --- racking ---------------------------------------------------------------

// One screen, because the cellar has one operation. You say which vessels the
// wine came out of and which it went into, and the kernel decides whether that
// moved a lot or made a new one. The screen never works that out for itself; it
// asks rack_plan and repeats the answer.

type Leg = { vessel_id: string; volume_l: number };

// A list of vessels and how much came out of, or went into, each. Built the way
// codeCapture builds codes: pick, type, add, and the list is the record.
function legList(
  title: string,
  hint: string,
  choices: () => VesselState[],
  onChange: () => void,
): { root: HTMLElement; legs: () => Leg[]; refresh: () => void } {
  const collected: Leg[] = [];
  const list = el("ul", { class: "code-list" });
  const select = el("select", { class: "input" });
  const volume = field({ label: "Litres", type: "number", placeholder: "220" });
  const message = el("div", {});

  function refresh(): void {
    const rows = choices();
    select.replaceChildren(
      ...rows.map((v) =>
        el("option", {
          value: v.id,
          text: v.is_empty
            ? `${v.name} (${v.type}), empty`
            : `${v.name} (${v.type}), ${v.lot_name ?? "unnamed"} ${v.current_volume_l ?? "?"} L`,
        }),
      ),
    );
  }
  refresh();

  function draw(): void {
    list.replaceChildren(
      ...collected.map((leg, i) => {
        const v = choices().find((row) => row.id === leg.vessel_id);
        const row = el(
          "li",
          { class: "code-row" },
          el("span", { class: "code-value", text: v?.name ?? leg.vessel_id }),
          el("span", { class: "code-label", text: `${leg.volume_l} L` }),
        );
        row.append(
          button(
            "Remove",
            () => {
              collected.splice(i, 1);
              draw();
              onChange();
            },
            "quiet",
          ),
        );
        return row;
      }),
    );
  }

  return {
    root: el(
      "div",
      { class: "field" },
      el("span", { class: "field-label", text: title }),
      el("span", { class: "field-hint", text: hint }),
      select,
      volume.root,
      button(
        "Add",
        () => {
          const id = select.value;
          const litres = Number(volume.value());
          if (!id || !litres || litres <= 0) {
            message.replaceChildren(
              banner("Pick a vessel and say how many litres.", "error"),
            );
            return;
          }
          if (collected.some((leg) => leg.vessel_id === id)) {
            message.replaceChildren(
              banner("That vessel is already on this list.", "error"),
            );
            return;
          }
          collected.push({ vessel_id: id, volume_l: litres });
          volume.input.value = "";
          message.replaceChildren();
          draw();
          onChange();
        },
        "secondary",
      ),
      list,
      message,
    ),
    legs: () => collected.slice(),
    refresh,
  };
}

function rackScreen(): HTMLElement {
  const message = el("div", {});
  const holder = el("div", { class: "rows" });
  const preview = el("div", {});
  let kit: VesselState[] = [];
  let overfillOk = false;

  const view = screen(
    "Rack",
    lede(
      "Which vessels it came out of, and which it went into. Whether that moves a " +
        "lot or makes a new one is the database's answer, not a choice here.",
    ),
    holder,
  );

  void (async () => {
    kit = await vessels();

    const sources = legList(
      "Out of",
      "Vessels with wine in them.",
      () => kit.filter((v) => !v.is_empty),
      () => void refreshPlan(),
    );
    const destinations = legList(
      "Into",
      "Anything. Racking onto wine already in a vessel blends with it.",
      () => kit,
      () => void refreshPlan(),
    );

    const gasSource = termOrText("Gas in the source", "air, argon, nitrogen");
    const gasLine = termOrText("Gas in the line", "air, argon");
    const method = termOrText("Method", "gravity, pump");
    const lees = field({
      label: "Lees carried, litres",
      type: "number",
      placeholder: "0",
      hint: "Blank for a clean rack. Lees are recorded here and are not yet their own lot, see sorry S-23.",
    });

    async function refreshPlan(): Promise<void> {
      const s = sources.legs();
      const d = destinations.legs();
      if (s.length === 0 || d.length === 0) {
        preview.replaceChildren(
          empty("Add what came out and what went in, and this will say what it means."),
        );
        return;
      }
      try {
        const plan = await rackPlan(s, d);
        overfillOk = false;
        preview.replaceChildren(
          el(
            "div",
            { class: "summary" },
            summaryRow(
              "This is",
              plan.kind === "move"
                ? `a move: ${plan.parents[0]?.name ?? "one lot"} stays the same lot`
                : `a blend: a new lot from ${plan.parents.length}, and each of those shrinks`,
            ),
            summaryRow("Out", `${plan.out_l} L`),
            summaryRow("In", `${plan.in_l} L`),
            summaryRow("Loss", `${plan.loss_l} L`),
          ),
          ...(plan.mixed_owners
            ? [
                banner(
                  "These lots have different owners. Nothing stops you recording it, " +
                    "and the new lot is filed under the largest contributor. See sorry S-22.",
                  "note",
                ),
              ]
            : []),
          ...plan.overfill.map((o) =>
            banner(
              `${o.name} holds ${o.capacity_l} L and this would put ${o.would_hold} L in it.`,
              "error",
            ),
          ),
        );
        if (plan.overfill.length > 0) {
          const confirm = checkbox("Record it anyway");
          on(confirm.input, "change", () => {
            overfillOk = confirm.input.checked;
          });
          preview.append(confirm.root);
        }
      } catch (error) {
        preview.replaceChildren(fail(error));
      }
    }

    holder.append(
      sources.root,
      destinations.root,
      el("h2", { class: "section-head", text: "How" }),
      gasSource.root,
      gasLine.root,
      method.root,
      lees.root,
      el("h2", { class: "section-head", text: "What this does" }),
      preview,
      button("Rack it", async () => {
        const s = sources.legs();
        const d = destinations.legs();
        if (s.length === 0 || d.length === 0) {
          message.replaceChildren(
            banner("A rack needs a source and a destination.", "error"),
          );
          return;
        }
        try {
          const result = await rackTransfer({
            sources: s,
            destinations: d,
            allowOverfill: overfillOk,
            data: {
              gas_source: gasSource.value() || null,
              gas_line: gasLine.value() || null,
              method: method.value() || null,
              lees_l: lees.value() ? Number(lees.value()) : null,
            },
          });
          showResult(
            await resultScreen(
              d[0]?.vessel_id ?? "",
              result.node_id,
              0,
              result.kind === "move"
                ? `Moved. ${result.out_l} L out, ${result.in_l} L in, ${result.loss_l} L lost.`
                : `A new lot from ${result.parents.length}. ${result.out_l} L out, ` +
                    `${result.in_l} L in, ${result.loss_l} L lost.`,
            ),
            d[0]?.vessel_id ?? "",
          );
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button("Back", () => goBack(), "quiet"),
      message,
    );

    await refreshPlan();
  })();

  return view;
}

// Free text for now. Gas and method want vocabularies, and term_kind is an
// enum in the fixed tier, so adding two is a decision about that enum rather
// than a detail of this screen.
function termOrText(label: string, placeholder: string) {
  return field({ label, placeholder });
}

// --- vessel types: what each sort of vessel gets asked ---------------------

// C-6 killed configuration screens because they would be built "before anyone
// had discovered which fields they actually want to edit". The fields have now
// been discovered and named, so this exists. It is one screen for one kind of
// term rather than the general vocabulary editor C-6 refused.

function vesselTypeListScreen(user: AppUser): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Vessel types",
    lede(
      user.role === "admin"
        ? "What each sort of vessel gets asked when you create one."
        : "What each sort of vessel gets asked. Only an admin can change these, " +
            "but you can say what is missing and they will see it.",
    ),
    body,
  );

  void (async () => {
    try {
      const kinds = await terms("vessel_type");
      body.replaceChildren(
        rows(
          ...kinds.map((t) => {
            const bag = (t.attributes ?? {}) as Record<string, unknown>;
            const count = Array.isArray(bag.fields) ? bag.fields.length : 0;
            const row = el(
              "li",
              {
                class: "vessel-row vessel-row-tappable",
                role: "button",
                tabindex: "0",
              },
              el("span", { class: "vessel-name", text: t.label }),
              el("span", {
                class: "vessel-detail",
                text: `${count} extra ${count === 1 ? "field" : "fields"}`,
              }),
              el("span", {
                class: "vessel-edit-hint",
                text: user.role === "admin" ? "Edit" : "Suggest",
              }),
            );
            on(row, "click", () => go({ at: "vessel-type", id: t.id }));
            return row;
          }),
          button("Back", () => goBack(), "quiet"),
        ),
      );
    } catch (error) {
      body.replaceChildren(
        fail(error),
        button("Back", () => goBack(), "quiet"),
      );
    }
  })();

  return view;
}

function vesselTypeScreen(user: AppUser, type: Term): HTMLElement {
  const message = el("div", {});
  const body = el("div", {}, empty("Loading."));
  const noteList = el("div", {});
  const view = screen(type.label, body);
  const isAdmin = user.role === "admin";

  // A working copy. Nothing is written until Save, so a half-edited field list
  // never reaches the database and never reaches anyone else's form.
  const bag = (type.attributes ?? {}) as Record<string, unknown>;
  const fields = (
    Array.isArray(bag.fields) ? (bag.fields as Array<Record<string, unknown>>) : []
  ).map((f) => ({ ...f }));

  function fieldEditor(spec: Record<string, unknown>, index: number): HTMLElement {
    const label = field({ label: "Label", value: String(spec.label ?? "") });
    on(label.input, "input", () => {
      spec.label = label.value();
    });

    const kind = el("select", { class: "input" });
    kind.replaceChildren(
      el("option", { value: "text", text: "Text" }),
      el("option", { value: "number", text: "Number" }),
      el("option", { value: "term", text: "Pick from a list" }),
    );
    kind.value = String(spec.kind ?? "text");
    on(kind, "change", () => {
      spec.kind = kind.value;
      draw();
    });

    const open = checkbox("Open by default", spec.open === true);
    on(open.input, "change", () => {
      spec.open = open.input.checked;
    });
    const required = checkbox("Required", spec.required === true);
    on(required.input, "change", () => {
      spec.required = required.input.checked;
    });

    const extras: HTMLElement[] = [];
    if (spec.kind === "number") {
      const unit = field({
        label: "Unit",
        value: String(spec.unit ?? ""),
        hint: "Shown beside the box. Nothing converts it yet, see sorry S-20.",
      });
      on(unit.input, "input", () => {
        spec.unit = unit.value() || null;
      });
      const min = field({
        label: "Minimum",
        type: "number",
        value: spec.min == null ? "" : String(spec.min),
      });
      on(min.input, "input", () => {
        spec.min = min.value() === "" ? null : Number(min.value());
      });
      const max = field({
        label: "Maximum",
        type: "number",
        value: spec.max == null ? "" : String(spec.max),
      });
      on(max.input, "input", () => {
        spec.max = max.value() === "" ? null : Number(max.value());
      });
      extras.push(unit.root, min.root, max.root);
    }
    if (spec.kind === "term") {
      const vocab = field({
        label: "Vocabulary",
        value: String(spec.term_kind ?? ""),
        hint: "Which list this picks from, for example cooper or wood.",
      });
      on(vocab.input, "input", () => {
        spec.term_kind = vocab.value();
      });
      const contract = field({
        label: "Contract",
        value: String(spec.contract ?? ""),
        hint: "Optional. Narrows the list, the way manufacturer narrows makers.",
      });
      on(contract.input, "input", () => {
        spec.contract = contract.value() || null;
      });
      extras.push(vocab.root, contract.root);
    }

    return el(
      "div",
      { class: "add-inline" },
      el("span", { class: "field-label", text: String(spec.key) }),
      label.root,
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "Kind" }),
        kind,
      ),
      ...extras,
      open.root,
      required.root,
      button(
        "Remove this field",
        () => {
          fields.splice(index, 1);
          draw();
        },
        "quiet",
      ),
    );
  }

  function draw(): void {
    const parts: HTMLElement[] = [];

    if (isAdmin) {
      for (const [i, spec] of fields.entries()) parts.push(fieldEditor(spec, i));

      const newKey = field({
        label: "Add a field",
        placeholder: "oxygen ingress",
        hint: "The stored name is derived from this and never changes afterwards.",
      });
      parts.push(
        newKey.root,
        button(
          "Add it",
          () => {
            const key = slug(newKey.value());
            if (!key) return;
            if (fields.some((f) => f.key === key)) {
              message.replaceChildren(banner("That field already exists.", "error"));
              return;
            }
            fields.push({
              key,
              label: newKey.value(),
              kind: "text",
              open: true,
              sort_order: (fields.length + 1) * 10,
            });
            newKey.input.value = "";
            draw();
          },
          "secondary",
        ),
        button("Save", async () => {
          try {
            fields.forEach((f, i) => {
              f.sort_order = (i + 1) * 10;
            });
            await setVesselTypeFields(type.id, fields);
            message.replaceChildren(banner("Saved.", "good"));
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        }),
      );
    } else {
      parts.push(
        fields.length === 0
          ? empty("This type asks for nothing beyond the basics.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...fields.map((f) =>
                el(
                  "li",
                  { class: "vessel-row" },
                  el("span", {
                    class: "vessel-name",
                    text: String(f.label ?? f.key),
                  }),
                  el("span", { class: "vessel-detail", text: String(f.kind) }),
                ),
              ),
            ),
      );
    }

    // Present for everyone. An admin who spots a gap mid-walk also wants to
    // write it down rather than stop and rebuild the form standing up.
    const note = field({
      label: "Suggest a change",
      placeholder: "Tanks need somewhere to record oxygen ingress",
      hint: isAdmin
        ? "For later, or for whoever picks this up."
        : "An admin will see this. Nothing changes until they act on it.",
    });
    parts.push(
      note.root,
      button(
        "Leave the note",
        async () => {
          if (!note.value()) return;
          try {
            await addVesselTypeNote(type.id, note.value());
            note.input.value = "";
            message.replaceChildren(banner("Noted.", "good"));
            void loadNotes();
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        },
        "secondary",
      ),
      noteList,
      button("Back", () => goBack(), "quiet"),
      message,
    );

    body.replaceChildren(rows(...parts));
  }

  async function loadNotes(): Promise<void> {
    try {
      const notes = await vesselTypeNotes(type.id);
      const open = notes.filter((n) => !n.resolved_at);
      noteList.replaceChildren(
        open.length === 0
          ? empty("No open notes.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...open.map((n) => {
                const row = el(
                  "li",
                  { class: "vessel-row" },
                  el("span", { class: "vessel-name", text: n.body }),
                );
                if (isAdmin) {
                  row.append(
                    button(
                      "Done",
                      async () => {
                        await resolveVesselTypeNote(n.id);
                        void loadNotes();
                      },
                      "quiet",
                    ),
                  );
                }
                return row;
              }),
            ),
      );
    } catch (error) {
      noteList.replaceChildren(fail(error));
    }
  }

  draw();
  void loadNotes();
  return view;
}

// --- an empty vessel: fill it, or correct it ------------------------------

// Two things you might want and no way to guess which, so ask rather than
// bury one of them. Only appears for an empty vessel: a full one has no fill
// action until racking exists.
function vesselChoiceScreen(vesselId: string, vesselName: string): HTMLElement {
  return screen(
    vesselName,
    lede("This vessel is empty."),
    rows(
      button("Put wine in it", () => go({ at: "vessel-fill", id: vesselId })),
      button(
        "Edit the vessel",
        () => go({ at: "vessel-edit", id: vesselId }),
        "secondary",
      ),
      button("Back", () => goBack(), "quiet"),
    ),
  );
}

// --- editing a vessel that already exists ---------------------------------

// A vessel is not what it was on the day it was made. Barrels move rooms, a
// tank's jacket goes on in January, a capacity gets typed wrong. The screen is
// the create form with the current values in it, so there is one description of
// what a vessel is and not two that drift.
function vesselEditScreen(vesselId: string, title: string): HTMLElement {
  const message = el("div", {});
  const body = el("div", {}, empty("Loading."));
  const view = screen(`Edit ${title}`, body);

  void (async () => {
    try {
      const [partyRows, row, writable] = await Promise.all([
        parties(),
        vesselById(vesselId),
        writableColumns("vessel"),
      ]);
      const form = vesselFields(partyRows);
      await form.preset(row);
      // After preset, so a draft wins over what is saved: a draft only exists
      // because somebody typed over the saved values and did not get to save.
      const here: Place = { at: "vessel-edit", id: vesselId };
      const restored = await form.draftTo(here);
      // After both, so the locked fields show what is there rather than blanks.
      form.lockTo(scope?.may_admin ? null : writable);

      const note = el("div", {});
      if (restored) {
        note.replaceChildren(
          draftBanner(
            "Changes you had not saved are back in this form, over what is stored.",
            () => {
              form.draftDone();
              go(here);
            },
          ),
        );
      }

      body.replaceChildren(
        rows(
          note,
          ...form.nodes,
          button("Save changes", async () => {
            const problem = form.ready();
            if (problem) {
              message.replaceChildren(banner(problem, "error"));
              return;
            }
            try {
              const values = form.read();
              const file = form.photoFile();
              const attributes = { ...values.attributes };
              // Keep the photo already on the vessel unless a new one is picked.
              const existing = (row.attributes ?? {}) as Record<string, unknown>;
              attributes.photo_path = file
                ? await uploadVesselPhoto(vesselId, file)
                : (existing.photo_path ?? null);

              // B23. update_vessel treats a present key as "set this", so
              // sending the whole form makes every save a write to every column,
              // and the trigger refuses on whichever disallowed one it reaches
              // first. That is why W-8 changed a capacity and was told it may not
              // change vessel.attributes. Locking the controls is cosmetic on its
              // own; the patch has to carry only what this caller may write.
              const patch: Record<string, unknown> = { ...values, attributes };
              if (!scope?.may_admin) {
                for (const key of Object.keys(patch)) {
                  if (!writable.includes(key)) delete patch[key];
                }
              }

              const result = await updateVessel(vesselId, patch);
              message.replaceChildren(
                banner(
                  result.thermal_change
                    ? "Saved, and the thermal change was recorded as an event."
                    : "Saved.",
                  "good",
                ),
              );
              form.draftDone();
              goBack();
            } catch (error) {
              message.replaceChildren(fail(error));
            }
          }),
          button("Back", () => goBack(), "quiet"),
          message,
        ),
      );
    } catch (error) {
      body.replaceChildren(
        fail(error),
        button("Back", () => goBack(), "quiet"),
      );
    }
  })();

  return view;
}

// Says that what is in the form is typing that came back, not what is saved.
// Without this a restored draft and a loaded vessel are the same picture, which
// is the A13 shape in the one place a person is about to act on it.
function draftBanner(sentence: string, discard: () => void): HTMLElement {
  return el(
    "div",
    { class: "draft-note" },
    banner(`${sentence} Nothing has been written yet.`, "note"),
    button("Start again", discard, "quiet"),
  );
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
    const here: Place = { at: "vessel-new" };
    const restored = await form.draftTo(here);
    const note = el("div", {});
    if (restored) {
      note.replaceChildren(
        draftBanner("A vessel you had not saved is back in this form.", () => {
          form.draftDone();
          go(here);
        }),
      );
    }
    holder.append(
      note,
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
          form.draftDone();
          go(HOME);
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button(
        "Back",
        () => {
          capture.stop();
          goBack();
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

// --- what a lot is, shared by both screens that create one ----------------

// Extracted when the fill screen arrived. Two screens create a lot now, and a
// lot described twice is a lot described differently by next winter.
type WineForm = {
  nodes: HTMLElement[];
  volumeL: () => number | null;
  read: () => NodePayload;
  ready: () => string | null;
  reload: () => Promise<void>;
};

function wineFields(): WineForm {
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
  // Whose wine this is, which is a different question from whose vessel it is
  // in. A client's wine in our barrel is the ordinary custom crush case. The
  // kernel defaults to the facility, and node_read scopes a client's login by
  // exactly this column, so leaving it unasked meant a client could never see
  // their own wine.
  const owner = partyPicker({ label: "Whose wine is this", stickyKey: "lot_owner" });

  function autoName(): void {
    if (lotName.input.dataset.touched === "true") return;
    const parts = [variety.label(), vintage.value()].filter(Boolean);
    lotName.input.value = parts.join(" ");
  }

  on(vintage.input, "change", () => {
    remember("vintage", vintage.value());
    autoName();
  });
  on(lotName.input, "input", () => {
    lotName.input.dataset.touched = "true";
  });
  on(variety.root, "change", () => autoName());

  const volumeOf = () => (volume.value() ? Number(volume.value()) : null);

  return {
    nodes: [
      variety.root,
      vintage.root,
      productType.root,
      lotName.root,
      owner.root,
      volume.root,
    ],
    volumeL: volumeOf,
    read: () => ({
      id: newId(),
      stage: "maturation",
      name: lotName.value(),
      variety_id: variety.value() || null,
      vintage: vintage.value() ? Number(vintage.value()) : null,
      product_type_id: productType.value() || null,
      unit: "L",
      quantity: volumeOf(),
      // Empty means the facility, which is what the kernel coalesces to.
      owner_id: owner.value() || null,
    }),
    ready: () => (lotName.value() ? null : "The lot needs a name."),
    reload: async () => {
      await Promise.all([variety.reload(), productType.reload(), owner.reload()]);
      autoName();
    },
  };
}

// --- wine into a vessel that already exists -------------------------------

// The other half of build order 1. create_vessel_with_wine covers a vessel that
// does not exist yet; this covers the empty tank you registered last week and
// have now filled. Inventory only: it says wine is here, not where it came
// from, which is S-19.
function fillVesselScreen(vesselId: string, vesselName: string): HTMLElement {
  const message = el("div", {});
  const holder = el("div", { class: "rows" });

  const view = screen(
    `Put wine in ${vesselName}`,
    lede(
      "Records wine that is already in this vessel and that the app has not heard of " +
        "yet. If the wine is already a lot somewhere else, this is not the screen: " +
        "moving it is a rack, which closes one placement and opens another.",
    ),
    holder,
  );

  void (async () => {
    const wine = wineFields();
    await wine.reload();

    holder.append(
      ...wine.nodes,
      button("Put wine in it", async () => {
        const problem = wine.ready();
        if (problem) {
          message.replaceChildren(banner(problem, "error"));
          return;
        }
        try {
          const result = await fillVessel({
            vesselId,
            node: wine.read(),
            volumeL: wine.volumeL(),
          });
          showResult(
            await resultScreen(
              result.vessel_id,
              result.node_id,
              result.events_generated,
            ),
            result.vessel_id,
          );
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button("Back", () => goBack(), "quiet"),
      message,
    );
  })();

  return view;
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

    const wine = wineFields();

    await Promise.all([form.reload(), wine.reload()]);

    // The vessel half only. The wine half is S-48: a form gets a draft by
    // having a serialisable read, and wineFields does not have one yet.
    const here: Place = { at: "vessel-wine" };
    const restored = await form.draftTo(here);
    const note = el("div", {});
    if (restored) {
      note.replaceChildren(
        draftBanner("A vessel you had not saved is back in this form.", () => {
          form.draftDone();
          go(here);
        }),
      );
    }

    holder.append(
      note,
      el("h2", { class: "section-head", text: "The vessel" }),
      ...form.nodes,
      capture.root,
      el("h2", { class: "section-head", text: "The wine" }),
      ...wine.nodes,
      button("Create vessel and wine", async () => {
        const problem = form.ready() ?? wine.ready();
        if (problem) {
          message.replaceChildren(banner(problem, "error"));
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
            node: wine.read(),
            volumeL: wine.volumeL(),
            codes: capture.codes(),
          });
          capture.stop();
          form.draftDone();
          showResult(
            await resultScreen(
              result.vessel_id,
              result.node_id,
              result.events_generated,
            ),
            result.vessel_id,
          );
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }),
      button(
        "Back",
        () => {
          capture.stop();
          goBack();
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
  // Racking reuses this page and has nothing to do with variety templates, so
  // it says what it did instead of explaining a zero nobody asked about.
  note?: string,
): Promise<HTMLElement> {
  const kit = await vessels();
  const vessel = kit.find((v) => v.id === vesselId);

  // Ledger B20. Everything below reads `vessel?.` with a sensible fallback, and
  // seven sensible fallbacks compose into a complete, plausible, entirely
  // fabricated success page: "Saved. Vessel unknown, Lot unknown, Wine
  // unspecified, Volume unrecorded", over rows that are really in the database.
  // No single one of those expressions is wrong. The defect is the density.
  //
  // The read throwing is already handled by the caller. What was not handled is
  // the read succeeding and not containing the row, which happens when a policy
  // filters it, when the write went somewhere this session cannot see, or when
  // the response is empty for any reason at all. **That is an outcome and not a
  // rendering condition**, and the repair is to stop rendering rather than to
  // improve the fallbacks.
  if (!vessel) {
    return screen(
      "Saved, and this screen cannot show it",
      lede(
        "The write went through. Reading it back did not, so anything shown here " +
          "would be this page guessing rather than the cellar answering.",
      ),
      summaryRow("Vessel", vesselId),
      summaryRow("Lot", nodeId),
      banner(
        "Those two identifiers are the record. Nothing is lost, and the vessel " +
          "list will show it once the read works.",
        "note",
      ),
      button("Back to the cellar", () => go(HOME)),
    );
  }

  const events = await nodeHistory(nodeId);

  const photoPath = vessel.attributes?.photo_path;
  const photo = el("div", {});
  if (typeof photoPath === "string") {
    const url = await vesselPhotoUrl(photoPath);
    if (url) photo.append(el("img", { class: "photo", src: url, alt: "The vessel" }));
  }

  return screen(
    `${vessel.name} is on the books`,
    lede(
      note ??
        (generated === 0
          ? "No template exists for this variety yet, so no history was generated. That is " +
            "an honest zero rather than a failure: see sorry S-17."
          : `${generated} events generated from the variety template, every one marked inferred.`),
    ),
    photo,
    el(
      "div",
      { class: "summary" },
      summaryRow("Vessel", vessel ? `${vessel.name} (${vessel.type})` : "unknown"),
      summaryRow("Location", vessel.location_name ?? "unassigned"),
      summaryRow("Lot", vessel.lot_name ?? "unknown"),
      summaryRow(
        "Wine",
        [vessel.variety, vessel.vintage].filter(Boolean).join(" ") || "unspecified",
      ),
      summaryRow(
        "Volume",
        vessel.current_volume_l === null
          ? "unrecorded"
          : `${vessel.current_volume_l} L`,
      ),
      // Two independent facts. Our barrel holds a client's wine as often as
      // their barrel holds ours, and nothing in the schema ties the two
      // together because nothing in the cellar does either.
      //
      // The vessel's line appears when it differs from the wine's, which is
      // exactly when it carries information. Showing it only for a
      // client-owned vessel left our barrel full of their wine reading as
      // though the barrel were theirs too.
      summaryRow("Whose wine", vessel.lot_owner_name ?? "unrecorded"),
      ...(vessel && !sameOwner(vessel)
        ? [
            summaryRow(
              "Whose vessel",
              vessel.facility_owned ? "The facility" : (vessel.owner_name ?? "unknown"),
            ),
          ]
        : []),
      summaryRow("Codes", (vessel.codes ?? []).join(", ") || "none bound"),
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
              // Inherited events happened to this wine before it was this lot.
              // Saying so is the difference between a history and a claim.
              e.inherited
                ? el("span", { class: "tag tag-inherited", text: "before the split" })
                : null,
            ),
          ),
        ),
    rows(
      button("Add another", () => go({ at: "vessel-wine" })),
      button("Back to the cellar", () => go(HOME), "secondary"),
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
                  // B11, the other one. A volume of zero is a real reading and
                  // an emptied vessel is a real state; only null means nobody
                  // wrote it down.
                  vessel.current_volume_l === null
                    ? "unrecorded"
                    : `${vessel.current_volume_l} L`,
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
        goBack();
      },
      "quiet",
    ),
  );
}
