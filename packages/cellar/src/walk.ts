import {
  type AppUser,
  type Attachment,
  addBinsToPick,
  addBlock,
  addDayNote,
  addLocation,
  addNote,
  addPaperRecord,
  addParty,
  addPhoto,
  addPlanting,
  addShoppingItem,
  addSupply,
  addTerm,
  addToWine,
  addVessels,
  addVesselTypeNote,
  addVineyard,
  appUsers,
  attachmentsFor,
  type BarrelColour,
  type BinFruit,
  type Block,
  barrelColours,
  barrelWarning,
  bindCode,
  binFruit,
  binInventory,
  binsToReturn,
  blocks,
  cancelPick,
  captionPhoto,
  claimAccount,
  colourConflicts,
  confirmNote,
  contract,
  countSupply,
  createVesselWithWine,
  currentAppUser,
  currentBackend,
  currentSession,
  type DayNote,
  dayLog,
  dayNotes,
  declareBarrelColour,
  drawCut,
  drawToLevel,
  exportCellar,
  facilityParty,
  fillVessel,
  finishPress,
  type GlycolMachineLoad,
  glycolConflicts,
  glycolMachines,
  hookUpGlycol,
  invites,
  jackets,
  type Location,
  type LotWithoutColour,
  type LotWithoutVintage,
  locations,
  lotAdditions,
  lotDetail,
  lotsWithoutColour,
  lotsWithoutVintage,
  makeInvite,
  markBought,
  markPropagated,
  moveSupply,
  moveVessels,
  type NodePayload,
  newId,
  nodeHistory,
  notesFor,
  openPicks,
  type PaperRecord,
  type Party,
  type PastWeighing,
  type PlantingDetail,
  type PressInProgress,
  paperRecordOperations,
  paperRecords,
  parties,
  photoUrl,
  pickBins,
  pickById,
  pickWeighings,
  plantings,
  practiceAvailable,
  pressDraws,
  pressesInProgress,
  type RoomClimate,
  type RunningOperation,
  rackPlan,
  rackTransfer,
  reconditionBarrel,
  registerBins,
  registerGlycolMachine,
  removeDayNote,
  removePick,
  removePlanting,
  resolveCode,
  resolveVesselTypeNote,
  retirePaperRecord,
  rooms,
  running,
  type SampleKind,
  type SiteFields,
  type SubjectNote,
  type SupplyOnHand,
  samples,
  sampleTargets,
  screens,
  setBinFruit,
  setColour,
  setMakerMakes,
  setPaperRecordOperations,
  setPartyLogin,
  setRoomClimate,
  setVesselTypeBin,
  setVesselTypeFields,
  setVintage,
  shoppingList,
  signIn,
  signOut,
  signUp,
  slug,
  startPress,
  suppliesBelowLevel,
  suppliesForAddition,
  suppliesOnHand,
  switchBackend,
  type Term,
  type TermKind,
  type ThermalMode,
  type ToPropagate,
  type TypedFact,
  takeSample,
  terms,
  termsForVesselField,
  toPropagate,
  typedFacts,
  typeNote,
  type UnweighedBin,
  unhookGlycol,
  unwatchSubject,
  unweighedBins,
  updateBlock,
  updatePlanting,
  updateVessel,
  updateVineyard,
  uploadPhoto,
  uploadVesselPhoto,
  type VesselGlycol,
  type VesselRow,
  type VesselState,
  type ViewerScope,
  type Vineyard,
  vesselById,
  vesselByIdOrNull,
  vesselPhotoUrl,
  vesselStateById,
  vessels,
  vesselTypeNotes,
  viewerScope,
  vineyards,
  type Watching,
  watching,
  watchSubject,
  weighBins,
  weighingsWithoutPhoto,
  withdrawInvite,
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
import { pref, prefSet, setPref, setPrefSet } from "./prefs.ts";
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
  type Field,
  field,
  lede,
  on,
  rows,
  screen,
  summaryRow,
  type Variant,
  variantSwitch,
  whenNoteWanted,
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
  // 0101. What the note button on every screen does. Registered here rather
  // than known by ui.ts, which would have to reach the kernel to do it.
  //
  // atPlace is null on the sign in and claim screens, which are not places and
  // have nothing to be a note about, and no button is drawn there because the
  // sheet would have nothing to offer.
  whenNoteWanted(() => {
    const here = atPlace;
    if (!here) return;
    document.body.append(noteSheet(here));
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
      return vesselListScreen(
        await vessels(),
        await locations(),
        await barrelColours(),
        await rooms(),
      );
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
    case "vintages":
      return vintagesScreen();
    case "colours":
      return coloursScreen();
    case "bins":
      return binsScreen();
    case "glycol":
      return glycolScreen();
    case "running":
      return runningScreen();
    case "wine":
      return wineScreen(place.id);
    case "additions":
      return additionsScreen();
    case "practice":
      return practiceScreen();
    case "fact-kinds":
      return factKindsScreen();
    case "invites":
      return invitesScreen(user);
    case "go":
      return paletteScreen();
    case "sampling":
      return samplingScreen();
    case "sample":
      return sampleScreen(place.id);
    case "day":
      return dayScreen(place.id);
    case "paper":
      return paperScreen();
    case "block": {
      const there = (await blocks()).some((b) => b.id === place.id);
      if (!there) throw new GoneError("That block is not there to open.");
      return blockScreen(place.id);
    }
    // Checked before opening for the same reason the block is: a link somebody
    // kept to a vineyard that has since gone should say so.
    case "vineyard": {
      const there = (await vineyards()).some((v) => v.id === place.id);
      if (!there) throw new GoneError("That vineyard is not there to open.");
      return vineyardScreen(place.id);
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
      if (place.at === "vessel") {
        const state = await vesselStateById(vessel.id);
        return vesselChoiceScreen(
          vessel.id,
          vessel.name,
          state?.node_id ?? null,
          state?.lot_name ?? null,
        );
      }
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
        // Always offered while in practice, because practice is the one place
        // where things are expected to break, and the first version of this
        // screen left the winemaker looking at a refusal with no way back to
        // his own cellar. A way out does not belong behind the thing that is
        // broken.
        ...leavePractice(),
      ),
    );
  }
}

/** The escape hatch, on every screen that can strand somebody. Empty when not
 * in practice, so it costs nothing anywhere else. */
