// ---------------------------------------------------------------------------
// Type: source
// Purpose: "Shows what sources say about a vineyard, block or row: the claim,
//           the source's own words, where it came from, and whether anybody
//           here has confirmed it."
// Depends on: [supabase/migrations/0164_a_claim_says_where_it_came_from.sql,
//              supabase/migrations/0166_a_confirmation_happens.sql,
//              supabase/migrations/0168_a_claim_can_be_wrong.sql]
// Depended on by: [packages/vineyard/src/vineyard.ts]
// ---------------------------------------------------------------------------
//
// "Keep the lineage so we know where each claim's coming from." So no claim is
// drawn without its source beside it: the value, then the source's exact words
// in quotation marks, then who said it and when it was read. Two sources that
// disagree are drawn next to each other under the same heading, which is the
// point: the screen does not choose, a person does, by confirming one.

import {
  banner,
  button,
  confirmNote,
  el,
  field,
  rejectClaim,
  reopenClaim,
  type SourcedClaim,
} from "core";

function readOn(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function rowsText(c: SourcedClaim): string | null {
  if (c.row_from === null) return null;
  return c.row_from === c.row_to
    ? `row ${c.row_from}`
    : `rows ${c.row_from} to ${c.row_to}`;
}

function claimCard(c: SourcedClaim, changed: () => void): HTMLElement {
  const said = el("div", {});
  const sourceLine = el(
    "p",
    { class: "claim-source" },
    c.source_url
      ? el("a", {
          href: c.source_url,
          target: "_blank",
          rel: "noopener",
          text: c.source_title,
        })
      : el("span", {
          text:
            c.source_kind === "person"
              ? `${c.source_title}, from what they know`
              : `${c.source_title} (a document)`,
        }),
    el("span", {
      text:
        (c.publisher ? `, ${c.publisher}` : "") +
        (c.published_on ? `, ${c.published_on}` : "") +
        `. Read ${readOn(c.retrieved_at)}.` +
        (c.locator ? ` ${c.locator}.` : ""),
    }),
  );
  return el(
    "li",
    { class: `claim claim-${c.provenance}` },
    el(
      "div",
      { class: "claim-head" },
      el("span", {
        class: "claim-value",
        text: `${c.value}${c.unit ? ` ${c.unit}` : ""}`,
      }),
      ...(rowsText(c) ? [el("span", { class: "tag", text: rowsText(c) ?? "" })] : []),
      el("span", {
        class: `tag ${
          c.verdict === "rejected"
            ? "tag-warn"
            : c.provenance === "confirmed"
              ? "tag-confirmed"
              : "tag-inherited"
        }`,
        text:
          c.verdict === "rejected"
            ? "marked wrong"
            : c.provenance === "confirmed"
              ? "confirmed here"
              : "a source says",
      }),
    ),
    c.statement && !c.statement.startsWith(`${c.kind_label}:`)
      ? el("p", { class: "claim-statement", text: c.statement })
      : null,
    el("blockquote", { class: "claim-quote", text: `“${c.excerpt}”` }),
    sourceLine,
    c.verdict === "rejected"
      ? el("p", {
          class: "claim-verdict",
          text: `Marked wrong${c.verdict_by ? ` by ${c.verdict_by}` : ""}${
            c.verdict_at ? `, ${readOn(c.verdict_at)}` : ""
          }: ${c.verdict_reason ?? ""}`,
        })
      : null,
    el("div", { class: "claim-actions" }, ...actions(c, changed, said)),
    said,
  );
}

// What can be said about a claim depends on what has been: a claim nobody has
// judged can be confirmed or called wrong; a confirmed or rejected one can be
// taken back, which leaves it as what its source says. Calling one wrong asks
// why, because the why is the follow-up, and what is right if it is known.
function actions(
  c: SourcedClaim,
  changed: () => void,
  said: HTMLElement,
): HTMLElement[] {
  const fail = (error: unknown) =>
    said.replaceChildren(banner((error as Error).message, "error"));
  if (c.provenance === "confirmed" || c.verdict === "rejected") {
    return [
      button(
        c.verdict === "rejected" ? "Reopen" : "Undo",
        async () => {
          try {
            await reopenClaim(c.note_id);
            changed();
          } catch (error) {
            fail(error);
          }
        },
        "quiet",
      ),
    ];
  }
  const why = field({
    label: "What is wrong",
    placeholder: "It was replanted in 2012",
  });
  const right = field({
    label: "What is right, if you know",
    placeholder: c.kind === "planted_year" ? "2012" : "",
    hint: "Recorded as your own claim, confirmed. Leave it blank to follow up later.",
  });
  const form = el(
    "details",
    { class: "more claim-wrong" },
    el("summary", { text: "This is wrong" }),
    why.root,
    right.root,
    button(
      "Mark it wrong",
      async () => {
        if (!why.value()) {
          said.replaceChildren(banner("Say what is wrong with it.", "error"));
          return;
        }
        try {
          await rejectClaim({
            noteId: c.note_id,
            reason: why.value(),
            right: right.value() || null,
          });
          changed();
        } catch (error) {
          fail(error);
        }
      },
      "secondary",
    ),
  );
  return [
    button(
      "This is right",
      async () => {
        try {
          await confirmNote(c.note_id);
          changed();
        } catch (error) {
          fail(error);
        }
      },
      "quiet",
    ),
    form,
  ];
}

// Every claim somebody here has called wrong, with why, wherever it is: the
// follow-up list.
export function followUpList(claims: SourcedClaim[], changed: () => void): HTMLElement {
  const wrong = claims.filter((c) => c.verdict === "rejected");
  if (wrong.length === 0) {
    return el("p", { class: "field-hint", text: "Nothing marked wrong yet." });
  }
  return el(
    "ul",
    { class: "claim-list" },
    ...wrong.map((c) =>
      el(
        "li",
        { class: "claim" },
        el(
          "div",
          { class: "claim-head" },
          el("span", {
            class: "claim-value",
            text: `${c.about ?? ""}: ${c.kind_label}`,
          }),
          el("span", { class: "tag tag-warn", text: c.value }),
        ),
        el("p", { class: "claim-verdict", text: c.verdict_reason ?? "" }),
        el("p", {
          class: "claim-source",
          text: `From ${c.publisher ?? c.source_title}.`,
        }),
        button(
          "Reopen",
          async () => {
            await reopenClaim(c.note_id);
            changed();
          },
          "quiet",
        ),
      ),
    ),
  );
}

// Grouped by what the claim is about, in the vocabulary's order, so planting
// year sits above rootstock above spacing whichever source said them first.
export function claimList(claims: SourcedClaim[], changed: () => void): HTMLElement {
  if (claims.length === 0) {
    return el("p", {
      class: "field-hint",
      text: "Nothing recorded from any source yet.",
    });
  }
  const byKind = new Map<string, SourcedClaim[]>();
  for (const c of claims)
    byKind.set(c.kind_label, [...(byKind.get(c.kind_label) ?? []), c]);
  return el(
    "div",
    { class: "claims" },
    ...[...byKind].map(([label, list]) => {
      const values = new Set(list.map((c) => c.value));
      return el(
        "section",
        { class: "claim-group" },
        el(
          "h3",
          { class: "claim-kind" },
          el("span", { text: label }),
          values.size > 1 && !list.some((c) => c.row_from !== null)
            ? el("span", { class: "tag tag-warn", text: "sources differ" })
            : null,
        ),
        el("ul", { class: "claim-list" }, ...list.map((c) => claimCard(c, changed))),
      );
    }),
  );
}
