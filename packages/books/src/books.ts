// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The books, as a periphery of its own: four piles of transactions and
//           a thumb working through them, one tap where the answer is already
//           known and a picker where it is not."
// Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql,
//              supabase/migrations/0125_the_categories_are_schedule_f.sql,
//              supabase/migrations/0126_only_a_person_confirms.sql,
//              packages/books/src/places.ts,
//              supabase/migrations/0130_the_bank_says_more_than_a_name.sql]
// Depended on by: [packages/books/src/index.ts,
//                  packages/books/src/places.ts]
// ---------------------------------------------------------------------------
//
// The fourth periphery, and the first one that is not about something you can
// stand in front of.
//
// **The centre of this app is the one-tap confirm, and that is a constraint
// rather than a flourish.** There are eight hundred transactions waiting and the
// winemaker said outright that the point of the module is doing the matching on
// a phone. Eight hundred rows at four taps each is not work anybody finishes;
// eight hundred at one tap each is an evening. So the list carries the answer
// and the button together, and opening a transaction is what you do when the
// answer is wrong, not what you do to say it is right.
//
// The suggestion comes from `merchant_suggestion`, a view over attestations
// somebody already confirmed. It is memory rather than a model: the app cannot
// suggest anything until a person has said it once, and what it suggests is
// exactly what that person said. That is also why this button may write
// `confirm: true` and the import path may not. T0-4 puts a trust field in the
// hands of the verifier, and here the verifier is the thumb.
//
// May import from `core`. May never import from `cellar`, `shop` or `vineyard`.
// scripts/verify.sh checks that.

import {
  attestLine,
  banner,
  button,
  el,
  empty,
  field,
  lede,
  type MerchantSuggestion,
  type MoneyLine,
  type MoneyTally,
  merchantSuggestions,
  moneyLine,
  moneyQueue,
  moneyTally,
  on,
  rows,
  signIn,
  summaryRow,
  type Term,
  terms,
  viewerScope,
} from "core";
import { type BookPlace, decode, encode, PILES, PLACES } from "./places.ts";

let root: HTMLElement | null = null;

// The vocabulary, fetched once. Thirty-odd Schedule F lines plus whatever this
// winery has added, and refetching them per transaction would be the single
// biggest thing this app does over the wire.
let vocabulary: Term[] = [];

// What each pile is, in the words somebody working through it would use. Not
// the kernel's words: `unexplained` is what the view calls it and "Nobody has
// said" is what it means at eleven at night.
const PILE: Record<string, { title: string; blurb: string }> = {
  unexplained: {
    title: "Nobody has said",
    blurb: "Transactions with nothing on them yet. This is the pile that shrinks.",
  },
  unconfirmed: {
    title: "Guessed, not confirmed",
    blurb:
      "Something proposed a category and no person has agreed to it yet. One tap each.",
  },
  disputed: {
    title: "Two answers",
    blurb:
      "More than one person filed these differently. Worth a look rather than a fix.",
  },
  settled: {
    title: "Settled",
    blurb: "A person confirmed these. They are here so you can find one again.",
  },
};

// `noUncheckedIndexedAccess` is right about this: the key came out of a URL
// hash, and `decode` only promises it is one of PILES. A pile the kernel grew
// and this table has not heard of is a real possibility, and it should draw
// under its own name rather than throw.
function pileMeta(key: string): { title: string; blurb: string } {
  return PILE[key] ?? { title: key, blurb: "" };
}

function here(): BookPlace {
  return decode(window.location.hash);
}

function go(place: BookPlace): void {
  window.location.hash = encode(place);
}

// Money as a person reads it. Signed, because the useful fact about a
// transaction on a phone is whether it went out, and a column saying "Debit"
// next to a positive number makes you do that subtraction yourself every time.
function money(n: number): string {
  const s = Math.abs(n).toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return (n < 0 ? "-$" : "$") + s;
}

function day(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? iso.slice(0, 10)
    : d.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "2-digit",
      });
}

function screen(
  place: string,
  title: string,
  ...body: (Node | string | null | false)[]
): HTMLElement {
  if (!PLACES.has(place)) {
    // A place this module does not admit to having. The same guard the shop and
    // the vineyard use, and scripts/screens.sh checks the list against the
    // registry so a screen nobody registered cannot be noted about.
    throw new Error(`no such place: ${place}`);
  }
  return el(
    "section",
    { class: "screen" },
    el("h1", { text: title }),
    ...body.filter((b): b is Node | string => b !== null && b !== false),
  );
}