function leavePractice(): HTMLElement[] {
  if (currentBackend() !== "practice") return [];
  return [
    el("p", {
      class: "field-hint",
      text: "You are in practice. Nothing here is your real cellar.",
    }),
    button(
      "Leave practice, back to the real cellar",
      () => {
        switchBackend("cellar");
        window.location.assign("#/home");
        window.location.reload();
      },
      "secondary",
    ),
  ];
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
      // Somebody who cannot sign in to practice still has a cellar to go back to.
      ...leavePractice(),
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
  // 0068. Somebody already here has to let you in, from the second person
  // onwards. The first claim on a fresh install needs none, which is what
  // creates the person who issues the rest, so this field is offered rather
  // than required and the kernel decides which case it is.
  const invite = field({
    label: "Invite code",
    placeholder: "K7QM2P",
    hint: "From whoever runs the cellar. Not needed for the very first account.",
  });
  const message = el("div", {});

  return screen(
    "One more thing",
    lede(
      `Signed in as ${email}. The cellar needs a name to put against what you record, ` +
        "and an invite from somebody already here. The very first account needs no " +
        "invite and becomes the administrator, which the database decides rather than " +
        "this screen.",
    ),
    rows(
      name.root,
      invite.root,
      button("Continue", async () => {
        if (!name.value()) return;
        try {
          await claimAccount(name.value(), invite.value() || null);
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
// How somebody has arranged their own home screen, on this phone.
//
// The winemaker, after a fortnight of using it: "I like the idea of being able
// to edit your home screen. Collapse things, add things to subcategories...
// long press an operation and then move it to within another operation."
//
// **The arrangement is per device and never in the URL**, the same as the vessel
// filters and the press layout: a link somebody sends should open the app, not
// somebody else's idea of where things go. Items are identified by their name,
// which is stable enough for a menu and means an arrangement survives a screen
// being rewritten around it.
//
// Nesting is one level deep on purpose. Two levels is a tree, a tree needs cycle
// checks and a way to see where you are, and nobody asked for a tree: they asked
// to tuck three things they rarely use underneath one they do.
const HIDDEN = "home.hidden";
const PARENT = "home.parent";
const COLLAPSED = "home.collapsed";

function hiddenItems(): Set<string> {
  return prefSet(HIDDEN);
}

function parentOf(name: string): string {
  return pref(`${PARENT}.${name}`);
}

function setParent(name: string, parent: string): void {
  setPref(`${PARENT}.${name}`, parent);
}

/** Arrange mode is a screen-level state, so every menu on the screen shows its
 * controls at once. Somebody moving one thing usually moves three. */
let arranging = false;

// An item with nowhere to go is not a dead button, it is a statement about
// what this app does not do yet. Showing them is the same instinct as the
// sorry ledger: a named gap is worth more than a blank space, and the order
// they are in is spec.md section 7, which is ordered by how unrecoverable the
// failure is rather than by what would be fun to build.
function menu(items: MenuItem[], all: MenuItem[] = items): HTMLElement {
  const hidden = hiddenItems();
  const top = items.filter((i) => !parentOf(i.name));

  function itemRow(item: MenuItem, depth = 0): HTMLElement[] {
    if (hidden.has(item.name) && !arranging) return [];
    const children = all.filter((c) => parentOf(c.name) === item.name);

    const row = el(
      "li",
      {
        class:
          `menu-item${item.go ? "" : " menu-soon"}` +
          (depth > 0 ? " menu-nested" : "") +
          (hidden.has(item.name) ? " menu-hidden" : ""),
        ...(item.go && !arranging ? { role: "button", tabindex: "0" } : {}),
      },
      el(
        "span",
        { class: "menu-head" },
        el("span", { class: "menu-name", text: item.name }),
        item.badge ? el("span", { class: "menu-badge", text: item.badge }) : null,
      ),
      el("span", { class: "menu-note", text: item.note }),
      ...(arranging ? [arrangeControls(item, all)] : []),
    );

    if (item.go && !arranging) {
      const open = () => item.go?.();
      on(row, "click", open);
      on(row, "keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          ev.preventDefault();
          open();
        }
      });
      // The shortcut he asked for. A long press anywhere on the menu turns the
      // controls on, which is faster once you know it and undiscoverable until
      // somebody tells you, which is why the button exists as well.
      let timer: number | undefined;
      const start = (): void => {
        timer = window.setTimeout(() => {
          arranging = true;
          void route();
        }, 550);
      };
      const stop = (): void => {
        if (timer) window.clearTimeout(timer);
      };
      on(row, "pointerdown", start);
      on(row, "pointerup", stop);
      on(row, "pointercancel", stop);
      on(row, "pointerleave", stop);
    }

    return [row, ...children.flatMap((c) => itemRow(c, depth + 1))];
  }

  return el("ul", { class: "menu" }, ...top.flatMap((i) => itemRow(i)));
}

// Shown only while arranging. Explicit controls rather than dragging, because a
// drag on a phone with one wet hand is a thing that goes wrong, and because
// "put this inside that" is a choice from a list rather than a gesture.
function arrangeControls(item: MenuItem, all: MenuItem[]): HTMLElement {
  const hidden = hiddenItems();
  const into = el("select", { class: "input menu-arrange-select" });
  into.replaceChildren(
    el("option", { value: "", text: "On its own" }),
    ...all
      // Never inside itself, and never inside something that is already inside
      // something, which is the whole of the cycle check at one level deep.
      .filter((other) => other.name !== item.name && !parentOf(other.name))
      .map((other) =>
        el("option", {
          value: other.name,
          text: `Inside ${other.name}`,
          ...(parentOf(item.name) === other.name ? { selected: "true" } : {}),
        }),
      ),
  );
  on(into, "change", () => {
    setParent(item.name, into.value);
    void route();
  });

  return el(
    "span",
    { class: "menu-arrange" },
    into,
    button(
      hidden.has(item.name) ? "Show" : "Hide",
      () => {
        const next = hiddenItems();
        if (next.has(item.name)) next.delete(item.name);
        else next.add(item.name);
        setPrefSet(HIDDEN, next);
        void route();
      },
      "quiet",
    ),
  );
}

/** A section that remembers whether somebody folded it away. */
function section(title: string, ...body: Node[]): HTMLElement {
  const collapsed = prefSet(COLLAPSED);
  const shut = collapsed.has(title);
  const head = el("h2", {
    class: `section-head section-toggle${shut ? " section-shut" : ""}`,
    role: "button",
    tabindex: "0",
    text: shut ? `${title}  (folded)` : title,
  });
  const toggle = (): void => {
    const next = prefSet(COLLAPSED);
    if (next.has(title)) next.delete(title);
    else next.add(title);
    setPrefSet(COLLAPSED, next);
    void route();
  };
  on(head, "click", toggle);
  on(head, "keydown", (ev) => {
    if (ev.key === "Enter" || ev.key === " ") {
      ev.preventDefault();
      toggle();
    }
  });
  return el("div", { class: "section" }, head, ...(shut ? [] : body));
}

async function homeScreen(user: AppUser, facility: Party): Promise<HTMLElement> {
  const practising = currentBackend() === "practice";
  const [
    places,
    kit,
    unweighed,
    owedBins,
    owedPaper,
    buying,
    silent,
    pressing,
    uncoloured,
    clashes,
    inFlight,
  ] = await Promise.all([
    locations(),
    vessels(),
    unweighedBins(),
    binsToReturn(),
    toPropagate(),
    shoppingList(),
    lotsWithoutVintage(),
    pressesInProgress(),
    lotsWithoutColour(),
    colourConflicts(),
    running(),
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

  const harvest: MenuItem[] = [
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
      name: "Sampling",
      note:
        "What was sampled and what it read. A vineyard, a block, one variety " +
        "in one block, or a tank with wine in it.",
      go: () => go({ at: "sampling" }),
    },
    {
      name: "Press",
      note:
        pressing.length > 0
          ? "A press is running. Record the litres as they come off."
          : "Fruit in, juice out. Where the lot gets the name it keeps.",
      // The badge is the whole of "pop off to other vessels and pop back in":
      // a press is deliberately unfinished for hours, and it is the one thing
      // on this screen somebody has to be able to find without remembering
      // where they left it.
      ...(pressing.length > 0
        ? {
            badge:
              pressing.length === 1
                ? `${Number(pressing[0]?.litres_so_far ?? 0).toLocaleString()} L so far`
                : `${pressing.length} running`,
          }
        : {}),
      go: () => go({ at: "press" }),
    },
    {
      name: "Bins to return",
      note: "Borrowed bins that are empty. Owed back rather than available.",
      ...(owed > 0 ? { badge: String(owed) } : {}),
      go: () => go({ at: "bins-to-return" }),
    },
  ];

  const cellar: MenuItem[] = [
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
      name: "Additions",
      note: "What went into the wine, and off the shelf at the same time.",
      go: () => go({ at: "additions" }),
    },
    // 0095. First, and only when there is something in it. A heading that is
    // permanently present and permanently empty is one people stop seeing, and
    // this one is worth seeing.
    ...(inFlight.length > 0
      ? [
          {
            name: "Running",
            note: "Started and not finished.",
            badge: String(inFlight.length),
            go: () => go({ at: "running" }),
          },
        ]
      : []),
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
    // Only while there is one. The list can only shrink, so this entry is
    // temporary by construction and leaving it behind empty would be a
    // permanent reminder of a job that is finished.
    ...(silent.length > 0
      ? [
          {
            name: "Lots without a vintage",
            note:
              "Recorded before the app asked. Say which year, or that it is " +
              "non-vintage.",
            badge: String(silent.length),
            go: () => go({ at: "vintages" }),
          },
        ]
      : []),
    // 0072. Two counts, one entry. A lot with no colour is why a barrel reads
    // unknown, and a white sitting in a red barrel is the thing that count is
    // for, so putting them behind separate doors would hide the second behind
    // the first. Always present rather than conditional, unlike the vintage
    // list above: that one can only shrink and this one fills up every time
    // fruit comes in.
    {
      name: "Colour",
      note:
        clashes.length > 0
          ? "A wine is sitting in a barrel that has held red."
          : "What colour each wine is, and what that has made of the barrels.",
      ...(clashes.length > 0
        ? { badge: `${clashes.length} to look at` }
        : uncoloured.length > 0
          ? { badge: `${uncoloured.length} to say` }
          : {}),
      go: () => go({ at: "colours" }),
    },
  ];

  const setup: MenuItem[] = [
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
      name: "Kinds of fact",
      note: "What a note can be turned into. Brix, pH, fruit condition, whatever else you measure.",
      go: () => go({ at: "fact-kinds" }),
    },
    {
      name: "Vineyards",
      note: "Where fruit comes from. Blocks, and what is planted in them.",
      go: () => go({ at: "vineyards" }),
    },
    {
      name: "Picking bins",
      note: "How many there are and whose they are. Register a stack at a time.",
      go: () => go({ at: "bins" }),
    },
    {
      name: "Glycol",
      note: "Each machine and the jackets hanging off it. Move a hose, see what is on what.",
      go: () => go({ at: "glycol" }),
    },
    {
      name: "Clients",
      note: "Custom crush clients, and which login sees their wine.",
      go: () => go({ at: "clients" }),
    },
    {
      name: "Letting somebody in",
      note: "An invite code for a new intern. Six characters, good for a week, used once.",
      go: () => go({ at: "invites" }),
    },
    {
      name: "Take a copy",
      note:
        "Everything you can read, as one file on your phone. The cellar lives " +
        "on one machine, so a copy elsewhere is what makes it survivable.",
      go: () => go({ at: "export" }),
    },
    // Only when a practice stack is actually configured. Offering it in a
    // build with nothing behind it means somebody turns it on and every
    // screen fails to load with no explanation.
    ...(practiceAvailable()
      ? [
          {
            name: practising ? "Leave practice" : "Practice mode",
            note: practising
              ? "Go back to the real cellar. What you did in practice stays in practice."
              : "A second cellar with nothing real in it. Try anything, break anything, throw it away.",
            ...(practising ? { badge: "on" } : {}),
            go: () => go({ at: "practice" }),
          },
        ]
      : []),
  ];

  const soon: MenuItem[] = [
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
  ];

  // Every item on the screen, handed to each menu so that somebody can tuck
  // a thing from one section underneath a thing in another. Which section an
  // item was written in is the app's opinion; where it ends up is theirs.
  const everything: MenuItem[] = [...harvest, ...cellar, ...setup, ...soon];

  // The way in, because a long press is undiscoverable until somebody tells you.
  const arrangeBar = el(
    "div",
    { class: "arrange-bar" },
    arranging
      ? button("Done arranging", () => {
          arranging = false;
          void route();
        })
      : button(
          "Arrange this screen",
          () => {
            arranging = true;
            void route();
          },
          "quiet",
        ),
    arranging
      ? el("span", {
          class: "field-hint",
          text:
            "Hide what you never use, or put something inside something else. " +
            "Tap a heading to fold a whole section away. This phone only.",
        })
      : el("span", {
          class: "field-hint",
          text: "Or press and hold anything below.",
        }),
    ...(arranging
      ? [
          button(
            "Put everything back",
            () => {
              for (const item of everything) setParent(item.name, "");
              setPrefSet("home.hidden", []);
              setPrefSet("home.collapsed", []);
              void route();
            },
            "quiet",
          ),
        ]
      : []),
  );

  return screen(
    facility.name,
    lede(`${user.name}, ${user.role}. What would you like to do?`),
    button("Go anywhere", () => go({ at: "go" }), "secondary"),
    arrangeBar,
    section("Harvest", menu(harvest, everything)),
    section("In the cellar", menu(cellar, everything)),
    section("Set up", menu(setup, everything)),
    section("Not built yet", menu(soon, everything)),
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

// The winemaker, with sixty vessels and counting: "in vessels I'd love to be
// able to sort them in a bunch of different ways. Like include and exclude
// types, sort by status, sort by name, etc."
//
// All of it client side and none of it in the URL. A sort order is a way of
// looking at a list rather than a place, so it does not belong in a Place: a
// link somebody sends should open the vessels, not somebody else's filter.
//
// The choices persist per device in `prefs.ts`. They shipped against `sticky.ts`
// first, which is in memory and pin-gated, so every control worked and every
// choice was thrown away on reload with nothing to show for it. See prefs.ts for
// why there are three stores now and what each is for.
type VesselOrder =
  | "name"
  | "fullest"
  | "emptiest"
  | "type"
  | "recent"
  | "vintage"
  // Two different questions, and at a custom crush winery they routinely
  // have different answers: a client's wine in our barrel, our wine in a
  // client's tank. "Another thing to sort by in vessels: owners" is
  // ambiguous between them, so both are offered rather than guessed at.
  | "wine-owner"
  | "vessel-owner";

// What to call a vessel's owner. owner_name is null for a vessel this winery
// owns outright, which is a name in the list rather than a blank.
function vesselOwner(v: VesselState): string {
  return v.owner_name ?? "Ours";
}

function vesselListScreen(
  kit: VesselState[],
  places: Location[],
  barrels: BarrelColour[],
  climate: RoomClimate[],
): HTMLElement {
  const body = el("div", {});
  const count = el("p", { class: "lede" });
  // Outside the bar on purpose: the bar is rebuilt on every draw, and a
  // confirmation written into it disappears in the same tick it is created.
  const notice = el("div", {});

  // Types present, from the vessels themselves rather than from the vocabulary,
  // so a type nobody owns one of does not appear as a filter that empties the
  // list.
  const types = [...new Set(kit.map((v) => v.type))].sort();
  const excluded = prefSet("vessel_filter_out");
  // 0099. "Another thing to add for sorting vessels, by vintage. Maybe just
  // 2024/2025/2026/NV?"
  //
  // Those are this cellar's years today and they are not written down anywhere,
  // because a list of years in the client is a list somebody has to edit every
  // September. It is what the vessels are actually holding, newest first, with
  // NV after the years because it belongs to no year rather than to the oldest
  // one. `vintage_label` is the kernel's answer, so a screen never decides
  // whether a blank means NV.
  const years = [
    ...new Set(
      kit
        .map((v) => v.vintage_label)
        .filter((x): x is string => x !== null && x !== "NV"),
    ),
  ].sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  const vintages = [
    ...years,
    ...(kit.some((v) => v.vintage_label === "NV") ? ["NV"] : []),
    // Only offered when there is one, because a filter that can only ever empty
    // the list is a control that teaches somebody the screen is broken.
    ...(kit.some((v) => !v.is_empty && v.vintage_label === null) ? ["said"] : []),
  ];
  // Whose wine, from the vessels themselves. Same reason the vintages are not
  // written down: a client list in the client goes stale the first time
  // somebody new brings fruit in.
  const wineOwners = [
    ...new Set(
      kit
        .filter((v) => !v.is_empty)
        .map((v) => v.lot_owner_name)
        .filter((x): x is string => !!x),
    ),
  ].sort();
  let owner = pref("vessel_owner") || "";
  if (owner && !wineOwners.includes(owner)) {
    owner = "";
    setPref("vessel_owner", "");
  }
  let vintage = pref("vessel_vintage") || "";
  // A vintage this device chose last month that nothing is holding any more.
  // Left standing it hides every vessel while the control beside the empty list
  // reads blank, because the value is not one of its options: a filter that is
  // on, invisible, and unexplained.
  if (vintage && !vintages.includes(vintage)) {
    vintage = "";
    setPref("vessel_vintage", "");
  }
  // 0088. "I'd love to be able to select 6 barrels to move to a new room, or
  // put the 5 picking bins in the south bay, without doing it individually."
  //
  // Not sticky, unlike the filters: a selection is about the next thirty
  // seconds, and a device that reopened the vessels screen holding six barrels
  // somebody chose yesterday would be holding a loaded gun.
  const picked = new Set<string>();
  let selecting = false;
  // One object, handed to whichever view is drawn, so the list and the map
  // cannot disagree about what is chosen.
  const selection: Selecting = {
    get on() {
      return selecting;
    },
    has: (id) => picked.has(id),
    toggle: (id) => {
      if (picked.has(id)) picked.delete(id);
      else picked.add(id);
      draw();
    },
    // What a long press means: turn choosing on and take the thing under the
    // finger with it.
    begin: (id) => {
      selecting = true;
      picked.add(id);
      draw();
    },
  };
  let order: VesselOrder = (pref("vessel_order") as VesselOrder) || "name";
  let onlyFull = pref("vessel_only") === "full";
  let onlyEmpty = pref("vessel_only") === "empty";

  function shown(): VesselState[] {
    let out = kit.filter((v) => !excluded.has(v.type));
    if (onlyFull) out = out.filter((v) => !v.is_empty);
    if (onlyEmpty) out = out.filter((v) => v.is_empty);
    // An empty vessel is in no vintage, so choosing one drops the empties. That
    // is the point of choosing one: "show me the 2025" is asked by somebody
    // looking for wine, and the Show control above is where empties come back.
    // Whose wine, so an empty vessel is not an answer to it. The Show control
    // above is where the empties come back.
    if (owner) out = out.filter((v) => v.lot_owner_name === owner);
    if (vintage === "said") {
      out = out.filter((v) => !v.is_empty && v.vintage_label === null);
    } else if (vintage) {
      out = out.filter((v) => v.vintage_label === vintage);
    }

    const fullness = (v: VesselState): number =>
      v.capacity_l !== null && v.current_volume_l !== null && Number(v.capacity_l) > 0
        ? Number(v.current_volume_l) / Number(v.capacity_l)
        : -1;

    const by: Record<VesselOrder, (a: VesselState, b: VesselState) => number> = {
      name: (a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }),
      // Numeric collation, because B10 sorts before B9 otherwise and a barrel
      // room is numbered.
      type: (a, b) =>
        a.type.localeCompare(b.type) ||
        a.name.localeCompare(b.name, undefined, { numeric: true }),
      fullest: (a, b) => fullness(b) - fullness(a),
      emptiest: (a, b) => fullness(a) - fullness(b),
      // When the wine went in, newest first, with the empty ones after. Not
      // when the vessel was registered: `vessel_state` does not carry that, and
      // "what did I fill most recently" is the question somebody actually asks
      // standing in the barrel room.
      recent: (a, b) =>
        (b.filled_at ?? "").localeCompare(a.filled_at ?? "") ||
        a.name.localeCompare(b.name, undefined, { numeric: true }),
      // Whose wine, with the empty vessels last: a vessel with nothing in it
      // has no owner rather than an owner whose name sorts early.
      "wine-owner": (a, b) =>
        (a.is_empty ? 1 : 0) - (b.is_empty ? 1 : 0) ||
        (a.lot_owner_name ?? "").localeCompare(b.lot_owner_name ?? "") ||
        a.name.localeCompare(b.name, undefined, { numeric: true }),
      // Whose vessel. Every vessel has an answer, because facility owned is one.
      "vessel-owner": (a, b) =>
        vesselOwner(a).localeCompare(vesselOwner(b)) ||
        a.name.localeCompare(b.name, undefined, { numeric: true }),
      // Newest vintage first, NV after the years, and the empties last. An
      // empty vessel has no vintage rather than an early one, so it sorts to
      // the end instead of ahead of 2024.
      vintage: (a, b) => {
        const rank = (v: VesselState): string =>
          v.vintage_label === null
            ? "0"
            : v.vintage_label === "NV"
              ? "1"
              : `2${v.vintage_label}`;
        return (
          rank(b).localeCompare(rank(a), undefined, { numeric: true }) ||
          a.name.localeCompare(b.name, undefined, { numeric: true })
        );
      },
    };
    return out.sort(by[order]);
  }

  const views: Variant<void>[] = [
    {
      key: "list",
      label: "List",
      note: "Sortable, filterable, and it tells you the numbers exactly.",
      render: () => vesselList(shown(), selection),
    },
    {
      key: "map",
      label: "Map",
      note: "The rooms, with what is standing in them. Sized by capacity, filled by how full.",
      // The map takes the same selection, because six barrels to a new room is
      // a thing somebody does looking at where the barrels are, which is the
      // map's whole argument.
      render: () => cellarMapLayout(shown(), places, barrels, climate, selection),
    },
  ];

  // Everything the batch bar needs, rebuilt on every draw because the count in
  // it is the whole point of it.
  function batchBar(list: VesselState[]): HTMLElement {
    if (!selecting) {
      return el(
        "div",
        { class: "button-row" },
        button(
          "Select several",
          () => {
            selecting = true;
            draw();
          },
          "quiet",
        ),
      );
    }

    const here = list.filter((v) => picked.has(v.id)).length;
    const hidden = picked.size - here;
    const where = el("select", { class: "input" });
    where.replaceChildren(
      el("option", { value: "", text: "Which room" }),
      ...places.map((pl) => el("option", { value: pl.id, text: pl.name })),
    );
    const said = el("div", {});

    return el(
      "div",
      { class: "batch-bar" },
      el("span", {
        class: "field-label",
        text:
          picked.size === 0
            ? "Tap vessels to choose them."
            : `${picked.size} chosen` +
              // A selection the filters are hiding is the one way a batch
              // surprises somebody: they see two ticks and move six.
              (hidden > 0 ? `, ${hidden} of them hidden by the filters` : ""),
      }),
      where,
      el(
        "div",
        { class: "button-row" },
        button("Move them", async () => {
          if (picked.size === 0) {
            said.replaceChildren(banner("Nothing is chosen.", "error"));
            return;
          }
          if (!where.value) {
            said.replaceChildren(banner("Say which room.", "error"));
            return;
          }
          try {
            const going = [...picked];
            const out = await moveVessels(going, where.value);
            // The rows this screen is holding are now stale in one field. Told
            // rather than refetched: a reload here would throw away the sort,
            // the filters and the place in the list somebody had scrolled to.
            for (const v of kit) {
              if (going.includes(v.id)) v.location_name = out.location;
            }
            picked.clear();
            selecting = false;
            notice.replaceChildren(
              banner(
                `Moved ${out.moved} ${out.moved === 1 ? "vessel" : "vessels"} to ${out.location}.`,
                "good",
              ),
            );
            draw();
          } catch (error) {
            said.replaceChildren(fail(error));
          }
        }),
        button(
          "Done",
          () => {
            selecting = false;
            picked.clear();
            draw();
          },
          "quiet",
        ),
      ),
      said,
    );
  }

  function draw(): void {
    const list = shown();
    count.textContent =
      list.length === kit.length
        ? `${kit.filter((v) => !v.is_empty).length} of ${kit.length} have wine in them.`
        : `${list.length} of ${kit.length} shown, ` +
          `${list.filter((v) => !v.is_empty).length} with wine in them.`;
    const chosen = pref("vessel_view", "list");
    const view = views.find((v) => v.key === chosen) ?? views[0];
    body.replaceChildren(
      // Above the list rather than under it. Under twenty one vessels and the
      // layout switcher is a control nobody scrolls to, which is how it first
      // shipped and why the winemaker could not find it.
      batchBar(list),
      list.length === 0
        ? empty("Nothing matches. Widen the filters above.")
        : (view?.render() ?? vesselList(list)),
      variantSwitch(views, view?.key ?? "list", (key) => {
        setPref("vessel_view", key);
        draw();
      }),
    );
  }

  const sort = el("select", { class: "input" });
  sort.replaceChildren(
    el("option", { value: "name", text: "Name" }),
    el("option", { value: "type", text: "Type, then name" }),
    el("option", { value: "fullest", text: "Fullest first" }),
    el("option", { value: "emptiest", text: "Emptiest first" }),
    el("option", { value: "recent", text: "Most recently filled" }),
    el("option", { value: "vintage", text: "Vintage, newest first" }),
    el("option", { value: "wine-owner", text: "Whose wine, then name" }),
    el("option", { value: "vessel-owner", text: "Whose vessel, then name" }),
  );
  sort.value = order;
  on(sort, "change", () => {
    order = sort.value as VesselOrder;
    setPref("vessel_order", order);
    draw();
  });

  const status = el("select", { class: "input" });
  status.replaceChildren(
    el("option", { value: "", text: "Full and empty" }),
    el("option", { value: "full", text: "Only ones with wine" }),
    el("option", { value: "empty", text: "Only empty ones" }),
  );
  status.value = onlyFull ? "full" : onlyEmpty ? "empty" : "";
  on(status, "change", () => {
    onlyFull = status.value === "full";
    onlyEmpty = status.value === "empty";
    setPref("vessel_only", status.value);
    draw();
  });

  const whose = el("select", { class: "input" });
  whose.replaceChildren(
    el("option", { value: "", text: "Anybody's wine" }),
    ...wineOwners.map((o) => el("option", { value: o, text: o })),
  );
  whose.value = owner;
  on(whose, "change", () => {
    owner = whose.value;
    setPref("vessel_owner", owner);
    draw();
  });

  // One at a time rather than ticks, unlike the types. Types are a "these three
  // kinds of thing" question and vintage is a "show me the 2025" one, which is
  // one tap here and four unticks the other way.
  const which = el("select", { class: "input" });
  which.replaceChildren(
    el("option", { value: "", text: "Every vintage" }),
    ...vintages.map((y) =>
      el("option", {
        value: y,
        text: y === "NV" ? "NV" : y === "said" ? "No vintage said" : y,
      }),
    ),
  );
  which.value = vintage;
  on(which, "change", () => {
    vintage = which.value;
    setPref("vessel_vintage", vintage);
    draw();
  });

  // Ticked means shown. Exclusion is the thing he asked for and inclusion is
  // how it reads: nobody thinks in terms of what they are hiding.
  const typeBoxes = types.map((t) => {
    const box = checkbox(t, !excluded.has(t));
    on(box.input, "change", () => {
      if (box.input.checked) excluded.delete(t);
      else excluded.add(t);
      setPrefSet("vessel_filter_out", excluded);
      draw();
    });
    return box.root;
  });

  draw();

  return screen(
    "Vessels",
    kit.length === 0 ? lede("Nothing yet.") : count,
    notice,
    kit.length === 0
      ? empty(
          // W-9 phase 4. "No vessels yet" is only true for somebody who can see
          // all of them. describeEmpty is the one place that difference is said.
          `${describeEmpty("vessels", scope)} The first one is the longest; the rest remember your answers.`,
        )
      : el(
          "div",
          {},
          el(
            "details",
            { class: "more" },
            el("summary", { text: "Sort and filter" }),
            rows(
              el(
                "div",
                { class: "field" },
                el("span", { class: "field-label", text: "Sort by" }),
                sort,
              ),
              el(
                "div",
                { class: "field" },
                el("span", { class: "field-label", text: "Show" }),
                status,
              ),
              // Only when there is more than one, so a cellar holding a single
              // vintage does not carry a control with one answer.
              ...(vintages.length > 1
                ? [
                    el(
                      "div",
                      { class: "field" },
                      el("span", { class: "field-label", text: "Vintage" }),
                      which,
                    ),
                  ]
                : []),
              // Same rule. A winery with no custom crush clients sees no
              // control, because every answer would be its own name.
              ...(wineOwners.length > 1
                ? [
                    el(
                      "div",
                      { class: "field" },
                      el("span", { class: "field-label", text: "Whose wine" }),
                      whose,
                    ),
                  ]
                : []),
              ...(types.length > 1
                ? [el("span", { class: "field-label", text: "Types" }), ...typeBoxes]
                : []),
            ),
          ),
          body,
        ),
    button("Back", () => goBack(), "quiet"),
  );
}

// --- the cellar as a place -------------------------------------------------

// "Locations being an actual location with little barrels and vessels in it or
// something."
//
// Both established winery systems have this and neither treats it as
// decoration. vintrace calls it a bird's eye view for displaying and planning
// the layout of the tanks; InnoVint renders a top-down and a 3D one and, more
// to the point, overlays "lot code, date filled, current volume" onto the vessel
// itself. **The map is the vessel list with position as the organising axis
// instead of a sort order**, and what makes it worth having is what is written
// on each shape.
//
// **Nothing is positioned by hand and that is on purpose for a first look.**
// Asking somebody to place sixty vessels before they can see anything is how a
// feature goes unused. So this lays them out by room, in rows, sized by
// capacity, and if the arrangement is wrong the answer is to let him drag them,
// which is half a day and wants his opinion on this first.
//
// What is drawn on each one is the whole argument: the name, how full it is as a
// height rather than a number, and whose wine it is when it is not ours. A
// vessel somebody else owns is the thing you most need to not make a mistake
// with, and a list buries that in a column.
// A snowflake and a flame, drawn rather than typed. An emoji would be a
// different picture on every phone in the barn and a different size on each,
// and this has to read at 14px on a shape the size of a thumbnail. Both take
// their colour from the text around them, so the skins keep control of it.
function thermalBadge(mode: ThermalMode, temp: number | null): HTMLElement {
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", "0 0 16 16");
  svg.setAttribute("class", "thermal-icon");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS(ns, "path");
  if (mode === "cooling") {
    // Three crossed strokes plus four small arms: a snowflake reads as one at
    // this size, where anything more detailed turns to mud.
    path.setAttribute(
      "d",
      "M8 1v14M2 4.5l12 7M14 4.5l-12 7M8 4.2 6 2.6M8 4.2l2-1.6M8 11.8l-2 1.6M8 11.8l2 1.6",
    );
  } else {
    // A flame, in one stroke, leaning the way a flame leans.
    path.setAttribute(
      "d",
      "M8 15c3 0 4.6-2 4.6-4.2 0-3.2-3.4-4.4-2.6-8.3C7.6 3.4 6 5.6 6 7.4c0 1 .4 1.7.4 2.3 0 .8-.6 1.2-1.2 1.2-.7 0-1.2-.6-1.3-1.5-.6.8-.9 1.7-.9 2.6C3 13.4 5 15 8 15Z",
    );
  }
  path.setAttribute("fill", "none");
  path.setAttribute("stroke", "currentColor");
  path.setAttribute("stroke-width", "1.3");
  path.setAttribute("stroke-linecap", "round");
  path.setAttribute("stroke-linejoin", "round");
  svg.appendChild(path);

  return el(
    "span",
    { class: `thermal thermal-${mode}` },
    svg,
    el("span", {
      class: "thermal-temp",
      // The number is the fact and the colour is the feeling. A held vessel
      // with no setpoint recorded still says it is held.
      text: temp === null ? "" : `${Number(temp).toFixed(temp % 1 === 0 ? 0 : 1)}C`,
    }),
  );
}

function cellarMapLayout(
  kit: VesselState[],
  places: Location[],
  barrels: BarrelColour[] = [],
  climate: RoomClimate[] = [],
  sel?: Selecting,
): Node {
  // 0079. Which way each room is held, by name, because the map groups by the
  // room's name and a vessel carries the name rather than the id.
  const roomClimate = new Map(climate.map((r) => [r.name, r]));
  // 0072. A barrel is red, white or unknown, derived from what has been in it.
  // On a map it is a rim colour rather than a word, because the question it
  // answers is asked while standing in the barrel room looking for somewhere to
  // put a white, and a person scanning a wall of shapes is not reading labels.
  const colourOf = new Map(barrels.map((b) => [b.id, b.colour]));
  // Grouped by the room it stands in. A vessel with no location is in its own
  // group at the end rather than hidden: "nobody has said where this is" is a
  // real state and the map is where it becomes obvious.
  const byPlace = new Map<string, VesselState[]>();
  for (const v of kit) {
    const key = v.location_name ?? "";
    const list = byPlace.get(key) ?? [];
    list.push(v);
    byPlace.set(key, list);
  }

  const roomOrder = [
    ...places.map((p) => p.name).filter((n) => byPlace.has(n)),
    ...[...byPlace.keys()].filter((k) => k !== "" && !places.some((p) => p.name === k)),
    ...(byPlace.has("") ? [""] : []),
  ];

  function vesselShape(v: VesselState): HTMLElement {
    const cap = v.capacity_l === null ? null : Number(v.capacity_l);
    const held = v.current_volume_l === null ? 0 : Number(v.current_volume_l);
    // A bin's fill is how full of fruit it is, which bin_fruit already resolves
    // from whichever half somebody said. Without this every bin draws empty,
    // because a bin has no litres in it and never will.
    const fill =
      v.fruit_pct !== null
        ? Math.min(Number(v.fruit_pct) / 100, 1)
        : cap && cap > 0
          ? Math.min(held / cap, 1)
          : 0;

    // Sized by capacity, within limits, so a 2200 L tank reads as bigger than a
    // 228 L barrel without a 500 L one being invisible. The scale is a cube
    // root, because volume is a volume and a linear scale makes the small ones
    // vanish.
    const size = cap
      ? Math.max(46, Math.min(104, Math.round(26 * Math.cbrt(cap / 10))))
      : 52;

    const shape = el(
      "button",
      {
        type: "button",
        class:
          `map-vessel map-${v.type.toLowerCase().replace(/[^a-z]+/g, "-")}` +
          (cap ? "" : " map-nosize") +
          (v.is_empty ? " map-empty" : "") +
          (colourOf.has(v.id) ? ` map-barrel-${colourOf.get(v.id)}` : "") +
          // Held cold, held warm, or neither. A jacket that is off is not a
          // jacket that is doing something, so `has_glycol` is not the test:
          // what the vessel is doing right now is.
          (v.mode === "off" ? "" : ` map-${v.mode}`) +
          (size < 72 ? " map-small" : "") +
          (v.lot_facility_owned === false ? " map-theirs" : ""),
        style: `--size:${size}px; --fill:${fill.toFixed(3)}`,
        title:
          `${v.name}, ${v.type}` +
          (cap ? `, ${cap.toLocaleString()} L` : "") +
          (v.is_empty
            ? ", empty"
            : `, ${held.toLocaleString()} L of ${v.lot_name ?? "wine"}`) +
          (v.mode === "off"
            ? ""
            : `, ${v.mode} to ${v.setpoint_c ?? "an unrecorded setpoint"}`),
      },
      el("span", { class: "map-fill" }),
      // The winemaker: "instead of saying the vessel name on the vessel (Eric,
      // intern Randy, etc) it should say the wine in the vessel". The shape is
      // the vessel; what you need to read off a wall of them is what is in
      // each. An empty one has nothing to say but its own name, which is also
      // when its name is the thing you want, because you are looking for
      // somewhere to put something.
      el("span", {
        class: "map-name",
        // A barrel is 52 pixels across and "Cynic Pinot Gris 2025" is not. On a
        // small shape the variety and the year are what somebody says out loud
        // in a barrel room anyway, and the full name is one tap away; on a
        // shape with room, the lot's own name is better because two barrels of
        // one variety and year are otherwise identical.
        text: v.is_empty
          ? v.name
          : size < 72 && v.variety
            ? `${v.variety}${v.vintage ? ` ${String(v.vintage).slice(-2)}` : ""}`
            : (v.lot_name ?? "wine"),
      }),
      // And the vessel underneath, where there is room for it. A 52 pixel
      // barrel gets one line and the name arrives on tap; anything bigger can
      // carry both, which is what makes "where is Eric" answerable without
      // leaving the map.
      ...(v.is_empty || size < 72
        ? []
        : [el("span", { class: "map-vessel-name", text: v.name })]),
      // The number, because a height is a feeling and somebody deciding where
      // 400 litres will fit needs the figure.
      el("span", {
        class: "map-litres",
        // Pounds on a bin, litres on everything else. The figure on a shape is
        // whatever unit the thing in it is actually measured in.
        text: v.is_empty
          ? ""
          : v.fruit_lbs !== null
            ? `${Math.round(Number(v.fruit_lbs))} lb`
            : `${Math.round(held)}`,
      }),
      // The setpoint rather than the room: a jacketed vessel overrides what the
      // room is doing, which is what `effective_temp_c` has meant since 0006.
      ...(v.mode === "off" ? [] : [thermalBadge(v.mode, v.setpoint_c)]),
    );

    // Always the choice screen, for the same reason the list rows are: a barrel
    // on a map is a barrel with wine in it, and the wine is usually what
    // somebody tapping it wants. While choosing, a tap chooses instead.
    on(shape, "click", () => {
      if (sel?.on) sel.toggle(v.id);
      else go({ at: "vessel", id: v.id });
    });
    if (sel?.on && sel.has(v.id)) shape.classList.add("map-chosen");

    // And the same long press, because six barrels to a new room is a thing
    // somebody does while looking at where the barrels are.
    if (sel && !sel.on) {
      let timer: number | undefined;
      const start = (): void => {
        timer = window.setTimeout(() => sel.begin(v.id), 550);
      };
      const stop = (): void => {
        if (timer) window.clearTimeout(timer);
      };
      on(shape, "pointerdown", start);
      on(shape, "pointerup", stop);
      on(shape, "pointercancel", stop);
      on(shape, "pointerleave", stop);
    }
    return shape;
  }

  return el(
    "div",
    { class: "cellar-map" },
    ...roomOrder.map((room) => {
      const here = byPlace.get(room) ?? [];
      const full = here.filter((v) => !v.is_empty).length;
      const litres = here.reduce((sum, v) => sum + Number(v.current_volume_l ?? 0), 0);
      // The room itself, which is the negative space behind the shapes. A room
      // that is controlled and has not said which way it is held gets the
      // temperature and no colour, because that is the honest picture of what
      // anybody knows about it.
      const air = roomClimate.get(room);
      // 0097. `held` is derived from how far the room sits from room
      // temperature; `mode` is only what somebody said. Reading the told one
      // meant a cold room looked like nothing until it was labelled by hand.
      const holding = air && air.held !== "off" ? air.held : null;
      return el(
        "div",
        { class: `map-room${holding ? ` map-room-${holding}` : ""}` },
        el(
          "div",
          { class: "map-room-head" },
          el(
            "span",
            { class: "map-room-title" },
            el("span", {
              class: "map-room-name",
              text: room === "" ? "Nobody has said where these are" : room,
            }),
            ...(holding ? [thermalBadge(holding, air?.ambient_c ?? null)] : []),
          ),
          el("span", {
            class: "map-room-note",
            text:
              `${full} of ${here.length} holding wine` +
              (litres > 0 ? `, ${Math.round(litres).toLocaleString()} L` : ""),
          }),
          // Controlled and sitting at room temperature, which is a real state
          // and not a gap: somebody is holding it where it would be anyway.
          ...(air?.controlled && !holding
            ? [
                el("span", {
                  class: "map-room-note",
                  text: `held at ${air.ambient_c ?? "an unrecorded temperature"}, which is room temperature here`,
                }),
              ]
            : []),
        ),
        el("div", { class: "map-floor" }, ...here.map(vesselShape)),
      );
    }),
  );
}

// Whether the barrel and the wine in it belong to the same party. Both being
// the facility counts as the same; one of each never does.
function sameOwner(v: VesselState): boolean {
  if (v.facility_owned !== v.lot_facility_owned) return false;
  if (v.facility_owned) return true;
  return v.owner_id === v.lot_owner_id;
}

// How a row behaves when the screen is choosing rather than browsing. Passed
// in rather than reached for, because this list is also rendered from the scan
// screen and from the palette, where there is nothing to select into.
type Selecting = {
  on: boolean;
  has: (id: string) => boolean;
  toggle: (id: string) => void;
  // Turn choosing on and take this one with it, which is what a long press
  // means: the thing under your finger is the first one you chose.
  begin: (id: string) => void;
};

function vesselList(kit: VesselState[], sel?: Selecting): HTMLElement {
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
      const chosen = sel?.on === true && sel.has(v.id);
      const row = el(
        "li",
        {
          class:
            `vessel-row vessel-row-tappable${fill !== null && fill > 1 ? " over" : ""}` +
            (chosen ? " vessel-row-chosen" : ""),
          role: sel?.on ? "checkbox" : "button",
          "aria-checked": sel?.on ? (chosen ? "true" : "false") : undefined,
          tabindex: "0",
          ...(fill === null ? {} : { style: `--fill:${Math.min(fill, 1).toFixed(3)}` }),
        },
        el("span", {
          class: "vessel-name",
          text: `${chosen ? "\u2713 " : ""}${v.name} (${v.type})`,
        }),
        el("span", {
          class: "vessel-detail",
          text: v.is_empty
            ? "empty"
            : // 0091. A bin holds pounds and everything else holds litres, and
              // until now a bin read "? L", which is the app asking a question
              // it had the answer to.
              v.fruit_lbs !== null
              ? `${v.lot_name ?? "unnamed lot"}, ${Number(v.fruit_lbs).toLocaleString()} lb, ${Number(v.fruit_tons ?? 0).toFixed(2)} ton`
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
          text: v.is_empty ? "Fill or edit" : "Open",
        }),
      );
      // Both offer the choice now. A full one used to go straight to the vessel
      // edit screen under a comment saying that was the only thing left to do to
      // it, which stopped being true when a lot gained facts somebody says after
      // intake: "I also need a way to edit (add/append only is fine) wine in
      // vessels, like to add the color." The wine and the vessel are two things
      // and the row cannot know which one you meant.
      // In selection mode a tap chooses rather than opens. One gesture doing
      // two things is how somebody ends up on a vessel screen when they meant
      // to tick it, and back is not free on a phone in a barn.
      const openRow = () => {
        if (sel?.on) sel.toggle(v.id);
        else go({ at: "vessel", id: v.id });
      };

      // A long press starts choosing and takes this row with it. He reached for
      // this before reading anything, which settles whether it is the right
      // gesture: the home screen's arrange mode already works this way, so it
      // is the one this app has taught.
      if (sel && !sel.on) {
        let timer: number | undefined;
        const start = (): void => {
          timer = window.setTimeout(() => sel.begin(v.id), 550);
        };
        const stop = (): void => {
          if (timer) window.clearTimeout(timer);
        };
        on(row, "pointerdown", start);
        on(row, "pointerup", stop);
        on(row, "pointercancel", stop);
        on(row, "pointerleave", stop);
      }
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

  const existing = el("div", {});

  // 0079. Every room that is already here, with the one control that did not
  // exist when it was added. A screen that can only add rooms is a screen that
  // cannot answer a question about the rooms there are.
  async function drawExisting(): Promise<void> {
    const air = await rooms();
    const said = el("div", {});

    function row(r: RoomClimate): HTMLElement {
      async function hold(mode: ThermalMode): Promise<void> {
        try {
          await setRoomClimate(r.id, mode, null);
          await drawExisting();
        } catch (error) {
          said.replaceChildren(fail(error));
        }
      }

      return el(
        "details",
        { class: "more" },
        el("summary", {
          text:
            `${r.name}, ${r.vessels} vessel${r.vessels === 1 ? "" : "s"}` +
            (r.mode === "off"
              ? r.controlled
                ? ", controlled, direction not said"
                : ""
              : `, ${r.mode} at ${r.ambient_c ?? "an unrecorded temperature"}`),
        }),
        rows(
          el("p", {
            class: "field-hint",
            text:
              "Which way the room is held. It cannot be read off the " +
              "temperature: the same 15C is cooling in September and heating " +
              "in January.",
          }),
          el(
            "div",
            { class: "button-row" },
            button(
              "Held cold",
              () => void hold("cooling"),
              r.mode === "cooling" ? "primary" : "secondary",
            ),
            button(
              "Held warm",
              () => void hold("heating"),
              r.mode === "heating" ? "primary" : "secondary",
            ),
            button(
              "Neither",
              () => void hold("off"),
              r.mode === "off" ? "primary" : "secondary",
            ),
          ),
        ),
      );
    }

    existing.replaceChildren(
      rows(
        el("h2", { class: "section-head", text: "Rooms there are" }),
        ...air.map(row),
        said,
      ),
    );
  }

  void drawExisting();

  return screen(
    "Locations",
    lede("Where vessels live. Add them as you walk into them."),
    rows(
      existing,
      el("h2", { class: "section-head", text: "Add one" }),
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
  // The photo control itself. A screen adding twelve barrels at once takes it
  // away, because a photograph is of one object and attaching it to twelve
  // would be attaching it to none of them.
  photoNode: HTMLElement;
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
    photoNode: photoField,
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
    // "Racking needs gas at destination too." What the receiving vessel was
    // full of before the wine arrived is the half of an oxygen pickup record
    // that was missing: a purged tank and one left open are the difference
    // between a clean rack and a lost one, and only this field can tell them
    // apart afterwards.
    //
    // One value for all destinations, the same shape the source field has. A
    // rack into two vessels purged differently would need this per leg, which
    // is a change to legList and not one anybody has asked for.
    const gasDestination = termOrText("Gas in the destination", "air, argon, nitrogen");
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

        // 0072. Asked of the kernel, once per destination, and never worked out
        // here: a client that decided which barrel is red would be a second
        // implementation of the rule and the two would disagree the first time
        // somebody said a colour. Nothing is blocked. The winemaker: "warn and
        // let through because somebody could put the wine in the barrel before
        // using the app".
        const goingIn = plan.parents[0]?.node_id;
        if (goingIn) {
          const said = await Promise.all(
            d.map((leg) => barrelWarning(leg.vessel_id, goingIn)),
          );
          for (const w of said) {
            if (w.warn && w.why) preview.append(banner(w.why, "note"));
          }
        }
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
      gasDestination.root,
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
              gas_destination: gasDestination.value() || null,
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
// --- the wine, as opposed to the vessel -----------------------------------

// The winemaker: "I also need a way to edit (add/append only is fine) wine in
// vessels, like to add the color."
//
// **There was nowhere to do that.** Tapping a full vessel went to the vessel
// edit screen, under a comment saying that is the only thing left to do to it.
// That was true when every fact about a lot arrived at intake and stopped, and
// it stopped being true the moment a lot had a colour somebody says afterwards.
//
// Append only, which is what he offered and is also what the kernel wants: a
// colour and a vintage are told values with one blessed function each, and
// everything else anybody wants to say about a lot is a note, which is the
// untyped floor from 0064 and can be turned into a fact later without anybody
// deciding in advance which facts exist.
function wineScreen(nodeId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("The wine", body);

  async function load(): Promise<void> {
    const [rows_, palette, notes] = await Promise.all([
      lotDetail(nodeId),
      terms("wine_colour"),
      notesFor("node", nodeId),
    ]);

    const lot = rows_[0];
    if (!lot) {
      body.replaceChildren(
        empty("That lot is not there to open."),
        button("Back", () => goBack(), "quiet"),
      );
      return;
    }

    view.querySelector("h1")?.replaceChildren(document.createTextNode(lot.name));

    const said = el("div", {});
    const note = field({
      label: "Add a note",
      placeholder: "Fruit condition was mostly good",
      hint: "Anything at all. It can be turned into a fact later, or left as prose.",
    });

    // Every vessel it is standing in, because a lot split across four barrels
    // is four rows and flattening that would be inventing a single answer.
    const standing = rows_.filter((r) => r.vessel_id !== null);

    body.replaceChildren(
      rows(
        el(
          "div",
          { class: "summary" },
          summaryRow("Variety", lot.variety ?? "not said"),
          summaryRow(
            "Vintage",
            lot.non_vintage
              ? "non-vintage"
              : lot.vintage
                ? String(lot.vintage)
                : "not said",
          ),
          summaryRow(
            "Colour",
            lot.colour_label
              ? lot.colour_told
                ? lot.colour_label
                : `${lot.colour_label}, inherited from what it came off`
              : "nobody has said",
          ),
          summaryRow("Owner", lot.owner_name ?? "this winery"),
          ...(standing.length === 0
            ? [summaryRow("Where", "not in a vessel")]
            : standing.map((r) =>
                summaryRow(
                  r === standing[0] ? "Where" : "and",
                  `${r.vessel}, ${r.volume_l ?? "?"} L`,
                ),
              )),
        ),

        // Colour first, because it is the thing he came here for and the thing
        // a barrel's own state is derived from.
        el("h2", { class: "section-head", text: "Colour" }),
        el("p", {
          class: "field-hint",
          text: lot.colour_told
            ? "Said about this lot. Saying it again replaces it."
            : lot.colour_label
              ? "This came down from what the lot was made from. Saying it here pins it to this lot."
              : "Nothing that comes off this lot can be called white or red until somebody says.",
        }),
        el(
          "div",
          { class: "button-row" },
          ...palette.map((c) =>
            button(
              c.label,
              async () => {
                try {
                  await setColour(nodeId, c.value);
                  await load();
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              c.value === lot.colour ? "primary" : "secondary",
            ),
          ),
        ),

        ...(lot.vintage === null && !lot.non_vintage
          ? [
              el("h2", { class: "section-head", text: "Vintage" }),
              el("p", {
                class: "field-hint",
                text: "This lot says neither a year nor non-vintage.",
              }),
              button("Say which year", () => go({ at: "vintages" }), "secondary"),
            ]
          : []),

        el("h2", { class: "section-head", text: "Notes" }),
        note.root,
        button("Add it", async () => {
          if (!note.value().trim()) {
            said.replaceChildren(banner("Type something first.", "error"));
            return;
          }
          try {
            await addNote({
              subjectType: "node",
              subjectId: nodeId,
              body: note.value(),
            });
            note.input.value = "";
            await load();
          } catch (error) {
            said.replaceChildren(fail(error));
          }
        }),
        said,
        notes.length === 0
          ? empty("Nothing said about this lot yet.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...notes.slice(0, 20).map((n) =>
                el(
                  "li",
                  { class: "vessel-row" },
                  el("span", { class: "vessel-name", text: n.body }),
                  el("span", {
                    class: "vessel-detail",
                    text: `${n.by_name ?? "somebody"}, ${new Date(n.at).toLocaleString()}`,
                  }),
                ),
              ),
            ),

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

// What a vessel offers, which depends on whether there is wine in it. It used
// to be reached only when empty, because a full vessel went straight to its own
// edit screen. Now both come here: the wine and the vessel are two different
// things to open and a tap on a row cannot know which one somebody meant.
function vesselChoiceScreen(
  vesselId: string,
  vesselName: string,
  nodeId: string | null = null,
  lotName: string | null = null,
): HTMLElement {
  if (nodeId) {
    return screen(
      vesselName,
      lede(`${lotName ?? "Wine"} is in this vessel.`),
      rows(
        // First, because it is the one that was missing and because the wine is
        // what somebody standing in front of a barrel is thinking about.
        button("The wine in it", () => go({ at: "wine", id: nodeId })),
        button(
          "Edit the vessel",
          () => go({ at: "vessel-edit", id: vesselId }),
          "secondary",
        ),
        button(
          "Notes and photographs",
          () => go({ at: "vessel-photos", id: vesselId }),
          "secondary",
        ),
        button("Back", () => goBack(), "quiet"),
      ),
    );
  }

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
        "Notes and photographs",
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
  // 0098. "Seems like all it needs to be is a number of vessel in the type.
  // Then it defaults to 1 but you can change it to whatever you need." A row of
  // twelve barrels off a pallet was twelve trips through this form, and the
  // answers were the same every time.
  const count = field({
    label: "How many",
    type: "number",
    value: "1",
    hint: "One unless you say otherwise. More than one and they are numbered on from the highest already used.",
  });
  const howMany = () => Math.max(1, Math.floor(Number(count.value() || "1")));
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
    // A code is scanned off one object and a photograph is of one object, so
    // both go away as soon as this is a batch. Left up, they would be asked for
    // and then quietly attached to the first barrel of twelve, which is A13.
    const batchNote = el("div", {});
    const single = () => {
      const many = howMany() > 1;
      // Hidden only while there is nothing in it. Codes already scanned stay on
      // screen, because the save refuses rather than throwing them away and a
      // refusal about a list nobody can see is not one anybody can act on.
      // There is no way to take one back off the list, so the refusal says the
      // two things that do work: change the count, or leave.
      capture.root.hidden = many && capture.codes().length === 0;
      form.photoNode.hidden = many;
      if (many) capture.stop();
      batchNote.replaceChildren(
        many
          ? banner(
              `${howMany()} of these, numbered on from the highest already used. ` +
                "A code and a photograph belong to one vessel, so they are not asked " +
                "for here: open a vessel afterwards to add them.",
              "note",
            )
          : el("span", {}),
      );
    };
    on(count.input, "input", single);

    holder.append(
      note,
      count.root,
      batchNote,
      ...form.nodes,
      capture.root,
      button("Save vessel", async () => {
        const problem = form.ready();
        if (problem) {
          message.replaceChildren(banner(problem, "error"));
          return;
        }
        // Scanned and then abandoned by changing the count is the A13 shape: the
        // list goes away with the control and the codes would be written
        // nowhere, which reads as a save that worked.
        if (howMany() > 1 && capture.codes().length > 0) {
          message.replaceChildren(
            banner(
              `${capture.codes().length} scanned code(s) belong to one vessel and ` +
                "would be thrown away by a batch. Set the count back to 1 to keep " +
                "them, or go back and start this again without them.",
              "error",
            ),
          );
          return;
        }
        try {
          const many = howMany();
          const id = newId();
          const values = form.read();
          const file = many > 1 ? null : form.photoFile();
          const attributes = { ...values.attributes };
          if (file) attributes.photo_path = await uploadVesselPhoto(id, file);

          const made = await addVessels({ id, ...values, attributes }, many);
          if (many === 1) {
            for (const row of capture.codes()) await bindOne(id, row);
          }
          capture.stop();
          form.draftDone();
          if (many > 1) {
            // Said rather than assumed. The names are worked out by the kernel,
            // so the person who asked for twelve has no other way to learn what
            // is now on the floor.
            message.replaceChildren(
              banner(
                `${made.count} vessels added, ${made.from} to ${made.to}.`,
                "good",
              ),
            );
            count.input.value = "1";
            single();
            return;
          }
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
  // A lot is of a year or is deliberately non-vintage, and 0049 stopped blank
  // from meaning both of those plus "nobody got round to it". The box empties
  // the year field rather than sitting beside it, because a lot that says both
  // is refused and a form that lets you type a contradiction is a form that
  // will.
  const nv = checkbox("Non-vintage", false);
  on(nv.input, "change", () => {
    if (nv.input.checked) vintage.input.value = "";
    vintage.input.disabled = nv.input.checked;
    autoName();
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
    const parts = [variety.label(), nv.input.checked ? "NV" : vintage.value()].filter(
      Boolean,
    );
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
      nv.root,
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
      vintage: nv.input.checked || !vintage.value() ? null : Number(vintage.value()),
      non_vintage: nv.input.checked,
      product_type_id: productType.value() || null,
      unit: "L",
      quantity: volumeOf(),
      // Empty means the facility, which is what the kernel coalesces to.
      owner_id: owner.value() || null,
    }),
    // Asked here rather than let the constraint refuse it, so the sentence is
    // one somebody can act on instead of a constraint name.
    ready: () =>
      !lotName.value()
        ? "The lot needs a name."
        : !vintage.value() && !nv.input.checked
          ? "Say which vintage this is, or tick non-vintage."
          : null,
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

// Picks that have been described and have no bins yet. Held here rather than in
// the URL because one is not a thing until its first bin is recorded, and a
// place is resolved by asking the kernel, which would have nothing to answer
// with.
//
// A list rather than one, because picking is chosen a vineyard at a time and
// then a set of blocks within it. **One entry per block, and never one entry
// carrying several.** `block_composition` in 0002 derives a wine's block makeup
// by walking the lineage back to the picks that fed it and reading `block_id`
// off each one, so a pick is the unit that carries a block. A pick naming three
// blocks would not be a blend the kernel could take apart, it would be three
// percentages that had stopped existing, and nothing later could recover them.
type PendingPick = {
  id: string;
  block_id: string | null;
  // Carried so the switcher can label itself without another read, and so the
  // label survives a block being renamed mid-pick.
  block_name: string;
  variety_id: string | null;
  vintage: number | null;
  // The real id, once the first bin has landed and this has stopped being
  // pending. The entry stays in the list rather than being removed, because the
  // switcher has to keep offering a block after fruit has gone into it.
  node_id: string | null;
};

let pendingPicks: PendingPick[] = [];
// The vineyard chosen last, because a picking day is usually one vineyard and
// retyping it for every block set is the kind of friction that gets a screen
// worked around rather than used.
let lastVineyard = "";
let pendingAt = 0;

function currentPick(): PendingPick | null {
  return pendingPicks[pendingAt] ?? null;
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
      const [vineRows, blockRows] = await Promise.all([vineyards(), blocks()]);
      const variety = termPicker("variety", { label: "Variety", stickyKey: "variety" });
      const vintage = field({
        label: "Vintage",
        type: "number",
        value: String(new Date().getFullYear()),
        // No non-vintage box here, deliberately. Fruit picked this year is of
        // this year; NV is something a blend becomes later, not something a
        // pick can be. 0049 requires one of the two and this is always the year.
        hint: "Fruit picked now is of this year.",
      });
      await variety.reload();

      // The vineyard first, and the blocks after. "You should start a pick by
      // selecting a vineyard, and then it presents the blocks within the
      // vineyard." The flat list of every block at every vineyard that used to
      // be here was already long in a two-vineyard season.
      const vineyardPick = el("select", { class: "input" });
      vineyardPick.replaceChildren(
        el("option", { value: "", text: "Pick a vineyard" }),
        ...vineRows.map((v) => el("option", { value: v.id, text: v.name })),
      );
      // The same vineyard all morning is the normal shape of a picking day.
      if (lastVineyard && vineRows.some((v) => v.id === lastVineyard)) {
        vineyardPick.value = lastVineyard;
      }

      const blockBox = el("div", {});
      let ticked: { field: Field; block: Block }[] = [];

      function drawBlocks(): void {
        const id = vineyardPick.value;
        ticked = [];
        if (!id) {
          blockBox.replaceChildren(empty("Pick a vineyard to see its blocks."));
          return;
        }
        const mine = blockRows.filter((b) => b.vineyard_id === id);
        if (mine.length === 0) {
          blockBox.replaceChildren(
            empty("That vineyard has no blocks yet."),
            button("Add a block to it", () => go({ at: "vineyard", id }), "secondary"),
          );
          return;
        }
        ticked = mine.map((b) => ({ field: checkbox(b.name), block: b }));
        blockBox.replaceChildren(
          el("span", { class: "field-label", text: "Blocks" }),
          ...ticked.map((t) => t.field.root),
          el("span", {
            class: "field-hint",
            text:
              "Tick as many as you are picking. Each one becomes its own pick, " +
              "so what came off each block stays its own number, and the bin " +
              "screen asks which block a bin is off.",
          }),
        );
      }

      on(vineyardPick, "change", () => {
        lastVineyard = vineyardPick.value;
        drawBlocks();
      });
      drawBlocks();

      body.replaceChildren(
        rows(
          el(
            "div",
            { class: "field" },
            el("span", { class: "field-label", text: "Vineyard" }),
            vineyardPick,
          ),
          blockBox,
          variety.root,
          vintage.root,
          button("Next, add bins", () => {
            if (!vineyardPick.value) {
              message.replaceChildren(banner("Pick a vineyard.", "error"));
              return;
            }
            const chosen = ticked.filter((t) => t.field.input.checked);
            if (chosen.length === 0) {
              message.replaceChildren(banner("Tick at least one block.", "error"));
              return;
            }
            if (!variety.value()) {
              message.replaceChildren(banner("Pick a variety.", "error"));
              return;
            }
            if (!vintage.value()) {
              message.replaceChildren(
                banner("Say which vintage this fruit is.", "error"),
              );
              return;
            }
            // Each id is made here, before anything is written, so the bin
            // screen can add to one and a repeated call finds the same pick
            // rather than making a second one.
            pendingPicks = chosen.map((t) => ({
              id: newId(),
              block_id: t.block.id,
              block_name: t.block.name,
              variety_id: variety.value(),
              vintage: Number(vintage.value()),
              node_id: null,
            }));
            pendingAt = 0;
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
  // Opening a named pick from the list is not resuming the batch. Without this
  // the switcher would come back holding this morning's blocks and the next bin
  // would land on whichever one was current, which is the worst class of bug
  // this screen can have: fruit recorded against the wrong block, silently.
  if (openOn) {
    pendingPicks = [];
    pendingAt = 0;
  }
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const tally = el("div", {});
  const switcher = el("div", { class: "variant-switch" });
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

      // 0087. "Picking bins should hold fruit in lbs or % ton", and then the
      // better version: "the bins should each have a fruit amount in lbs so we
      // just use that right?" Right, so pounds are what gets stored and how
      // full is what gets worked out, which is the reverse of what this asked
      // before. Both units are offered because he asked for both, and which one
      // is remembered per device because it is a habit rather than a decision.
      //
      // A full bin is 850 pounds here, which is his "800 to 900 if it's
      // bulging" with the middle taken. It lives on the bin type, so the middle
      // moves without a release.
      const fullLbs = Number(binTypes[0]?.attributes?.full_lbs ?? 0) || null;
      const tare = Number(binTypes[0]?.attributes?.tare_lbs ?? 0) || 0;

      // 0092. Three ways to say how much is in a bin, and the screen has to say
      // which one it is asking for. "It should be very clear whether the
      // measurement is the net weight or fruit weight": somebody at a pallet
      // scale reads 923 and that is the bin as well as the fruit, and 923 and
      // 831 are both plausible weights for a bin of Chardonnay.
      //
      // Read once and never reassigned: the buttons write the preference and
      // redraw, rather than mutating this and leaving the label saying the old
      // unit.
      const saidUnit = pref("bin_unit");
      const unit: "net" | "gross" | "pct" =
        saidUnit === "gross" ? "gross" : saidUnit === "pct" && fullLbs ? "pct" : "net";

      const fill = field({
        label:
          unit === "net"
            ? "Fruit in each bin, lbs"
            : unit === "gross"
              ? "On the scale with the bin, lbs"
              : "How full, percent",
        type: "number",
        // Deliberately empty. It pre-filled 850, so five bins recorded without
        // anybody typing a weight came out reading a weight. 0049 refused to
        // prefill a vintage for this reason, in a field where being wrong costs
        // less than it does here.
        placeholder: unit === "pct" ? "100" : "900",
        hint:
          unit === "net"
            ? "The fruit alone. Nothing is filled in for you."
            : unit === "gross"
              ? `What the scale reads with the bin on it. A bin is ${tare} lb and that comes off.`
              : `Percent of a nominal bin, which this winery calls ${fullLbs ?? "?"} lb. Over a hundred is a bulging one.`,
      });
      const converted = el("p", { class: "field-hint" });

      const saidLbs = (): number | null => {
        const raw = fill.value();
        return raw && unit === "net" ? Number(raw) : null;
      };
      const saidGross = (): number | null => {
        const raw = fill.value();
        return raw && unit === "gross" ? Number(raw) : null;
      };
      const fillPct = (): number | null => {
        const raw = fill.value();
        return raw && unit === "pct" ? Number(raw) : null;
      };

      function showConversion(): void {
        const raw = fill.value() ? Number(fill.value()) : null;
        if (raw === null) {
          converted.textContent = "";
          return;
        }
        // The kernel does this arithmetic when the row is written. This repeats
        // it to put the number in front of somebody before they commit to it,
        // which is the one thing a client may do with a rule it does not own.
        const fruit =
          unit === "net"
            ? raw
            : unit === "gross"
              ? raw - tare
              : fullLbs
                ? Math.round((raw / 100) * fullLbs)
                : null;
        if (fruit === null) {
          converted.textContent = "";
          return;
        }
        if (unit === "gross" && fruit <= 0) {
          converted.textContent = `A bin weighs ${tare} lb empty, so that reading has no fruit in it.`;
          return;
        }
        const both = `${fruit.toLocaleString()} lb of fruit, ${(fruit / 2000).toFixed(2)} ton`;
        converted.textContent =
          unit === "gross"
            ? `${both}, with the ${tare} lb bin taken off.`
            : unit === "net"
              ? `${both}. On a scale with the bin that reads ${(fruit + tare).toLocaleString()}.`
              : `About ${both}, assuming a bin holds ${fullLbs}. Weigh them and that is replaced.`;
      }

      // Three buttons rather than a toggle, because a toggle between three
      // things is a puzzle, and because which one is chosen has to be readable
      // without tapping it.
      const choices: Array<[string, string]> = [
        ["net", "Fruit only"],
        ["gross", "With the bin"],
      ];
      if (fullLbs) choices.push(["pct", "How full"]);
      const unitToggle = el(
        "div",
        { class: "button-row" },
        ...choices.map(([key, label]) =>
          button(
            label,
            () => {
              setPref("bin_unit", key);
              void route();
            },
            unit === key ? "primary" : "quiet",
          ),
        ),
      );
      on(fill.input, "input", showConversion);
      showConversion();

      async function refreshTally(id: string): Promise<void> {
        const [waiting, inBins, shots] = await Promise.all([
          unweighedBins(id),
          binFruit(id),
          attachmentsFor("node", id),
        ]);

        // The total first, because it is the number somebody says out loud and
        // the one they are checking against a contract.
        const lbs = inBins.reduce((n, b) => n + Number(b.lbs ?? 0), 0);
        const unknown = inBins.filter((b) => b.lbs === null).length;

        function binRow(b: BinFruit): HTMLElement {
          const box = field({
            label: `${b.bin}, lbs`,
            type: "number",
            value: b.lbs === null ? "" : String(b.lbs),
            hint:
              b.said_as === "pct"
                ? `Worked out from ${b.said_pct}% of a nominal bin. A weight typed here replaces that.`
                : b.said_as === "gross"
                  ? `From ${Number(b.said_gross).toLocaleString()} lb on the scale, less the ${b.tare_lbs} lb bin.`
                  : "The fruit, the bin not counted.",
          });
          // 0092. The other way somebody has the number: what the scale showed
          // with the bin on it. Two boxes rather than one with a mode, because
          // this row is read at a glance and a mode you cannot see is how 923
          // becomes 923 pounds of fruit.
          const grossBox = field({
            label: "Or on the scale with the bin, lbs",
            type: "number",
            placeholder: b.gross === null ? "923" : String(b.gross),
            hint: `The ${b.tare_lbs} lb bin comes off.`,
          });
          const said = el("div", {});

          // "It shouldn't be used in a calculation except to see the difference
          // between my guesses and reality." This is that comparison, and it is
          // the whole of what a percentage is for now.
          const against =
            b.said_pct !== null && b.pct_full !== null
              ? el("p", {
                  class: "field-hint",
                  text:
                    `Guessed ${b.said_pct}% full, came in at ${b.pct_full}%` +
                    (Math.abs(Number(b.said_pct) - Number(b.pct_full)) <= 5
                      ? ". Close."
                      : "."),
                })
              : el("span", {});

          return el(
            "details",
            { class: "more" },
            el(
              "summary",
              {},
              el("span", {
                text:
                  `${b.bin}: ` +
                  (b.lbs === null
                    ? // 0093. A percentage is a guess and never becomes a
                      // weight, so a bin with only a guess has no pounds and
                      // says so rather than reporting a plausible number.
                      b.said_pct !== null
                      ? `guessed ${b.said_pct}% full, never weighed`
                      : "nobody has said"
                    : // Both numbers, always, because one of them alone does
                      // not say which one it is.
                      `${Number(b.lbs).toLocaleString()} lb of fruit, ` +
                      `${Number(b.tons ?? 0).toFixed(2)} ton, ` +
                      `${Number(b.gross ?? 0).toLocaleString()} on the scale` +
                      (b.said_as === "weighed" ? ", weighed" : "")),
              }),
            ),
            rows(
              against,
              // A weighed bin is not corrected by typing over it. The scale's
              // figure has a photograph and an author behind it, and replacing
              // it belongs to the weighing, which already knows how to be
              // superseded.
              b.said_as === "weighed"
                ? el("p", {
                    class: "field-hint",
                    text:
                      "This came off the scale. To change it, correct the " +
                      "weighing rather than typing over it here.",
                  })
                : el("span", {}),
              box.root,
              button(
                "That is the fruit",
                async () => {
                  if (!box.value()) {
                    said.replaceChildren(banner("Type a weight.", "error"));
                    return;
                  }
                  try {
                    await setBinFruit(b.vessel_id, { netLbs: Number(box.value()) });
                    await refreshTally(id);
                  } catch (error) {
                    said.replaceChildren(fail(error));
                  }
                },
                "secondary",
              ),
              grossBox.root,
              button(
                "That is what the scale said",
                async () => {
                  if (!grossBox.value()) {
                    said.replaceChildren(banner("Type the scale reading.", "error"));
                    return;
                  }
                  try {
                    await setBinFruit(b.vessel_id, {
                      grossLbs: Number(grossBox.value()),
                    });
                    await refreshTally(id);
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

        tally.replaceChildren(
          rows(
            inBins.length === 0
              ? empty("No bins on this pick yet.")
              : el(
                  "div",
                  { class: "summary" },
                  summaryRow(
                    "Bins",
                    `${inBins.length}, ${lbs.toLocaleString()} lb, ${(lbs / 2000).toFixed(2)} ton`,
                  ),
                  // An estimate and a weighing are different numbers and the
                  // screen says which this is. S-84: nothing reconciles them.
                  summaryRow(
                    "This is",
                    unknown > 0
                      ? `an estimate, and ${unknown} bin${unknown === 1 ? " has" : "s have"} no figure at all`
                      : "an estimate until the scale",
                  ),
                ),
            ...inBins.map(binRow),

            // "So how do I see the pictures of the bins?" They were three taps
            // away behind a button at the foot of this screen, under the bin
            // list and the new bin form. A photograph is evidence about the
            // thing above it, so the way to it belongs beside the thing.
            el(
              "ul",
              { class: "vessel-list" },
              (() => {
                const row = el(
                  "li",
                  {
                    class: "vessel-row vessel-row-tappable",
                    role: "button",
                    tabindex: "0",
                  },
                  el("span", {
                    class: "vessel-name",
                    text:
                      shots.length === 0
                        ? "No photographs yet"
                        : `${shots.length} photograph${shots.length === 1 ? "" : "s"}`,
                  }),
                  el("span", {
                    class: "vessel-detail",
                    text:
                      shots.length === 0
                        ? "Of the scale, the fruit, the paperwork."
                        : "Tap to look at them, or add another.",
                  }),
                );
                const open = () => go({ at: "pick-photos", id });
                on(row, "click", open);
                on(row, "keydown", (ev) => {
                  if (ev.key === "Enter" || ev.key === " ") {
                    ev.preventDefault();
                    open();
                  }
                });
                return row;
              })(),
            ),

            el("p", {
              class: "lede",
              text:
                waiting.length === 0
                  ? "Every bin on this pick has been weighed."
                  : `${waiting.length} bin${waiting.length === 1 ? "" : "s"} waiting for the scale: ${waiting
                      .map((w) => w.bin_name)
                      .join(", ")}`,
            }),
          ),
        );
      }

      // The pick's description travels with the first bin that joins it, and by
      // id after that, so a second call does not make a second pick.
      function pickPayload(): Record<string, unknown> | null {
        if (nodeId) return { id: nodeId };
        const p = currentPick();
        if (!p) return null;
        // A block whose first bin has already landed is joined by id; one that
        // is still only described travels with its description. `block_name` is
        // this client's label and not the kernel's business, so it does not go.
        if (p.node_id) return { id: p.node_id };
        return {
          id: p.id,
          block_id: p.block_id,
          variety_id: p.variety_id,
          vintage: p.vintage,
        };
      }

      async function landed(result: { node_id: string; bins: number }, said: string) {
        const p = currentPick();
        if (p) p.node_id = result.node_id;
        nodeId = result.node_id;
        await refreshTally(result.node_id);
        message.replaceChildren(
          banner(
            `${said} ${result.bins} bin${result.bins === 1 ? "" : "s"} on ` +
              (p && pendingPicks.length > 1 ? p.block_name : "this pick") +
              ".",
            "good",
          ),
        );
        drawSwitcher();
        // The pick has an id worth resuming on now, which it did not have when
        // this screen opened.
        //
        // Only when it is the only one in hand. A batch cannot be named by one
        // pick's id, and writing one into the URL would mean a reload came back
        // holding a single block with the rest of the morning's blocks gone.
        // Several blocks in hand keeps the bare place and keeps the batch here.
        if (pendingPicks.length <= 1) {
          pendingPicks = [];
          pendingAt = 0;
          window.history.replaceState(
            null,
            "",
            encode({ at: "pick-bins", id: result.node_id }),
          );
        }
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
            netLbs: saidLbs(),
            grossLbs: saidGross(),
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
            netLbs: saidLbs(),
            grossLbs: saidGross(),
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

      // Which block the next bin belongs to. Drawn only when more than one was
      // ticked, because one block needs no choosing and a control that offers a
      // single option is a control that teaches somebody to ignore it.
      //
      // The blocks stay on screen after fruit has gone into them, and say how
      // much, because picking runs back and forth: two bins off Block 1, four
      // off Block 3, another off Block 1 when the crew moves back up the row.
      function drawSwitcher(): void {
        if (pendingPicks.length <= 1) {
          switcher.replaceChildren();
          return;
        }
        switcher.replaceChildren(
          el("span", { class: "field-label", text: "Bins are coming off" }),
          el(
            "div",
            { class: "variant-options" },
            ...pendingPicks.map((p, i) =>
              button(
                p.node_id ? `${p.block_name} ✓` : p.block_name,
                () => void switchTo(i),
                i === pendingAt ? "primary" : "quiet",
              ),
            ),
          ),
          el("span", {
            class: "field-hint",
            text:
              "Each block is its own pick, so what comes off each one stays " +
              "its own number. A tick means fruit has gone in.",
          }),
        );
      }

      // Changing blocks changes which pick the bin buttons write to, and the
      // tally has to follow or it reports the block you just left.
      async function switchTo(i: number): Promise<void> {
        pendingAt = i;
        const p = currentPick();
        nodeId = p?.node_id ?? undefined;
        message.replaceChildren();
        if (nodeId) {
          await refreshTally(nodeId);
        } else {
          tally.replaceChildren(
            empty(`No bins on ${p?.block_name ?? "this block"} yet.`),
          );
        }
        drawSwitcher();
        drawCancel();
      }

      drawCancel();
      drawSwitcher();
      if (nodeId) await refreshTally(nodeId);

      body.replaceChildren(
        rows(
          switcher,
          tally,
          fill.root,
          converted,
          // Only where percent means something. With no figure for what a full
          // bin holds, a percent is a number with no second half.
          unitToggle,
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
                "Notes and photographs",
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
  const id = currentPick()?.block_id;
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

// --- additions -------------------------------------------------------------

// Something goes into the wine in a vessel.
//
// Vessel first, because that is how the winemaker asked for it and because it
// is how the job is done: you stand in front of a tank. The lot is whatever is
// in the vessels ticked, which the kernel works out and refuses if they hold
// different wine.
//
// The rate is not a field. The volume of wine at the moment of the addition is
// a function of the placements, and the rate is the amount over that volume, so
// both are shown after the fact rather than typed before it. Alexis's form has
// four columns for what is one recorded fact and two derivations.
function additionsScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Additions",
    lede(
      "What went into the wine, and into which vessel. Taking it off the shelf " +
        "happens here too, so it does not have to be recorded twice.",
    ),
    body,
  );

  void (async () => {
    try {
      const [kit, shelf] = await Promise.all([vessels(), suppliesForAddition()]);
      const holding = kit.filter((v) => !v.is_empty);

      if (holding.length === 0) {
        body.replaceChildren(
          empty("No vessel has wine in it, so there is nothing to add to."),
          button("Back", () => goBack(), "quiet"),
        );
        return;
      }

      // Grouped by lot, because the kernel refuses an addition spanning two of
      // them and offering a selection that will be refused is offering a
      // refusal. A lot in three barrels shows as three tickable rows under one
      // heading, and ticking one of them is the ordinary case.
      const byLot = new Map<string, typeof holding>();
      for (const v of holding) {
        const key = v.node_id ?? `loose:${v.id}`;
        const list = byLot.get(key) ?? [];
        list.push(v);
        byLot.set(key, list);
      }

      function lotBlock(members: typeof holding): HTMLElement {
        const boxes = members.map((v) => ({
          vessel: v,
          box: checkbox(
            v.current_volume_l === null
              ? v.name
              : `${v.name} (${Number(v.current_volume_l).toLocaleString()} L)`,
            members.length === 1,
          ),
        }));

        // Off the shelf, or by name. Both are real: a winery adds things it does
        // not keep an inventory of, and refusing those would mean they go
        // unrecorded rather than that somebody sets up a supply first.
        const fromShelf = el("select", { class: "input" });
        fromShelf.replaceChildren(
          el("option", { value: "", text: "Not off the shelf" }),
          ...shelf.map((s) =>
            el("option", {
              value: s.supply_id,
              text: `${s.name} (${Number(s.on_hand).toLocaleString()} ${s.unit} on hand)`,
            }),
          ),
        );
        const shelfField = el(
          "div",
          { class: "field" },
          el("span", { class: "field-label", text: "From the shelf" }),
          fromShelf,
          el("span", {
            class: "field-hint",
            text:
              shelf.length === 0
                ? "Nothing on the shelf is flagged as going into wine yet. Set that on the supply in Stores."
                : "Picking one takes the amount off the shelf as well.",
          }),
        );

        const what = field({
          label: "What went in",
          placeholder: "KMBS",
          hint: "Needed only if it did not come off the shelf.",
        });
        const amount = field({ label: "How much", type: "number", placeholder: "30" });
        const unit = field({ label: "Unit", placeholder: "g" });
        const when = field({
          label: "When",
          type: "datetime-local",
          hint: "Blank means now.",
        });
        const note = field({ label: "Note", placeholder: "for the cold soak" });
        const said = el("div", {});

        // The unit follows the shelf when something is picked, because the one
        // case where the shelf does not move is a unit mismatch, and the way to
        // have fewer of those is to offer the right answer rather than to
        // explain the wrong one afterwards.
        on(fromShelf, "change", () => {
          const picked = shelf.find((s) => s.supply_id === fromShelf.value);
          if (picked && !unit.value()) unit.input.value = picked.unit;
        });

        return el(
          "div",
          { class: "rows" },
          el("h2", {
            class: "section-head",
            text: members[0]?.lot_name ?? "Wine with no lot name",
          }),
          ...boxes.map((b) => b.box.root),
          shelfField,
          what.root,
          amount.root,
          unit.root,
          when.root,
          note.root,
          button("Record this addition", async () => {
            const chosen = boxes
              .filter((b) => b.box.input.checked)
              .map((b) => b.vessel.id);
            if (chosen.length === 0) {
              said.replaceChildren(banner("Tick the vessels this went into.", "error"));
              return;
            }
            if (!amount.value() || !unit.value()) {
              said.replaceChildren(
                banner("Say how much went in, and in what unit.", "error"),
              );
              return;
            }
            if (!fromShelf.value && !what.value()) {
              said.replaceChildren(
                banner("Say what went in, or pick it off the shelf.", "error"),
              );
              return;
            }
            try {
              const out = await addToWine({
                vesselIds: chosen,
                amount: Number(amount.value()),
                unit: unit.value(),
                supplyId: fromShelf.value || null,
                what: what.value() || null,
                at: when.value() ? new Date(when.value()).toISOString() : null,
                note: note.value() || null,
              });
              said.replaceChildren(
                banner(
                  `${out.amount} ${out.unit} of ${out.what} into ${out.lot_name}` +
                    (out.volume_l > 0
                      ? `, which held ${Number(out.volume_l).toLocaleString()} L, so ` +
                        `${out.per_litre} ${out.unit} per litre.`
                      : ". No volume is recorded for those vessels, so there is no rate."),
                  "good",
                ),
                // Two outcomes, said apart. The addition landed either way, and
                // a banner claiming the shelf moved when it did not is the A13
                // shape.
                ...(out.shelf_note
                  ? [
                      banner(
                        `The addition is recorded. The shelf was not touched: ${out.shelf_note}.`,
                        "note",
                      ),
                    ]
                  : []),
                ...(out.shelf_moved
                  ? [banner("Taken off the shelf as well.", "good")]
                  : []),
              );
              amount.input.value = "";
              note.input.value = "";
              what.input.value = "";
            } catch (error) {
              said.replaceChildren(fail(error));
            }
          }),
          said,
        );
      }

      const past = await lotAdditions();

      body.replaceChildren(
        rows(
          ...[...byLot.values()].map(lotBlock),

          el("h2", { class: "section-head", text: "Already recorded" }),
          past.length === 0
            ? empty("Nothing has been added to anything yet.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...past.slice(0, 20).map((a) =>
                  el(
                    "li",
                    { class: "vessel-row" },
                    el("span", {
                      class: "vessel-name",
                      text: `${a.amount} ${a.unit} ${a.what}`,
                    }),
                    el("span", {
                      class: "vessel-detail",
                      text:
                        `${a.lot_name}` +
                        (a.vessels.length > 0 ? ` in ${a.vessels.join(", ")}` : "") +
                        `, ${new Date(a.at).toLocaleDateString()}` +
                        (a.per_litre === null ? "" : `, ${a.per_litre} ${a.unit}/L`),
                    }),
                    // Whether the inventory moved with it, because the whole
                    // point of naming the supply is that it did.
                    a.took_from_the_shelf
                      ? el("span", { class: "tag", text: "off the shelf" })
                      : null,
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

// --- go anywhere -----------------------------------------------------------

// Linear and Superhuman put every action one keystroke away and show the
// shortcut beside the command so that muscle memory forms without anybody
// setting out to learn it. Superhuman treats fifty milliseconds as the product.
//
// That is a desktop pattern and this is a phone, so what carries over is not the
// keystroke: it is **not having to know where a thing lives**. Four taps to
// reach Stores is four taps whether or not you remember the route, and typing
// "sto" is one.
//
// **It costs almost nothing because the contract already enumerates everything.**
// `contract()` returns every capability and every readable with a label and a
// sentence written for a person, which is exactly what a palette needs, and it
// was written for a second periphery rather than for this. A palette built from
// it never goes stale: a capability added in a migration appears here without
// anybody remembering to add it.
//
// The screens themselves are not in the contract, so the places are listed
// alongside. That duplication is real and is the argument for the home menu
// eventually being generated from the contract too.
type Destination = {
  label: string;
  note: string;
  hay: string;
  go: () => void;
};

function paletteScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const box = field({
    label: "Go to",
    placeholder: "weigh, press, stores, Grundy",
    hint: "Type a few letters. Screens, things you can record, and vessels by name.",
  });
  const view = screen("Go anywhere", rows(box.root, body));

  void (async () => {
    try {
      const [spec, kit] = await Promise.all([contract(), vessels()]);

      const places: Destination[] = [
        {
          label: "The day",
          note: "What happened today.",
          hay: "day log notes",
          go: () => go({ at: "day" }),
        },
        {
          label: "Picking",
          note: "Record bins as they are filled.",
          hay: "pick intake bins fruit",
          go: () => go({ at: "intake" }),
        },
        {
          label: "Weigh bins",
          note: "What the scale said.",
          hay: "weigh scale weight lbs",
          go: () => go({ at: "scale" }),
        },
        {
          label: "Press",
          note: "Fruit in, juice out.",
          hay: "press cut litres",
          go: () => go({ at: "press" }),
        },
        {
          label: "Sampling",
          note: "What was sampled and what it read.",
          hay: "sample brix ph reading",
          go: () => go({ at: "sampling" }),
        },
        {
          label: "Additions",
          note: "What went into the wine.",
          hay: "addition so2 dap nutrient",
          go: () => go({ at: "additions" }),
        },
        {
          label: "Vessels",
          note: "What is in the cellar.",
          hay: "vessel tank barrel map",
          go: () => go({ at: "vessels" }),
        },
        {
          label: "Rack",
          note: "Move wine between vessels.",
          hay: "rack blend transfer",
          go: () => go({ at: "rack" }),
        },
        {
          label: "Stores",
          note: "What is on the shelf.",
          hay: "stores supply shopping buy",
          go: () => go({ at: "stores" }),
        },
        {
          label: "Bins to return",
          note: "Borrowed bins that are empty.",
          hay: "bins return borrowed",
          go: () => go({ at: "bins-to-return" }),
        },
        {
          label: "Vineyards",
          note: "Blocks and what is planted.",
          hay: "vineyard block planting",
          go: () => go({ at: "vineyards" }),
        },
        {
          label: "On paper",
          note: "Measurements owed to a form.",
          hay: "paper form propagate",
          go: () => go({ at: "paper" }),
        },
        {
          label: "Kinds of fact",
          note: "What a note can be turned into.",
          hay: "fact kind brix parameter",
          go: () => go({ at: "fact-kinds" }),
        },
        {
          label: "Colour",
          note: "What colour each wine is, and what that made of the barrels.",
          hay: "colour color red white rose orange barrel stain",
          go: () => go({ at: "colours" }),
        },
        {
          label: "Picking bins",
          note: "How many there are and whose they are.",
          hay: "bins picking inventory stack register borrowed",
          go: () => go({ at: "bins" }),
        },
        {
          label: "Running",
          note: "Everything started and not finished.",
          hay: "running open in progress going press pick unfinished",
          go: () => go({ at: "running" }),
        },
        {
          label: "Glycol",
          note: "Machines, and the jackets hooked to them.",
          hay: "glycol chiller cooler pump jacket hose cooling heating machine",
          go: () => go({ at: "glycol" }),
        },
        {
          label: "Take a copy",
          note: "Everything you can read, as one file.",
          hay: "export backup copy",
          go: () => go({ at: "export" }),
        },
      ];

      // Straight from the contract. Nobody maintains this list: a capability
      // added in a migration turns up here without anybody remembering to.
      //
      // Only the ones with a screen behind them. A capability the contract
      // declares and no screen records is real and is not somewhere to send
      // anybody, and a palette entry that silently does nothing is worse than
      // no entry at all.
      const doable: Destination[] = (spec.capabilities ?? []).flatMap((c) => {
        const route = capabilityRoute(c.key);
        if (!route) return [];
        return [
          {
            label: c.label,
            note: c.note ?? "",
            hay: `${c.label} ${c.note ?? ""} ${c.key}`,
            go: () => go(route),
          },
        ];
      });

      const named: Destination[] = kit.map((v) => ({
        label: v.name,
        note: v.is_empty ? `${v.type}, empty` : `${v.type}, ${v.lot_name ?? "wine"}`,
        hay: `${v.name} ${v.type} ${v.lot_name ?? ""}`,
        go: () => go({ at: "vessel", id: v.id }),
      }));

      const all = [...places, ...doable, ...named];

      function draw(): void {
        const q = box.value().toLowerCase().trim();
        // Every letter in order, not a substring: "wb" finds "Weigh bins". It is
        // the cheapest fuzzy match there is and it is the one people expect.
        const hits = q
          ? all.filter((d) => subsequence(q, d.hay.toLowerCase()))
          : all.slice(0, 12);
        body.replaceChildren(
          hits.length === 0
            ? empty("Nothing matches that.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...hits.slice(0, 20).map((d) => {
                  const row = el(
                    "li",
                    {
                      class: "vessel-row vessel-row-tappable",
                      role: "button",
                      tabindex: "0",
                    },
                    el("span", { class: "vessel-name", text: d.label }),
                    el("span", { class: "vessel-detail", text: d.note }),
                  );
                  on(row, "click", d.go);
                  on(row, "keydown", (ev) => {
                    if (ev.key === "Enter") {
                      ev.preventDefault();
                      d.go();
                    }
                  });
                  return row;
                }),
              ),
        );
      }

      on(box.input, "input", draw);
      // Enter takes the first hit, which is the whole point of typing three
      // letters rather than scrolling.
      on(box.input, "keydown", (ev) => {
        if (ev.key !== "Enter") return;
        const q = box.value().toLowerCase().trim();
        const first = q
          ? all.find((d) => subsequence(q, d.hay.toLowerCase()))
          : undefined;
        if (first) {
          ev.preventDefault();
          first.go();
        }
      });
      draw();
      box.input.focus();
    } catch (error) {
      body.replaceChildren(fail(error));
    }
  })();

  return view;
}

/** Every letter of `needle` appearing in order somewhere in `hay`. */
function subsequence(needle: string, hay: string): boolean {
  let i = 0;
  for (const ch of hay) {
    if (ch === needle[i]) i += 1;
    if (i === needle.length) return true;
  }
  return needle.length === 0;
}

/** Which screen records a given capability, where one exists. The contract says
 * what can be recorded and not where somebody does it, which is the gap AR-Q8
 * names: this map is knowledge living in the client that the kernel could hold,
 * and it is small enough to be worth saying so rather than pretending. */
function capabilityRoute(key: string): Place | null {
  const routes: Record<string, Place> = {
    "cellar.weigh_bins": { at: "scale" },
    "cellar.start_press": { at: "press" },
    "cellar.draw_cut": { at: "press" },
    "cellar.draw_to_level": { at: "press" },
    "cellar.finish_press": { at: "press" },
    "cellar.add_to_wine": { at: "additions" },
    "cellar.take_sample": { at: "sampling" },
    "cellar.count_supply": { at: "stores" },
    "cellar.set_vintage": { at: "vintages" },
    "cellar.set_colour": { at: "colours" },
    "cellar.register_bins": { at: "bins" },
    "cellar.register_glycol_machine": { at: "glycol" },
    "cellar.hook_up_glycol": { at: "glycol" },
    "cellar.unhook_glycol": { at: "glycol" },
    "cellar.add_vessels": { at: "vessel-new" },
    "cellar.recondition_barrel": { at: "colours" },
    "cellar.declare_barrel_colour": { at: "colours" },
    "cellar.cancel_pick": { at: "intake" },
  };
  return routes[key] ?? null;
}

// --- sampling --------------------------------------------------------------

// "Samples should be able to be assigned to vineyards and blocks and varieties,
// both as a sampling button and in the vineyard button."
//
// Two of those three are subjects already. The third is the interesting one: a
// variety is a word, and sampling a word is not a thing somebody does. What they
// do is walk into the Southeast block and pick Pinot Gris, and that is a
// planting, which `0039` already made a row. So the picker below offers
// vineyards, blocks and plantings, and the third reads as "Vitae Springs
// Vineyard Southeast Pinot Gris" rather than as "Pinot Gris", because which
// Pinot Gris is the whole question.
//
// **A sample carries no readings.** It is the act; the numbers are typed notes
// about it. So taking one lands you on the thing that holds them, and the same
// control that turns any note into a fact turns "21.5" into a Brix.
// --- picking bins, as a stack ----------------------------------------------

// The winemaker: "Also batch add for picking bins. I'd rather just inventory
// and add as they don't really differ."
//
// **They do not differ.** A barrel has a maker, a toast, a year and a history
// worth arguing about. A picking bin has a number written on the side. Sixty of
// them differ in one integer, so this screen asks how many and what to call
// them and nothing else: the type, the capacity and the numbering all come from
// the stack already in the shed.
//
// The inventory above the form is the other half of "just inventory". Counted
// rather than listed, because the useful facts about sixty interchangeable
// objects are how many there are, how many hold fruit, and how many go back to
// somebody, and a list of sixty names answers none of those without arithmetic.
// --- what is running -------------------------------------------------------

// The winemaker: "there should also be a tab called running operations that has
// open things: press going, pick going, etc."
//
// Every one of these was already a badge on the home screen, added one at a
// time as somebody noticed a thing going missing. The cost of that is that
// knowing what is in flight means knowing which badges to read, which is
// exactly the knowledge somebody coming back after two days does not have.
//
// Grouped by heading rather than flat, because "a press is going" and "a pick
// has fruit on the pad" are different kinds of worry, and oldest first inside
// each, because the press started four hours ago is the one worth asking about.
// --- a note about anything -------------------------------------------------

// "I want to be able to add a note to anything. Maybe a permanent top right
// block to select something on any screen to take a note of? One of my first
// uses will be to make notes of verbage changes, so notes point to actual
// objects."
//
// add_note has taken any registered subject since 0063, so this is the control
// and not the capability. What it has to get right is the default: a note filed
// against the wrong thing is worse than one filed against nothing, because it
// will be found by somebody looking at the wrong object.

// What the screen somebody is standing on is about, where that is a thing the
// kernel knows. Null means the screen itself is the only subject, which is the
// case a wording note wants anyway.
function subjectOfPlace(place: Place): { type: string; id: string } | null {
  switch (place.at) {
    case "vessel":
    case "vessel-edit":
    case "vessel-fill":
    case "vessel-photos":
      return { type: "vessel", id: place.id };
    case "vessel-type":
      // 0101 registered term, which is where the words this winery chose live.
      return { type: "term", id: place.id };
    case "wine":
    case "pick-photos":
      return { type: "node", id: place.id };
    // pick-bins is reachable with a pick and without one, so its id is only
    // sometimes there. Without one the screen is the subject, which is right:
    // a note taken on the bin list with no pick open is about the list.
    case "pick-bins":
      return place.id ? { type: "node", id: place.id } : null;
    case "block":
      return { type: "block", id: place.id };
    default:
      // Including every screen with no id, and `sample`, which is not a subject
      // type the kernel has. Guessing at one would file notes against a
      // subject_type add_note refuses, which is a failure at save time rather
      // than a wrong default.
      return null;
  }
}

// The sheet. Opened from the button every screen carries.
function noteSheet(place: Place): HTMLElement {
  const said = el("div", {});
  const body = field({
    label: "The note",
    hint: "What you want to remember about it.",
  });
  const about = el("select", { class: "input" });
  const existing = el("div", {});
  const holder = el("div", { class: "rows" }, empty("Loading."));

  const sheet = el(
    "div",
    { class: "sheet" },
    el(
      "div",
      { class: "sheet-inner" },
      el("h2", { class: "section-head", text: "Take a note" }),
      holder,
    ),
  );

  function close(): void {
    sheet.remove();
  }

  void (async () => {
    const here = subjectOfPlace(place);
    const rows = await screens();
    const screenRow = rows.find((r) => r.key === place.at) ?? null;

    // Two options at most, and the first is the one that is right more often.
    // A note taken while standing on a vessel is nearly always about the
    // vessel; a note taken on a list is about the screen.
    const choices: { value: string; text: string }[] = [];
    if (here) {
      choices.push({
        value: `${here.type}:${here.id}`,
        text: `This ${here.type === "term" ? "vessel type" : here.type}`,
      });
    }
    if (screenRow) {
      choices.push({
        value: `screen:${screenRow.id}`,
        text: `This screen (${screenRow.label})`,
      });
    }

    if (choices.length === 0) {
      // Rather than a composer that cannot save. S-89's neighbour: a screen the
      // registry has not caught up with, which the gate is supposed to prevent.
      holder.replaceChildren(
        banner(
          "There is nothing on this screen a note can point at yet. " +
            "That is a gap in the app rather than in what you wanted to say.",
          "error",
        ),
        button("Close", close, "quiet"),
      );
      return;
    }

    about.replaceChildren(
      ...choices.map((c) => el("option", { value: c.value, text: c.text })),
    );

    async function showExisting(): Promise<void> {
      const [type, id] = about.value.split(":");
      if (!type || !id) return;
      try {
        const already = await notesFor(type, id);
        existing.replaceChildren(
          already.length === 0
            ? el("span", {})
            : el(
                "div",
                { class: "rows" },
                el("span", {
                  class: "field-label",
                  text: `Already said about this (${already.length})`,
                }),
                // The last three. Enough to notice you are about to write the
                // same thing twice, which is what a wording list fills up with.
                ...already
                  .slice(0, 3)
                  .map((n) => el("p", { class: "row-note", text: n.body })),
              ),
        );
      } catch {
        // A read failing must not stop somebody writing the note. The list is
        // a convenience and the note is the point.
        existing.replaceChildren(el("span", {}));
      }
    }

    on(about, "change", () => void showExisting());

    holder.replaceChildren(
      el(
        "div",
        { class: "field" },
        el("span", { class: "field-label", text: "About" }),
        about,
      ),
      body.root,
      existing,
      el(
        "div",
        { class: "button-row" },
        button("Save the note", async () => {
          const text = body.value().trim();
          if (!text) {
            said.replaceChildren(banner("There is nothing here to say.", "error"));
            return;
          }
          const [type, id] = about.value.split(":");
          if (!type || !id) return;
          try {
            await addNote({ subjectType: type, subjectId: id, body: text });
            close();
          } catch (error) {
            said.replaceChildren(fail(error));
          }
        }),
        button("Close", close, "quiet"),
      ),
      said,
    );
    void showExisting();
  })();

  return sheet;
}

// --- glycol ----------------------------------------------------------------

// "The glycol jackets should be linked to a glycol pump and chiller/cooler",
// and then: "we have two glycol machines, both have pumps and coolers, one can
// also heat (the bigger one, but can only cool or heat at once)."
//
// Read from both ends on one screen, because that is the request: each machine
// with what is hanging off it, and underneath, the jackets on nothing. A vessel
// also carries its machine on its own row, which is the other direction.
function glycolScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const notice = el("div", {});
  const view = screen(
    "Glycol",
    lede("Each machine, and the jackets hanging off it."),
    notice,
    body,
  );

  function openVessel(label: string, id: string): HTMLElement {
    const link = el("button", { class: "link", text: label });
    on(link, "click", () => go({ at: "vessel", id }));
    return link;
  }

  function direction(running: GlycolMachineLoad["running"]): string {
    return running === "both"
      ? "cooling and heating at once"
      : running === "off"
        ? "nothing on it is calling"
        : running;
  }

  async function load(): Promise<void> {
    const [machines, all, clashes] = await Promise.all([
      glycolMachines(),
      jackets(),
      glycolConflicts(),
    ]);

    // Somewhere to put a hose. Rebuilt per jacket, because a select is a
    // control and two rows cannot share one.
    function machinePicker(j: VesselGlycol): HTMLElement {
      const pick = el("select", { class: "input" });
      pick.replaceChildren(
        el("option", { value: "", text: j.machine ? "Move to" : "Hook to" }),
        ...machines
          .filter((m) => m.active && m.id !== j.machine_id)
          .map((m) =>
            el("option", {
              value: m.id,
              // Said on the option rather than found out by being refused. A
              // tank held warm on a machine with no heater is a refusal the
              // kernel makes, and a person should see it coming.
              text:
                j.mode === "heating" && !m.can_heat
                  ? `${m.name} (cannot heat)`
                  : m.name,
            }),
          ),
      );
      on(pick, "change", async () => {
        if (!pick.value) return;
        try {
          const out = await hookUpGlycol(j.vessel_id, pick.value);
          notice.replaceChildren(
            banner(
              out.already
                ? `${out.vessel} was already on ${out.machine}.`
                : `${out.vessel} is on ${out.machine}.`,
              out.already ? "note" : "good",
            ),
          );
          await load();
        } catch (error) {
          notice.replaceChildren(fail(error));
        }
      });
      return pick;
    }

    function jacketRow(j: VesselGlycol): HTMLElement {
      const held =
        j.mode === "off"
          ? "not being held"
          : `${j.mode}${j.setpoint_c !== null ? ` to ${j.setpoint_c}C` : ""}`;
      return el(
        "div",
        { class: "row" },
        el(
          "div",
          { class: "row-main" },
          // Wired rather than given as an attribute: el() sets anything it does
          // not know with setAttribute, so an onclick here would be stored as a
          // string and never fire, which is a link that looks like a link.
          openVessel(j.vessel, j.vessel_id),
          el("span", { class: "row-note", text: `${j.type}, ${held}` }),
        ),
        el(
          "div",
          { class: "button-row" },
          machinePicker(j),
          ...(j.machine_id
            ? [
                button(
                  "Take off",
                  async () => {
                    try {
                      const out = await unhookGlycol(j.vessel_id);
                      notice.replaceChildren(
                        banner(
                          out.unhooked
                            ? `${out.vessel} is on no machine.`
                            : `${out.vessel} was already on nothing.`,
                          out.unhooked ? "good" : "note",
                        ),
                      );
                      await load();
                    } catch (error) {
                      notice.replaceChildren(fail(error));
                    }
                  },
                  "quiet",
                ),
              ]
            : []),
        ),
      );
    }

    const loose = all.filter((j) => j.on_nothing);

    body.replaceChildren(
      // The conflicts first, and they name both sides, because the thing to
      // decide is which of the two to move.
      ...clashes.map((c) =>
        banner(
          `${c.machine} is being asked to cool ${c.cold_side} and heat ${c.warm_side} ` +
            "at the same time, which it cannot do. Move one of them, or change a mode.",
          "error",
        ),
      ),
      ...(machines.length === 0
        ? [empty("No glycol machines yet. Add the first one below.")]
        : machines.map((m) => {
            const on = all.filter((j) => j.machine_id === m.id);
            return el(
              "div",
              { class: "card" },
              el(
                "h2",
                { class: "section-head" },
                el("span", { text: m.name }),
                el("span", {
                  class: "row-note",
                  text: m.can_heat ? " cools or heats" : " cools only",
                }),
              ),
              el("p", {
                class: "lede",
                // Derived, and said as derived. S-88: this is what the jackets
                // are asking for, not what the machine is doing, and nothing in
                // this app has ever touched the machine.
                text:
                  `${m.vessels} hooked up, ${direction(m.running)}` +
                  (m.coldest_c !== null ? `, coldest ${m.coldest_c}C` : "") +
                  (m.location_name ? `. Stands in ${m.location_name}` : ""),
              }),
              on.length === 0
                ? empty("Nothing on it.")
                : el("div", { class: "rows" }, ...on.map(jacketRow)),
            );
          })),
      ...(loose.length > 0
        ? [
            el("h2", { class: "section-head", text: "Jackets on no machine" }),
            el("p", {
              class: "lede",
              text: "Either fine or forgotten. Listed so it can be one or the other on purpose.",
            }),
            el("div", { class: "rows" }, ...loose.map(jacketRow)),
          ]
        : []),
      addMachine(),
      button("Back", () => goBack(), "quiet"),
    );
  }

  function addMachine(): HTMLElement {
    const name = field({ label: "Called", placeholder: "Big glycol" });
    const heats = checkbox("Can heat as well as cool", false);
    const said = el("div", {});
    return el(
      "details",
      { class: "more" },
      el("summary", { text: "Add a glycol machine" }),
      rows(
        name.root,
        heats.root,
        button("Add it", async () => {
          if (!name.value().trim()) {
            said.replaceChildren(banner("Give it a name.", "error"));
            return;
          }
          try {
            await registerGlycolMachine({
              name: name.value().trim(),
              canHeat: heats.input.checked,
            });
            name.input.value = "";
            heats.input.checked = false;
            await load();
          } catch (error) {
            said.replaceChildren(fail(error));
          }
        }),
        said,
      ),
    );
  }

  void load();
  return view;
}

function runningScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("Running", lede("Everything started and not finished."), body);

  function where(r: RunningOperation): Place | null {
    switch (r.kind) {
      case "press":
        return { at: "press" };
      case "pick":
        return { at: "pick-bins", id: r.subject_id };
      case "import":
        return null;
      default:
        return r.subject_type === "vessel" ? { at: "vessel", id: r.subject_id } : null;
    }
  }

  function ago(since: string | null): string {
    if (!since) return "";
    const mins = Math.max(0, Math.round((Date.now() - Date.parse(since)) / 60000));
    if (mins < 60) return `${mins} min`;
    const hours = Math.round(mins / 60);
    if (hours < 36) return `${hours} h`;
    return `${Math.round(hours / 24)} days`;
  }

  async function load(): Promise<void> {
    const [rows_, hot] = await Promise.all([running(), watching()]);

    if (rows_.length === 0 && hot.length === 0) {
      body.replaceChildren(
        banner("Nothing is running and nothing is being watched.", "good"),
        button("Back", () => goBack(), "quiet"),
      );
      return;
    }

    // The hot list first. 0096. A thing somebody asked to keep in front of
    // them outranks a thing that merely has not finished, and the two are
    // different questions: "what is going on" and "what am I worried about".
    const watched = new Set(hot.map((w) => w.subject_id));

    function hotRow(w: Watching): HTMLElement {
      const said = el("div", {});
      // "I imagine by the time it's finished it'll be more like 450 liters."
      // The gap is the whole point, so both numbers are on the row and
      // neither is dressed up as the other.
      const progress =
        w.expect !== null && w.so_far !== null
          ? `${Number(w.so_far).toLocaleString()} of ${Number(w.expect).toLocaleString()} ${w.unit ?? ""}`.trim() +
            `, ${Math.round((Number(w.so_far) / Number(w.expect)) * 100)}% of what you expected`
          : w.expect !== null
            ? `expecting ${Number(w.expect).toLocaleString()} ${w.unit ?? ""}`.trim()
            : "no number, just keeping an eye on it";

      return el(
        "li",
        { class: "vessel-row" },
        el("span", { class: "vessel-name", text: w.what ?? "something" }),
        el("span", { class: "vessel-detail", text: progress }),
        ...(w.note ? [el("span", { class: "vessel-detail", text: w.note })] : []),
        button(
          "Stop watching",
          async () => {
            try {
              await unwatchSubject(w.subject_type, w.subject_id);
              await load();
            } catch (error) {
              said.replaceChildren(fail(error));
            }
          },
          "quiet",
        ),
        said,
      );
    }

    // On a running thing that nobody is watching yet: say what you expect.
    function expectBox(r: RunningOperation): HTMLElement {
      const how = field({
        label: "What do you expect",
        type: "number",
        placeholder: r.kind === "press" ? "450" : "",
        hint:
          r.kind === "press"
            ? "Litres by the time it is finished. It stays an expectation and never becomes a measurement."
            : "A number you have in mind. It stays an expectation.",
      });
      const said = el("div", {});
      return el(
        "details",
        { class: "more" },
        el("summary", { text: "Watch this" }),
        rows(
          how.root,
          button(
            "Keep it in front of me",
            async () => {
              try {
                await watchSubject({
                  subjectType: r.subject_type,
                  subjectId: r.subject_id,
                  expect: how.value() ? Number(how.value()) : null,
                  unit: how.value() ? (r.kind === "press" ? "litres" : "units") : null,
                });
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

    const headings = [...new Set(rows_.map((r) => r.heading))];

    body.replaceChildren(
      rows(
        ...(hot.length === 0
          ? []
          : [
              el("h2", { class: "section-head", text: "Watching" }),
              el("ul", { class: "vessel-list" }, ...hot.map(hotRow)),
            ]),
        ...headings.flatMap((h) => [
          el("h2", { class: "section-head", text: h }),
          el(
            "ul",
            { class: "vessel-list" },
            ...rows_
              .filter((r) => r.heading === h)
              .map((r) => {
                const to = where(r);
                const row = el(
                  "li",
                  {
                    class: `vessel-row${to ? " vessel-row-tappable" : ""}`,
                    ...(to ? { role: "button", tabindex: "0" } : {}),
                  },
                  el("span", { class: "vessel-name", text: r.what }),
                  el("span", {
                    class: "vessel-detail",
                    text: r.detail ?? "",
                  }),
                  // How long it has been going, which is the thing that turns
                  // a list into a question worth asking.
                  el("span", { class: "tag tag-inherited", text: ago(r.since) }),
                );
                if (to) {
                  const open = () => go(to);
                  on(row, "click", open);
                  on(row, "keydown", (ev) => {
                    if (ev.key === "Enter" || ev.key === " ") {
                      ev.preventDefault();
                      open();
                    }
                  });
                }
                return watched.has(r.subject_id)
                  ? row
                  : el("li", { class: "vessel-row-group" }, row, expectBox(r));
              }),
          ),
        ]),
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

function binsScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Picking bins",
    lede(
      "How many there are and whose they are. Register them in a stack: bins do " +
        "not differ, so nothing is asked about them one at a time.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const [stock, owed] = await Promise.all([binInventory(), binsToReturn()]);

    const howMany = field({
      label: "How many",
      type: "number",
      placeholder: "12",
      hint: "Up to forty at once.",
    });
    const prefix = field({
      label: "Called",
      placeholder: "PB",
      // 0098. Leaving this blank on a borrowed stack gives them the lender's
      // name rather than the next numbers in our own series, which is what
      // put five of Pearlstaad's bins in the middle of ours as PB4 to PB8.
      hint:
        "Blank means PB for ours and the lender's name for borrowed ones. " +
        "Numbering carries on from the highest already used, so nothing is reused.",
    });
    const lender = field({
      label: "On loan from",
      placeholder: "Pearlstaad",
      hint: "A grower who lent them. Leave blank if they are yours.",
    });

    const total = stock.reduce((n, r) => n + Number(r.bins), 0);
    const working = stock.reduce((n, r) => n + Number(r.in_use), 0);

    body.replaceChildren(
      rows(
        stock.length === 0
          ? empty("No picking bins registered.")
          : el(
              "div",
              { class: "summary" },
              summaryRow("Bins", String(total)),
              summaryRow("Holding fruit", `${working} of ${total}`),
              ...stock.map((r) =>
                summaryRow(
                  r.whose ?? "Ours",
                  `${r.bins} ${r.bin_type.toLowerCase()}${r.bins === 1 ? "" : "s"}, ` +
                    `${r.in_use} holding fruit` +
                    (r.borrowed ? ", goes back" : ""),
                ),
              ),
            ),

        // Only when there are any. A permanent empty heading is a job that
        // always looks half done.
        ...(owed.length === 0
          ? []
          : [
              banner(
                `${owed.length} borrowed bin${owed.length === 1 ? " is" : "s are"} empty and owed back.`,
                "note",
              ),
              button("See which", () => go({ at: "bins-to-return" }), "secondary"),
            ]),

        el("h2", { class: "section-head", text: "Register a stack" }),
        howMany.root,
        prefix.root,
        lender.root,
        button("Register them", async () => {
          const n = howMany.value() ? Number(howMany.value()) : 0;
          if (!n) {
            message.replaceChildren(banner("How many bins?", "error"));
            return;
          }
          try {
            const out = await registerBins({
              count: n,
              prefix: prefix.value() || null,
              onLoanFrom: lender.value() || null,
            });
            message.replaceChildren(
              banner(
                out.count === 1
                  ? `Registered ${out.from}.`
                  : `Registered ${out.count} bins, ${out.from} to ${out.to}.`,
                "good",
              ),
            );
            howMany.input.value = "";
            await load();
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        }),
        message,
        el("p", {
          class: "field-hint",
          text:
            "These are inventory. Adding them to a pick happens on the picking " +
            "screen, where you choose which ones went out.",
        }),
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

function samplingScreen(subjectType?: string, subjectId?: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Sampling",
    lede(
      "Record that somebody sampled something. The readings go on afterwards, " +
        "which is what lets one sample carry a Brix and a pH and a remark about the weather.",
    ),
    body,
  );

  // The winemaker's three: "vineyard sampling and juice sampling and wine
  // sampling should all be easily separated". Sticky per device, because which
  // of the three you are doing changes about twice a season and not twice a
  // screen. Nothing is hidden by default: the first time somebody opens this,
  // a filter they did not set that is already hiding rows is indistinguishable
  // from a list that has lost them.
  const KINDS: Array<{ key: SampleKind; label: string; note: string }> = [
    {
      key: "vineyard",
      label: "Vineyard",
      note: "Watching fruit ripen, to decide when to pick.",
    },
    { key: "juice", label: "Juice", note: "Fruit in bins, and ferments." },
    { key: "wine", label: "Wine", note: "What is in barrel and tank." },
  ];
  const off = prefSet("sample_kinds_off");
  // Not `on`: that is the event binder every screen in this file uses, and
  // shadowing it here made three listeners further down stop compiling.
  function showing(k: SampleKind): boolean {
    return !off.has(k);
  }
  function chosen(): SampleKind[] {
    // An empty selection means every kind, rather than nothing. Turning the
    // last one off and getting an empty screen is a worse answer than turning
    // the filter off, and it is the one somebody reaches by tapping.
    const picked = KINDS.map((k) => k.key).filter(showing);
    return picked.length === 0 ? KINDS.map((k) => k.key) : picked;
  }

  async function load(): Promise<void> {
    const want = chosen();
    const [targets, taken] = await Promise.all([
      sampleTargets(),
      samples(subjectType, subjectId, want),
    ]);

    // Both halves filter on the same thing. A list that hides last vintage's
    // barrels while the picker still offers all of them has separated nothing.
    const shown = targets.filter((t) => want.includes(t.kind));

    const pick = el("select", { class: "input" });
    const groups = [...new Set(shown.map((t) => t.grouping))];
    pick.replaceChildren(
      ...groups.map((g) =>
        el(
          "optgroup",
          { label: g },
          ...shown
            .filter((t) => t.grouping === g)
            .map((t) =>
              el("option", {
                value: `${t.subject_type}:${t.subject_id}`,
                text: t.detail ? `${t.label} (${t.detail})` : t.label,
                ...(subjectType === t.subject_type && subjectId === t.subject_id
                  ? { selected: "true" }
                  : {}),
              }),
            ),
        ),
      ),
    );

    const filters = el(
      "div",
      { class: "button-row" },
      ...KINDS.map((k) => {
        const b = button(
          k.label,
          async () => {
            if (showing(k.key)) off.add(k.key);
            else off.delete(k.key);
            await load();
          },
          showing(k.key) ? "primary" : "quiet",
        );
        b.title = k.note;
        return b;
      }),
    );

    const when = field({
      label: "When",
      type: "datetime-local",
      hint: "Blank means now. Useful for a sample taken this morning.",
    });
    const about = field({
      label: "About the sample itself",
      placeholder: "north end, 50 berries",
      hint: "How it was taken. The readings go on next.",
    });

    body.replaceChildren(
      rows(
        filters,
        el("p", {
          class: "field-hint",
          text:
            KINDS.filter((k) => !showing(k.key)).length === 0
              ? "Showing all three. Tap one to put it away."
              : `Showing ${want.join(" and ")}.`,
        }),
        el(
          "div",
          { class: "field" },
          el("span", { class: "field-label", text: "What was sampled" }),
          pick,
          el("span", {
            class: "field-hint",
            text:
              "A whole vineyard, one block, or one variety in one block. " +
              "Sampling a variety means sampling it somewhere.",
          }),
        ),
        when.root,
        about.root,
        button("Record the sample", async () => {
          const [type, id] = pick.value.split(":");
          if (!type || !id) {
            message.replaceChildren(banner("Pick what was sampled.", "error"));
            return;
          }
          try {
            const out = await takeSample({
              subjectType: type,
              subjectId: id,
              at: when.value() ? new Date(when.value()).toISOString() : null,
              note: about.value() || null,
            });
            message.replaceChildren(
              banner(
                `Sampled ${out.of}. Add the readings below: each one is a note ` +
                  "you turn into a fact.",
                "good",
              ),
            );
            about.input.value = "";
            await load();
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        }),
        message,

        el("h2", { class: "section-head", text: "Samples" }),
        taken.length === 0
          ? empty("Nothing sampled yet.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...taken.slice(0, 30).map((sm) => {
                const row = el(
                  "li",
                  {
                    class: "vessel-row vessel-row-tappable",
                    role: "button",
                    tabindex: "0",
                  },
                  el("span", {
                    class: "vessel-name",
                    text: sm.of_what ?? "something that is no longer there",
                  }),
                  el("span", {
                    class: "vessel-detail",
                    text:
                      `${new Date(sm.at).toLocaleString()}` +
                      // The lot as it was when the sample was taken, and its
                      // vintage, because the whole complaint was previous
                      // vintages getting in the way of this one.
                      (sm.lot_name
                        ? `, ${sm.lot_name}${sm.vintage ? ` (${sm.vintage})` : ""}`
                        : "") +
                      (sm.note ? `, ${sm.note}` : "") +
                      `, ${sm.readings} reading${sm.readings === 1 ? "" : "s"}`,
                  }),
                  el("span", { class: `tag tag-kind-${sm.kind}`, text: sm.kind }),
                  // Zero readings on a sample is the state worth seeing: somebody
                  // took fruit and the numbers never got entered.
                  sm.readings === 0
                    ? el("span", { class: "tag tag-inherited", text: "no readings" })
                    : null,
                );
                // Into the sample itself, which is what the readings hang off.
                // Not into the block: two samples of one block a week apart are
                // two different sets of numbers.
                const open = () => go({ at: "sample", id: sm.event_id });
                on(row, "click", open);
                on(row, "keydown", (ev) => {
                  if (ev.key === "Enter" || ev.key === " ") {
                    ev.preventDefault();
                    open();
                  }
                });
                return row;
              }),
            ),
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

// --- one sample, and what came off it --------------------------------------

// The readings live on the sample rather than on the block, because two samples
// of one block a week apart are two different sets of numbers and watching them
// move is the whole point of sampling.
//
// A reading is a note written and typed in one go: the words and the value
// together, with `about_event` pointing at this sample. Same machinery as every
// other note, which is why there is no reading table anywhere in this schema.
function sampleScreen(eventId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen("Sample", body);

  async function load(): Promise<void> {
    const [all, kinds] = await Promise.all([samples(), terms("fact_kind")]);
    const sm = all.find((x) => x.event_id === eventId);
    if (!sm) {
      body.replaceChildren(
        empty("That sample is not there."),
        button("Back", () => goBack(), "quiet"),
      );
      return;
    }
    const facts = (await typedFacts(sm.subject_type, sm.subject_id)).filter(
      (f) => f.about_event === eventId,
    );

    const kind = el("select", { class: "input" });
    kind.replaceChildren(
      ...kinds.map((k) => el("option", { value: k.value, text: k.label })),
    );
    const value = field({ label: "Reading", placeholder: "21.5" });
    const words = field({
      label: "Anything worth saying",
      placeholder: "off the north end, a bit shrivelled",
      hint: "Kept beside the number, which is the reason this is not a column.",
    });

    function shapeOf(): string {
      const picked = kinds.find((k) => k.value === kind.value);
      return String(picked?.attributes?.value_type ?? "text");
    }
    on(kind, "change", () => {
      value.input.type = shapeOf() === "number" ? "number" : "text";
    });
    value.input.type = shapeOf() === "number" ? "number" : "text";

    body.replaceChildren(
      rows(
        summaryRow("Of", sm.of_what ?? "something that is no longer there"),
        summaryRow("Taken", new Date(sm.at).toLocaleString()),
        summaryRow("By", sm.by_name ?? "somebody"),
        ...(sm.note ? [summaryRow("Note", sm.note)] : []),

        el("h2", { class: "section-head", text: "Readings" }),
        facts.length === 0
          ? empty("Nothing read off this sample yet.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...facts.map((f) =>
                el(
                  "li",
                  { class: "vessel-row" },
                  el("span", {
                    class: "vessel-name",
                    text: `${f.kind_label}: ${f.value}${f.unit ? ` ${f.unit}` : ""}`,
                  }),
                  el("span", { class: "vessel-detail", text: f.body }),
                  f.provenance === "confirmed"
                    ? el("span", { class: "tag", text: "confirmed" })
                    : null,
                ),
              ),
            ),

        el("h2", { class: "section-head", text: "Add a reading" }),
        kinds.length === 0
          ? banner(
              "No kinds of fact are set up, so there is nothing to record a reading as. " +
                "Set up, then Kinds of fact.",
              "note",
            )
          : el("span", {}),
        el(
          "div",
          { class: "field" },
          el("span", { class: "field-label", text: "What was measured" }),
          kind,
        ),
        value.root,
        words.root,
        button("Record it", async () => {
          if (!kind.value) {
            message.replaceChildren(banner("Say what was measured.", "error"));
            return;
          }
          if (!value.value()) {
            message.replaceChildren(banner("Give the reading.", "error"));
            return;
          }
          try {
            // Two calls rather than one: the note is written, then typed. The
            // composition is the client's and both rules are the kernel's.
            const label = kinds.find((k) => k.value === kind.value)?.label ?? "reading";
            const made = await addNote({
              subjectType: sm.subject_type,
              subjectId: sm.subject_id,
              body: words.value() || `${label} ${value.value()}`,
              aboutEvent: eventId,
              at: sm.at,
            });
            await typeNote({
              noteId: made.id,
              kind: kind.value,
              valueNum: shapeOf() === "number" ? Number(value.value()) : null,
              valueText: shapeOf() === "number" ? null : value.value(),
            });
            value.input.value = "";
            words.input.value = "";
            await load();
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        }),
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

// --- letting somebody in ---------------------------------------------------

// The winemaker: "how could I do this so my interns don't need to download an
// app besides the vitae springs app?"
//
// They do not have to. It is a web page they add to their home screen, and the
// install prompt has been there since `install.ts`. What was in the way is that
// the only route to it is Tailscale, and getting off Tailscale means being
// reachable by strangers, and **reaching the sign-up page used to be the same
// thing as working here**.
//
// So: an invite. An administrator makes one, reads six characters out loud, and
// the intern types them when they claim. No email, because a winery hands
// somebody a phone in a barn rather than asking them to check their inbox, and
// because email delivery would be a dependency this project has not taken.
function invitesScreen(user: AppUser): HTMLElement {
  if (user.role !== "admin") {
    return screen(
      "Letting somebody in",
      banner(
        "Only an administrator hands out invites. That is the point of them: a " +
          "cellar hand who could issue one could admit their own second account.",
        "note",
      ),
      button("Back", () => goBack(), "quiet"),
    );
  }

  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Letting somebody in",
    lede(
      "A code somebody types when they sign up. Six characters, good for a week, " +
        "and usable once.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const list = await invites();
    const asAdmin = checkbox("They should be an administrator", false);
    const why = field({
      label: "Who is it for",
      placeholder: "Sam, harvest intern",
      hint: "So that a code sitting unused in a month still means something.",
    });

    const waiting = list.filter((i) => !i.used_at);
    const spent = list.filter((i) => i.used_at);

    body.replaceChildren(
      rows(
        why.root,
        asAdmin.root,
        button("Make an invite", async () => {
          try {
            const made = await makeInvite(
              asAdmin.input.checked ? "admin" : "cellar",
              why.value() || null,
            );
            message.replaceChildren(
              banner(
                `${made.code}. Read that to them. It works once and expires in a week.`,
                "good",
              ),
            );
            why.input.value = "";
            await load();
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        }),
        message,

        el("h2", { class: "section-head", text: "Outstanding" }),
        waiting.length === 0
          ? empty("Nothing waiting to be used.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...waiting.map((i) =>
                el(
                  "li",
                  { class: "vessel-row" },
                  el("span", { class: "vessel-name", text: i.code }),
                  el("span", {
                    class: "vessel-detail",
                    text:
                      (i.note ? `${i.note}, ` : "") +
                      `${i.role}, ` +
                      (new Date(i.expires_at) < new Date()
                        ? "expired"
                        : `good until ${new Date(i.expires_at).toLocaleDateString()}`),
                  }),
                  button(
                    "Withdraw",
                    async () => {
                      try {
                        await withdrawInvite(i.code);
                        await load();
                      } catch (error) {
                        message.replaceChildren(fail(error));
                      }
                    },
                    "quiet",
                  ),
                ),
              ),
            ),

        // Used ones are kept rather than deleted, because who let somebody in is
        // the only record of it there will ever be.
        ...(spent.length === 0
          ? []
          : [
              el("h2", { class: "section-head", text: "Used" }),
              el(
                "ul",
                { class: "vessel-list" },
                ...spent.map((i) =>
                  el(
                    "li",
                    { class: "vessel-row" },
                    el("span", { class: "vessel-name", text: i.code }),
                    el("span", {
                      class: "vessel-detail",
                      text:
                        (i.note ? `${i.note}, ` : "") +
                        `used ${new Date(i.used_at ?? "").toLocaleDateString()}`,
                    }),
                  ),
                ),
              ),
            ]),
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

// --- kinds of fact ---------------------------------------------------------

// The list that makes `0064` worth having.
//
// A note becomes a fact by being given a kind, and the kinds are registry rows,
// which is what lets an unsettled chemistry specification be data rather than a
// reason to defer. That is only true if somebody can actually add one, so this
// is the screen that makes the claim true rather than theoretical.
//
// Deliberately plain. It is a vocabulary editor and it is used about once a
// season.
function factKindsScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const message = el("div", {});
  const view = screen(
    "Kinds of fact",
    lede(
      "What a note can be turned into. Brix, pH, fruit condition, anything else " +
        "worth asking about later. Adding one is a row, not a change to the app.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const kinds = await terms("fact_kind");

    const label = field({ label: "Name", placeholder: "Brix" });
    const shape = el("select", { class: "input" });
    shape.replaceChildren(
      el("option", { value: "number", text: "A number" }),
      el("option", { value: "text", text: "Written out" }),
    );
    const unit = field({
      label: "Unit",
      placeholder: "Brix",
      hint: "Optional, and recorded rather than checked. That is sorry S-75.",
    });

    body.replaceChildren(
      rows(
        kinds.length === 0
          ? empty("None yet.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...kinds.map((k) =>
                el(
                  "li",
                  { class: "vessel-row" },
                  el("span", { class: "vessel-name", text: k.label }),
                  el("span", {
                    class: "vessel-detail",
                    text:
                      (String(k.attributes?.value_type ?? "text") === "number"
                        ? "a number"
                        : "written out") +
                      (k.attributes?.unit ? `, in ${String(k.attributes.unit)}` : ""),
                  }),
                ),
              ),
            ),
        el("h2", { class: "section-head", text: "Add one" }),
        label.root,
        el(
          "div",
          { class: "field" },
          el("span", { class: "field-label", text: "Its value is" }),
          shape,
        ),
        unit.root,
        button("Add it", async () => {
          if (!label.value().trim()) {
            message.replaceChildren(banner("Give it a name.", "error"));
            return;
          }
          try {
            await addTerm("fact_kind", label.value().trim(), {
              value_type: shape.value,
              ...(unit.value().trim() ? { unit: unit.value().trim() } : {}),
            });
            label.input.value = "";
            unit.input.value = "";
            await load();
          } catch (error) {
            message.replaceChildren(fail(error));
          }
        }),
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

// --- practice mode ---------------------------------------------------------

// A second cellar with nothing real in it.
//
// The winemaker asked for "a server or delete things or whatever so I can
// actually play around and try out things and delete them later, but also use
// the app to record", and then framed the switch as "maybe it's a debugging
// mode that actually ships". So this is a feature, written for a winemaker, and
// the words avoid every programmer's word for it: not sandbox, not staging, not
// dev. Practice.
//
// **Switching signs you out, and that is deliberate rather than a limitation.**
// The two stacks have separate logins, so the session genuinely cannot travel.
// Making somebody sign in again is also the clearest possible signal that they
// have moved, at the one moment it matters most.
function practiceScreen(): HTMLElement {
  const practising = currentBackend() === "practice";
  const message = el("div", {});

  function move(to: "cellar" | "practice"): void {
    switchBackend(to);
    // A full reload rather than a re-render. Every cached thing in this tab
    // belongs to the stack being left, including the session, and a switch that
    // left any of it behind would be the exact confusion this screen exists to
    // prevent.
    window.location.assign("#/home");
    window.location.reload();
  }

  return screen(
    practising ? "You are in practice" : "Practice mode",
    lede(
      practising
        ? "This is not your cellar. Nothing recorded here is real, and all of it " +
            "can be thrown away without touching anything that is."
        : "A second cellar, a copy of the real one, where trying something and " +
            "deleting it afterwards is allowed.",
    ),
    rows(
      summaryRow("Right now", practising ? "Practice" : "The real cellar"),
      el("p", {
        class: "field-hint",
        text:
          "The two have separate logins, so switching signs you out and you " +
          "sign in again on the other side. That is also how you can always " +
          "tell which one you are in.",
      }),
      el("p", {
        class: "field-hint",
        text:
          "Every screen in practice carries a band across the top. If you ever " +
          "cannot see one, you are in the real cellar and what you record counts.",
      }),
      practising
        ? button("Go back to the real cellar", () => move("cellar"))
        : button("Switch to practice", () => {
            message.replaceChildren(
              banner(
                "This signs you out and moves you to the practice cellar. " +
                  "Tap again to confirm.",
                "note",
              ),
              button("Yes, switch to practice", () => move("practice")),
            );
          }),
      message,
      button("Back", () => goBack(), "quiet"),
    ),
  );
}

// --- lots that never said their vintage ------------------------------------

// A list that empties and then stops existing.
//
// `0049` made a lot say either a year or that it is deliberately non-vintage,
// and closed the third state, which was nobody having got round to it. The
// constraint is added `not valid`, so lots written before it are grandfathered
// rather than guessed at. This is where somebody who knows says which, and when
// it is empty the whole entry disappears from the home screen.
//
// The year read off a lot's own name is offered and never filled in for them. A
// lot called "2024 Eola Springs" is almost certainly a 2024, and almost
// certainly not a thing software may decide on somebody's behalf.
// --- colour ----------------------------------------------------------------

// The winemaker asked for red and white barrels and then said the better thing:
// "obviously this is something we are missing in the wine type, which should be
// red/orange/rose/white". So this screen is about wine, and the barrels are what
// falls out of it.
//
// It is one screen rather than two because the two halves only make sense
// together: a barrel reads `unknown` exactly as long as it has held a lot nobody
// has typed, so the list of untyped lots is the thing that turns the barrel list
// from guesswork into an answer. Splitting them would leave somebody looking at
// four unknown barrels with no idea what to do about it.
function coloursScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Colour",
    lede(
      "What colour each wine is, and what that has made of the barrels. A barrel " +
        "goes red when red goes in it and stays red until somebody reconditions it.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const [waiting, barrels, conflicts, palette] = await Promise.all([
      lotsWithoutColour(),
      barrelColours(),
      colourConflicts(),
      terms("wine_colour"),
    ]);

    function lotRow(lot: LotWithoutColour): HTMLElement {
      const said = el("div", {});

      async function answer(colour: string): Promise<void> {
        try {
          const out = await setColour(lot.id, colour);
          said.replaceChildren(
            banner(
              out.left === 0
                ? "Done, and that was the last one."
                : `Done. ${out.left} lot${out.left === 1 ? "" : "s"} still to say.`,
              "good",
            ),
          );
          await load();
        } catch (error) {
          said.replaceChildren(fail(error));
        }
      }

      return el(
        "details",
        { class: "more" },
        el("summary", { text: `${lot.name} (${lot.stage})` }),
        rows(
          summaryRow("Variety", lot.variety ?? "not said"),
          // Offered as a sentence, never as a filled box. Pinot Noir is made
          // here as a red, a rose and a blanc de noir, so a prefilled answer is
          // a wrong answer somebody taps past.
          el("p", {
            class: "field-hint",
            text: lot.likely
              ? `${lot.variety} is almost always white, but say it rather than assume it.`
              : "Pinot Noir is made three ways here, so this one needs somebody who knows.",
          }),
          el(
            "div",
            { class: "button-row" },
            ...palette.map((c) =>
              button(c.label, () => void answer(c.value), "secondary"),
            ),
          ),
          said,
        ),
      );
    }

    function barrelRow(b: BarrelColour): HTMLElement {
      const said = el("div", {});
      const method = field({
        label: "What was done to it",
        placeholder: "Shaved, retoasted, deep cleaned",
        hint: "Required. It is the whole of the evidence that this barrel is white again.",
      });

      const detail =
        b.colour === "red"
          ? `Went red with ${b.went_red_with ?? "an earlier lot"}` +
            (b.went_red_at ? ` on ${new Date(b.went_red_at).toLocaleDateString()}` : "")
          : b.colour === "unknown"
            ? "Has held a lot nobody has said a colour for"
            : "Nothing that stains has been in it";

      return el(
        "details",
        { class: "more" },
        el(
          "summary",
          {},
          el("span", { class: `colour-dot colour-${b.colour}` }),
          el("span", { text: `${b.name}, ${b.colour}` }),
        ),
        rows(
          summaryRow("Why", detail),
          ...(b.reconditioned_at
            ? [
                summaryRow(
                  "Last reconditioned",
                  new Date(b.reconditioned_at).toLocaleDateString(),
                ),
              ]
            : []),
          // For a barrel bought used, which has no history here and would
          // otherwise read white. Offered on anything not already red: a red
          // barrel has nothing to learn from being told it is red, and telling
          // it that it is white is refused by the kernel anyway, because a
          // declaration is not a process.
          ...(b.colour === "red"
            ? []
            : [
                el("p", {
                  class: "field-hint",
                  text:
                    "Bought used? Say what it arrived as. Everything after that " +
                    "still comes from what goes in it.",
                }),
                el(
                  "div",
                  { class: "button-row" },
                  button(
                    "It arrived red",
                    async () => {
                      try {
                        await declareBarrelColour(b.id, "red", null);
                        await load();
                      } catch (error) {
                        said.replaceChildren(fail(error));
                      }
                    },
                    "secondary",
                  ),
                  button(
                    "It arrived neutral white",
                    async () => {
                      try {
                        await declareBarrelColour(b.id, "white", null);
                        await load();
                      } catch (error) {
                        said.replaceChildren(fail(error));
                      }
                    },
                    "secondary",
                  ),
                ),
                said,
              ]),
          // Only offered where it means something. Reconditioning a barrel that
          // is already white records a process that had no effect, and a control
          // that does nothing is worse than no control.
          ...(b.colour === "red"
            ? [
                method.root,
                button(
                  "Reconditioned, so it is white again",
                  async () => {
                    try {
                      await reconditionBarrel(b.id, method.value(), null);
                      await load();
                    } catch (error) {
                      said.replaceChildren(fail(error));
                    }
                  },
                  "secondary",
                ),
                said,
              ]
            : []),
        ),
      );
    }

    body.replaceChildren(
      rows(
        // The conflicts first, because they are the only part of this screen
        // that is about something already wrong.
        ...(conflicts.length === 0
          ? []
          : [
              el("h2", { class: "section-head", text: "Worth a look" }),
              banner(
                `${conflicts.length} lot${conflicts.length === 1 ? " is" : "s are"} ` +
                  "sitting in a barrel that has held red. Nothing stopped it and " +
                  "nothing will: a barrel can be filled before anybody records it.",
                "note",
              ),
              el(
                "ul",
                { class: "vessel-list" },
                ...conflicts.map((c) =>
                  el(
                    "li",
                    { class: "vessel-row" },
                    el("span", {
                      class: "vessel-name",
                      text: `${c.lot} in ${c.vessel}`,
                    }),
                    el("span", {
                      class: "vessel-detail",
                      text: `${c.lot_colour} wine, and ${c.vessel} went red with ${c.went_red_with ?? "an earlier lot"}`,
                    }),
                  ),
                ),
              ),
            ]),

        el("h2", { class: "section-head", text: "Wines with no colour" }),
        waiting.length === 0
          ? banner("Every wine says its colour.", "good")
          : rows(
              el("p", {
                class: "field-hint",
                text:
                  "Say it once on a pick and everything that comes off it " +
                  "inherits it. A barrel cannot be called white while it has " +
                  "held one of these.",
              }),
              ...waiting.map(lotRow),
            ),

        el("h2", { class: "section-head", text: "Barrels" }),
        barrels.length === 0 ? empty("No barrels.") : rows(...barrels.map(barrelRow)),

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

function vintagesScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Lots without a vintage",
    lede(
      "These were recorded before the app started asking. Say which year each " +
        "one is, or that it is non-vintage. Nothing new can land here.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const waiting = await lotsWithoutVintage();

    if (waiting.length === 0) {
      body.replaceChildren(
        banner("Every lot says its vintage.", "good"),
        button("Back", () => goBack(), "quiet"),
      );
      return;
    }

    function row(lot: LotWithoutVintage): HTMLElement {
      const year = field({
        label: "Vintage",
        type: "number",
        placeholder: lot.suggested_year ?? String(new Date().getFullYear()),
        // Deliberately not `value`. A prefilled box is a box people tap past,
        // and the whole reason this lot is on the list is that nobody ever said.
        hint: lot.year_in_the_name
          ? `The name says ${lot.suggested_year}. Type it if that is right.`
          : "The name gives no clue, so this one needs somebody who knows.",
      });
      const said = el("div", {});

      async function answer(vintage: number | null, nv: boolean): Promise<void> {
        try {
          const out = await setVintage(lot.id, vintage, nv);
          said.replaceChildren(
            banner(
              out.left === 0
                ? "Done, and that was the last one."
                : `Done. ${out.left} lot${out.left === 1 ? "" : "s"} still to say.`,
              "good",
            ),
          );
          await load();
        } catch (error) {
          said.replaceChildren(fail(error));
        }
      }

      return el(
        "details",
        { class: "more" },
        el("summary", {
          text: `${lot.name} (${lot.stage})`,
        }),
        rows(
          summaryRow("Recorded", new Date(lot.created_at).toLocaleDateString()),
          year.root,
          button("That is the vintage", () => {
            if (!year.value()) {
              said.replaceChildren(
                banner("Type a year, or say it is non-vintage below.", "error"),
              );
              return;
            }
            void answer(Number(year.value()), false);
          }),
          // Separate control rather than a checkbox above, because these are two
          // different answers and neither is a modifier of the other.
          button("It is non-vintage", () => void answer(null, true), "secondary"),
          said,
        ),
      );
    }

    body.replaceChildren(
      rows(
        ...waiting.map(row),
        el("p", {
          class: "field-hint",
          text:
            "A wine blended from two vintages becomes non-vintage on its own, " +
            "when it is blended. Nothing here needs doing for those.",
        }),
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
    "Notes and photographs",
    lede(
      subject === "node"
        ? "Anything worth saying about this pick, and any picture of it, added " +
            "whenever somebody gets to it. A photograph of the scale belongs to " +
            "the reading it shows rather than to the pick."
        : "Anything worth saying about this vessel, and any picture of it. As " +
            "many as you like: nothing here replaces what was already there.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const [already, weighings, said, facts, kinds] = await Promise.all([
      attachmentsFor(subject, subjectId),
      subject === "node" ? pickWeighings(subjectId) : Promise.resolve([]),
      notesFor(subject, subjectId),
      typedFacts(subject, subjectId),
      terms("fact_kind"),
    ]);
    const typedIds = new Set(facts.map((f) => f.note_id));

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

    // An untyped note, with the one control that turns it into a fact. The kind
    // decides whether the value is a number or words, which is read off the
    // registry rather than guessed here: adding a kind is a row and this screen
    // must not need changing when somebody adds one.
    function untypedRow(n: SubjectNote, allKinds: Term[]): HTMLElement {
      const rowSaid = el("div", {});
      const kind = el("select", { class: "input" });
      kind.replaceChildren(
        el("option", { value: "", text: "Just a note" }),
        ...allKinds.map((k) => el("option", { value: k.value, text: k.label })),
      );
      const value = field({ label: "Value", placeholder: "mostly good" });

      function shapeOf(): string {
        const picked = allKinds.find((k) => k.value === kind.value);
        return String(picked?.attributes?.value_type ?? "text");
      }
      on(kind, "change", () => {
        value.input.type = shapeOf() === "number" ? "number" : "text";
      });

      return el(
        "details",
        { class: "more" },
        el("summary", {
          text:
            `${n.body}  ${new Date(n.at).toLocaleDateString()}` +
            (n.edited_at ? " (reworded)" : ""),
        }),
        rows(
          summaryRow("Said by", n.by_name ?? "somebody"),
          el(
            "div",
            { class: "field" },
            el("span", { class: "field-label", text: "Make it a fact" }),
            kind,
            el("span", {
              class: "field-hint",
              text: "Leave it as just a note if it is talking rather than a measurement.",
            }),
          ),
          value.root,
          button(
            "Type it",
            async () => {
              if (!kind.value) {
                rowSaid.replaceChildren(
                  banner("Pick what kind of fact it is.", "error"),
                );
                return;
              }
              if (!value.value()) {
                rowSaid.replaceChildren(banner("Give it a value.", "error"));
                return;
              }
              try {
                await typeNote({
                  noteId: n.id,
                  kind: kind.value,
                  valueNum: shapeOf() === "number" ? Number(value.value()) : null,
                  valueText: shapeOf() === "number" ? null : value.value(),
                });
                await load();
              } catch (error) {
                rowSaid.replaceChildren(fail(error));
              }
            },
            "secondary",
          ),
          rowSaid,
        ),
      );
    }

    // A fact, with how much anybody has checked it. `observed` and `confirmed`
    // are different states and must not read the same: T0-4 is only worth
    // anything if the difference is visible.
    function factRow(f: TypedFact): HTMLElement {
      const rowSaid = el("div", {});
      return el(
        "li",
        { class: "vessel-row" },
        el("span", {
          class: "vessel-name",
          text: `${f.kind_label}: ${f.value}${f.unit ? ` ${f.unit}` : ""}`,
        }),
        el("span", {
          class: "vessel-detail",
          text:
            `${f.body}, said by ${f.by_name ?? "somebody"}, ` +
            `${new Date(f.at).toLocaleDateString()}`,
        }),
        f.provenance === "confirmed"
          ? el("span", { class: "tag", text: "confirmed" })
          : button(
              "Confirm",
              async () => {
                try {
                  await confirmNote(f.note_id);
                  await load();
                } catch (error) {
                  rowSaid.replaceChildren(fail(error));
                }
              },
              "quiet",
            ),
        rowSaid,
      );
    }

    // First on the screen, because it is the cheapest thing to do and it is what
    // somebody standing over a bin actually came here for. "The fruit was mostly
    // good" is a sentence, not a form.
    const saying = field({
      label: "Say something",
      placeholder:
        subject === "node"
          ? "fruit was mostly good, a bit of shrivel"
          : "gasket perished",
      hint: "Kept with this and never counted as a measurement.",
    });
    const noteWhen = field({
      label: "When it is about",
      type: "datetime-local",
      hint: "Blank means now. Useful for something you noticed this morning.",
    });
    const noteSaid = el("div", {});

    body.replaceChildren(
      rows(
        el("h2", { class: "section-head", text: "Notes" }),
        saying.root,
        noteWhen.root,
        button("Add this note", async () => {
          if (!saying.value().trim()) {
            noteSaid.replaceChildren(banner("Type what you want to say.", "error"));
            return;
          }
          try {
            await addNote({
              subjectType: subject,
              subjectId,
              body: saying.value(),
              at: noteWhen.value() ? new Date(noteWhen.value()).toISOString() : null,
            });
            saying.input.value = "";
            await load();
          } catch (error) {
            noteSaid.replaceChildren(fail(error));
          }
        }),
        noteSaid,
        said.filter((n) => !typedIds.has(n.id)).length === 0
          ? empty("Nothing said about this that is not already a fact.")
          : el(
              "div",
              {},
              ...said
                .filter((n) => !typedIds.has(n.id))
                .map((n) => untypedRow(n, kinds)),
            ),

        // S-74. The migration was the hard half and this is the half that makes
        // it usable: what has been typed about this thing, with the sentence it
        // came from, and whether anybody has checked it.
        ...(facts.length === 0
          ? []
          : [
              el("h2", { class: "section-head", text: "Facts" }),
              el("p", {
                class: "lede",
                text:
                  "Notes somebody turned into something you can ask about. The " +
                  "words are still there, which is the point of not making it a field.",
              }),
              el("div", {}, ...facts.map(factRow)),
            ]),

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

// --- a press, from starting it to finishing it -----------------------------

// --- a press, from starting it to finishing it -----------------------------

// Build order 3, and the screen the winemaker rewrote twice from the crush pad.
// First: "pressing needs to be a process instead of an entry at the end. Like I
// wanted to start a press but I can't know how many liters until after I've
// pressed." Then, having used it: "I want a different pressing UI. Maybe try a
// few different ones I can test out."
//
// So there are three moments, hours apart. Start, which empties the bins and
// puts the fruit in the press. Draw, as many times as it takes, because "you
// might update the liters multiple times, or after different pressures". Finish,
// which is when the yield exists.
//
// **And there are three layouts, because nobody here can tell which one is
// right.** A screen used with wet hands and a hose in the other hand is not a
// screen anybody designs correctly at a desk. The kernel calls, the refusals and
// the messages are shared: what varies is the arrangement, which is the only
// part in question. Whichever he keeps is the finding, and the other two go.
function pressScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "Press",
    lede(
      "Start a press when the fruit goes in. Come back and record the litres as " +
        "they come off, as many times as you like. Finish it when it is done.",
    ),
    body,
  );

  async function load(): Promise<void> {
    const [running, picks, kit, cuts, vesselTypes, draws, allBins] = await Promise.all([
      pressesInProgress(),
      openPicks(),
      vessels(),
      terms("press_cut"),
      terms("vessel_type"),
      pressDraws(),
      pickBins(),
    ]);
    const pressTerm = vesselTypes.find((t) => t.value === "press");

    // --- the one copy of everything that writes --------------------------
    //
    // Shared across the layouts on purpose. Three arrangements of the same
    // actions is a comparison; three arrangements that each refuse differently
    // is three bugs.

    async function recordDraw(
      p: PressInProgress,
      vesselId: string,
      litres: string,
      cutId: string,
      note: string,
      said: HTMLElement,
    ): Promise<boolean> {
      if (!litres) {
        said.replaceChildren(banner("Say how many litres.", "error"));
        return false;
      }
      try {
        const out = await drawCut({
          loadId: p.node_id,
          vesselId,
          volumeL: Number(litres),
          cutId: cutId || null,
          note: note || null,
        });
        said.replaceChildren(
          banner(
            `${out.volume_l} L of ${out.cut}. That cut is now ${out.cut_total} L, ` +
              `and this press has given ${out.load_total} L.`,
            "good",
          ),
          // Said, not refused. Somebody who has just filled a tank past its
          // capacity has a real problem, and refusing the number loses it.
          ...(out.over_capacity
            ? [
                banner(
                  `That vessel now holds ${out.in_vessel} L, which is more than its capacity. ` +
                    "Recorded anyway, because the wine is really in there.",
                  "note",
                ),
              ]
            : []),
        );
        await load();
        return true;
      } catch (error) {
        said.replaceChildren(fail(error));
        return false;
      }
    }

    async function recordFinish(
      p: PressInProgress,
      detail: Record<string, unknown>,
      said: HTMLElement,
    ): Promise<void> {
      try {
        const out = await finishPress(p.node_id, detail);
        said.replaceChildren(
          banner(
            `${Number(out.litres_out).toLocaleString()} L off ` +
              `${Number(out.lbs_in).toLocaleString()} lbs in ${out.cuts} cut` +
              `${out.cuts === 1 ? "" : "s"}` +
              (out.yield_l_per_ton === null
                ? ". Nothing was weighed, so there is no yield."
                : `, which is ${out.yield_l_per_ton} L per ton.`),
            "good",
          ),
        );
        await load();
      } catch (error) {
        said.replaceChildren(fail(error));
      }
    }

    // --- starting one, the same in every layout ---------------------------

    function startBlock(): HTMLElement {
      const presses = kit.filter((v) => v.type === "Press" && v.is_empty);
      // 0090. "Pressing just needs to click the Pearlstaad pick, then that
      // brings up the 5 bins so I can select from them into the press." A pick
      // is usually more than one press: five half tonne bins against a 1.2
      // tonne press is two loads and a bit, and ticking the whole pick was the
      // app assuming otherwise.
      //
      // So the pick is a heading rather than a checkbox, and the bins under it
      // are what goes in. Expanded when there is one pick, because then the
      // heading is a step with no decision in it.
      const binBoxes = allBins.map((b) => ({
        bin: b,
        box: checkbox(
          b.lbs === null
            ? `${b.bin} (nobody has said what is in it)`
            : `${b.bin}, ${Number(b.lbs).toLocaleString()} lb, ${Number(b.tons ?? 0).toFixed(2)} ton`,
          false,
        ),
      }));

      function chosenBins(): typeof binBoxes {
        return binBoxes.filter((b) => b.box.input.checked);
      }

      // What the press is being asked to hold, updated as boxes are ticked,
      // because the whole reason for choosing bins is that the press has a
      // capacity and the pick does not fit in it.
      const loadSoFar = el("p", { class: "field-hint" });
      function showRunning(): void {
        const going = chosenBins();
        if (going.length === 0) {
          loadSoFar.textContent = "";
          return;
        }
        const lbs = going.reduce((n, b) => n + Number(b.bin.lbs ?? 0), 0);
        const blind = going.filter((b) => b.bin.lbs === null).length;
        loadSoFar.textContent =
          `${going.length} bin${going.length === 1 ? "" : "s"}, ` +
          `${lbs.toLocaleString()} lb, ${(lbs / 2000).toFixed(2)} ton` +
          (blind > 0
            ? `, and ${blind} with no figure, so it is at least this much.`
            : ".");
      }
      for (const b of binBoxes) on(b.box.input, "change", showRunning);

      const whichPress = el("select", { class: "input" });
      whichPress.replaceChildren(
        ...presses.map((v) => el("option", { value: v.id, text: v.name })),
      );
      const said = el("div", {});

      // A picker with nothing in it and a note telling somebody to go and set
      // something up first is a dead end, and this one is on the path to the
      // press itself. "I don't know how to make a press and so the selection is
      // blank." So the press gets made here, in one field.
      const pressName = field({
        label: "Name this press",
        value: presses.length === 0 ? "The press" : "",
        placeholder: "The press",
        hint: "Whatever you call it. It can be renamed later like any vessel.",
      });

      return el(
        "div",
        { class: "rows" },
        el("h2", { class: "section-head", text: "Start a press" }),
        presses.length === 0
          ? banner(
              "No empty press is registered yet. Add one below: it is how the " +
                "fruit has somewhere to be for the hours between the bins and the tank.",
              "note",
            )
          : el("span", {}),
        picks.length === 0
          ? empty("No open pick to press.")
          : el(
              "div",
              {},
              // Grouped by pick, which is the shape he asked for: the pick is
              // how somebody names what they are pressing, and the bins are
              // what actually fits.
              ...[...new Set(allBins.map((b) => b.node_id))].map((id) => {
                const mine = binBoxes.filter((b) => b.bin.node_id === id);
                const lbs = mine.reduce((n, b) => n + Number(b.bin.lbs ?? 0), 0);
                return el(
                  "details",
                  { class: "more", ...(picks.length === 1 ? { open: "true" } : {}) },
                  el("summary", {
                    text:
                      `${mine[0]?.bin.pick ?? "a pick"}: ${mine.length} bin` +
                      `${mine.length === 1 ? "" : "s"} left, about ` +
                      `${lbs.toLocaleString()} lb`,
                  }),
                  rows(...mine.map((b) => b.box.root)),
                );
              }),
            ),
        el(
          "div",
          { class: "field" },
          el("span", { class: "field-label", text: "Into which press" }),
          whichPress,
          el("span", {
            class: "field-hint",
            text: "The bins empty as soon as you start, so they are free for the next pick.",
          }),
        ),
        loadSoFar,
        button("Start pressing", async () => {
          const chosen = chosenBins().map((b) => b.bin.vessel_id);
          if (chosen.length === 0) {
            said.replaceChildren(banner("Tick which bins are going in.", "error"));
            return;
          }
          if (!whichPress.value) {
            said.replaceChildren(banner("Say which press it is going into.", "error"));
            return;
          }
          try {
            const out = await startPress({
              vesselIds: chosen,
              pressVesselId: whichPress.value,
            });
            said.replaceChildren(
              banner(
                `Pressing ${Number(out.lbs_in).toLocaleString()} lbs` +
                  // A floor rather than a total when something went in with no
                  // figure on it. Saying the number flat would be reporting a
                  // weight that is missing a bin.
                  (out.unmeasured > 0 ? " at least" : "") +
                  `. ${out.bins_emptied} bin${out.bins_emptied === 1 ? "" : "s"} are free again. ` +
                  "Come back and record the litres as they come off.",
                "good",
              ),
              // The half of 0090 worth saying out loud: the pick is still open
              // and still has fruit in it, which is the normal case now.
              ...(out.picks_spent === 0
                ? [
                    banner(
                      "The pick is still open, with the bins that did not go in. " +
                        "Press them when this one is finished.",
                      "note",
                    ),
                  ]
                : []),
              // T1-4's cost, said out loud rather than refused.
              ...(out.unweighed_left > 0
                ? [
                    banner(
                      `${out.unweighed_left} bin${out.unweighed_left === 1 ? " that" : "s that"} never reached a scale went in, ` +
                        "so the yield will be wrong by whatever they held.",
                      "note",
                    ),
                  ]
                : []),
            );
            await load();
          } catch (error) {
            said.replaceChildren(fail(error));
          }
        }),
        el(
          "details",
          { class: "more" },
          el("summary", {
            text: presses.length === 0 ? "Add a press" : "Add another press",
          }),
          rows(
            pressName.root,
            button(
              "Add it",
              async () => {
                if (!pressTerm) {
                  said.replaceChildren(
                    banner(
                      "There is no Press vessel type in this cellar's vocabulary. " +
                        "An administrator can add one under Vessel types.",
                      "error",
                    ),
                  );
                  return;
                }
                if (!pressName.value().trim()) {
                  said.replaceChildren(banner("Give it a name.", "error"));
                  return;
                }
                try {
                  await addVessels({
                    id: newId(),
                    type_id: pressTerm.id,
                    name: pressName.value().trim(),
                  });
                  await load();
                } catch (error) {
                  said.replaceChildren(fail(error));
                }
              },
              "secondary",
            ),
          ),
        ),
        said,
      );
    }

    // --- the pieces each layout arranges differently ----------------------

    function destinationSelect(p: PressInProgress): HTMLSelectElement {
      const sel = el("select", { class: "input" });
      sel.replaceChildren(
        ...kit
          .filter((v) => v.id !== p.press_vessel_id)
          .map((v) =>
            el("option", {
              value: v.id,
              text: v.is_empty
                ? `${v.name} (${v.type}, empty)`
                : `${v.name} (${v.type}, holding ${v.lot_name ?? "wine"})`,
            }),
          ),
      );
      return sel;
    }

    function finishFields(): {
      nodes: HTMLElement[];
      detail: () => Record<string, unknown>;
    } {
      const program = field({
        label: "Program",
        placeholder: "W2",
        hint: "Which program the press was run on.",
      });
      const minutes = field({
        label: "Minutes",
        type: "number",
        placeholder: "95",
        hint: "How long it ran, start to finish.",
      });
      const note = field({ label: "Anything else", placeholder: "" });
      return {
        nodes: [program.root, minutes.root, note.root],
        detail: () => ({
          ...(program.value() ? { program: program.value() } : {}),
          ...(minutes.value() ? { minutes: Number(minutes.value()) } : {}),
          ...(note.value() ? { note: note.value() } : {}),
        }),
      };
    }

    // --- way 1: say what came off ----------------------------------------
    //
    // Everything on one screen in reading order, and every entry names its own
    // cut and its own destination. What it is good at is being complete and
    // never assuming; what it is bad at is asking three questions when the
    // answer to two of them has not changed since the last time.

    function formLayout(): Node {
      function runningBlock(p: PressInProgress): HTMLElement {
        const destination = destinationSelect(p);
        const cut = el("select", { class: "input" });
        cut.replaceChildren(
          el("option", { value: "", text: "No particular cut" }),
          ...cuts.map((c) => el("option", { value: c.id, text: c.label })),
        );
        const litres = field({
          label: "Litres off",
          type: "number",
          placeholder: "400",
          hint: "What has come off since you last recorded. It adds up.",
        });
        const note = field({ label: "Note", placeholder: "end of free run" });
        const said = el("div", {});
        const fin = finishFields();

        return el(
          "div",
          { class: "rows" },
          el("h2", { class: "section-head", text: p.name }),
          rows(
            summaryRow("In", p.press_name ?? "a press that is no longer there"),
            summaryRow("Started", new Date(p.started_at).toLocaleTimeString()),
            summaryRow(
              "Fruit in",
              p.lbs_in > 0
                ? `${Number(p.lbs_in).toLocaleString()} lbs`
                : "nothing weighed, so there will be no yield",
            ),
            summaryRow(
              "Off so far",
              p.cuts === 0
                ? "nothing yet"
                : `${Number(p.litres_so_far).toLocaleString()} L in ${p.cuts} cut${p.cuts === 1 ? "" : "s"}`,
            ),
            el("h3", { class: "section-head", text: "Record some litres" }),
            el(
              "div",
              { class: "field" },
              el("span", { class: "field-label", text: "Into" }),
              destination,
            ),
            el(
              "div",
              { class: "field" },
              el("span", { class: "field-label", text: "Cut" }),
              cut,
              el("span", {
                class: "field-hint",
                text:
                  "The same cut into the same vessel again adds to it rather than " +
                  "starting a second lot.",
              }),
            ),
            litres.root,
            note.root,
            button("Record it", async () => {
              const ok = await recordDraw(
                p,
                destination.value,
                litres.value(),
                cut.value,
                note.value(),
                said,
              );
              if (ok) {
                litres.input.value = "";
                note.input.value = "";
              }
            }),
            said,
            el(
              "details",
              { class: "more" },
              el("summary", { text: "Finish this press" }),
              rows(
                el("p", {
                  class: "field-hint",
                  text:
                    "Finishing sets the yield and closes the load. Record the last " +
                    "of the litres first.",
                }),
                ...fin.nodes,
                button("Finish the press", () => recordFinish(p, fin.detail(), said)),
              ),
            ),
          ),
        );
      }

      return el("div", {}, ...running.map(runningBlock), startBlock());
    }

    // --- way 2: read the tank, not the press ------------------------------
    //
    // "Maybe UX, even." The first three were arrangements of one interaction.
    // This is a different interaction: you say what the receiving tank reads
    // now, and the kernel works out what came off. One number, read off a gauge
    // in front of you, no arithmetic and nothing to remember from an hour ago.
    //
    // The cut is not asked for a vessel that already holds one, because a tank
    // holding free run receiving more juice is receiving more free run. That is
    // one fewer decision per entry with exactly one right answer.

    function levelLayout(): Node {
      function runningBlock(p: PressInProgress): HTMLElement {
        const said = el("div", {});
        const rows_: HTMLElement[] = [];

        for (const v of kit.filter((x) => x.id !== p.press_vessel_id)) {
          const holdsThisPress = draws.some(
            (d) => d.load_id === p.node_id && d.vessel_id === v.id,
          );
          // Everything is offered, but what is already taking juice from this
          // press comes first and is open. A press fills two or three vessels,
          // not thirty, and scrolling past twenty-seven empty barrels to find
          // the one you are standing at is the thing this layout exists to stop.
          const level = el("input", {
            class: "input big-number",
            type: "number",
            inputmode: "decimal",
            placeholder: String(Math.round(Number(v.current_volume_l ?? 0))),
          });
          const cut = el("select", { class: "input" });
          cut.replaceChildren(
            el("option", { value: "", text: "Cut, if it is a new one" }),
            ...cuts.map((c) => el("option", { value: c.id, text: c.label })),
          );

          const row = el(
            "details",
            { class: "more", ...(holdsThisPress ? { open: "true" } : {}) },
            el("summary", {
              text: `${v.name}: ${Number(v.current_volume_l ?? 0).toLocaleString()} L`,
            }),
            rows(
              el("p", {
                class: "field-hint",
                text: holdsThisPress
                  ? "Already taking juice from this press. Read the gauge and type what it says now."
                  : "Empty of this press so far. Type what it reads once juice is going in.",
              }),
              level,
              ...(holdsThisPress ? [] : [cut]),
              button(
                `Set ${v.name} to this`,
                async () => {
                  if (!level.value) {
                    said.replaceChildren(banner("Type what the gauge reads.", "error"));
                    return;
                  }
                  try {
                    const out = await drawToLevel({
                      loadId: p.node_id,
                      vesselId: v.id,
                      levelL: Number(level.value),
                      cutId: cut.value || null,
                    });
                    said.replaceChildren(
                      banner(
                        `${v.name} was at ${out.was_at} L and is now at ${out.now_at} L, ` +
                          `so ${out.volume_l} L of ${out.cut} came off. ` +
                          `This press has given ${out.load_total} L.`,
                        "good",
                      ),
                    );
                    level.value = "";
                    await load();
                  } catch (error) {
                    said.replaceChildren(fail(error));
                  }
                },
                holdsThisPress ? "primary" : "secondary",
              ),
            ),
          );
          if (holdsThisPress) rows_.unshift(row);
          else rows_.push(row);
        }

        const fin = finishFields();
        return el(
          "div",
          { class: "rows" },
          el("h2", { class: "section-head", text: p.name }),
          el("p", {
            class: "lede",
            text:
              `${Number(p.litres_so_far).toLocaleString()} L off so far. ` +
              "Say what a tank reads and the difference is worked out for you.",
          }),
          ...rows_,
          said,
          el(
            "details",
            { class: "more" },
            el("summary", { text: "Finish this press" }),
            rows(
              ...fin.nodes,
              button("Finish the press", () => recordFinish(p, fin.detail(), said)),
            ),
          ),
        );
      }

      return el("div", {}, ...running.map(runningBlock), startBlock());
    }

    // --- way 3: stay in a cut ----------------------------------------------
    //
    // The third interaction, and the one closest to how a press actually runs.
    // You are on free run for an hour, then you change pressure and you are on
    // something else. So the cut is a mode you are in rather than a field you
    // fill in: set it once, and every entry after that is one number and one
    // tap. The destination is remembered the same way.
    //
    // What it costs is that the mode is invisible when you come back to the
    // phone, which is why the current one is written across the top in the
    // largest type on the screen.

    function cutModeLayout(): Node {
      if (running.length === 0) {
        return el(
          "div",
          {},
          empty("Nothing is pressing. Start one below."),
          startBlock(),
        );
      }

      function runningBlock(p: PressInProgress): HTMLElement {
        const said = el("div", {});
        const modeKey = `press_mode_cut_${p.node_id}`;
        const whereKey = `press_mode_vessel_${p.node_id}`;
        const currentCut = pref(modeKey);
        let currentVessel = pref(whereKey);

        const options = kit.filter((v) => v.id !== p.press_vessel_id);
        if (!currentVessel && options[0]) currentVessel = options[0].id;

        const cutName =
          cuts.find((c) => c.id === currentCut)?.label ?? "no particular cut";
        const vesselName =
          options.find((v) => v.id === currentVessel)?.name ?? "nowhere";

        const litres = el("input", {
          class: "input big-number",
          type: "number",
          inputmode: "decimal",
          placeholder: "0",
        });

        const cutButtons = cuts.map((c) =>
          button(
            c.label,
            () => {
              setPref(modeKey, currentCut === c.id ? "" : c.id);
              void load();
            },
            c.id === currentCut ? "primary" : "quiet",
          ),
        );
        for (const b of cutButtons) b.classList.add("big-toggle");

        const where = el("select", { class: "input" });
        where.replaceChildren(
          ...options.map((v) =>
            el("option", {
              value: v.id,
              text: `${v.name} (${Number(v.current_volume_l ?? 0).toLocaleString()} L)`,
              ...(v.id === currentVessel ? { selected: "true" } : {}),
            }),
          ),
        );
        on(where, "change", () => {
          setPref(whereKey, where.value);
          currentVessel = where.value;
        });

        const fin = finishFields();
        return el(
          "div",
          { class: "rows big-press" },
          // The mode, in the largest type on the screen, because a mode you
          // cannot see is a mode you record the wrong thing into.
          el("p", { class: "big-mode", text: cutName }),
          el("p", {
            class: "lede",
            text: `into ${vesselName}. ${Number(p.litres_so_far).toLocaleString()} L off so far.`,
          }),
          el("div", { class: "big-toggles" }, ...cutButtons),
          litres,
          button("Add these litres", async () => {
            const ok = await recordDraw(
              p,
              currentVessel,
              litres.value,
              currentCut,
              "",
              said,
            );
            if (ok) litres.value = "";
          }),
          said,
          el(
            "details",
            { class: "more" },
            el("summary", { text: "Change where it is going, or finish" }),
            rows(
              el(
                "div",
                { class: "field" },
                el("span", { class: "field-label", text: "Into" }),
                where,
              ),
              ...fin.nodes,
              button("Finish the press", () => recordFinish(p, fin.detail(), said)),
            ),
          ),
        );
      }

      return el("div", {}, ...running.map(runningBlock));
    }

    // --- way 4: keep the log ----------------------------------------------
    //
    // The press as the record of a morning rather than as a form to fill in.
    // Add at the top, then every draw in the order it came off. What it is good
    // at is noticing that the second pressure gave half what the first did,
    // which no total can ever show; what it is bad at is being short.

    function logLayout(): Node {
      function runningBlock(p: PressInProgress): HTMLElement {
        const mine = draws
          .filter((d) => d.load_id === p.node_id)
          .sort((a, b) => b.at.localeCompare(a.at));
        const destination = destinationSelect(p);
        const cut = el("select", { class: "input" });
        cut.replaceChildren(
          el("option", { value: "", text: "No cut" }),
          ...cuts.map((c) => el("option", { value: c.id, text: c.label })),
        );
        const litres = field({ label: "Litres", type: "number", placeholder: "400" });
        const note = field({ label: "Note", placeholder: "" });
        const said = el("div", {});
        const fin = finishFields();

        return el(
          "div",
          { class: "rows" },
          el("h2", { class: "section-head", text: p.name }),
          el("p", {
            class: "lede",
            text:
              `${Number(p.litres_so_far).toLocaleString()} L off ` +
              (p.lbs_in > 0
                ? `${Number(p.lbs_in).toLocaleString()} lbs`
                : "an unweighed load") +
              `, started ${new Date(p.started_at).toLocaleTimeString()}.`,
          }),
          el(
            "div",
            { class: "log-add" },
            litres.root,
            el(
              "div",
              { class: "field" },
              el("span", { class: "field-label", text: "Cut" }),
              cut,
            ),
            el(
              "div",
              { class: "field" },
              el("span", { class: "field-label", text: "Into" }),
              destination,
            ),
            note.root,
            button("Add to the log", async () => {
              const ok = await recordDraw(
                p,
                destination.value,
                litres.value(),
                cut.value,
                note.value(),
                said,
              );
              if (ok) {
                litres.input.value = "";
                note.input.value = "";
              }
            }),
          ),
          said,
          mine.length === 0
            ? empty("Nothing has come off yet.")
            : el(
                "ul",
                { class: "vessel-list" },
                ...mine.map((d) =>
                  el(
                    "li",
                    { class: `vessel-row${d.superseded ? " weighed" : ""}` },
                    el("span", {
                      class: "vessel-name",
                      text: `${Number(d.volume_l).toLocaleString()} L ${d.cut_label ?? ""}`.trim(),
                    }),
                    el("span", {
                      class: "vessel-detail",
                      text:
                        `${new Date(d.at).toLocaleTimeString()} into ${d.vessel_name ?? "somewhere"}` +
                        (d.note ? `, ${d.note}` : "") +
                        (d.superseded ? " (corrected later)" : ""),
                    }),
                  ),
                ),
              ),
          el(
            "details",
            { class: "more" },
            el("summary", { text: "Finish this press" }),
            rows(
              ...fin.nodes,
              button("Finish the press", () => recordFinish(p, fin.detail(), said)),
            ),
          ),
        );
      }

      return el("div", {}, ...running.map(runningBlock), startBlock());
    }

    // Four ways of working, not four arrangements of one. The winemaker asked
    // for layouts and then corrected it to "maybe UX, even", which is the harder
    // and better version: what differs below is what you are asked and what is
    // worked out for you, and the one he keeps is the answer.
    const layouts: Variant<void>[] = [
      {
        key: "form",
        label: "Say what came off",
        note: "Type the litres that have come off, and name the cut and the tank each time. Complete, and three questions per entry.",
        render: formLayout,
      },
      {
        key: "level",
        label: "Read the tank",
        note: "Type what the receiving tank's gauge says now. The difference is worked out for you, and the cut is inferred.",
        render: levelLayout,
      },
      {
        key: "cut",
        label: "Stay in a cut",
        note: "Set the cut once, like a mode, then every entry is one number and one tap. Fewest taps, and the mode is a thing to forget.",
        render: cutModeLayout,
      },
      {
        key: "log",
        label: "Keep a log",
        note: "Every draw in the order it came off, so a weak pressure is visible at a glance.",
        render: logLayout,
      },
    ];
    const chosen = pref("press_layout", "form");
    const layout = layouts.find((l) => l.key === chosen) ?? layouts[0];

    body.replaceChildren(
      rows(
        layout?.render() ?? empty("No layout."),
        variantSwitch(layouts, layout?.key ?? "form", (key) => {
          setPref("press_layout", key);
          void load();
        }),
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

      // The vineyard itself is a row, not a heading. It was a heading, and the
      // consequence was that a vineyard somebody had just added rendered as its
      // own name over the words "No blocks yet" with nothing to tap: the only
      // adder for a block lived inside the pick screen's block picker, so the
      // way to put a block in a new vineyard was to go and pretend to tap fruit.
      function vineyardRow(v: Vineyard, count: number): HTMLElement {
        const row = el(
          "li",
          { class: "vessel-row", role: "button", tabindex: "0" },
          el("span", { class: "vessel-name", text: v.name }),
          el("span", {
            class: "vessel-detail",
            text: count === 1 ? "1 block" : `${count} blocks`,
          }),
          v.location ? el("span", { class: "vessel-detail", text: v.location }) : null,
        );
        const open = () => go({ at: "vineyard", id: v.id });
        on(row, "click", open);
        on(row, "keydown", (ev) => {
          if (ev.key === "Enter" || ev.key === " ") {
            ev.preventDefault();
            open();
          }
        });
        return row;
      }

      body.replaceChildren(
        rows(
          ...vineRows.flatMap((v) => [
            el(
              "ul",
              { class: "vessel-list" },
              vineyardRow(v, (blocksOf.get(v.id) ?? []).length),
            ),
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

// One vineyard: what it is called, where it is, and the blocks in it.
//
// This screen is the answer to a vineyard being unopenable. Everything a
// vineyard can hold today is name, location and blocks, so that is what it
// offers. Adding a block from here rather than from the pick screen's picker is
// the point: the picker exists to choose an existing block while tapping fruit,
// and creating one was a side effect it grew because there was nowhere else.
//
// S-51: `block` carries an admin-write policy, so the adder below refuses for a
// cellar hand. It refuses out loud, through the same fail() every other write
// uses, which is the A13 requirement. It does not hide itself, because a person
// who cannot add a block should be told that rather than shown a screen with a
// piece quietly missing from it.
function vineyardScreen(vineyardId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("Vineyard", body);

  void (async () => {
    try {
      const [vineRows, blockRows, planted] = await Promise.all([
        vineyards(),
        blocks(),
        plantings(),
      ]);
      const vine = vineRows.find((v) => v.id === vineyardId);
      if (!vine) {
        body.replaceChildren(
          banner("That vineyard is not there to open.", "note"),
          button("Back", () => goBack(), "quiet"),
        );
        return;
      }
      view.replaceChildren(el("h1", { text: vine.name }), body);

      const mine = blockRows.filter((b) => b.vineyard_id === vineyardId);
      const varietiesOf = new Map<string, string[]>();
      for (const p of planted) {
        varietiesOf.set(p.block_id, [
          ...(varietiesOf.get(p.block_id) ?? []),
          p.variety,
        ]);
      }

      const name = field({ label: "Name", value: vine.name });
      const where = field({
        label: "Where it is",
        value: vine.location ?? "",
        hint: "Free text. An address, a road, whatever you would recognise.",
      });
      const said = el("div", {});

      const blockName = field({ label: "Block name", placeholder: "East" });
      const adding = el("div", {});

      const list =
        mine.length === 0
          ? empty("No blocks yet. Add one below.")
          : el(
              "ul",
              { class: "vessel-list" },
              ...mine.map((b) => {
                const kinds = varietiesOf.get(b.id) ?? [];
                const row = el(
                  "li",
                  { class: "vessel-row", role: "button", tabindex: "0" },
                  el("span", { class: "vessel-name", text: b.name }),
                  el("span", {
                    class: "vessel-detail",
                    text:
                      kinds.length === 0
                        ? "nothing planted recorded"
                        : kinds.join(", "),
                  }),
                  b.acres === null
                    ? null
                    : el("span", {
                        class: "vessel-detail",
                        text: `${b.acres} acres`,
                      }),
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

      body.replaceChildren(
        rows(
          lede(
            "Blocks belong to a vineyard, and what is planted in a block is a " +
              "list of varieties. Open a block to say what is in it.",
          ),
          list,
          el(
            "details",
            { class: "more", open: "" },
            el("summary", { text: "Add a block" }),
            rows(
              blockName.root,
              button(
                "Add it",
                async () => {
                  if (!blockName.value()) {
                    adding.replaceChildren(banner("The block needs a name.", "error"));
                    return;
                  }
                  try {
                    const blockId = newId();
                    await addBlock({
                      id: blockId,
                      vineyard_id: vineyardId,
                      name: blockName.value(),
                    });
                    // Straight into the block, because the next thing anybody
                    // wants after naming a block is to say what is planted in
                    // it, and that lives there.
                    go({ at: "block", id: blockId });
                  } catch (error) {
                    adding.replaceChildren(fail(error));
                  }
                },
                "secondary",
              ),
              adding,
            ),
          ),
          el(
            "details",
            { class: "more" },
            el("summary", { text: "Rename it, or say where it is" }),
            rows(
              name.root,
              where.root,
              button(
                "Save",
                async () => {
                  if (!name.value()) {
                    said.replaceChildren(banner("It needs a name.", "error"));
                    return;
                  }
                  try {
                    await updateVineyard(vineyardId, {
                      name: name.value(),
                      location: where.value() || null,
                    });
                    go({ at: "vineyard", id: vineyardId });
                  } catch (error) {
                    said.replaceChildren(fail(error));
                  }
                },
                "secondary",
              ),
              said,
            ),
          ),
          button("All vineyards", () => go({ at: "vineyards" }), "quiet"),
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
          // The second way in he asked for. Standing in a block, the thing you
          // want is to sample this block, not to go to a list and find it.
          button("Sample this block", () => go({ at: "sampling" }), "secondary"),
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
