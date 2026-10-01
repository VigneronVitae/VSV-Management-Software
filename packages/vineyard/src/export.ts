// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The whole vineyard as one workbook somebody outside the winery can
//           open: blocks with their planting, a coloured map of every block,
//           every vine, and every claim with where it came from."
// Depends on: [packages/core/src/xlsx.ts,
//              supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
//              supabase/migrations/0165_what_each_row_is_said_to_be.sql]
// Depended on by: [packages/vineyard/src/vineyard.ts]
// ---------------------------------------------------------------------------
//
// "I meant see vineyard data, like the map I gave you but consolidated into an
// export. A derived vineyard map with planting dates and such." The map came
// in as five sheets of coloured cells; this sends it back out the same way,
// derived from the plant spaces rather than copied, with the planting year,
// rootstock and spacing of every row beside it from the claims (0165), each
// marked as confirmed or as what a source says.
//
// **Everything here is read, nothing decided.** Counts and acreage come from
// the kernel's views, the row facts from `row_fact`, which already chose
// between claims. What this file does is lay them out.

import {
  type BlockAcreage,
  type Cell,
  download,
  type PlantSpace,
  type RowFact,
  type SourcedClaim,
  workbook,
} from "core";

export type MapPalette = {
  colourOf: (s: PlantSpace) => string;
  inkOn: (c: string) => string;
};

// What a plant space says in its cell: the clone where there is one, because
// that is what tells Overlook's rows apart, otherwise a short variety name.
const SHORT: Record<string, string> = {
  "Pinot Noir": "PN",
  "Pinot Gris": "PG",
  "Pinot Blanc": "PB",
  "Pinot Meunier": "PM",
  Riesling: "RI",
  "Grüner Veltliner": "GV",
  "Müller Thurgau": "MT",
  Gamay: "GA",
  Chardonnay: "CH",
  "Table grapes": "TG",
};

function code(s: PlantSpace): string {
  if (s.state === "empty") return "";
  if (s.state === "rootstock_only") return "R";
  const base =
    s.clone ??
    (s.variety ? (SHORT[s.variety] ?? s.variety.slice(0, 2).toUpperCase()) : "?");
  return s.state === "young_scion" ? `${base}*` : base;
}

// A hex colour for Excel, which cannot read a CSS variable: the gap colour on
// screen is the theme's rule line.
function solid(c: string): string {
  return c.startsWith("#") ? c : "#DCD9D2";
}

function factOf(facts: RowFact[], rowId: string, kind: string): RowFact | undefined {
  return facts.find((f) => f.row_id === rowId && f.kind === kind);
}

function said(f: RowFact | undefined): string {
  if (!f) return "";
  return f.confirmed ? f.value : `${f.value} (source)`;
}

