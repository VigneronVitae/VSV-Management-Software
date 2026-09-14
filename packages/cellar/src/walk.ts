import {
  type AppUser,
  type Attachment,
  addBinsToPick,
  addBlock,
  addDayNote,
  addLocation,
  addPaperRecord,
  addParty,
  addPhoto,
  addPlanting,
  addShoppingItem,
  addSupply,
  addVessel,
  addVesselTypeNote,
  addVineyard,
  appUsers,
  attachmentsFor,
  type Block,
  bindCode,
  binsToReturn,
  blocks,
  cancelPick,
  captionPhoto,
  claimAccount,
  countSupply,
  createVesselWithWine,
  currentAppUser,
  currentSession,
  type DayNote,
  dayLog,
  dayNotes,
  exportCellar,
  facilityParty,
  fillVessel,
  locations,
  markBought,
  markPropagated,
  moveSupply,
  type NodePayload,
  newId,
  nodeHistory,
  openPicks,
  type PaperRecord,
  type Party,
  type PastWeighing,
  type PlantingDetail,
  paperRecordOperations,
  paperRecords,
  parties,
  photoUrl,
  pickById,
  pickWeighings,
  plantings,
  press,
  rackPlan,
  rackTransfer,
  removeDayNote,
  removePick,
  removePlanting,
  resolveCode,
  resolveVesselTypeNote,
  retirePaperRecord,
  type SiteFields,
  type SupplyOnHand,
  setMakerMakes,
  setPaperRecordOperations,
  setPartyLogin,
  setVesselTypeBin,
  setVesselTypeFields,
  shoppingList,
  signIn,
  signOut,
  signUp,
  slug,
  suppliesBelowLevel,
  suppliesOnHand,
  type Term,
  type TermKind,
  type ThermalMode,
  type ToPropagate,
  terms,
  termsForVesselField,
  toPropagate,
  type UnweighedBin,
  unweighedBins,
  updateBlock,
  updatePlanting,
  updateVessel,
  uploadPhoto,
  uploadVesselPhoto,
  type VesselRow,
  type VesselState,
  type ViewerScope,
  type Vineyard,
  vesselById,
  vesselByIdOrNull,
  vesselPhotoUrl,
  vessels,
  vesselTypeNotes,
  viewerScope,
  vineyards,
  weighBins,
  weighingsWithoutPhoto,
  writableColumns,
} from "core";
import {
  installBlockedBecause,
  isInstalled,
  onInstallChanged,
  promptInstall,
} from "./install.ts";
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

// Where the last paint was, as a place. Held so the shell can decide whether a
// way home makes sense without every screen having to say so. Null on the gate
// screens, which are not places: there is no cellar to go back to from the sign
// in screen.
let atPlace: Place | null = null;

// One control, in the shell rather than on twenty screens. Three screens deep in
// a pick, home used to be three taps of Back, and Back is the wrong instrument
// for "I am done with this": it retraces where you came from rather than taking
// you where you are going.
//
// Sticky, because the screen it is most needed on is the long one you have
// scrolled down.
function homeBar(): HTMLElement | null {
  if (!atPlace || atPlace.at === "home") return null;
  return el(
    "div",
    { class: "topbar" },
    button("Home", () => go(HOME), "quiet"),
  );
}

