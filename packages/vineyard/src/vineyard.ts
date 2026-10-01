// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The vineyard, as a periphery of its own: blocks, rows, and the vine
//           standing in each position."
// Depends on: [supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
//              supabase/migrations/0117_the_vine_map_is_loaded.sql,
//              packages/vineyard/src/claims.ts, packages/vineyard/src/export.ts]
// Depended on by: [packages/vineyard/src/index.ts]
// ---------------------------------------------------------------------------
//
// The third periphery. The winemaker's reason for the second one holds for this
// one: a single client leans on knowledge it never wrote down, and each new one
// trips over the gaps rather than inheriting them.
//
// **This app is the map.** Its centre is the row screen, which draws a row as
// the spreadsheet drew it, one cell per plant space coloured by what is in it.
// That is not decoration. The source document has been unreadable by anything
// for years precisely because the information was in the colours, and the point
// of loading it was to make it something you can stand in front of a row and
// check.
//
// May import from `core`. May never import from `cellar` or `shop`.
// scripts/verify.sh checks that.

import {
  addNote,
  allPlantSpaces,
  type BlockAcreage,
  type BlockPlanting,
  banner,
  blockAcreage,
  blockPlanting,
  button,
  el,
  empty,
  field,
  lede,
  on,
  type PlantSpace,
  plantSpaces,
  rowFacts,
  rows,
  sourcedClaims,
  type VineRow,
  vineRows,
  vineyards,
} from "core";
import { claimList, followUpList } from "./claims.ts";
import { downloadVineHighlights, downloadVineMap } from "./export.ts";
import { decode, encode, PLACES, type VinePlace } from "./places.ts";

let root: HTMLElement | null = null;

// What a vine of each variety is drawn as. Taken from the map's own palette
// where it reads on a screen, adjusted where it did not: the map distinguishes
// Pinot Gris from table grapes by two greys three percent apart, which is fine
// on a laptop in a farm office and useless on a phone in the sun.
const VARIETY_COLOUR: Record<string, string> = {
  "Pinot Noir": "#843640",
  "Pinot Gris": "#9aa0a6",
  Riesling: "#bf9000",
  "Grüner Veltliner": "#8faa33",
  "Müller Thurgau": "#d4c52d",
  "Pinot Meunier": "#c86470",
  "Pinot Blanc": "#cfc7b0",
  Gamay: "#f4b183",
  "Table grapes": "#7a6a9a",
};

function colourOf(s: PlantSpace): string {
  if (s.state === "empty") return "var(--rule)";
  if (s.state === "rootstock_only") return "#806000";
  return (s.variety && VARIETY_COLOUR[s.variety]) || "var(--ink-faint)";
}

// Black or white on top, whichever can be read. Found by screenshotting a real
// row: white numbers on Gamay and Müller Thurgau were barely legible, and those
// are pale by necessity because the map paints them pale. A fixed text colour
// works for the dark half of the palette and fails for the rest, and this grid
// is read at arm's length in sunlight.
//
// Rec. 601 luma rather than full WCAG contrast: the question is only which of
// two colours to use, the palette is nine known values, and the cheap formula
// gets all nine right.
function inkOn(colour: string): string {
  if (!colour.startsWith("#")) return "#fff";
  const hex = colour.slice(1);
  const n = Number.parseInt(
    hex.length === 3
      ? hex
          .split("")
          .map((c) => c + c)
          .join("")
      : hex,
    16,
  );
  const r = (n >> 16) & 255;
  const g = (n >> 8) & 255;
  const b = n & 255;
  return (r * 299 + g * 587 + b * 114) / 1000 > 150 ? "#1a1a19" : "#fff";
}

function here(): VinePlace {
  return decode(window.location.hash);
}

function go(place: VinePlace): void {
  window.location.hash = encode(place);
}