export function downloadVineMap(args: {
  vineyard: string;
  spaces: PlantSpace[];
  acreage: BlockAcreage[];
  facts: RowFact[];
  claims: SourcedClaim[];
  palette: MapPalette;
}): void {
  const { spaces, acreage, facts, claims, palette } = args;
  const blocks = [...new Set(spaces.map((s) => s.block))];

  // Per block, what its rows say, gathered: a block planted in two years says
  // both, in row order, because Southeast was.
  const blockFact = (blockId: string, kind: string): string => {
    const vals: string[] = [];
    let anyInferred = false;
    for (const f of facts.filter((x) => x.block_id === blockId && x.kind === kind)) {
      if (!vals.includes(f.value)) vals.push(f.value);
      if (!f.confirmed) anyInferred = true;
    }
    return vals.length === 0
      ? ""
      : `${vals.join(", ")}${anyInferred ? " (source)" : ""}`;
  };

  const summary: Cell[][] = acreage
    .filter((b) => spaces.some((s) => s.block_id === b.block_id))
    .map((b) => [
      b.vineyard ?? "",
      b.block,
      b.plants,
      b.gaps,
      b.acres === null ? null : Number(b.acres),
      b.vines_per_acre === null ? null : Number(b.vines_per_acre),
      blockFact(b.block_id, "planted_year"),
      blockFact(b.block_id, "rootstock"),
      blockFact(b.block_id, "spacing"),
    ]);

  const maps = blocks.map((block) => {
    const here = spaces.filter((s) => s.block === block);
    const rowIds = [...new Set(here.map((s) => s.row_id))];
    const widest = Math.max(
      ...rowIds.map((r) => here.filter((s) => s.row_id === r).length),
    );
    return {
      name: `Map ${block}`,
      freeze: false,
      columns: [
        { header: "Row", width: 5 },
        { header: "Planted", width: 14 },
        { header: "Rootstock", width: 14 },
        { header: "Spacing", width: 12 },
        ...Array.from({ length: widest }, (_, i) => ({
          header: String(i + 1),
          width: 4,
        })),
      ],
      rows: rowIds.map((rowId) => {
        const inRow = here.filter((s) => s.row_id === rowId);
        return [
          inRow[0]?.row_number ?? null,
          said(factOf(facts, rowId, "planted_year")),
          said(factOf(facts, rowId, "rootstock")),
          said(factOf(facts, rowId, "spacing")),
          ...inRow.map((s): Cell => {
            const fill = solid(palette.colourOf(s));
            return { text: code(s), fill, ink: palette.inkOn(fill) };
          }),
        ];
      }),
    };
  });

  const key = new Map<string, { fill: string; ink: string }>();
  for (const s of spaces) {
    const label =
      s.state === "empty"
        ? "Gap"
        : s.state === "rootstock_only"
          ? "R: rootstock only"
          : `${code(s)}: ${s.variety ?? "unknown"}${s.clone ? ` ${s.clone}` : ""}${s.state === "young_scion" ? ", young scion" : ""}`;
    if (!key.has(label)) {
      const fill = solid(palette.colourOf(s));
      key.set(label, { fill, ink: palette.inkOn(fill) });
    }
  }

  const factsByRow = (rowId: string, kind: string) =>
    factOf(facts, rowId, kind)?.value ?? "";

  const blob = workbook([
    {
      name: "Blocks",
      columns: [
        { header: "Vineyard", width: 24 },
        { header: "Block", width: 20 },
        { header: "Plants", width: 9 },
        { header: "Gaps", width: 7 },
        { header: "Acres, counted", width: 14 },
        { header: "Vines an acre", width: 13 },
        { header: "Planted", width: 18 },
        { header: "Rootstock", width: 16 },
        { header: "Spacing", width: 16 },
      ],
      rows: summary,
    },
    ...maps,
    {
      name: "Key",
      columns: [
        { header: "Cell", width: 8 },
        { header: "Means", width: 40 },
      ],
      rows: [
        ...[...key].map(([label, c]): Cell[] => [
          { text: label.split(":")[0] ?? "", fill: c.fill, ink: c.ink },
          label,
        ]),
        ["*", "A young scion: grafted, not bearing yet."],
        [
          "(source)",
          "Planted, rootstock and spacing marked (source) are what a source says and nobody here has confirmed yet; the Claims sheet says which source.",
        ],
      ],
    },
    {
      name: "Every vine",
      columns: [
        { header: "Vineyard", width: 22 },
        { header: "Block", width: 18 },
        { header: "Row", width: 6 },
        { header: "Plant", width: 7 },
        { header: "State", width: 14 },
        { header: "Variety", width: 18 },
        { header: "Clone", width: 10 },
        { header: "Planted", width: 10 },
        { header: "Rootstock", width: 14 },
        { header: "Spacing", width: 10 },
        { header: "As of", width: 12 },
      ],
      rows: spaces.map((s) => [
        s.vineyard ?? "",
        s.block,
        s.row_number,
        s.space_number,
        s.state_label ?? "",
        s.variety ?? "",
        s.clone ?? "",
        factsByRow(s.row_id, "planted_year"),
        factsByRow(s.row_id, "rootstock"),
        factsByRow(s.row_id, "spacing"),
        s.as_of ? { date: s.as_of } : null,
      ]),
    },
    {
      name: "Claims",
      columns: [
        { header: "About", width: 34 },
        { header: "Fact", width: 16 },
        { header: "Value", width: 30 },
        { header: "Rows", width: 9 },
        { header: "Status", width: 12 },
        { header: "Source", width: 40 },
        { header: "Publisher", width: 26 },
        { header: "Published", width: 12 },
        { header: "Read", width: 12 },
        { header: "Link", width: 40 },
        { header: "The source's words", width: 60 },
        { header: "Where in it", width: 16 },
      ],
      rows: claims.map((c) => [
        c.about ?? "",
        c.kind_label,
        c.value,
        c.row_from === null
          ? ""
          : c.row_from === c.row_to
            ? String(c.row_from)
            : `${c.row_from}-${c.row_to}`,
        c.provenance === "confirmed" ? "confirmed" : "a source says",
        c.source_title,
        c.publisher ?? "",
        c.published_on ? { date: c.published_on } : null,
        { date: c.retrieved_at },
        c.source_url ?? "",
        c.excerpt,
        c.locator ?? "",
      ]),
    },
  ]);
  const day = new Date().toISOString().slice(0, 10);
  download(
    blob,
    `${args.vineyard.replace(/[^A-Za-z0-9]+/g, "-")}-vine-map-${day}.xlsx`,
  );
}