function show(node: HTMLElement): void {
  const done = leaving;
  leaving = [];
  for (const fn of done) fn();
  const bar = homeBar();
  if (bar) root.replaceChildren(bar, node);
  else root.replaceChildren(node);
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
    case "intake":
      return intakeScreen();
    case "pick-new":
      return newPickScreen();
    case "pick-bins":
      return pickBinsScreen(place.id);
    case "scale":
      return scaleScreen();
    case "press":
      return pressScreen();
    case "bins-to-return":
      return binsToReturnScreen();
    case "export":
      return exportScreen();
    case "vineyards":
      return vineyardsScreen();
    case "makers":
      return makersScreen();
    case "stores":
      return storesScreen();
    case "day":
      return dayScreen(place.id);
    case "paper":
      return paperScreen();
    case "block": {
      const there = (await blocks()).some((b) => b.id === place.id);
      if (!there) throw new GoneError("That block is not there to open.");
      return blockScreen(place.id);
    }
    // Checked before opening, the same as every other place carrying an id: a
    // link to the photographs of a pick somebody cancelled should say so rather
    // than offering to attach a photograph to nothing.
    case "pick-photos": {
      // `pickById` rather than `openPicks`, because a pick that has been pressed
      // is closed and its photographs are still worth attaching the week after.
      const pick = await pickById(place.id);
      if (!pick) throw new GoneError("That pick is not there to open.");
      return photosScreen("node", place.id);
    }
    case "vessel-photos": {
      const vessel = await vesselByIdOrNull(place.id);
      if (!vessel) throw new GoneError("That vessel is not there to open.");
      return photosScreen("vessel", place.id);
    }
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
    atPlace = place;
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
      atPlace = HOME;
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
  atPlace = vesselId ? { at: "vessel", id: vesselId } : HOME;
  window.history.replaceState(null, "", encode(atPlace));
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
    // Cleared before the gates, so a sign out does not leave a way home on a
    // screen that has no cellar behind it.
    atPlace = null;
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
  const [places, kit, unweighed, owedBins, owedPaper, buying] = await Promise.all([
    locations(),
    vessels(),
    unweighedBins(),
    binsToReturn(),
    toPropagate(),
    shoppingList(),
  ]);
  const filled = kit.filter((v) => !v.is_empty).length;
  // On the home screen on purpose. T1-4 allows a bin to exist with no weight,
  // which is only safe if the count of them is somewhere nobody has to go
  // looking for it.
  const waiting = unweighed.length;
  const owed = owedBins.length;
  // On the home screen for the same reason the unweighed bin count is: a list
  // that must be empty only works if nobody has to go looking for it.
  const owedToPaper = owedPaper.length;
  const toBuy = buying.length;

  return screen(
    facility.name,
    lede(`${user.name}, ${user.role}. What would you like to do?`),
    el("h2", { class: "section-head", text: "Harvest" }),
    menu([
      {
        name: "The day",
        note: "What happened today, and anything worth writing down about it.",
        go: () => go({ at: "day" }),
      },
      {
        name: "Stores",
        note: "What is on the shelf, and what to buy.",
        ...(toBuy > 0 ? { badge: String(toBuy) } : {}),
        go: () => go({ at: "stores" }),
      },
      {
        name: "On paper",
        note: "Measurements that also have to go on a physical form, and have not yet.",
        ...(owedToPaper > 0 ? { badge: String(owedToPaper) } : {}),
        go: () => go({ at: "paper" }),
      },
      {
        name: "Picking",
        note:
          "Record bins as they are filled. The weight comes later, and until it " +
          "does the bin says so.",
        ...(waiting > 0 ? { badge: `${waiting} to weigh` } : {}),
        go: () => go({ at: "intake" }),
      },
      {
        name: "Weigh bins",
        note: "What the scale said, with the bins' own weight taken off.",
        go: () => go({ at: "scale" }),
      },
      {
        name: "Press",
        note: "Fruit in, juice out. Where the lot gets the name it keeps.",
        go: () => go({ at: "press" }),
      },
      {
        name: "Bins to return",
        note: "Borrowed bins that are empty. Owed back rather than available.",
        ...(owed > 0 ? { badge: String(owed) } : {}),
        go: () => go({ at: "bins-to-return" }),
      },
    ]),
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
        name: "Vessel makers",
        note: "One list, flagged for what each of them builds. Somebody who makes both is entered once.",
        go: () => go({ at: "makers" }),
      },
      {
        name: "Vineyards",
        note: "Where fruit comes from. Blocks, and what is planted in them.",
        go: () => go({ at: "vineyards" }),
      },
      {
        name: "Clients",
        note: "Custom crush clients, and which login sees their wine.",
        go: () => go({ at: "clients" }),
      },
      {
        name: "Take a copy",
        note:
          "Everything you can read, as one file on your phone. The cellar lives " +
          "on one machine, so a copy elsewhere is what makes it survivable.",
        go: () => go({ at: "export" }),
      },
    ]),
    el("h2", { class: "section-head", text: "Not built yet" }),
    menu([
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
    installBlock(),
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

// Putting the app on the phone properly, without the three tap hunt through
// Chrome's menu that was the honest answer before this existed.
//
// The button is present whenever the app is not already installed, even when
// the browser has not offered. A control that appears only sometimes is
// indistinguishable from one that is broken, and the case where the offer never
// comes is exactly the case somebody needs telling about.
function installBlock(): HTMLElement {
  const holder = el("div", {});
  if (isInstalled()) return holder;

  const said = el("div", {});

  function draw(): void {
    if (isInstalled()) {
      holder.replaceChildren();
      return;
    }
    holder.replaceChildren(
      el("h2", { class: "section-head", text: "This phone" }),
      button(
        "Install the app",
        async () => {
          const outcome = await promptInstall();
          if (outcome === "accepted") {
            said.replaceChildren(
              banner(
                "Installed. Open it from the new icon rather than from Chrome: " +
                  "an installed app gets its own slot in the task switcher and is " +
                  "far less likely to be thrown away while you are taking a photo.",
                "good",
              ),
            );
            return;
          }
          if (outcome === "dismissed") {
            said.replaceChildren(
              banner("Left it as it was. The button stays here.", "note"),
            );
            return;
          }
          // No offer from the browser. Which is a different sentence depending
          // on whose fault it is, and the app knows: a worker that failed to
          // register is this app's problem and saying "your browser did not
          // offer" would be blaming the phone for it.
          const blocked = installBlockedBecause();
          said.replaceChildren(
            banner(
              blocked
                ? `The app cannot be installed yet because its service worker did not load: ${blocked}`
                : "This browser has not offered to install it. In Chrome the same " +
                    "thing lives under the three dot menu, as Install app or Add to " +
                    "Home screen. On an iPhone it is Share, then Add to Home Screen.",
              "note",
            ),
          );
        },
        "secondary",
      ),
      said,
    );
  }

  draw();
  onInstallChanged(draw);
  return holder;
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

// Two inputs, one of each, because one input cannot ask both questions.
//
// This used to live inside vesselFields, which is why for two days the only
// place in the app that could take a photograph was the vessel form: the scale
// screen had no way to ask for one, and three photographs of a scale ended up
// stuck on a phone. It is here now because a photograph is wanted in several
// places and a control that exists in one is a control that exists nowhere.
//
// Which of the two inputs wrote the file last is the answer, so they share a
// variable rather than being read in an order that would prefer one.
type PhotoPicker = {
  root: HTMLElement;
  file: () => File | null;
  clear: () => void;
};

function photoPicker(hint: string): PhotoPicker {
  let chosen: File | null = null;
  let fromCamera: HTMLInputElement | null = null;
  let fromLibrary: HTMLInputElement | null = null;
  const names: HTMLElement[] = [];

  function oneInput(capture: string | null, label: string): HTMLElement {
    const input = el("input", {
      class: "visually-hidden",
      type: "file",
      accept: "image/*",
      ...(capture ? { capture } : {}),
    });
    const name = el("span", { class: "field-hint" });
    names.push(name);
    on(input, "change", () => {
      chosen = input.files?.[0] ?? null;
      for (const n of names) n.textContent = "";
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

  // `capture` is what separates them. Leaving it off does not produce a choice,
  // it produces the library: on Android the bare input opens the system photo
  // picker and the camera is behind an icon that is not obviously a way out of
  // it. The winemaker hit that from the other side, wanting a photo of the tank
  // in front of him and getting his gallery. A choice is two controls.
  const cameraChoice = oneInput("environment", "Take photo");
  const libraryChoice = oneInput(null, "Choose photo");
  fromCamera = cameraChoice.querySelector("input");
  fromLibrary = libraryChoice.querySelector("input");

  return {
    root: el(
      "div",
      { class: "field" },
      el("span", { class: "field-label", text: "Photo" }),
      el("div", { class: "photo-choices" }, cameraChoice, libraryChoice),
      el("span", { class: "field-hint", text: hint }),
    ),
    file: () => chosen,
    clear: () => {
      chosen = null;
      for (const n of names) n.textContent = "";
      for (const i of [fromCamera, fromLibrary]) if (i) i.value = "";
    },
  };
}

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

    // A yes or a no. 0033 added the kind because "Borrowed, goes back" is a
    // checkbox, and a text field holding the word yes would be the wrong control
    // and the wrong data.
    if (spec.kind === "boolean") {
      const box = checkbox(labelText, false);
      return {
        spec,
        root: box.root,
        read: () => box.input.checked,
        label: () => null,
        set: async (value) => {
          box.input.checked = value === true;
        },
        // A required checkbox means the box has to be ticked, which is a
        // consent, not a field. Nothing declares one and this says what would
        // happen if something did.
        missing: () => required && !box.input.checked,
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

  const photo = photoPicker(
    "Optional. Useful when the label falls off. Take one now, or pick one " +
      "already on the phone. A vessel holds as many as you take: open it to " +
      "add more.",
  );
  const photoField = photo.root;

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
    photoFile: () => photo.file(),
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
      el("option", { value: "boolean", text: "Yes or no" }),
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

  // Whether this type is weighed at intake, and what one weighs empty. Both are
  // facts about the type rather than fields on each vessel, so they sit above
  // the field list rather than in it. See 0033.
  function binEditor(): HTMLElement {
    const isBin = checkbox(
      "Fruit is weighed in this at intake",
      bag.intake_bin === true,
    );
    const tare = field({
      label: "Tare, lbs",
      type: "number",
      value: bag.tare_lbs == null ? "" : String(bag.tare_lbs),
      hint:
        "What one weighs empty. The scale subtracts it once per bin. Nothing is " +
        "assumed if this is blank: weighing refuses and says so, because a tare " +
        "of zero would make every pick read heavy by the weight of its own bins.",
    });
    const tareBox = el("div", {}, tare.root);
    const sync = () => {
      tareBox.hidden = !isBin.input.checked;
    };
    sync();
    on(isBin.input, "change", sync);

    return el(
      "div",
      { class: "rows" },
      el("h2", { class: "section-head", text: "At intake" }),
      isBin.root,
      tareBox,
      button(
        "Save intake settings",
        async () => {
          try {
            const raw = tare.value();
            await setVesselTypeBin(type.id, {
              intakeBin: isBin.input.checked,
              tareLbs: isBin.input.checked && raw ? Number(raw) : null,
            });
            bag.intake_bin = isBin.input.checked ? true : undefined;
            bag.tare_lbs = raw ? Number(raw) : undefined;
            message.replaceChildren(
              banner(
                isBin.input.checked && !raw
                  ? "Saved. No tare yet, so weighing this type will refuse until one is set."
                  : "Saved.",
                isBin.input.checked && !raw ? "note" : "good",
              ),
            );
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        },
        "secondary",
      ),
    );
  }

  function draw(): void {
    const parts: HTMLElement[] = [];

    if (isAdmin) {
      parts.push(binEditor());
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
      button(
        "Photographs",
        () => go({ at: "vessel-photos", id: vesselId }),
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

// --- intake ----------------------------------------------------------------

// Build order 2 in spec.md §7, and the one screen where a missed record cannot
// be reconstructed afterwards. Everything here is arranged around T1-4: intake
// must be fast before it is complete, so a bin is recorded in one tap with no
// weight, and the weight is a separate act at the scale.

// A pick that has been described and has no bins yet. Held here rather than in
// the URL because it is not a thing until its first bin is recorded, and a place
// is resolved by asking the kernel, which would have nothing to answer with.
let pendingPick: {
  id: string;
  block_id: string | null;
  variety_id: string | null;
  vintage: number | null;
} | null = null;
// The block a pick came from, with a way to add one without leaving the screen.
// S-51: block carries an admin-write policy, so a cellar hand gets a refusal
// here rather than a row, and the refusal says what it is.
//
// A block now belongs to a vineyard rather than carrying its name as text, so
// adding one means naming the vineyard first. Both are one field and the
// vineyard is remembered, which is the point of 0039: "Pearlstaad" is typed
// once for the season rather than once per block.
function blockField(): {
  root: HTMLElement;
  value: () => string;
  reload: (selected?: string) => Promise<void>;
} {
  const select = el("select", { class: "input" });
  const message = el("div", {});
  const vineyardPick = el("select", { class: "input" });
  const newVineyard = field({
    label: "Or a vineyard not listed",
    placeholder: "Pearlstaad",
  });
  const name = field({ label: "Block", placeholder: "Southeast" });
  let known: Vineyard[] = [];

  async function load(selected?: string): Promise<void> {
    const [blockRows, vineRows] = await Promise.all([blocks(), vineyards()]);
    known = vineRows;
    const named = new Map(vineRows.map((v) => [v.id, v.name]));
    select.replaceChildren(
      el("option", { value: "", text: "Pick a block" }),
      ...blockRows.map((b) =>
        el("option", {
          value: b.id,
          text: b.vineyard_id ? `${named.get(b.vineyard_id) ?? "?"} ${b.name}` : b.name,
        }),
      ),
    );
    vineyardPick.replaceChildren(
      el("option", { value: "", text: "Pick a vineyard" }),
      ...vineRows.map((v) => el("option", { value: v.id, text: v.name })),
    );
    if (selected) select.value = selected;
  }

  const adder = el(
    "details",
    { class: "more" },
    el("summary", { text: "Add a block" }),
    rows(
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "Vineyard" }),
        vineyardPick,
      ),
      newVineyard.root,
      name.root,
      button(
        "Add it",
        async () => {
          const typed = newVineyard.value().trim();
          if (!vineyardPick.value && !typed) {
            message.replaceChildren(
              banner("Which vineyard is this block in?", "error"),
            );
            return;
          }
          if (!name.value()) {
            message.replaceChildren(banner("The block needs a name.", "error"));
            return;
          }
          try {
            let vineyardId = vineyardPick.value;
            if (!vineyardId) {
              // Matched case-insensitively against what is already there, so a
              // second spelling does not become a second vineyard. That is the
              // whole reason a vineyard stopped being a string.
              const already = known.find(
                (v) => v.name.toLowerCase() === typed.toLowerCase(),
              );
              if (already) {
                vineyardId = already.id;
              } else {
                vineyardId = newId();
                await addVineyard({ id: vineyardId, name: typed });
              }
            }
            const blockId = newId();
            await addBlock({
              id: blockId,
              vineyard_id: vineyardId,
              name: name.value(),
            });
            await load(blockId);
            newVineyard.input.value = "";
            name.input.value = "";
            message.replaceChildren(
              banner(
                "Added. What is planted in it goes on the vineyard screen.",
                "good",
              ),
            );
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        },
        "secondary",
      ),
      message,
    ),
  );

  return {
    root: el(
      "div",
      { class: "field" },
      el("span", { class: "field-label", text: "Block" }),
      select,
      adder,
    ),
    value: () => select.value,
    reload: load,
  };
}

// The list of picks with fruit still in bins. A pick with unweighed bins says so
// on its row, because that is the number somebody checks at the end of a day.
function intakeScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Picking",
    lede(
      "Record a bin as it is filled. The weight comes later, at the scale, and " +
        "until then the bin shows up as waiting for one.",
    ),
    body,
  );

  void (async () => {
    try {
      const [picks, waiting, unphotographed] = await Promise.all([
        openPicks(),
        unweighedBins(),
        weighingsWithoutPhoto(),
      ]);
      const waitingBy = new Map<string, number>();
      for (const b of waiting) {
        waitingBy.set(b.node_id, (waitingBy.get(b.node_id) ?? 0) + 1);
      }
      // Grouped by pick, because the screen that takes the photographs is the
      // pick's, and because "three readings on the Pinot Gris" is what somebody
      // holding three photographs actually has.
      const unphotographedBy = new Map<string, { name: string; n: number }>();
      for (const w of unphotographed) {
        const seen = unphotographedBy.get(w.node_id);
        unphotographedBy.set(w.node_id, {
          name: w.pick_name,
          n: (seen?.n ?? 0) + 1,
        });
      }

      body.replaceChildren(
        rows(
          button("Start a pick", () => go({ at: "pick-new" })),
          waiting.length > 0
            ? button(
                `Weigh bins (${waiting.length} waiting)`,
                () => go({ at: "scale" }),
                "secondary",
              )
            : empty("Nothing is waiting to be weighed."),

          // Not a work queue, and deliberately not styled as one. A bin with no
          // weight is unfinished work; a weighing with no photograph is merely
          // one whose number cannot be checked against anything. It is here
          // because three photographs of a scale sat on a phone for a day with
          // nowhere to go, and a list is how somebody finds the reading each of
          // them belongs to.
          ...(unphotographedBy.size === 0
            ? []
            : [
                el("h2", { class: "section-head", text: "Photographs not attached" }),
                el("p", {
                  class: "lede",
                  text:
                    "These weights have no photograph of the scale behind them. " +
                    "Not a problem, just weaker evidence. If you took one, it can go on now.",
                }),
                el(
                  "ul",
                  { class: "vessel-list" },
                  ...[...unphotographedBy.entries()].map(([id, { name, n }]) => {
                    const row = el(
                      "li",
                      { class: "vessel-row", role: "button", tabindex: "0" },
                      el("span", { class: "vessel-name", text: name }),
                      el("span", {
                        class: "vessel-detail",
                        text: `${n} reading${n === 1 ? "" : "s"}`,
                      }),
                    );
                    const openRow = () => go({ at: "pick-photos", id });
                    on(row, "click", openRow);
                    on(row, "keydown", (ev) => {
                      if (ev.key === "Enter" || ev.key === " ") {
                        ev.preventDefault();
                        openRow();
                      }
                    });
                    return row;
                  }),
                ),
              ]),

          el("h2", { class: "section-head", text: "Open picks" }),
          picks.length === 0
            ? empty("No fruit in bins right now.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...picks.map((p) => {
                  const unweighed = waitingBy.get(p.id) ?? 0;
                  const row = el(
                    "li",
                    { class: "vessel-row", role: "button", tabindex: "0" },
                    el("span", { class: "vessel-name", text: p.name }),
                    el("span", {
                      class: "vessel-detail",
                      // B11's lesson. Zero is a number and null is the absence
                      // of one, and they must not render the same: a pick with
                      // no weight yet has not been weighed, it does not weigh 0.
                      text:
                        p.quantity === null
                          ? "not weighed yet"
                          : `${Number(p.quantity).toLocaleString()} lbs`,
                    }),
                    unweighed > 0
                      ? el("span", {
                          class: "tag tag-inherited",
                          text: `${unweighed} unweighed`,
                        })
                      : null,
                  );
                  const openRow = () => go({ at: "pick-bins", id: p.id });
                  on(row, "click", openRow);
                  on(row, "keydown", (ev) => {
                    if (ev.key === "Enter" || ev.key === " ") {
                      ev.preventDefault();
                      openRow();
                    }
                  });
                  return row;
                }),
              ),
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

// Starting a pick is saying what the fruit is. No bin is recorded here: the
// first bin creates the pick, so a pick with nothing in it never exists.
function newPickScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Start a pick",
    lede("What is being picked. Bins go on next, one tap each."),
    body,
  );

  void (async () => {
    try {
      const block = blockField();
      const variety = termPicker("variety", { label: "Variety", stickyKey: "variety" });
      const vintage = field({
        label: "Vintage",
        type: "number",
        value: String(new Date().getFullYear()),
      });
      await Promise.all([block.reload(), variety.reload()]);

      body.replaceChildren(
        rows(
          block.root,
          variety.root,
          vintage.root,
          button("Next, add bins", () => {
            if (!variety.value()) {
              message.replaceChildren(banner("Pick a variety.", "error"));
              return;
            }
            // The pick's id is made here, before anything is written, so the
            // bin screen can add to it and a repeated call finds the same pick
            // rather than making a second one.
            pendingPick = {
              id: newId(),
              block_id: block.value() || null,
              variety_id: variety.value(),
              vintage: vintage.value() ? Number(vintage.value()) : null,
            };
            go({ at: "pick-bins" });
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

// The tapping screen. One control, pressed once per bin, with the fill estimate
// pre-set to full because most bins are full and the exceptions are the ones
// worth a second of attention.
function pickBinsScreen(openOn?: string): HTMLElement {
  let nodeId = openOn;
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const tally = el("div", {});
  const view = screen("Add bins", body);

  void (async () => {
    try {
      const [kit, types, blockRows, vineRows] = await Promise.all([
        vessels(),
        terms("vessel_type"),
        blocks(),
        vineyards(),
      ]);
      const binTypes = types.filter((t) => t.attributes?.intake_bin === true);

      if (binTypes.length === 0) {
        body.replaceChildren(
          banner(
            "No vessel type is marked as weighed at intake, so there are no " +
              "picking bins to fill. An administrator sets that on the vessel type.",
            "note",
          ),
          button("Back", () => goBack(), "quiet"),
        );
        return;
      }

      const binTypeIds = new Set(binTypes.map((t) => t.id));
      const free = kit.filter((v) => binTypeIds.has(v.type_id) && v.is_empty);

      const fill = field({
        label: "How full, percent",
        type: "number",
        value: "100",
        hint: "By eye. A bin weighed on its own later turns this into a real number.",
      });
      const fillPct = (): number | null => {
        const raw = fill.value();
        return raw ? Number(raw) : null;
      };

      async function refreshTally(id: string): Promise<void> {
        const waiting = await unweighedBins(id);
        tally.replaceChildren(
          el("p", {
            class: "lede",
            text:
              waiting.length === 0
                ? "Every bin on this pick has been weighed."
                : `${waiting.length} bin${waiting.length === 1 ? "" : "s"} waiting for the scale: ` +
                  waiting.map((w) => w.bin_name).join(", "),
          }),
        );
      }

      // The pick's description travels with the first bin that joins it, and by
      // id after that, so a second call does not make a second pick.
      function pickPayload(): Record<string, unknown> | null {
        if (nodeId) return { id: nodeId };
        return pendingPick ? { ...pendingPick } : null;
      }

      async function landed(result: { node_id: string; bins: number }, said: string) {
        pendingPick = null;
        nodeId = result.node_id;
        await refreshTally(result.node_id);
        message.replaceChildren(
          banner(
            `${said} ${result.bins} bin${result.bins === 1 ? "" : "s"} on this pick.`,
            "good",
          ),
        );
        // The pick has an id worth resuming on now, which it did not have when
        // this screen opened.
        window.history.replaceState(
          null,
          "",
          encode({ at: "pick-bins", id: result.node_id }),
        );
        // There is something to cancel now, which there was not a moment ago.
        drawCancel();
      }

      // --- bins that already exist -----------------------------------------

      // Checkboxes rather than one picker, because bins arrive by the stack. The
      // winemaker registered three and added them one at a time, which is six
      // actions for one decision.
      const existing = free.map((v) => ({
        vessel: v,
        box: checkbox(`${v.name} (${v.type})`, false),
      }));
      const existingBlock = el("div", { class: "rows" });
      const addExisting = button("Add ticked bins", () => void attachTicked());

      function drawExisting(): void {
        const left = existing.filter((e) => !e.box.input.disabled);
        existingBlock.replaceChildren(
          el("h2", { class: "section-head", text: "Bins you already have" }),
          left.length === 0
            ? empty("Every picking bin already holds fruit.")
            : el("div", { class: "rows" }, ...left.map((e) => e.box.root)),
        );
        addExisting.disabled = left.length === 0;
      }

      async function attachTicked(): Promise<void> {
        const chosen = existing
          .filter((e) => e.box.input.checked && !e.box.input.disabled)
          .map((e) => e.vessel.id);
        if (chosen.length === 0) {
          message.replaceChildren(
            banner("Tick the bins that have fruit in them.", "error"),
          );
          return;
        }
        const pick = pickPayload();
        if (!pick) {
          message.replaceChildren(
            banner("Start a pick first, so the bins have something to join.", "error"),
          );
          return;
        }
        try {
          const result = await addBinsToPick({
            pick,
            vesselIds: chosen,
            fillPct: fillPct(),
          });
          for (const e of existing) {
            if (chosen.includes(e.vessel.id)) {
              e.box.input.checked = false;
              e.box.input.disabled = true;
            }
          }
          drawExisting();
          await landed(result, "Added.");
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      }

      drawExisting();

      // --- bins that do not exist yet --------------------------------------

      // Three empty bins and three bins of fruit in one action. The naming is the
      // kernel's, not this screen's: "the next bin after PB3" is a rule, and a
      // rule a client computes is a rule the next client gets wrong.
      const howMany = field({
        label: "How many new bins",
        type: "number",
        value: "3",
        hint: "Registered and put on this pick together.",
      });
      const prefix = field({
        label: "Call them",
        value: commonPrefix(kit.filter((v) => binTypeIds.has(v.type_id))) || "PB",
        hint: "Numbered on from the highest one you already have.",
      });
      const newType = el("select", { class: "input" });
      newType.replaceChildren(
        ...binTypes.map((t) => el("option", { value: t.id, text: t.label })),
      );

      // Whose bins these are. Fruit bought in arrives in the grower's bins and
      // those go back, which is a different situation from a client's bins
      // living in the barn, so the two are asked separately.
      //
      // The grower is free text rather than a picker, because a vineyard you buy
      // fruit from is not a party at this winery and making it one would put a
      // row in the table lot visibility is scoped by. That is S-53, and the cost
      // is that the name is typed rather than chosen.
      const ours = checkbox("These are our bins", true);
      const lender = field({
        label: "On loan from",
        // The pick already knows which vineyard it came from, and fruit usually
        // arrives in the bins of whoever grew it.
        value: vineyardOfPick(blockRows, vineRows),
        placeholder: "Pearlstaad",
        hint: "They go back. Empty ones show up under Bins to return.",
      });
      const lenderBox = el("div", {}, lender.root);
      const syncOurs = () => {
        lenderBox.hidden = ours.input.checked;
      };
      syncOurs();
      on(ours.input, "change", syncOurs);

      const makeBins = button("Register and add", async () => {
        const count = howMany.value() ? Number(howMany.value()) : 0;
        if (!count) {
          message.replaceChildren(banner("How many bins?", "error"));
          return;
        }
        const pick = pickPayload();
        if (!pick) {
          message.replaceChildren(
            banner("Start a pick first, so the bins have something to join.", "error"),
          );
          return;
        }
        try {
          const result = await addBinsToPick({
            pick,
            newCount: count,
            newTypeId: newType.value,
            namePrefix: prefix.value(),
            fillPct: fillPct(),
            onLoanFrom: ours.input.checked ? null : lender.value(),
          });
          await landed(result, `Registered ${result.registered.join(", ")}.`);
        } catch (error) {
          message.replaceChildren(fail(error));
        }
      });

      // Cancelling is destructive enough to be worth a second tap and cheap
      // enough that hiding it behind a menu would be worse. Two taps, in place.
      const cancelBlock = el("div", {});

      function drawCancel(): void {
        if (!nodeId) {
          cancelBlock.replaceChildren();
          return;
        }
        cancelBlock.replaceChildren(
          button(
            "Cancel this pick",
            () => {
              cancelBlock.replaceChildren(
                banner(
                  "Cancelling frees the bins and takes this off the list. Anything " +
                    "already weighed stays in the record.",
                  "note",
                ),
                button("Yes, cancel it", () => void doCancel(), "secondary"),
                button("Keep it", () => drawCancel(), "quiet"),
              );
            },
            "quiet",
          ),
        );
      }

      async function doCancel(): Promise<void> {
        if (!nodeId) return;
        const id = nodeId;
        try {
          const out = await cancelPick(id);
          cancelBlock.replaceChildren(
            banner(
              `Cancelled. ${out.bins_freed} bin${out.bins_freed === 1 ? "" : "s"} freed` +
                (out.weighings_kept > 0
                  ? `, and ${out.weighings_kept} weighing${out.weighings_kept === 1 ? "" : "s"} kept in the record.`
                  : "."),
              "good",
            ),
            // Only offered when there was nothing to keep. A pick somebody
            // weighed into is a record of something that happened, however
            // wrong the block was.
            ...(out.weighings_kept === 0 && scope?.may_admin
              ? [
                  button(
                    "Remove it completely",
                    async () => {
                      try {
                        await removePick(id);
                        go({ at: "intake" });
                      } catch (error) {
                        message.replaceChildren(fail(error));
                      }
                    },
                    "quiet",
                  ),
                ]
              : []),
            button("Back to picking", () => go({ at: "intake" }), "secondary"),
          );
        } catch (error) {
          message.replaceChildren(fail(error));
          drawCancel();
        }
      }

      drawCancel();
      if (nodeId) await refreshTally(nodeId);

      body.replaceChildren(
        rows(
          tally,
          fill.root,
          el("h2", { class: "section-head", text: "New bins" }),
          howMany.root,
          prefix.root,
          binTypes.length > 1
            ? el(
                "div",
                { class: "field" },
                el("span", { class: "field-label", text: "Type" }),
                newType,
              )
            : el("span", {}),
          ours.root,
          lenderBox,
          makeBins,
          existingBlock,
          addExisting,
          button("Weigh bins", () => go({ at: "scale" }), "secondary"),
          // Only once the pick exists. Before the first bin lands there is no
          // pick to photograph, and a button that leads to a refusal is worse
          // than no button.
          nodeId
            ? button(
                "Photographs",
                () => (nodeId ? go({ at: "pick-photos", id: nodeId }) : undefined),
                "secondary",
              )
            : el("span", {}),
          button("Done", () => go({ at: "intake" }), "quiet"),
          cancelBlock,
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

// Which vineyard the pick in hand came from, so "on loan from" starts with the
// name somebody would otherwise type. Only useful while a pick is being
// described, which is the one moment this screen is open.
function vineyardOfPick(blockRows: Block[], vineRows: Vineyard[]): string {
  const id = pendingPick?.block_id;
  if (!id) return "";
  const vineyardId = blockRows.find((b) => b.id === id)?.vineyard_id;
  if (!vineyardId) return "";
  return vineRows.find((v) => v.id === vineyardId)?.name ?? "";
}

// What this winery calls its bins, read off what it has rather than assumed.
// Purely a default in a text box: the kernel is what decides the number, and a
// wrong guess here costs one edit rather than a wrong name in the record.
function commonPrefix(binsHere: VesselState[]): string {
  const counts = new Map<string, number>();
  for (const v of binsHere) {
    const m = /^([A-Za-z][A-Za-z\s-]*?)\s*\d+$/.exec(v.name);
    if (!m?.[1]) continue;
    const p = m[1].trim();
    counts.set(p, (counts.get(p) ?? 0) + 1);
  }
  let best = "";
  let most = 0;
  for (const [p, n] of counts) {
    if (n > most) {
      most = n;
      best = p;
    }
  }
  return best;
}

// The scale. Tick whatever went on it together, read the gross off the display,
// and the kernel subtracts those particular bins' tares. Nothing here divides
// the number across the bins, because the reading does not contain that.
function scaleScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Weigh bins",
    lede(
      "Tick the bins that went on the scale together and type what it said. " +
        "Their tares come off automatically.",
    ),
    body,
  );

  void (async () => {
    try {
      const waiting = await unweighedBins();
      if (waiting.length === 0) {
        body.replaceChildren(
          empty("Nothing is waiting to be weighed."),
          button("Back", () => goBack(), "quiet"),
        );
        return;
      }

      // Grouped by pick, because a scale reading is of one pick: the kernel
      // refuses a set of bins that do not all hold the same fruit, and offering
      // a mixed selection would be offering a refusal.
      const byPick = new Map<string, UnweighedBin[]>();
      for (const b of waiting) {
        const list = byPick.get(b.node_id) ?? [];
        list.push(b);
        byPick.set(b.node_id, list);
      }

      const groups = [...byPick.entries()].map(([nodeId, binsHere]) => {
        const boxes = binsHere.map((b) => ({
          bin: b,
          box: checkbox(
            b.fill_pct === null
              ? `${b.bin_name} (${b.bin_type})`
              : `${b.bin_name} (${b.bin_type}, ${b.fill_pct}% full)`,
            binsHere.length === 1,
          ),
        }));
        const gross = field({
          label: "Gross, lbs",
          type: "number",
          placeholder: "1000",
          hint: "What the scale says, bins and fruit together.",
        });
        const note = field({
          label: "Note",
          placeholder: "one full one half",
          hint: "Optional. What a number alone would not say.",
        });
        // Wanted, not required. A typed weight is somebody's report and a
        // photograph of the display is the thing itself, which is the sort of
        // disagreement nobody finds in March by staring at a spreadsheet. But
        // the truck is waiting, so a reading with no photograph goes through.
        const photo = photoPicker(
          "Of the display. Not required, but it is what lets this number be " +
            "checked later. If you cannot now, the pick screen takes them after.",
        );
        const result = el("div", {});

        return el(
          "div",
          { class: "rows" },
          el("h2", { class: "section-head", text: binsHere[0]?.pick_name ?? "Pick" }),
          ...boxes.map((b) => b.box.root),
          gross.root,
          note.root,
          photo.root,
          button("Record this weight", async () => {
            const chosen = boxes
              .filter((b) => b.box.input.checked)
              .map((b) => b.bin.vessel_id);
            if (chosen.length === 0) {
              result.replaceChildren(
                banner("Tick the bins this reading is of.", "error"),
              );
              return;
            }
            if (!gross.value()) {
              result.replaceChildren(banner("Type what the scale said.", "error"));
              return;
            }
            try {
              // The photograph goes up first, and a failure here must not lose
              // the weight. Somebody is standing at a scale with a truck behind
              // them, so a dead upload records the reading anyway and says the
              // photograph did not make it, rather than refusing the number.
              const file = photo.file();
              let photoPath: string | null = null;
              let photoFailed: string | null = null;
              if (file) {
                try {
                  photoPath = await uploadPhoto("node", nodeId, file);
                } catch (error) {
                  photoFailed = error instanceof Error ? error.message : String(error);
                }
              }

              const out = await weighBins({
                nodeId,
                vesselIds: chosen,
                grossLbs: Number(gross.value()),
                note: note.value() || null,
                photoPath,
              });
              result.replaceChildren(
                banner(
                  `${out.net_lbs.toLocaleString()} lbs of fruit: ${out.gross_lbs.toLocaleString()} gross ` +
                    `less ${out.tare_lbs.toLocaleString()} of bin. This pick is now ` +
                    `${out.total_lbs.toLocaleString()} lbs, with ${out.unweighed} bin` +
                    `${out.unweighed === 1 ? "" : "s"} still to weigh.` +
                    (out.photographed ? " Photograph of the scale attached." : ""),
                  "good",
                ),
                // Said separately and in a different colour, because the weight
                // landed and the photograph did not, and one banner claiming
                // both would be the A13 shape.
                ...(photoFailed
                  ? [
                      banner(
                        `The weight is recorded. The photograph did not upload: ${photoFailed}. ` +
                          "It is still on the phone; attach it from the pick screen when there is signal.",
                        "note",
                      ),
                    ]
                  : []),
              );
              gross.input.value = "";
              note.input.value = "";
              photo.clear();
              for (const b of boxes) {
                if (b.box.input.checked) {
                  b.box.input.checked = false;
                  b.box.input.disabled = true;
                  b.box.root.classList.add("weighed");
                }
              }
            } catch (error) {
              result.replaceChildren(fail(error));
            }
          }),
          result,
        );
      });

      body.replaceChildren(
        rows(
          ...groups,
          button("Done", () => go({ at: "intake" }), "quiet"),
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

// --- photographs -----------------------------------------------------------

// Attaching a photograph after the fact, which is the only time most of them
// get attached.
//
// The winemaker weighed three loads, photographed the scale three times, and
// came back that evening with three pictures and nowhere to put them: 0042 had
// put the photograph in the kernel and nothing on any screen ever asked for one.
// The scale screen asks now, but asking at the scale is not enough on its own.
// The moment of recording is the moment both hands are full, so a photograph
// that can only be attached then is a photograph that does not get attached.
//
// A photograph of a scale is evidence for one particular reading, so this lists
// the readings and lets each take its own. A photograph of the fruit is about
// the pick and about no reading, so that is a separate control and says so.

// Shown for a photograph that is already attached. The bucket is private, so the
// image comes through a signed url that expires; a card that fails to load still
// shows its caption and its date, because "there is a photograph here and it
// will not display" and "there is no photograph" must not look the same.
async function photoCard(
  a: Attachment,
  onChanged: () => void,
  said: HTMLElement,
): Promise<HTMLElement> {
  const url = await photoUrl(a.path);
  const caption = field({
    label: "Caption",
    value: a.caption ?? "",
    placeholder: "what this is of",
  });

  return el(
    "div",
    { class: "photo-card" },
    url
      ? el("img", { class: "photo", src: url, alt: a.caption ?? "A photograph" })
      : empty("This photograph did not load. It is still attached."),
    el("span", {
      class: "field-hint",
      text: `Taken ${new Date(a.at).toLocaleString()}`,
    }),
    caption.root,
    button(
      "Save caption",
      async () => {
        try {
          await captionPhoto(a.id, caption.value());
          said.replaceChildren(banner("Caption saved.", "good"));
          onChanged();
        } catch (error) {
          said.replaceChildren(fail(error));
        }
      },
      "secondary",
    ),
  );
}

function photosScreen(subject: "node" | "vessel", subjectId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Photographs",
    lede(
      subject === "node"
        ? "Pictures of this pick. A photograph of the scale belongs to the " +
            "reading it shows, so attach it to that reading rather than to the pick."
        : "Pictures of this vessel. As many as you take: nothing here replaces " +
            "what was already attached.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const [already, weighings] = await Promise.all([
      attachmentsFor(subject, subjectId),
      subject === "node" ? pickWeighings(subjectId) : Promise.resolve([]),
    ]);

    // One picker per reading. A single picker plus a dropdown would be fewer
    // controls and would put the choosing after the taking, which is the wrong
    // way round: he is looking at a photograph of a display reading 839 and
    // wants the row that says 839.
    function weighingRow(w: PastWeighing): HTMLElement {
      const picker = photoPicker(
        "Of the scale for this reading. Taken this morning is fine.",
      );
      const taken = field({
        label: "When it was taken",
        type: "datetime-local",
        // Defaults to when the reading was recorded, because a photograph of a
        // scale was almost always taken within a minute of the number being
        // typed. Editable, because almost always is not always.
        value: localStamp(w.at),
        hint: "Defaults to when this weight was recorded.",
      });
      const said = el("div", {});

      const what =
        `${w.net_lbs === null ? "no net" : `${Number(w.net_lbs).toLocaleString()} lbs`}` +
        `${w.gross_lbs === null ? "" : `, ${Number(w.gross_lbs).toLocaleString()} gross`}` +
        `${w.bins.length === 0 ? "" : ` on ${w.bins.join(", ")}`}`;

      return el(
        "details",
        { class: "more" },
        el("summary", {
          text:
            `${new Date(w.at).toLocaleTimeString()}: ${what}` +
            (w.superseded ? " (corrected later)" : "") +
            (w.photos > 0
              ? `, ${w.photos} photograph${w.photos === 1 ? "" : "s"}`
              : ", no photograph"),
        }),
        rows(
          ...(w.note ? [summaryRow("Note", w.note)] : []),
          // A corrected reading is still part of the record of the day, which is
          // why it is here at all rather than filtered out. Photographing one is
          // allowed and is occasionally the point: the photograph is how you
          // find out which of the two numbers was right.
          ...(w.superseded
            ? [
                el("p", {
                  class: "field-hint",
                  text:
                    "A later reading corrected this one, so it is not counted in " +
                    "the pick's total. A photograph of it still says what the scale showed.",
                }),
              ]
            : []),
          picker.root,
          taken.root,
          button(
            "Attach to this reading",
            async () => {
              const file = picker.file();
              if (!file) {
                said.replaceChildren(
                  banner("Take or choose a photograph first.", "error"),
                );
                return;
              }
              try {
                const out = await addPhoto({
                  subjectType: "node",
                  subjectId,
                  file,
                  aboutEvent: w.event_id,
                  takenAt: taken.value() ? new Date(taken.value()).toISOString() : null,
                });
                said.replaceChildren(
                  banner(
                    out.already
                      ? "That photograph was already attached to this reading. Nothing changed."
                      : "Attached. This reading can be checked against the scale now.",
                    out.already ? "note" : "good",
                  ),
                );
                picker.clear();
                await load();
              } catch (error) {
                said.replaceChildren(fail(error));
              }
            },
            "secondary",
          ),
          said,
        ),
      );
    }

    // Loose photographs: of the fruit, of the truck, of a bin with a split seam.
    const loose = photoPicker(
      subject === "node"
        ? "Of the pick itself rather than of a reading. The fruit, the bins, the truck."
        : "Of this vessel.",
    );
    const looseCaption = field({
      label: "Caption",
      placeholder: subject === "node" ? "fruit on the sorting table" : "the gauge",
      hint: "Optional. Worth a few words when it is not obvious six months later.",
    });
    const looseTaken = field({
      label: "When it was taken",
      type: "datetime-local",
      hint: "Optional. Leave blank for now.",
    });
    const looseSaid = el("div", {});

    const cards = await Promise.all(
      already.map((a) => photoCard(a, () => void load(), message)),
    );

    body.replaceChildren(
      rows(
        ...(subject === "node"
          ? [
              el("h2", { class: "section-head", text: "Weighings" }),
              weighings.length === 0
                ? empty("Nothing has been weighed on this pick yet.")
                : el("div", {}, ...weighings.map(weighingRow)),
            ]
          : []),

        el("h2", {
          class: "section-head",
          text: subject === "node" ? "A photograph of the pick" : "Add a photograph",
        }),
        loose.root,
        looseCaption.root,
        looseTaken.root,
        button("Attach it", async () => {
          const file = loose.file();
          if (!file) {
            looseSaid.replaceChildren(
              banner("Take or choose a photograph first.", "error"),
            );
            return;
          }
          try {
            const out = await addPhoto({
              subjectType: subject,
              subjectId,
              file,
              caption: looseCaption.value() || null,
              takenAt: looseTaken.value()
                ? new Date(looseTaken.value()).toISOString()
                : null,
            });
            looseSaid.replaceChildren(
              banner(
                out.already
                  ? "That photograph is already here. Nothing changed."
                  : "Attached.",
                out.already ? "note" : "good",
              ),
            );
            loose.clear();
            looseCaption.input.value = "";
            await load();
          } catch (error) {
            looseSaid.replaceChildren(fail(error));
          }
        }),
        looseSaid,

        el("h2", { class: "section-head", text: "Attached" }),
        already.length === 0
          ? empty("No photographs yet.")
          : el("div", { class: "photo-cards" }, ...cards),
        message,
        button("Back", () => goBack(), "quiet"),
      ),
    );
  }

  void (async () => {
    try {
      await load();
    } catch (error) {
      body.replaceChildren(
        fail(error),
        button("Back", () => goBack(), "quiet"),
      );
    }
  })();

  return view;
}

// `datetime-local` wants local wall time with no zone, and an ISO string from
// the database is UTC with one. Formatting it by hand rather than slicing the
// ISO string, because slicing shows a photograph taken at 9am as taken at 4pm.
// S-57 is the wider version of this: the app has no timezone of its own.
function localStamp(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number): string => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    `T${pad(d.getHours())}:${pad(d.getMinutes())}`
  );
}

// --- press -----------------------------------------------------------------

// Build order 3, and the screen where a lot gets the identity it keeps. The
// kernel decides what stage the juice lands at, which is why nothing here asks:
// fruit in bins presses to a ferment, a ferment presses off skins to maturation,
// and that is winery practice rather than a preference.
function pressScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Press",
    lede(
      "Which fruit went in and where the juice went. The weight comes off the " +
        "pick, so what is left in the bins is what is left.",
    ),
    body,
  );

  void (async () => {
    try {
      const [picks, kit, waiting] = await Promise.all([
        openPicks(),
        vessels(),
        unweighedBins(),
      ]);
      const ready = picks.filter((p) => p.quantity !== null);
      const unweighedBy = new Map<string, number>();
      for (const b of waiting) {
        unweighedBy.set(b.node_id, (unweighedBy.get(b.node_id) ?? 0) + 1);
      }

      if (ready.length === 0) {
        body.replaceChildren(
          picks.length === 0
            ? empty("There is no fruit in bins to press.")
            : banner(
                "Every open pick is still waiting for a weight. Pressing is the " +
                  "last moment anybody can weigh the fruit, so weigh it first.",
                "note",
              ),
          ...(picks.length === 0
            ? []
            : [button("Weigh bins", () => go({ at: "scale" }), "secondary")]),
          button("Back", () => goBack(), "quiet"),
        );
        return;
      }

      const source = el("select", { class: "input" });
      source.replaceChildren(
        ...ready.map((p) =>
          el("option", {
            value: p.id,
            text: `${p.name} (${Number(p.quantity).toLocaleString()} lbs)`,
          }),
        ),
      );

      const weight = field({
        label: "Fruit pressed, lbs",
        type: "number",
        hint: "Blank presses all of it. A smaller number leaves the rest in the bins.",
      });
      const warning = el("div", {});

      function syncWarning(): void {
        const left = unweighedBy.get(source.value) ?? 0;
        warning.replaceChildren(
          left > 0
            ? banner(
                `${left} bin${left === 1 ? "" : "s"} on this pick were never weighed. ` +
                  "Pressing goes ahead and those weights are gone afterwards.",
                "note",
              )
            : el("span", {}),
        );
      }
      syncWarning();
      on(source, "change", syncWarning);

      const empties = kit.filter((v) => v.is_empty);
      const cutKinds = await terms("press_cut");

      // One row per cut, added as you pull them. The first row is the whole
      // press when nobody is separating fractions, which is what this screen
      // did before 0045 and is still the common case.
      type CutRow = {
        root: HTMLElement;
        cut: () => string;
        vessel: () => string;
        litres: () => string;
      };
      const cutRows: CutRow[] = [];
      const cutHolder = el("div", { class: "rows" });

      function addCutRow(): void {
        const which = el("select", { class: "input" });
        which.replaceChildren(
          el("option", { value: "", text: "The whole press" }),
          ...cutKinds.map((t) => el("option", { value: t.id, text: t.label })),
        );
        const vessel = el("select", { class: "input" });
        vessel.replaceChildren(
          ...empties.map((v) =>
            el("option", {
              value: v.id,
              text: v.capacity_l
                ? `${v.name} (${v.type}, ${v.capacity_l} L)`
                : `${v.name} (${v.type})`,
            }),
          ),
        );
        const litres = field({
          label: "Litres",
          type: "number",
          placeholder: "1200",
          hint: "What actually went into the vessel.",
        });
        const root = el(
          "div",
          { class: "rows" },
          el(
            "div",
            { class: "field" },
            el("span", { class: "field-label", text: "Cut" }),
            which,
          ),
          el(
            "div",
            { class: "field" },
            el("span", { class: "field-label", text: "Into" }),
            vessel,
          ),
          litres.root,
        );
        cutRows.push({
          root,
          cut: () => which.value,
          vessel: () => vessel.value,
          litres: () => litres.value(),
        });
        cutHolder.append(root);
      }
      addCutRow();

      // What the processing log asks for beyond the numbers. All optional: a
      // press nobody timed is still a press, and a form that refused one would
      // be asking for a lie.
      // Picked rather than typed, so one run can be compared against another and
      // "Champagne 1.2 bar" typed three ways is not three programs. Open,
      // because the programs belong to this press and nobody else's.
      const program = termPicker("press_program", {
        label: "Press program",
        stickyKey: "press_program",
        allowEmpty: true,
      });
      const wholeCluster = field({
        label: "Whole cluster, percent",
        type: "number",
        hint: "Blank if nobody counted. 100 is whole cluster, 0 is fully destemmed.",
      });
      const skinStart = field({
        label: "Skin contact started",
        type: "datetime-local",
      });
      const skinEnd = field({ label: "Skin contact ended", type: "datetime-local" });
      // The other duration. How long the skins were on and how long the press
      // ran are two different facts, and the form asks for both.
      const ranFrom = field({ label: "Press started", type: "datetime-local" });
      const ranTo = field({ label: "Press finished", type: "datetime-local" });
      const name = field({
        label: "Name the lot",
        hint: "Blank names it after the pick.",
      });

      // A picker loads its own rows, and an unloaded one is an empty select
      // that looks like a winery with no programs rather than one nobody asked.
      await program.reload();

      body.replaceChildren(
        rows(
          el("h2", { class: "section-head", text: "The fruit" }),
          el(
            "div",
            { class: "field" },
            el("span", { class: "field-label", text: "Pick" }),
            source,
          ),
          warning,
          weight.root,
          el("h2", { class: "section-head", text: "The juice" }),
          empties.length === 0
            ? banner(
                "Every vessel is full. Rack one out before pressing into it.",
                "note",
              )
            : cutHolder,
          empties.length === 0
            ? el("span", {})
            : button(
                "Another cut",
                () => {
                  addCutRow();
                },
                "quiet",
              ),
          name.root,
          el(
            "details",
            { class: "more" },
            el("summary", { text: "How it was pressed" }),
            rows(
              program.root,
              wholeCluster.root,
              skinStart.root,
              skinEnd.root,
              ranFrom.root,
              ranTo.root,
            ),
          ),
          button("Record the press", async () => {
            if (cutRows.some((row) => !row.litres())) {
              message.replaceChildren(banner("How many litres came out?", "error"));
              return;
            }
            if (cutRows.some((row) => !row.vessel())) {
              message.replaceChildren(banner("Pick a vessel for the juice.", "error"));
              return;
            }
            try {
              // A datetime-local field gives a local wall clock with no zone.
              // Handing that to Postgres as text would have it read as UTC,
              // which puts a four hour skin contact seven hours out in Oregon.
              const asInstant = (raw: string) =>
                raw ? new Date(raw).toISOString() : null;

              const out = await press({
                sources: [
                  {
                    node_id: source.value,
                    weight_lbs: weight.value() ? Number(weight.value()) : null,
                  },
                ],
                cuts: cutRows.map((row) => ({
                  ...(row.cut() ? { cut_id: row.cut() } : {}),
                  destinations: [
                    { vessel_id: row.vessel(), volume_l: Number(row.litres()) },
                  ],
                })),
                ...(name.value() ? { node: { name: name.value() } } : {}),
                detail: Object.fromEntries(
                  Object.entries({
                    program_id: program.value() || null,
                    whole_cluster_pct: wholeCluster.value()
                      ? Number(wholeCluster.value())
                      : null,
                    skin_contact_start: asInstant(skinStart.value()),
                    skin_contact_end: asInstant(skinEnd.value()),
                    pressed_from: asInstant(ranFrom.value()),
                    pressed_to: asInstant(ranTo.value()),
                  }).filter(([, v]) => v !== null),
                ),
              });
              const first = cutRows[0]?.vessel() ?? "";
              showResult(
                await resultScreen(
                  first,
                  out.node_id,
                  0,
                  `Pressed. ${out.lbs_in.toLocaleString()} lbs in, ` +
                    `${out.litres_out.toLocaleString()} L out, ` +
                    `${out.yield_l_per_ton === null ? "yield unknown" : `${out.yield_l_per_ton} L per ton`}` +
                    `${out.cuts.length > 1 ? ` across ${out.cuts.length} cuts` : ""}. ` +
                    `${out.bins_emptied} bin${out.bins_emptied === 1 ? "" : "s"} emptied.`,
                ),
                first,
              );
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

// Borrowed bins with nothing in them. The winemaker's point: empty is not the
// same as available, because a bin lent by the grower of the fruit is owed back
// the moment it stops holding anything.
function binsToReturnScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Bins to return",
    lede("Borrowed bins that are empty. These are owed back, not available."),
    body,
  );

  void (async () => {
    try {
      const owed = await binsToReturn();
      body.replaceChildren(
        rows(
          owed.length === 0
            ? empty("No borrowed bin is sitting empty.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...owed.map((b) =>
                  el(
                    "li",
                    { class: "vessel-row" },
                    el("span", { class: "vessel-name", text: b.bin_name }),
                    el("span", { class: "vessel-detail", text: b.bin_type }),
                    el("span", {
                      class: "vessel-detail",
                      // Whose it is may genuinely not be recorded, and saying so
                      // is better than a blank that reads as nobody's.
                      text: b.owed_to ? `owed to ${b.owed_to}` : "owner not recorded",
                    }),
                  ),
                ),
              ),
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

// --- taking a copy away with you -------------------------------------------

// The database lives in a container on one desktop. That is the whole of the
// risk, and it is not a risk a screen can fix: what a screen can do is put a
// copy of the record in somebody's pocket, which is the difference between a
// harvest that can be reconstructed and one that cannot.
//
// This is an export and deliberately not called a backup. A backup is pg_dump,
// runs where the database is, and can be restored. This runs as whoever is
// signed in, carries only what they may read, and there is no importer for it
// yet: S-54, said on the screen rather than only in the ledger, because the
// person holding the file is the person who needs to know.
function exportScreen(): HTMLElement {
  const body = el("div", {}, empty("Gathering everything you can read."));
  const message = el("div", {});
  const view = screen(
    "Take a copy",
    lede(
      "Everything you can read, as one file. The cellar itself lives on one " +
        "machine, so a copy somewhere else is what makes it survivable.",
    ),
    body,
  );

  void (async () => {
    try {
      const dump = await exportCellar();
      const stamp = new Date(dump.exported_at);
      const day = `${stamp.getFullYear()}-${String(stamp.getMonth() + 1).padStart(2, "0")}-${String(stamp.getDate()).padStart(2, "0")}`;
      const filename = `vitae-springs-${day}.json`;
      const text = JSON.stringify(dump, null, 2);
      const size = new Blob([text]).size;

      // Biggest tables first: the interesting thing about an export is whether
      // the rows you were worried about are in it, and those are the numerous
      // ones. Empty tables are still listed, because "nothing to read here" and
      // "not included" have to look different.
      const counts = Object.entries(dump.tables)
        .map(([name, list]) => [name, Array.isArray(list) ? list.length : 0] as const)
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));

      function save(): void {
        const url = URL.createObjectURL(new Blob([text], { type: "application/json" }));
        const a = el("a", { href: url, download: filename });
        document.body.append(a);
        a.click();
        a.remove();
        // Freed on the next turn of the loop rather than immediately, because
        // revoking while the download is still being handed off cancels it on
        // some builds of Android Chrome.
        window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
      }

      async function share(): Promise<void> {
        const file = new File([text], filename, { type: "application/json" });
        const nav = navigator as Navigator & {
          canShare?: (data: { files: File[] }) => boolean;
          share?: (data: { files: File[]; title?: string }) => Promise<void>;
        };
        try {
          await nav.share?.({ files: [file], title: filename });
        } catch (error) {
          // Cancelling the share sheet rejects, and a cancel is not a failure.
          if ((error as Error)?.name === "AbortError") return;
          message.replaceChildren(
            banner(
              "This phone would not pass the file to another app. Save it instead.",
              "note",
            ),
          );
        }
      }

      const canShare =
        typeof navigator !== "undefined" &&
        typeof (navigator as { canShare?: unknown }).canShare === "function" &&
        (navigator as { canShare: (d: { files: File[] }) => boolean }).canShare({
          files: [new File([""], filename, { type: "application/json" })],
        });

      body.replaceChildren(
        rows(
          summaryRow("Taken", stamp.toLocaleString()),
          summaryRow("Rows", dump.rows.toLocaleString()),
          summaryRow("Size", `${Math.max(1, Math.round(size / 1024))} KB`),
          summaryRow("Shape", `${dump.table_count} tables`),
          button("Save to this phone", () => save()),
          ...(canShare
            ? [button("Send it somewhere", () => void share(), "secondary")]
            : []),
          banner(
            "This is a copy of the record, not a restore point. There is no way " +
              "to load it back in yet, so keep it beside the real backup rather " +
              "than instead of it. Sorry S-54.",
            "note",
          ),
          el("h2", { class: "section-head", text: "What is in it" }),
          el(
            "ul",
            { class: "vessel-list" },
            ...counts.map(([name, n]) =>
              el(
                "li",
                { class: "vessel-row" },
                el("span", { class: "vessel-name", text: name.replace(/_/g, " ") }),
                el("span", {
                  class: "vessel-detail",
                  text: n === 0 ? "nothing you can read" : `${n.toLocaleString()} rows`,
                }),
              ),
            ),
          ),
          message,
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

// --- the vineyard ----------------------------------------------------------

// Three levels, because the winemaker described three: a vineyard is a place, a
// block is part of it, and a planting is a variety in a block. The detail hangs
// off the planting, because "a block can carry several, and those varieties
// could also have different rootstocks and planting age".
//
// Everything here is input. Nothing computes anything about farming, and the
// shape is arranged so that a real vineyard module can later fill the same rows
// in without the screens changing.

// One description of the site fields, used to build both the block form and the
// planting form. Written once because they are the same nine questions asked at
// two levels, and two lists would drift.
const SITE_FIELDS: Array<{
  key: keyof SiteFields;
  label: string;
  numeric?: boolean;
  hint?: string;
}> = [
  { key: "acres", label: "Acres", numeric: true },
  { key: "planted_year", label: "Year planted", numeric: true },
  { key: "clone", label: "Clone" },
  { key: "rootstock", label: "Rootstock" },
  { key: "spacing", label: "Spacing", hint: "However you say it. 6 by 3, say." },
  { key: "trellis", label: "Trellis" },
  { key: "aspect", label: "Aspect" },
  { key: "elevation", label: "Elevation" },
  { key: "soil", label: "Soil" },
];

type SiteForm = {
  nodes: HTMLElement[];
  read: () => Record<string, unknown>;
};

// `inheritedFrom` supplies the value the block would give if this level says
// nothing, shown as the placeholder. That is the whole of the inheritance made
// visible: an empty box that shows 2008 in grey means "leave this and you get
// the block's 2008", which is different from an empty box meaning nothing.
function siteForm(
  current: Partial<SiteFields>,
  inheritedFrom?: Partial<SiteFields>,
): SiteForm {
  const built = SITE_FIELDS.map((spec) => {
    const own = current[spec.key];
    const fallback = inheritedFrom?.[spec.key];
    const control = field({
      label: spec.label,
      ...(spec.numeric ? { type: "number" as const } : {}),
      value: own == null ? "" : String(own),
      ...(fallback != null ? { placeholder: `${fallback} (from the block)` } : {}),
      ...(spec.hint ? { hint: spec.hint } : {}),
    });
    return { spec, control };
  });

  return {
    nodes: built.map((b) => b.control.root),
    read: () =>
      Object.fromEntries(
        built.map((b) => {
          const raw = b.control.value().trim();
          // Empty means "do not say", which at planting level means "ask the
          // block". Null rather than an empty string, so the coalesce in
          // planting_detail actually falls through.
          if (raw === "") return [b.spec.key, null];
          return [b.spec.key, b.spec.numeric ? Number(raw) : raw];
        }),
      ),
  };
}

function vineyardsScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Vineyards",
    lede(
      "Where fruit comes from. Blocks belong to a vineyard, and what is planted " +
        "in a block is a list of varieties.",
    ),
    body,
  );

  void (async () => {
    try {
      const [vineRows, blockRows, planted] = await Promise.all([
        vineyards(),
        blocks(),
        plantings(),
      ]);
      const blocksOf = new Map<string, Block[]>();
      for (const b of blockRows) {
        const key = b.vineyard_id ?? "";
        blocksOf.set(key, [...(blocksOf.get(key) ?? []), b]);
      }
      const varietiesOf = new Map<string, string[]>();
      for (const p of planted) {
        varietiesOf.set(p.block_id, [
          ...(varietiesOf.get(p.block_id) ?? []),
          p.variety,
        ]);
      }

      const name = field({ label: "Name", placeholder: "Pearlstaad" });
      const where = field({
        label: "Where it is",
        placeholder: "Spring Valley Road",
        hint: "Free text. An address, a road, whatever you would recognise.",
      });

      function blockList(list: Block[]): HTMLElement {
        if (list.length === 0) return empty("No blocks yet.");
        return el(
          "ul",
          { class: "vessel-list" },
          ...list.map((b) => {
            const kinds = varietiesOf.get(b.id) ?? [];
            const row = el(
              "li",
              { class: "vessel-row", role: "button", tabindex: "0" },
              el("span", { class: "vessel-name", text: b.name }),
              el("span", {
                class: "vessel-detail",
                text:
                  kinds.length === 0 ? "nothing planted recorded" : kinds.join(", "),
              }),
              b.acres === null
                ? null
                : el("span", { class: "vessel-detail", text: `${b.acres} acres` }),
            );
            const open = () => go({ at: "block", id: b.id });
            on(row, "click", open);
            on(row, "keydown", (ev) => {
              if (ev.key === "Enter" || ev.key === " ") {
                ev.preventDefault();
                open();
              }
            });
            return row;
          }),
        );
      }

      const orphans = blocksOf.get("") ?? [];

      body.replaceChildren(
        rows(
          ...vineRows.flatMap((v) => [
            el("h2", { class: "section-head", text: v.name }),
            v.location ? el("p", { class: "lede", text: v.location }) : el("span", {}),
            blockList(blocksOf.get(v.id) ?? []),
          ]),
          ...(orphans.length > 0
            ? [
                el("h2", { class: "section-head", text: "No vineyard yet" }),
                blockList(orphans),
              ]
            : []),
          el(
            "details",
            { class: "more" },
            el("summary", { text: "Add a vineyard" }),
            rows(
              name.root,
              where.root,
              button(
                "Add it",
                async () => {
                  if (!name.value()) {
                    message.replaceChildren(banner("It needs a name.", "error"));
                    return;
                  }
                  try {
                    await addVineyard({
                      id: newId(),
                      name: name.value(),
                      location: where.value() || null,
                    });
                    go({ at: "vineyards" });
                  } catch (error) {
                    message.replaceChildren(fail(error));
                  }
                },
                "secondary",
              ),
            ),
          ),
          message,
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

// A block, what is true of the whole of it, and what is planted in it. The two
// forms are the same nine questions at two levels, which is the winemaker's own
// answer: fill it in per variety, or let the block answer for all of them.
function blockScreen(blockId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen("Block", body);

  void (async () => {
    try {
      const [blockRows, vineRows, planted, varieties] = await Promise.all([
        blocks(),
        vineyards(),
        plantings(blockId),
        terms("variety"),
      ]);
      const block = blockRows.find((b) => b.id === blockId);
      if (!block) {
        body.replaceChildren(
          banner("That block is not there to open.", "note"),
          button("Back", () => goBack(), "quiet"),
        );
        return;
      }
      const vine = vineRows.find((v) => v.id === block.vineyard_id);
      view.replaceChildren(
        el("h1", { text: vine ? `${vine.name} ${block.name}` : block.name }),
        body,
      );

      const whole = siteForm(block);
      const notes = field({ label: "Notes", value: block.notes ?? "" });
      const newVariety = el("select", { class: "input" });
      const already = new Set(planted.map((p) => p.variety_id));
      const addable = varieties.filter((t) => !already.has(t.id));
      newVariety.replaceChildren(
        ...addable.map((t) => el("option", { value: t.id, text: t.label })),
      );

      function plantingRow(p: PlantingDetail): HTMLElement {
        const own = siteForm(
          // Only what this planting actually says, so an inherited value shows
          // as an empty box with the block's answer behind it rather than as a
          // value somebody typed.
          Object.fromEntries(
            SITE_FIELDS.map((f) => [
              f.key,
              p.inherited.includes(f.key) ? null : p[f.key],
            ]),
          ) as Partial<SiteFields>,
          block,
        );
        const plantingNotes = field({ label: "Notes", value: p.notes ?? "" });
        const said = el("div", {});
        return el(
          "details",
          { class: "more" },
          el("summary", {
            text:
              p.inherited.length === 0
                ? p.variety
                : `${p.variety} (${p.inherited.length} from the block)`,
          }),
          rows(
            ...own.nodes,
            plantingNotes.root,
            button(
              "Save this variety",
              async () => {
                try {
                  await updatePlanting(p.planting_id, {
                    ...own.read(),
                    notes: plantingNotes.value() || null,
                  });
                  said.replaceChildren(banner("Saved.", "good"));
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              "secondary",
            ),
            button(
              "Remove this variety",
              async () => {
                try {
                  await removePlanting(p.planting_id);
                  go({ at: "block", id: blockId });
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              "quiet",
            ),
            said,
          ),
        );
      }

      body.replaceChildren(
        rows(
          el("h2", { class: "section-head", text: "Planted" }),
          planted.length === 0
            ? empty("Nothing recorded as planted here yet.")
            : el("div", {}, ...planted.map(plantingRow)),
          ...(addable.length > 0
            ? [
                el(
                  "div",
                  { class: "field" },
                  el("span", { class: "field-label", text: "Add a variety" }),
                  newVariety,
                ),
                button(
                  "Add it",
                  async () => {
                    try {
                      await addPlanting({
                        id: newId(),
                        block_id: blockId,
                        variety_id: newVariety.value,
                      });
                      go({ at: "block", id: blockId });
                    } catch (error) {
                      message.replaceChildren(fail(error));
                    }
                  },
                  "secondary",
                ),
              ]
            : []),
          el("h2", { class: "section-head", text: "True of the whole block" }),
          el("p", {
            class: "lede",
            text: "Anything a variety above leaves blank takes the answer from here.",
          }),
          ...whole.nodes,
          notes.root,
          button("Save the block", async () => {
            try {
              await updateBlock(blockId, {
                ...whole.read(),
                notes: notes.value() || null,
              });
              message.replaceChildren(banner("Saved.", "good"));
            } catch (error) {
              message.replaceChildren(fail(error));
            }
          }),
          message,
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

// --- the day ---------------------------------------------------------------

// Both halves on one screen, which is what the winemaker asked for. The spine
// is derived from the record and cannot disagree with it; the notes are the
// things the schema has no column for and never will.

// A local date, not a UTC one. `toISOString().slice(0, 10)` is the obvious
// wrong answer here: at five in the afternoon in Oregon it names tomorrow, and
// a daily log on the wrong day is worse than none. The kernel does the same
// conversion for the same reason, in `day_log`.
function localDay(when: Date): string {
  const y = when.getFullYear();
  const m = String(when.getMonth() + 1).padStart(2, "0");
  const d = String(when.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function shiftDay(iso: string, by: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  const when = new Date(y ?? 2026, (m ?? 1) - 1, (d ?? 1) + by);
  return localDay(when);
}

// The numbers a person would want off a weighing or a press, in words. Anything
// this does not recognise is shown as it was stored rather than dropped: a log
// that quietly omits what it cannot format is a log you cannot trust.
function describeDetail(detail: Record<string, unknown> | null): string {
  if (!detail) return "";
  const parts: string[] = [];
  const num = (k: string) =>
    typeof detail[k] === "number" ? (detail[k] as number).toLocaleString() : null;

  if (num("net_lbs")) {
    parts.push(
      `${num("net_lbs")} lbs of fruit, from ${num("gross_lbs")} gross less ${num("tare_lbs")} of bin`,
    );
  }
  if (num("litres_out")) {
    parts.push(`${num("lbs_in")} lbs in, ${num("litres_out")} L out`);
  }
  if (typeof detail.note === "string" && detail.note) parts.push(detail.note);
  if (typeof detail.stage === "string" && parts.length === 0) {
    parts.push(num("quantity") ? `${num("quantity")} ${detail.unit}` : "no weight yet");
  }
  if (parts.length > 0) return parts.join(". ");

  const rest = Object.entries(detail).filter(([k]) => k !== "bins" && k !== "parents");
  return rest.length === 0 ? "" : rest.map(([k, v]) => `${k}: ${String(v)}`).join(", ");
}

function dayScreen(on?: string): HTMLElement {
  const day = on ?? localDay(new Date());
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen("The day", body);

  void (async () => {
    try {
      const [entries, notes, user] = await Promise.all([
        dayLog(day),
        dayNotes(day),
        currentAppUser(),
      ]);

      const today = localDay(new Date());
      const heading =
        day === today
          ? "Today"
          : new Date(`${day}T12:00:00`).toLocaleDateString(undefined, {
              weekday: "long",
              day: "numeric",
              month: "long",
            });
      view.replaceChildren(el("h1", { text: heading }), body);

      const written = field({
        label: "Write something",
        placeholder: "Fruit came in clean. Press ran slow after lunch.",
      });
      const isPrivate = checkbox("Only I can see this", false);

      function noteRow(n: DayNote): HTMLElement {
        const mine = n.author_id === user?.id;
        return el(
          "li",
          { class: "vessel-row" },
          el("span", { class: "vessel-name", text: n.body }),
          el("span", {
            class: "vessel-detail",
            text: n.private ? "private" : "on the board",
          }),
          ...(mine
            ? [
                button(
                  "Delete",
                  async () => {
                    try {
                      await removeDayNote(n.id);
                      go({ at: "day" });
                    } catch (error) {
                      message.replaceChildren(fail(error));
                    }
                  },
                  "quiet",
                ),
              ]
            : []),
        );
      }

      body.replaceChildren(
        rows(
          el(
            "div",
            { class: "day-move" },
            button("Earlier", () => go({ at: "day", id: shiftDay(day, -1) }), "quiet"),
            el("span", { class: "field-hint", text: day }),
            ...(day < today
              ? [
                  button(
                    "Later",
                    () => go({ at: "day", id: shiftDay(day, 1) }),
                    "quiet",
                  ),
                ]
              : []),
          ),

          el("h2", { class: "section-head", text: "What happened" }),
          entries.length === 0
            ? empty("Nothing recorded on this day.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...entries.map((e) =>
                  el(
                    "li",
                    { class: "vessel-row" },
                    el("span", {
                      class: "vessel-detail",
                      text: new Date(e.at).toLocaleTimeString(undefined, {
                        hour: "2-digit",
                        minute: "2-digit",
                      }),
                    }),
                    el("span", { class: "vessel-name", text: e.headline }),
                    el("span", { class: "vessel-detail", text: e.subject }),
                    describeDetail(e.detail)
                      ? el("span", {
                          class: "vessel-detail",
                          text: describeDetail(e.detail),
                        })
                      : null,
                    // T0-3 on the screen. An inferred event and one somebody
                    // stood in front of must not read the same.
                    e.provenance === "observed"
                      ? null
                      : el("span", { class: "tag tag-inherited", text: e.provenance }),
                  ),
                ),
              ),

          el("h2", { class: "section-head", text: "Notes" }),
          notes.length === 0
            ? empty("Nothing written about this day yet.")
            : el("ul", { class: "vessel-list" }, ...notes.map(noteRow)),
          written.root,
          isPrivate.root,
          button("Add it", async () => {
            if (!written.value().trim()) {
              message.replaceChildren(banner("Write something first.", "error"));
              return;
            }
            if (!user) {
              message.replaceChildren(
                banner("A note is signed, and this sign-in has no name here.", "error"),
              );
              return;
            }
            try {
              await addDayNote({
                id: newId(),
                on_date: day,
                body: written.value().trim(),
                private: isPrivate.input.checked,
                author_id: user.id,
              });
              go({ at: "day", id: day });
            } catch (error) {
              message.replaceChildren(fail(error));
            }
          }),
          message,
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

// --- what is still owed to paper -------------------------------------------

// The `unweighed_bin` pattern pointed at paperwork, which is what the winemaker
// asked for: a list that should be empty, derived rather than remembered.
//
// Grouped by document rather than by measurement, because the work is done a
// form at a time: you pick up the weight sheet, and then you write everything
// that belongs on it.
function paperScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "On paper",
    lede(
      "Measurements that also have to go on a physical form, and have not yet. " +
        "This list should be empty at the end of a day.",
    ),
    body,
  );

  void (async () => {
    try {
      const [owed, records, user, operations] = await Promise.all([
        toPropagate(),
        paperRecords(),
        currentAppUser(),
        terms("operation"),
      ]);

      const byRecord = new Map<string, ToPropagate[]>();
      for (const row of owed) {
        byRecord.set(row.paper_record_id, [
          ...(byRecord.get(row.paper_record_id) ?? []),
          row,
        ]);
      }

      function owedRow(row: ToPropagate): HTMLElement {
        const said = el("span", {});
        const line = el(
          "li",
          { class: "vessel-row" },
          el("span", {
            class: "vessel-detail",
            text: new Date(row.at).toLocaleString(undefined, {
              day: "numeric",
              month: "short",
              hour: "2-digit",
              minute: "2-digit",
            }),
          }),
          el("span", { class: "vessel-name", text: row.operation }),
          el("span", { class: "vessel-detail", text: row.subject }),
          describeDetail(row.data)
            ? el("span", { class: "vessel-detail", text: describeDetail(row.data) })
            : null,
          button(
            "Wrote it",
            async () => {
              if (!user) {
                said.replaceChildren(
                  banner("This sign-in has no name to put against it.", "error"),
                );
                return;
              }
              try {
                await markPropagated({
                  eventId: row.event_id,
                  paperRecordId: row.paper_record_id,
                  writtenBy: user.id,
                });
                line.remove();
              } catch (error) {
                said.replaceChildren(fail(error));
              }
            },
            "secondary",
          ),
          said,
        );
        return line;
      }

      // Which kinds of measurement belong on a form. Rows rather than a rule in
      // code, so the next form somebody is handed is a row.
      function recordEditor(r: PaperRecord): HTMLElement {
        const said = el("div", {});
        const boxes = operations.map((op) => ({
          op,
          box: checkbox(op.label, false),
        }));
        const holder = el("div", { class: "rows" });

        void (async () => {
          const chosen = new Set(await paperRecordOperations(r.id));
          for (const b of boxes) b.box.input.checked = chosen.has(b.op.id);
          holder.replaceChildren(...boxes.map((b) => b.box.root));
        })();

        return el(
          "details",
          { class: "more" },
          el("summary", {
            text: r.retired_at ? `${r.name} (retired)` : r.name,
          }),
          rows(
            el("p", {
              class: "field-hint",
              text: "Which measurements belong on this form.",
            }),
            holder,
            button(
              "Save what goes on it",
              async () => {
                try {
                  await setPaperRecordOperations(
                    r.id,
                    boxes.filter((b) => b.box.input.checked).map((b) => b.op.id),
                  );
                  said.replaceChildren(banner("Saved.", "good"));
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              "secondary",
            ),
            button(
              r.retired_at ? "Start keeping it again" : "Stop keeping this form",
              async () => {
                try {
                  await retirePaperRecord(r.id, !r.retired_at);
                  go({ at: "paper" });
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              "quiet",
            ),
            el("p", {
              class: "field-hint",
              text: r.retired_at
                ? "Retired, so it collects nothing new. Anything still owed from while it was kept stays owed: see sorry S-59."
                : "Retiring stops new work appearing. It does not clear what is already owed.",
            }),
            said,
          ),
        );
      }

      const newName = field({ label: "Name", placeholder: "Harvest weight sheet" });

      body.replaceChildren(
        rows(
          owed.length === 0
            ? banner(
                records.length === 0
                  ? "No physical forms are set up yet, so nothing is owed to paper."
                  : "Nothing is waiting to be written onto a form.",
                records.length === 0 ? "note" : "good",
              )
            : el("span", {}),

          ...[...byRecord.values()].flatMap((list) => [
            el("h2", {
              class: "section-head",
              text: `${list[0]?.paper_record ?? "Form"} (${list.length})`,
            }),
            el("ul", { class: "vessel-list" }, ...list.map(owedRow)),
          ]),

          el("h2", { class: "section-head", text: "The forms" }),
          records.length === 0
            ? empty("None set up.")
            : el("div", {}, ...records.map(recordEditor)),

          el(
            "details",
            { class: "more" },
            el("summary", { text: "Add a form" }),
            rows(
              newName.root,
              el("p", {
                class: "field-hint",
                text:
                  "It starts owing from now, so adding one today does not invent " +
                  "a backlog stretching to the start of the vintage.",
              }),
              button(
                "Add it",
                async () => {
                  if (!newName.value()) {
                    message.replaceChildren(banner("It needs a name.", "error"));
                    return;
                  }
                  try {
                    await addPaperRecord({ id: newId(), name: newName.value() });
                    go({ at: "paper" });
                  } catch (error) {
                    message.replaceChildren(fail(error));
                  }
                },
                "secondary",
              ),
            ),
          ),
          message,
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

// --- who builds what -------------------------------------------------------

// `0032` made what a maker builds a set, so that somebody who builds both
// barrels and tanks is entered once and flagged twice. That was the winemaker's
// own request and it then had nowhere to be done from: the only route to
// creating a maker is the inline add on a vessel form, which stamps whichever
// kind that form happens to be, and nothing could ever add the second flag.
//
// Found because the assertion suite used Letina as its example of a tank
// fabricator that is not offered for barrels, and Letina is the brand in both.
function makersScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Vessel makers",
    lede(
      "One list, flagged for what each of them builds. A maker flagged for both " +
        "is offered on a barrel and on a tank, entered once.",
    ),
    body,
  );

  void (async () => {
    try {
      const makers = await terms("vessel_maker");

      // A maker written before 0032 carries a single `contract` string instead
      // of a set. Read both, so the boxes show what is true rather than what is
      // in the newer of the two shapes.
      function buildsNow(m: Term): Set<string> {
        const bag = m.attributes ?? {};
        const makes = Array.isArray(bag.makes) ? (bag.makes as string[]) : null;
        if (makes) return new Set(makes);
        return typeof bag.contract === "string" ? new Set([bag.contract]) : new Set();
      }

      body.replaceChildren(
        rows(
          makers.length === 0
            ? empty("No makers yet. They are added from the vessel form as you go.")
            : el(
                "div",
                { class: "rows" },
                ...makers.map((m) => {
                  const now = buildsNow(m);
                  const cooper = checkbox("Barrels", now.has("cooper"));
                  const maker = checkbox("Tanks and bins", now.has("manufacturer"));
                  const said = el("div", {});
                  return el(
                    "div",
                    { class: "rows" },
                    el("h2", { class: "section-head", text: m.label }),
                    cooper.root,
                    maker.root,
                    button(
                      "Save",
                      async () => {
                        const makes = [
                          ...(cooper.input.checked ? ["cooper"] : []),
                          ...(maker.input.checked ? ["manufacturer"] : []),
                        ];
                        try {
                          await setMakerMakes(m.id, makes);
                          said.replaceChildren(
                            banner(
                              makes.length === 0
                                ? // Flagged for nothing is not the same as a
                                  // mistake: 0032 offers an unflagged maker
                                  // everywhere, on the reasoning that somebody
                                  // who has not said is not somebody who said no.
                                  "Saved. Flagged for neither, so it is offered on both."
                                : "Saved.",
                              "good",
                            ),
                          );
                        } catch (error) {
                          said.replaceChildren(fail(error));
                        }
                      },
                      "secondary",
                    ),
                    said,
                  );
                }),
              ),
          message,
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

// --- the stores ------------------------------------------------------------

// What is on the shelf and what to buy, on one screen, because during harvest
// they are one question asked twice.
//
// On hand is derived from what came in and what went out since the last count,
// which is the winemaker's own shape. The number is therefore only as good as
// the recording, and the screen says so rather than presenting it as fact: a
// supply nobody has counted shows when it was last counted as "never".
function storesScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Stores",
    lede(
      "What is on the shelf, worked out from what came in and went out. Counting " +
        "one sets it straight and records by how much it was off.",
    ),
    body,
  );

  void (async () => {
    try {
      const [stock, suggestions, list, user] = await Promise.all([
        suppliesOnHand(),
        suppliesBelowLevel(),
        shoppingList(),
        currentAppUser(),
      ]);

      function amount(s: SupplyOnHand): string {
        return `${Number(s.on_hand).toLocaleString()} ${s.unit}`;
      }

      // Counting and using, in place, because walking the shelf with a phone is
      // the moment both happen.
      function supplyRow(s: SupplyOnHand): HTMLElement {
        const said = el("div", {});
        const used = field({ label: `Used, ${s.unit}`, type: "number" });
        const got = field({ label: `Arrived, ${s.unit}`, type: "number" });
        const counted = field({ label: `Counted, ${s.unit}`, type: "number" });
        const broke = field({ label: `Broken, ${s.unit}`, type: "number" });
        const brokeNote = field({
          label: "What is wrong with it",
          hint:
            "Partly broken and still usable goes here rather than in the number, " +
            "because something usable should not come off what is usable.",
        });

        async function move(
          kind: "used" | "received" | "broken" | "repaired",
          raw: string,
          note?: string,
        ): Promise<void> {
          if (!raw || !user) return;
          try {
            await moveSupply({
              supplyId: s.supply_id,
              kind,
              quantity: Number(raw),
              note: note ?? null,
              byUser: user.id,
            });
            go({ at: "stores" });
          } catch (error) {
            said.replaceChildren(fail(error));
          }
        }

        return el(
          "details",
          { class: "more" },
          el("summary", {
            text:
              s.reorder_level !== null && s.on_hand < s.reorder_level
                ? `${s.name}: ${amount(s)}, below ${s.reorder_level}`
                : `${s.name}: ${amount(s)}`,
          }),
          rows(
            summaryRow(
              "Last counted",
              // Never counted and counted today are different states and a blank
              // would read as the second.
              s.counted_at ? new Date(s.counted_at).toLocaleDateString() : "never",
            ),
            ...(s.supplier ? [summaryRow("From", s.supplier)] : []),
            used.root,
            button("Record use", () => void move("used", used.value()), "secondary"),
            got.root,
            button(
              "Record a delivery",
              () => void move("received", got.value()),
              "secondary",
            ),
            broke.root,
            brokeNote.root,
            button(
              "Mark broken",
              () => void move("broken", broke.value(), brokeNote.value()),
              "secondary",
            ),
            ...(s.broken > 0
              ? [
                  button(
                    `Repair ${s.broken} ${s.unit}`,
                    () => void move("repaired", String(s.broken)),
                    "quiet",
                  ),
                ]
              : []),
            counted.root,
            button(
              "Count it",
              async () => {
                if (!counted.value()) return;
                try {
                  const out = await countSupply(s.supply_id, Number(counted.value()));
                  // The gap is the point. Absorbing it silently would destroy
                  // the one signal that says whether this inventory is worth
                  // believing.
                  said.replaceChildren(
                    banner(
                      out.difference === 0
                        ? `Counted ${out.counted} ${out.unit}, which is exactly what was expected.`
                        : `Counted ${out.counted} ${out.unit} where ${out.expected} was expected, ` +
                            `${out.difference > 0 ? "a surplus" : "a shortfall"} of ` +
                            `${Math.abs(out.difference)} ${out.unit}. That gap is how much use is going unrecorded.`,
                      out.difference === 0 ? "good" : "note",
                    ),
                  );
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              "secondary",
            ),
            said,
          ),
        );
      }

      const newName = field({ label: "Name", placeholder: "DAP" });
      const newUnit = field({ label: "Unit", placeholder: "g" });
      const newLevel = field({
        label: "Tell me below",
        type: "number",
        hint: "Optional. Blank means never suggest it, which is not the same as zero.",
      });
      const newItem = field({ label: "Add to the list", placeholder: "Filter pads" });

      body.replaceChildren(
        rows(
          el("h2", { class: "section-head", text: "Shopping list" }),
          list.length === 0
            ? empty("Nothing on the list.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...list.map((item) =>
                  el(
                    "li",
                    { class: "vessel-row" },
                    el("span", { class: "vessel-name", text: item.what }),
                    ...(item.quantity
                      ? [el("span", { class: "vessel-detail", text: item.quantity })]
                      : []),
                    button(
                      "Bought",
                      async () => {
                        try {
                          await markBought(item.id);
                          go({ at: "stores" });
                        } catch (error) {
                          message.replaceChildren(fail(error));
                        }
                      },
                      "secondary",
                    ),
                  ),
                ),
              ),
          newItem.root,
          button("Add it", async () => {
            if (!newItem.value().trim() || !user) return;
            try {
              await addShoppingItem({
                id: newId(),
                what: newItem.value().trim(),
                added_by: user.id,
              });
              go({ at: "stores" });
            } catch (error) {
              message.replaceChildren(fail(error));
            }
          }),

          // Suggestions, kept visibly apart from the list. The winemaker asked
          // for a list he keeps that is prompted by the derivation, not one that
          // fills itself, so these sit here until somebody agrees with them.
          ...(suggestions.length === 0
            ? []
            : [
                el("h2", { class: "section-head", text: "Running low" }),
                el("p", {
                  class: "lede",
                  text: "Under the level you set. Nothing goes on the list until you say so.",
                }),
                el(
                  "ul",
                  { class: "vessel-list" },
                  ...suggestions.map((s) =>
                    el(
                      "li",
                      { class: "vessel-row" },
                      el("span", { class: "vessel-name", text: s.name }),
                      el("span", {
                        class: "vessel-detail",
                        text: `${amount(s)}, below ${s.reorder_level}`,
                      }),
                      button(
                        "Add to list",
                        async () => {
                          if (!user) return;
                          try {
                            await addShoppingItem({
                              id: newId(),
                              what: s.name,
                              supply_id: s.supply_id,
                              added_by: user.id,
                            });
                            go({ at: "stores" });
                          } catch (error) {
                            message.replaceChildren(fail(error));
                          }
                        },
                        "secondary",
                      ),
                    ),
                  ),
                ),
              ]),

          el("h2", { class: "section-head", text: "On the shelf" }),
          stock.length === 0
            ? empty("No supplies set up yet.")
            : el("div", {}, ...stock.filter((s) => !s.retired_at).map(supplyRow)),

          el(
            "details",
            { class: "more" },
            el("summary", { text: "Add a supply" }),
            rows(
              newName.root,
              newUnit.root,
              newLevel.root,
              el("p", {
                class: "field-hint",
                text:
                  "Nothing converts between units yet, so record deliveries and " +
                  "use in the same one. That is sorry S-63.",
              }),
              button(
                "Add it",
                async () => {
                  if (!newName.value() || !newUnit.value()) {
                    message.replaceChildren(
                      banner("A supply needs a name and a unit.", "error"),
                    );
                    return;
                  }
                  try {
                    await addSupply({
                      id: newId(),
                      name: newName.value(),
                      unit: newUnit.value(),
                      reorder_level: newLevel.value() ? Number(newLevel.value()) : null,
                    });
                    go({ at: "stores" });
                  } catch (error) {
                    message.replaceChildren(fail(error));
                  }
                },
                "secondary",
              ),
            ),
          ),
          message,
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
