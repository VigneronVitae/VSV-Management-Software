// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The stores, as a periphery of its own: everything we have, where
//           each thing lives, and a photograph of the shelf with the thing
//           circled on it."
// Depends on: [supabase/migrations/0132_a_place_is_inside_another_place.sql,
//              supabase/migrations/0134_a_domain_tags_a_place_and_a_thing.sql,
//              supabase/migrations/0135_a_photograph_can_point_at_something.sql,
//              supabase/migrations/0136_the_stores_have_a_door.sql,
//              packages/inventory/src/places.ts]
// Depended on by: [packages/inventory/src/index.ts,
//                  packages/inventory/src/places.ts]
// ---------------------------------------------------------------------------
//
// The fifth periphery, and the one that answers a question rather than records
// an event: where is the thing.
//
// **The centre of it is the photograph with the circle drawn on it.** The review
// of 2026-09-20 found that the useful distinction is not visual against written
// but who is looking: an address in words serves somebody who knows the
// buildings, and a picture serves somebody who does not, and the two are rungs
// of the same ladder rather than competing designs. So the thing screen shows
// both, always, without asking which kind of person you are.
//
// The circle is drawn here from a coordinate rather than baked into a second
// image, which is 0135's whole argument: one photograph of a shelf carries a
// mark for each of twenty things on it, and re-photographing the shelf is one
// upload rather than twenty.
//
// May import from `core`. May never import from `cellar`, `shop`, `vineyard` or
// `books`. scripts/verify.sh checks that.

import {
  addPlace,
  addSupply,
  banner,
  button,
  el,
  empty,
  field,
  lede,
  type Mark,
  marksOn,
  on,
  type Place,
  places,
  rows,
  type SupplyOnHand,
  setSupplyHome,
  signIn,
  summaryRow,
  suppliesOnHand,
  type Term,
  tagPlace,
  tagSupply,
  terms,
  vesselPhotoUrl,
  viewerScope,
  type Whereabouts,
  whereabouts,
} from "core";
import { decode, encode, PLACES, type StorePlace } from "./places.ts";

let root: HTMLElement | null = null;

// Fetched once. Three rows that every screen wants and nothing changes during a
// session.
let domainTerms: Term[] = [];

function here(): StorePlace {
  return decode(window.location.hash);
}

function go(place: StorePlace): void {
  window.location.hash = encode(place);
}

function screen(
  place: string,
  title: string,
  ...body: (Node | string | null | false)[]
): HTMLElement {
  if (!PLACES.has(place)) {
    // A place this module does not admit to having. The same guard the other
    // four use, and scripts/screens.sh checks the list against the registry so a
    // screen nobody registered cannot be noted about.
    throw new Error(`no such place: ${place}`);
  }
  return el(
    "section",
    { class: "screen" },
    el("h1", { text: title }),
    ...body.filter((b): b is Node | string => b !== null && b !== false),
  );
}

function backTo(place: StorePlace, label: string): HTMLElement {
  return el(
    "p",
    { class: "crumb" },
    button(label, () => go(place), "quiet"),
  );
}

function domainChips(names: string[] | null): HTMLElement | null {
  if (!names || names.length === 0) return null;
  return el(
    "span",
    { class: "domains" },
    ...names.map((d) => el("span", { class: `domain domain-${d}`, text: d })),
  );
}

// ---------------------------------------------------------------------------
// The picture, with things circled on it
// ---------------------------------------------------------------------------