function backTo(place: BookPlace, label: string): HTMLElement {
  return el(
    "p",
    { class: "crumb" },
    button(label, () => go(place), "quiet"),
  );
}

// ---------------------------------------------------------------------------
// The front: which pile to open
// ---------------------------------------------------------------------------

async function moneyScreen(): Promise<HTMLElement> {
  const tally = await moneyTally();
  const by = new Map(tally.map((t) => [t.queue, t]));
  const total = tally.reduce((a, t) => a + t.net, 0);
  const lines = tally.reduce((a, t) => a + t.lines, 0);

  const piles = PILES.map((key) => {
    const t: MoneyTally = by.get(key) ?? { queue: key, lines: 0, net: 0 };
    const card = el(
      "button",
      {
        class: `pile pile-${key}`,
        type: "button",
        // A pile with nothing in it is not a thing to tap, and on a phone an
        // empty list you navigated to is indistinguishable from a broken one.
        disabled: t.lines === 0,
      },
      el("span", { class: "pile-count", text: String(t.lines) }),
      el(
        "span",
        { class: "pile-body" },
        el("span", { class: "pile-title", text: pileMeta(key).title }),
        el("span", { class: "pile-blurb", text: pileMeta(key).blurb }),
      ),
      el("span", { class: "pile-net", text: money(t.net) }),
    );
    on(card, "click", () => go({ at: "pile", id: key }));
    return card;
  });

  return screen(
    "money",
    "Books",
    lede(
      lines === 0
        ? "Nothing imported yet."
        : `${lines} transactions, ${money(total)} net.`,
    ),
    el("div", { class: "piles" }, ...piles),
    el(
      "p",
      { class: "crumb" },
      button("What a merchant has been called", () => go({ at: "merchants" }), "quiet"),
    ),
  );
}

// ---------------------------------------------------------------------------
// A pile: the list, and the tap
// ---------------------------------------------------------------------------

// How many come down at once. Fifty is about three screens of thumb on a phone,
// and the next fifty arrive on a button rather than on a scroll listener,
// because an infinite scroll that fires while you are reaching for a confirm
// chip moves the chip.
const PAGE = 50;

async function pileScreen(pile: string): Promise<HTMLElement> {
  const list = el("div", { class: "ledger" });
  const status = el("p", { class: "lede" });
  const search = field({
    label: "Find",
    placeholder: "part of a description",
    attrs: { autocapitalize: "none", autocorrect: "off" },
  });

  let offset = 0;
  let exhausted = false;
  let debounce = 0;

  const more = button(
    "Fifty more",
    async () => {
      offset += PAGE;
      await load(false);
    },
    "secondary",
  );

  function count(): void {
    status.textContent = `${list.childElementCount} shown${
      exhausted ? "" : ", more below"
    }`;
  }

  // One transaction, as a row you can act on without opening it.
  function row(line: MoneyLine): HTMLElement {
    // What we would file it as without asking: the memory's suggestion for a
    // line nobody has typed, or the standing guess for one that arrived with a
    // class already on it. Both are somebody else's word, and neither is a
    // confirmation until this button is pressed.
    const guessValue = line.class ?? line.suggested;
    const guessLabel = line.class_label ?? line.suggested_label;

    const open = el(
      "button",
      { class: "entry-open", type: "button" },
      el(
        "span",
        { class: "entry-head" },
        el("span", { class: "entry-when", text: day(line.at) }),
        el("span", { class: "entry-sum", text: money(line.signed_amount) }),
      ),
      el("span", {
        class: "entry-what",
        text: line.description || line.txn_type || "No description",
      }),
      line.check_number
        ? el("span", { class: "entry-tag", text: `check ${line.check_number}` })
        : null,
    );
    on(open, "click", () => go({ at: "line", id: line.id }));

    const item = el(
      "div",
      { class: `entry${line.signed_amount < 0 ? " entry-out" : " entry-in"}` },
      open,
    );

    if (guessValue && guessLabel) {
      // The whole point of the app. The suggestion and the agreement are one
      // control, so saying yes costs a tap and nothing else.
      const yes = button(
        `Yes, ${guessLabel}`,
        async () => {
          await attestLine({ lineId: line.id, klass: guessValue, confirm: true });
          // It leaves this pile the moment it is confirmed, and the list getting
          // shorter is the progress bar.
          item.remove();
          count();
          if (list.childElementCount === 0) list.append(empty("Pile cleared."));
        },
        "primary",
      );
      yes.classList.add("entry-yes");
      item.append(yes);
      if (line.suggested_on && !line.class) {
        item.append(
          el("span", {
            class: "entry-why",
            text: `said ${line.suggested_on} time${
              line.suggested_on === 1 ? "" : "s"
            } before`,
          }),
        );
      }
    } else {
      const pick = button(
        "Say what it was",
        () => go({ at: "line", id: line.id }),
        "secondary",
      );
      pick.classList.add("entry-yes");
      item.append(pick);
    }
    return item;
  }

  async function load(fresh: boolean): Promise<void> {
    if (fresh) {
      offset = 0;
      exhausted = false;
      list.replaceChildren();
    }
    const text = search.value();
    const found = await moneyQueue({
      queue: pile,
      limit: PAGE,
      offset,
      ...(text ? { search: text } : {}),
    });
    if (found.length < PAGE) exhausted = true;
    for (const line of found) list.append(row(line));
    if (list.childElementCount === 0) {
      list.append(empty("Nothing here matching that."));
    }
    count();
    more.hidden = exhausted;
  }

  on(search.input, "input", () => {
    window.clearTimeout(debounce);
    debounce = window.setTimeout(() => void load(true), 250);
  });

  await load(true);

  const meta = pileMeta(pile);
  return screen(
    "pile",
    meta.title,
    backTo({ at: "money" }, "Books"),
    lede(meta.blurb),
    search.root,
    status,
    list,
    more,
  );
}