// The app's own chrome. Not the cellar's: there is no practice band and no
// vessel language here, and the header carries where you are in the vineyard,
// which is the one thing you need while standing in it.
function screen(
  place: string,
  title: string,
  ...body: (Node | string | null | false)[]
): HTMLElement {
  if (!PLACES.has(place)) {
    // A place this module does not admit to having. The same guard the shop
    // uses, and scripts/screens.sh checks the list against the registry so a
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

// --- the blocks -----------------------------------------------------------

function blocksScreen(): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen(
    "blocks",
    "The vineyard",
    lede("Every block, counted from the vine map rather than typed."),
    body,
  );

  void (async () => {
    try {
      const all = await blockAcreage();
      const mine = all.filter((b) => b.plants > 0);
      if (mine.length === 0) {
        body.replaceChildren(empty("No blocks have any vines recorded yet."));
        return;
      }

      const totalPlants = mine.reduce((n, b) => n + b.plants, 0);
      const totalAcres = mine.reduce((n, b) => n + Number(b.acres ?? 0), 0);

      function blockRow(b: BlockAcreage): HTMLElement {
        const row = el(
          "li",
          { class: "vessel-row", role: "button", tabindex: "0" },
          el("span", { class: "vessel-name", text: b.block }),
          el("span", {
            class: "vessel-detail",
            text: `${b.plants.toLocaleString()} plants`,
          }),
          el("span", {
            class: "vessel-detail",
            // Null rather than nothing when the density is unset, because an
            // acreage with no divisor is a number nobody has worked out.
            text:
              b.acres === null
                ? "acreage not worked out"
                : `${Number(b.acres).toFixed(2)} acres`,
          }),
          b.gaps > 0
            ? el("span", { class: "tag tag-inherited", text: `${b.gaps} gaps` })
            : null,
        );
        const open = () => go({ at: "block", id: b.block_id });
        on(row, "click", open);
        on(row, "keydown", (ev) => {
          if (ev.key === "Enter" || ev.key === " ") {
            ev.preventDefault();
            open();
          }
        });
        return row;
      }

      const [allVineyards, claims] = await Promise.all([vineyards(), sourcedClaims()]);
      const said = el("div", {});
      // "Like the map I gave you but consolidated into an export." Every
      // block, coloured as the spreadsheet was, with each row's planting from
      // the claims, every vine, and every claim with its source.
      // "Maybe a much abridged version too, just the highlights." The short
      // one first, because it is the one somebody outside asks for.
      const highlightsButton = button(
        "Highlights for Excel",
        async () => {
          try {
            const [spaces, facts] = await Promise.all([allPlantSpaces(), rowFacts()]);
            downloadVineHighlights({
              vineyard: mine[0]?.vineyard ?? "vineyard",
              spaces,
              acreage: all,
              facts,
              claims,
            });
            said.replaceChildren(banner("Downloaded the highlights.", "good"));
          } catch (error) {
            said.replaceChildren(banner((error as Error).message, "error"));
          }
        },
        "secondary",
      );
      const exportButton = button(
        "Everything for Excel",
        async () => {
          try {
            const [spaces, facts] = await Promise.all([allPlantSpaces(), rowFacts()]);
            downloadVineMap({
              vineyard: mine[0]?.vineyard ?? "vineyard",
              spaces,
              acreage: all,
              facts,
              claims,
              palette: { colourOf, inkOn },
            });
            said.replaceChildren(
              banner(
                `Downloaded: ${spaces.length.toLocaleString()} plant spaces, ${claims.length} claims.`,
                "good",
              ),
            );
          } catch (error) {
            said.replaceChildren(banner((error as Error).message, "error"));
          }
        },
        "quiet",
      );

      function vineyardRow(id: string, name: string): HTMLElement {
        const n = claims.filter((c) => c.vineyard_id === id).length;
        const confirmed = claims.filter(
          (c) => c.vineyard_id === id && c.provenance === "confirmed",
        ).length;
        const row = el(
          "li",
          { class: "vessel-row", role: "button", tabindex: "0" },
          el("span", { class: "vessel-name", text: name }),
          el("span", {
            class: "vessel-detail",
            text:
              n === 0
                ? "nothing from any source"
                : `${n} claim${n === 1 ? "" : "s"}, ${confirmed} confirmed`,
          }),
        );
        const open = () => go({ at: "vineyard", id });
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
          el("ul", { class: "vessel-list" }, ...mine.map(blockRow)),
          el("p", {
            class: "field-hint",
            text:
              `${totalPlants.toLocaleString()} plants across ${mine.length} blocks, ` +
              `${totalAcres.toFixed(2)} acres. A rootstock counts as a plant, ` +
              "which is how the vine map counts.",
          }),
          highlightsButton,
          el("p", {
            class: "field-hint",
            text: "The highlights: what each vineyard is said to be, every block, and its rows gathered into runs planted alike.",
          }),
          exportButton,
          el("p", {
            class: "field-hint",
            text:
              "Everything: a coloured map of each block, every vine, and every claim with its source. " +
              "Both are made from the records each time, so neither is older than they are.",
          }),
          said,
          el("h2", { class: "section-head", text: "What sources say" }),
          el(
            "ul",
            { class: "vessel-list" },
            ...allVineyards.map((v) => vineyardRow(v.id, v.name)),
          ),
          el("h2", { class: "section-head", text: "Marked wrong, to follow up" }),
          followUpList(claims, () => render()),
        ),
      );
    } catch (error) {
      body.replaceChildren(banner((error as Error).message, "error"));
    }
  })();

  return view;
}