// Drawn rather than stored, which is the point. The marks arrive as fractions of
// the picture, so the same coordinates work at thumbnail size and full width and
// on a screen half as wide as the one they were placed on.
//
// `highlight` dims every mark that is not the one you asked for, so the same
// component serves "where is the hammer" and "what is on this shelf".
function markedPhoto(
  path: string,
  marks: { at_x: number; at_y: number; radius: number | null; label: string }[],
  highlight?: string,
): HTMLElement {
  const wrap = el("div", { class: "shelf" });
  const img = el("img", { class: "shelf-img", alt: "", loading: "lazy" });
  wrap.append(img);

  for (const m of marks) {
    const dim = highlight !== undefined && m.label !== highlight;
    const place = `left:${m.at_x * 100}%;top:${m.at_y * 100}%`;
    // A circle is sized from its stored radius as a percentage of the picture
    // width; a point has no radius and takes its size from the stylesheet. The
    // sizing is left off the inline style entirely in that case rather than
    // written and then overridden, which is what `!important` would have been.
    const size = m.radius
      ? `;width:${m.radius * 200}%;padding-bottom:${m.radius * 200}%`
      : "";
    const spot = el("span", {
      class: `spot${m.radius ? "" : " spot-point"}${dim ? " spot-dim" : ""}`,
      style: place + size,
      title: m.label,
    });
    // The label is a child of the circle rather than a sibling positioned by
    // arithmetic. Found by screenshotting: placed at the same coordinate it sits
    // across the circle's middle, and offsetting it needs the picture's aspect
    // ratio, because a radius is a fraction of the width and a top is a fraction
    // of the height. Nesting it inside the circle's own box needs neither.
    if (!dim) {
      spot.append(el("span", { class: "spot-label", text: m.label }));
    }
    wrap.append(spot);
  }

  // The bucket is private, so the src arrives on a short lived signed url and
  // the element is built before it resolves.
  void vesselPhotoUrl(path).then((url) => {
    if (url) img.setAttribute("src", url);
    else wrap.replaceChildren(empty("That photograph could not be loaded."));
  });

  return wrap;
}

// ---------------------------------------------------------------------------
// Everything we have
// ---------------------------------------------------------------------------

async function stockScreen(): Promise<HTMLElement> {
  const [held, where] = await Promise.all([suppliesOnHand(), whereabouts()]);
  const byId = new Map(where.map((w) => [w.supply_id, w]));

  const list = el("div", { class: "ledger" });
  const search = field({
    label: "Find",
    placeholder: "part of a name",
    attrs: { autocapitalize: "none", autocorrect: "off" },
  });
  const status = el("p", { class: "lede" });

  // Which domain's stores you are looking at. The union rule lives in the
  // kernel; this only picks a word. Blank means everything, because the whole
  // point is that each domain's inventory is a subset of one list.
  let domain = "";

  function draw(): void {
    const text = search.value().toLowerCase();
    const shown = held.filter((s) => {
      if (text && !s.name.toLowerCase().includes(text)) return false;
      if (!domain) return true;
      return (byId.get(s.supply_id)?.home_domains ?? []).includes(domain);
    });

    list.replaceChildren(
      ...(shown.length === 0
        ? [empty("Nothing here matching that.")]
        : shown.map((s) => row(s, byId.get(s.supply_id)))),
    );
    status.textContent = `${shown.length} of ${held.length}`;
  }

  function row(s: SupplyOnHand, w: Whereabouts | undefined): HTMLElement {
    const item = el(
      "button",
      { class: "entry entry-open", type: "button" },
      el(
        "span",
        { class: "entry-head" },
        el("span", { class: "entry-what", text: s.name }),
        el("span", {
          class: "entry-sum",
          text:
            s.on_hand === null
              ? "not counted"
              : `${s.on_hand}${s.unit ? ` ${s.unit}` : ""}`,
        }),
      ),
      // The address, because it is the cheapest useful thing on a list screen
      // and it is already computed.
      el("span", {
        class: "entry-when",
        text: w?.home_address ?? "no home recorded",
      }),
      domainChips(w?.home_domains ?? null),
    );
    on(item, "click", () => go({ at: "thing", id: s.supply_id }));
    return item;
  }

  const filters = el(
    "div",
    { class: "filters" },
    ...[
      { value: "", label: "Everything" },
      ...domainTerms.map((t) => ({
        value: t.value,
        label: t.label,
      })),
    ].map((d) => {
      const b = button(
        d.label,
        () => {
          domain = d.value;
          for (const other of filters.children) other.classList.remove("on");
          b.classList.add("on");
          draw();
        },
        "secondary",
      );
      b.classList.add("filter");
      if (d.value === domain) b.classList.add("on");
      return b;
    }),
  );

  let debounce = 0;
  on(search.input, "input", () => {
    window.clearTimeout(debounce);
    debounce = window.setTimeout(draw, 200);
  });

  draw();

  return screen(
    "stock",
    "Everything we have",
    lede(
      "Each domain's stores are a subset of this one list, not a list of their own.",
    ),
    filters,
    search.root,
    status,
    list,
    el(
      "p",
      { class: "crumb" },
      button("The places", () => go({ at: "places" }), "quiet"),
    ),
    addThing(),
  );
}