// ---------------------------------------------------------------------------
// One transaction, when the answer is not already there
// ---------------------------------------------------------------------------

// What the bank sent, and nothing that was worked out afterwards.
//
// "I want each transaction to list all identifying information from the credit union. Like
// maybe at the top as a section." So it is a section, it is at the top, and the
// rule for what goes in it is its title: a field appears here only if the bank
// put it there. The signed amount is not here, because the bank sent a direction
// and an amount and the sign is this system's arithmetic.
//
// The memo is printed whole rather than picked apart. For a card purchase it is
// four lines carrying the merchant with its street address, the kind of
// withdrawal, the authorisation reference and the last four of the card, but the
// bank wraps the merchant line at its own width, so the fourth line is sometimes
// the tail of the address and sometimes not. 0130 has the case that settles it.
// Printing it as sent means a person reads a wrapped address; parsing it means a
// client inventing a fact on some fraction of eight hundred rows.
function bankSection(line: MoneyLine): HTMLElement {
  const memo = (line.raw?.memo ?? "").trim();
  const fields: [string, string | null][] = [
    ["Posted", day(line.at)],
    ["Amount", `${money(line.amount)} ${line.direction.toLowerCase()}`],
    ["Description", line.description || null],
    ["Transaction type", line.txn_type],
    ["Group", line.txn_group],
    ["Check number", line.check_number],
    ["The bank's category", line.bank_category],
    ["Account", line.account],
    // Shown always rather than only when it is not dollars. A currency you
    // assumed is not a currency the bank told you.
    ["Currency", line.currency],
    // The FITID. It is what makes importing the same file twice land once, and
    // until now there was no way to see it from outside the database, which made
    // the one guarantee this module offers impossible to check.
    ["The bank's reference", line.external_id],
    ["Row in its import", String(line.row_no)],
  ];

  return el(
    "details",
    { class: "bank", open: true },
    el("summary", { class: "bank-head", text: "What the bank sent" }),
    rows(...fields.filter(([, v]) => v).map(([k, v]) => summaryRow(k, v as string))),
    memo
      ? el(
          "div",
          { class: "memo-block" },
          el("span", { class: "memo-label", text: "Memo, as sent" }),
          el("pre", { class: "memo", text: memo }),
        )
      : null,
  );
}