// --- one block ------------------------------------------------------------

function blockScreen(blockId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("block", "Block", body);

  void (async () => {
    try {
      const [acre, planted, rowList, claims] = await Promise.all([
        blockAcreage(),
        blockPlanting(blockId),
        vineRows(blockId),
        sourcedClaims(),
      ]);
      const mineClaims = claims.filter(
        (c) => c.subject_type === "block" && c.subject_id === blockId,
      );
      const b = acre.find((x) => x.block_id === blockId);
      if (!b) {
        body.replaceChildren(
          banner("That block is not there to open.", "note"),
          button("The vineyard", () => go({ at: "blocks" }), "quiet"),
        );
        return;
      }
      view.replaceChildren(el("h1", { text: b.block }), body);

      function plantingRow(p: BlockPlanting): HTMLElement {
        return el(
          "li",
          { class: "vessel-row" },
          el("span", {
            class: "vessel-name",
            text: p.clone ? `${p.variety} ${p.clone}` : (p.variety ?? "Unplanted"),
          }),
          el("span", {
            class: "vessel-detail",
            text: `${p.plants.toLocaleString()} ${p.state === "young_scion" ? "young" : "plants"}`,
          }),
          p.acres === null
            ? null
            : el("span", {
                class: "vessel-detail",
                text: `${Number(p.acres).toFixed(3)} acres`,
              }),
        );
      }

      function rowButton(r: VineRow): HTMLElement {
        const cell = el("button", {
          class: "row-number",
          type: "button",
          text: String(r.number),
        });
        on(cell, "click", () => go({ at: "row", id: r.id }));
        return cell;
      }

      body.replaceChildren(
        rows(
          el("p", {
            class: "lede",
            text:
              `${b.plants.toLocaleString()} plants, ` +
              `${b.acres === null ? "acreage not worked out" : `${Number(b.acres).toFixed(3)} acres`}` +
              `${b.gaps > 0 ? `, ${b.gaps} gaps` : ""}.`,
          }),
          el("h2", { class: "section-head", text: "What is planted" }),
          el("ul", { class: "vessel-list" }, ...planted.map(plantingRow)),
          el("h2", { class: "section-head", text: "Rows" }),
          rowList.length === 0
            ? empty("No rows recorded in this block.")
            : el("div", { class: "row-grid" }, ...rowList.map(rowButton)),
          el("p", {
            class: "field-hint",
            text: `${rowList.length} rows. Tap one to see the vines in it.`,
          }),
          el("h2", { class: "section-head", text: "What sources say" }),
          claimList(mineClaims, () => render()),
          button("The vineyard", () => go({ at: "blocks" }), "quiet"),
        ),
      );
    } catch (error) {
      body.replaceChildren(banner((error as Error).message, "error"));
    }
  })();

  return view;
}