function addThing(): HTMLElement {
  const name = field({ label: "What it is called" });
  const unit = field({
    label: "Counted in",
    hint: "Rolls, kg, each. Blank for something you would not count.",
  });
  const said = el("div", { class: "banner-slot" });

  return el(
    "details",
    { class: "more" },
    el("summary", { text: "Add a thing" }),
    rows(
      name.root,
      unit.root,
      button("Add it", async () => {
        try {
          const made = await addSupply({
            name: name.value(),
            unit: unit.value() || null,
          });
          go({ at: "thing", id: made.id });
        } catch (e) {
          said.replaceChildren(
            banner(e instanceof Error ? e.message : "That did not save.", "error"),
          );
        }
      }),
      said,
    ),
  );
}

// ---------------------------------------------------------------------------
// One thing, and where it is
// ---------------------------------------------------------------------------

async function thingScreen(id: string): Promise<HTMLElement> {
  const [found, held] = await Promise.all([whereabouts(id), suppliesOnHand()]);
  const w = found[0];
  const s = held.find((x) => x.supply_id === id);
  if (!w || !s) {
    return screen(
      "thing",
      "Not found",
      backTo({ at: "stock" }, "Everything we have"),
      banner("There is no such thing.", "error"),
    );
  }

  // Both rungs of the ladder, always, because the app does not know which kind
  // of person is holding the phone.
  const marks = w.attachment_id ? await marksOn(w.attachment_id) : [];
  const picture =
    w.photo_path && w.at_x !== null && w.at_y !== null
      ? markedPhoto(
          w.photo_path,
          marks.map((m: Mark) => ({
            at_x: m.at_x,
            at_y: m.at_y,
            radius: m.radius,
            label: m.subject_name ?? "",
          })),
          s.name,
        )
      : null;

  const said = el("div", { class: "banner-slot" });
  const allPlaces = await places();

  const home = el("select", { class: "input" });
  home.append(el("option", { value: "", text: "No home recorded" }));
  for (const p of allPlaces) {
    const o = el("option", { value: p.id, text: p.address });
    if (p.id === w.home_id) o.setAttribute("selected", "selected");
    home.append(o);
  }
  on(home, "change", () => {
    void setSupplyHome(id, home.value || null)
      .then(() => draw())
      .catch((e: unknown) =>
        said.replaceChildren(
          banner(e instanceof Error ? e.message : "That did not save.", "error"),
        ),
      );
  });

  const domains = el(
    "div",
    { class: "filters" },
    ...domainTerms.map((t) => {
      const b = button(
        t.label,
        async () => {
          try {
            await tagSupply(id, t.value);
            await draw();
          } catch (e) {
            said.replaceChildren(
              banner(e instanceof Error ? e.message : "That did not save.", "error"),
            );
          }
        },
        "secondary",
      );
      b.classList.add("filter");
      return b;
    }),
  );

  return screen(
    "thing",
    s.name,
    backTo({ at: "stock" }, "Everything we have"),
    picture ??
      lede(
        w.home_id
          ? "No photograph of where this lives yet. The address below is all there is."
          : "Nowhere recorded yet.",
      ),
    rows(
      summaryRow("Lives at", w.home_address ?? "nowhere recorded"),
      summaryRow(
        "On hand",
        s.on_hand === null
          ? "never counted"
          : `${s.on_hand}${s.unit ? ` ${s.unit}` : ""}`,
      ),
      s.supplier ? summaryRow("From", s.supplier) : null,
      s.reorder_level !== null
        ? summaryRow("Reorder below", String(s.reorder_level))
        : null,
    ),
    el("p", { class: "field-label", text: "Lives at" }),
    home,
    el("p", { class: "field-label", text: "Belongs to" }),
    domains,
    said,
  );
}