async function lineScreen(id: string): Promise<HTMLElement> {
  const line = await moneyLine(id);
  if (!line) {
    return screen(
      "line",
      "Not found",
      backTo({ at: "money" }, "Books"),
      banner("That transaction is not there.", "error"),
    );
  }
  if (vocabulary.length === 0) vocabulary = await terms("money_class");

  const note = field({ label: "Anything worth knowing", placeholder: "optional" });
  const said = el("div", { class: "banner-slot" });

  // Chips rather than a select. A native picker on a phone is a scroll wheel
  // over thirty-odd entries, and the thing it is worst at is exactly this: you
  // already know which one you want and you cannot see them all at once.
  const chips = el("div", { class: "classes" });
  for (const t of vocabulary) {
    const side = (t.attributes as { side?: string } | null)?.side;
    const chip = button(
      t.label,
      async () => {
        try {
          await attestLine({
            lineId: line.id,
            klass: t.value,
            note: note.value() || null,
            confirm: true,
          });
          said.replaceChildren(banner(`Filed as ${t.label}.`, "good"));
          // Back to the pile it came from, which is where the next one is.
          window.setTimeout(() => go({ at: "pile", id: line.queue }), 600);
        } catch (e) {
          said.replaceChildren(
            banner(e instanceof Error ? e.message : "That did not save.", "error"),
          );
        }
      },
      "secondary",
    );
    chip.classList.add("class-chip");
    if (side) chip.classList.add(`class-${side}`);
    if (t.value === (line.class ?? line.suggested))
      chip.classList.add("class-standing");
    chips.append(chip);
  }

  return screen(
    "line",
    money(line.signed_amount),
    backTo({ at: "pile", id: line.queue }, pileMeta(line.queue).title),
    bankSection(line),
    line.disputed
      ? banner(
          "More than one person has filed this differently. Adding another answer keeps all of them.",
          "note",
        )
      : null,
    line.class_label
      ? lede(
          `Currently ${line.class_label}${
            line.verified ? ", confirmed" : ", not confirmed by anybody"
          }.`,
        )
      : line.suggested_label
        ? lede(`Suggested: ${line.suggested_label}. Nothing is filed yet.`)
        : lede("Nothing filed and nothing suggested."),
    note.root,
    said,
    chips,
  );
}

// ---------------------------------------------------------------------------
// The memory, so it can be looked at rather than only trusted
// ---------------------------------------------------------------------------

async function merchantsScreen(): Promise<HTMLElement> {
  const memory: MerchantSuggestion[] = await merchantSuggestions();
  return screen(
    "merchants",
    "What a merchant has been called",
    backTo({ at: "money" }, "Books"),
    lede(
      memory.length === 0
        ? "Nothing yet. This fills up as transactions are confirmed, and it is what the one-tap suggestion reads."
        : `${memory.length} descriptions this winery has filed before. The suggestion on a new transaction comes from here.`,
    ),
    memory.length === 0
      ? null
      : rows(
          ...memory.map((m) =>
            el(
              "div",
              { class: "entry" },
              el("span", { class: "entry-what", text: m.description }),
              el("span", {
                class: "entry-tag",
                text: `${m.class_label}, ${m.times} time${m.times === 1 ? "" : "s"}`,
              }),
            ),
          ),
        ),
  );
}

// ---------------------------------------------------------------------------
// Who is allowed in
// ---------------------------------------------------------------------------
//
// A13, and this app is the sharpest case of it in the repo. Every books policy
// is `is_admin()`, which is stricter than anything else in the schema and meant
// to be. But an RLS refusal is an empty result set, so without this gate a
// cellar hand signing in and opening Books is told "Nothing imported yet" over
// four empty piles: a refusal wearing the exact face of a winery that has never
// spent any money. The first screen has to say which of the two it is.

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
    "money",
    "Books",
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

function notAdminScreen(): HTMLElement {
  return screen(
    "money",
    "Books",
    // Said outright rather than shown as an empty list. What is behind this is
    // every transaction the winery has made, and the honest thing to tell
    // somebody without the standing to read it is that it is there and they
    // cannot.
    banner("The books are administrators only. Your account is not one.", "note"),
    lede("This is not an empty ledger. It is a door, and it is shut for this account."),
  );
}

// ---------------------------------------------------------------------------

async function draw(): Promise<void> {
  if (!root) return;
  const place = here();
  try {
    const scope = await viewerScope();
    if (!scope.signed_in) {
      root.replaceChildren(await signInScreen());
      return;
    }
    if (!scope.may_admin) {
      root.replaceChildren(notAdminScreen());
      return;
    }
    const view =
      place.at === "money"
        ? await moneyScreen()
        : place.at === "pile"
          ? await pileScreen(place.id)
          : place.at === "line"
            ? await lineScreen(place.id)
            : await merchantsScreen();
    root.replaceChildren(view);
  } catch (e) {
    root.replaceChildren(
      screen(
        "money",
        "Books",
        banner(e instanceof Error ? e.message : "Something went wrong.", "error"),
      ),
    );
  }
  window.scrollTo(0, 0);
}

export function mountBooks(into: HTMLElement): void {
  root = into;
  window.addEventListener("hashchange", () => {
    void draw();
  });
  void draw();
}