// --- one row, which is the map ---------------------------------------------

function rowScreen(rowId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("row", "Row", body);

  void (async () => {
    try {
      const spaces = await plantSpaces(rowId);
      if (spaces.length === 0) {
        body.replaceChildren(
          banner("That row is not there, or has no plant spaces.", "note"),
          button("The vineyard", () => go({ at: "blocks" }), "quiet"),
        );
        return;
      }
      const first = spaces[0];
      if (!first) return;
      view.replaceChildren(
        el("h1", { text: `${first.block}, row ${first.row_number}` }),
        body,
      );

      const detail = el("div", { class: "vine-detail" });
      let chosen: PlantSpace | null = null;

      function draw(): void {
        if (!chosen) {
          detail.replaceChildren(
            el("p", {
              class: "field-hint",
              text: "Tap a vine to see what the map says is in that position.",
            }),
          );
          return;
        }
        const s = chosen;
        const said = el("div", {});
        const note = field({
          label: "Note about this vine",
          placeholder: "Sucker only. Grow tube. Dead, needs replanting.",
        });
        detail.replaceChildren(
          rows(
            el("h2", {
              class: "section-head",
              text: `Plant ${s.space_number}`,
            }),
            el("p", {
              class: "lede",
              text:
                s.state === "empty"
                  ? "Nothing in this position."
                  : s.state === "rootstock_only"
                    ? "Rootstock, not grafted."
                    : `${s.variety}${s.clone ? ` ${s.clone}` : ""}${s.state === "young_scion" ? ", young scion" : ""}.`,
            }),
            el("p", {
              class: "field-hint",
              // Provenance said out loud on the screen, because every row of
              // this came off a spreadsheet and not off a walk down the row.
              text:
                `As of ${s.as_of ?? "unknown"}, ` +
                (s.provenance === "inferred"
                  ? "read from the vine map rather than seen. Walk the row to confirm it."
                  : "observed."),
            }),
            note.root,
            button(
              "Save the note",
              async () => {
                if (!note.value()) {
                  said.replaceChildren(banner("Write something first.", "error"));
                  return;
                }
                try {
                  await addNote({
                    subjectType: "plant_space",
                    subjectId: s.space_id,
                    body: note.value(),
                  });
                  note.input.value = "";
                  said.replaceChildren(banner("Saved against this vine.", "good"));
                } catch (error) {
                  said.replaceChildren(banner((error as Error).message, "error"));
                }
              },
              "secondary",
            ),
            said,
          ),
        );
      }

      const grid = el(
        "div",
        { class: "vine-grid" },
        ...spaces.map((s) => {
          const cell = el("button", {
            class: `vine${s.state === "empty" ? " vine-gap" : ""}`,
            type: "button",
            text: String(s.space_number),
            title: `${s.space_number}: ${s.state_label ?? "unknown"}${s.variety ? `, ${s.variety}` : ""}`,
          });
          const paint = colourOf(s);
          cell.style.setProperty("--vine", paint);
          cell.style.setProperty("--vine-ink", inkOn(paint));
          on(cell, "click", () => {
            chosen = s;
            for (const other of grid.querySelectorAll(".vine-on")) {
              other.classList.remove("vine-on");
            }
            cell.classList.add("vine-on");
            draw();
          });
          return cell;
        }),
      );

      // What this row is made of, so the strip has a key beside it rather than
      // needing one remembered.
      const tally = new Map<string, number>();
      for (const s of spaces) {
        const k =
          s.state === "empty"
            ? "Gap"
            : s.state === "rootstock_only"
              ? "Rootstock"
              : `${s.variety}${s.clone ? ` ${s.clone}` : ""}${s.state === "young_scion" ? " (young)" : ""}`;
        tally.set(k, (tally.get(k) ?? 0) + 1);
      }

      draw();
      body.replaceChildren(
        rows(
          el("p", {
            class: "lede",
            text:
              `${spaces.length} plant spaces` +
              (first.orientation ? `, ${first.orientation.toLowerCase()}` : "") +
              ".",
          }),
          grid,
          el(
            "ul",
            { class: "vessel-list" },
            ...[...tally].map(([label, n]) =>
              el(
                "li",
                { class: "vessel-row" },
                el("span", { class: "vessel-name", text: label }),
                el("span", { class: "vessel-detail", text: String(n) }),
              ),
            ),
          ),
          detail,
          button(
            "Back to the block",
            () => go({ at: "block", id: first.block_id }),
            "quiet",
          ),
        ),
      );
    } catch (error) {
      body.replaceChildren(banner((error as Error).message, "error"));
    }
  })();

  return view;
}