// ---------------------------------------------------------------------------
// The places
// ---------------------------------------------------------------------------

async function placesScreen(): Promise<HTMLElement> {
  const all = await places();
  const said = el("div", { class: "banner-slot" });

  const name = field({ label: "What it is called" });
  const inside = el("select", { class: "input" });
  inside.append(el("option", { value: "", text: "Not inside anything" }));
  for (const p of all) inside.append(el("option", { value: p.id, text: p.address }));

  const kind = el("select", { class: "input" });
  kind.append(el("option", { value: "", text: "Kind of place" }));
  for (const k of ["building", "room", "storage"]) {
    kind.append(el("option", { value: k, text: k }));
  }

  return screen(
    "places",
    "The places",
    backTo({ at: "stock" }, "Everything we have"),
    lede(
      all.length === 0
        ? "Nowhere recorded yet."
        : "A place inside a place inside a place. Everything inside a place belongs to whatever the outer one belongs to.",
    ),
    rows(
      ...all.map((p: Place) => {
        const item = el(
          "button",
          // Indented by depth, which is the cheapest possible drawing of a tree
          // and reads correctly on a phone where a real tree would not.
          {
            class: "entry entry-open",
            type: "button",
            style: `margin-left:${(p.depth - 1) * 1.1}rem`,
          },
          el("span", { class: "entry-what", text: p.name }),
          el("span", { class: "entry-when", text: p.kind_label ?? "" }),
          domainChips(p.domains),
        );
        on(item, "click", () => go({ at: "place", id: p.id }));
        return item;
      }),
    ),
    el(
      "details",
      { class: "more" },
      el("summary", { text: "Add a place" }),
      rows(
        name.root,
        kind,
        inside,
        button("Add it", async () => {
          try {
            await addPlace({
              name: name.value(),
              kind: kind.value || null,
              parentId: inside.value || null,
            });
            await draw();
          } catch (e) {
            said.replaceChildren(
              banner(e instanceof Error ? e.message : "That did not save.", "error"),
            );
          }
        }),
        said,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// One place, and everything in it
// ---------------------------------------------------------------------------

async function placeScreen(id: string): Promise<HTMLElement> {
  const [all, where] = await Promise.all([places(), whereabouts()]);
  const p = all.find((x) => x.id === id);
  if (!p) {
    return screen(
      "place",
      "Not found",
      backTo({ at: "places" }, "The places"),
      banner("There is no such place.", "error"),
    );
  }

  const living = where.filter((w) => w.home_id === id);
  // Every thing in this place that has been pointed at on the same photograph,
  // which is the shelf view: one picture, everything on it marked at once, and
  // the picture you actually want when putting things away.
  const shot = living.find((w) => w.attachment_id);
  const marks = shot?.attachment_id ? await marksOn(shot.attachment_id) : [];

  const said = el("div", { class: "banner-slot" });
  const domains = el(
    "div",
    { class: "filters" },
    ...domainTerms.map((t) => {
      const b = button(
        t.label,
        async () => {
          try {
            await tagPlace(id, t.value);
            await draw();
          } catch (e) {
            said.replaceChildren(
              banner(e instanceof Error ? e.message : "That did not save.", "error"),
            );
          }
        },
        "secondary",
      );
      b.classList.add("filter");
      return b;
    }),
  );

  return screen(
    "place",
    p.name,
    backTo({ at: "places" }, "The places"),
    lede(p.address),
    shot?.photo_path
      ? markedPhoto(
          shot.photo_path,
          marks.map((m: Mark) => ({
            at_x: m.at_x,
            at_y: m.at_y,
            radius: m.radius,
            label: m.subject_name ?? "",
          })),
        )
      : null,
    domainChips(p.domains),
    el("p", { class: "field-label", text: "Used for" }),
    domains,
    said,
    living.length === 0
      ? empty("Nothing lives here yet.")
      : rows(
          ...living.map((w) => {
            const item = el(
              "button",
              { class: "entry entry-open", type: "button" },
              el("span", { class: "entry-what", text: w.name }),
            );
            on(item, "click", () => go({ at: "thing", id: w.supply_id }));
            return item;
          }),
        ),
  );
}

// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Who is allowed in
// ---------------------------------------------------------------------------
//
// A13, and the thing that made it concrete here: signed out, every screen in
// this app drew perfectly and said "0 of 0", because `supply` is scoped to
// `is_facility_user()` and an RLS refusal is an empty result set.
//
// It also corrected a misreading worth writing down. The assertion suite judges
// `term.term_read` permissive, and permissive there means `using (true)` **to
// the authenticated role**, not to the world. Nothing in this system is readable
// signed out. So an app with no gate does not show a reduced view to a stranger;
// it shows an empty one, indistinguishable from a winery that owns nothing.

async function signInScreen(): Promise<HTMLElement> {
  const email = field({
    label: "Email",
    type: "email",
    attrs: { autocomplete: "email" },
  });
  const password = field({
    label: "Password",
    type: "password",
    attrs: { autocomplete: "current-password" },
  });
  const said = el("div", { class: "banner-slot" });

  return screen(
    "stock",
    "Stores",
    lede("Sign in. The same account as the cellar."),
    rows(
      email.root,
      password.root,
      button("Sign in", async () => {
        try {
          await signIn(email.value(), password.value());
          await draw();
        } catch (e) {
          said.replaceChildren(
            banner(e instanceof Error ? e.message : "That did not sign in.", "error"),
          );
        }
      }),
      said,
    ),
  );
}

function notOursScreen(): HTMLElement {
  return screen(
    "stock",
    "Stores",
    // Said outright rather than shown as an empty list, because what is behind
    // this is every tool and consumable the winery owns, and the honest thing to
    // tell somebody without the standing to read it is that it is there.
    banner("The stores are for people who work here.", "note"),
    lede("This is not an empty shed. It is a door, and it is shut for this account."),
  );
}

async function draw(): Promise<void> {
  if (!root) return;
  const place = here();
  try {
    const scope = await viewerScope();
    if (!scope.signed_in) {
      root.replaceChildren(await signInScreen());
      return;
    }
    if (scope.party_kind !== "facility") {
      root.replaceChildren(notOursScreen());
      return;
    }
    if (domainTerms.length === 0) {
      domainTerms = await terms("domain" as Parameters<typeof terms>[0]);
    }
    const view =
      place.at === "stock"
        ? await stockScreen()
        : place.at === "thing"
          ? await thingScreen(place.id)
          : place.at === "places"
            ? await placesScreen()
            : await placeScreen(place.id);
    root.replaceChildren(view);
  } catch (e) {
    root.replaceChildren(
      screen(
        "stock",
        "Stores",
        banner(e instanceof Error ? e.message : "Something went wrong.", "error"),
      ),
    );
  }
  window.scrollTo(0, 0);
}

export function mountInventory(into: HTMLElement): void {
  root = into;
  window.addEventListener("hashchange", () => {
    void draw();
  });
  void draw();
}