// --- one vineyard, by what sources say --------------------------------------

// 0164. Every vineyard this winery deals with, including the ones it buys from
// and has no map of: what public sources and its own documents say, each with
// its source and words, its blocks' claims beneath its own.
function vineyardScreen(vineyardId: string): HTMLElement {
  const body = el("div", {}, empty("Loading."));
  const view = screen("vineyard", "Vineyard", body);

  void (async () => {
    try {
      const [all, claims] = await Promise.all([vineyards(), sourcedClaims()]);
      const v = all.find((x) => x.id === vineyardId);
      if (!v) {
        body.replaceChildren(
          banner("That vineyard is not there to open.", "note"),
          button("The vineyard", () => go({ at: "blocks" }), "quiet"),
        );
        return;
      }
      view.replaceChildren(el("h1", { text: v.name }), body);
      const own = claims.filter(
        (c) => c.subject_type === "vineyard" && c.subject_id === vineyardId,
      );
      const blockClaims = claims.filter(
        (c) => c.subject_type !== "vineyard" && c.vineyard_id === vineyardId,
      );
      const byBlock = new Map<string, typeof blockClaims>();
      for (const c of blockClaims) {
        const k = c.about ?? "A block";
        byBlock.set(k, [...(byBlock.get(k) ?? []), c]);
      }
      body.replaceChildren(
        rows(
          el("p", {
            class: "lede",
            text:
              own.length + blockClaims.length === 0
                ? "Nothing recorded from any source yet."
                : "What sources say, each with its own words and where it came from. Nothing here is confirmed until somebody who knows says so.",
          }),
          claimList(own, () => render()),
          ...[...byBlock].flatMap(([block, list]) => [
            el("h2", { class: "section-head", text: block }),
            claimList(list, () => render()),
          ]),
          button("The vineyard", () => go({ at: "blocks" }), "quiet"),
        ),
      );
    } catch (error) {
      body.replaceChildren(banner((error as Error).message, "error"));
    }
  })();

  return view;
}

// --- the shell ------------------------------------------------------------

function render(): void {
  if (!root) return;
  const place = here();
  try {
    if (place.at === "block") {
      root.replaceChildren(blockScreen(place.id));
    } else if (place.at === "row") {
      root.replaceChildren(rowScreen(place.id));
    } else if (place.at === "vineyard") {
      root.replaceChildren(vineyardScreen(place.id));
    } else {
      root.replaceChildren(blocksScreen());
    }
  } catch (error) {
    root.replaceChildren(
      el("section", { class: "screen" }, banner((error as Error).message, "error")),
    );
  }
}

export function mountVineyard(target: HTMLElement): void {
  root = target;
  window.addEventListener("hashchange", render);
  render();
}
