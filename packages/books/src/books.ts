// ---------------------------------------------------------------------------
// Type: source
// Purpose: "The books, as a periphery of its own: four piles of transactions and
//           a thumb working through them, one tap where the answer is already
//           known and a picker where it is not."
// Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql,
//              supabase/migrations/0125_the_categories_are_schedule_f.sql,
//              supabase/migrations/0126_only_a_person_confirms.sql,
//              packages/books/src/places.ts,
//              supabase/migrations/0130_the_bank_says_more_than_a_name.sql,
//              supabase/migrations/0144_a_paper_says_what_money_was.sql,
//              supabase/migrations/0145_the_books_keep_score.sql]
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
  type BooksProgress,
  banner,
  booksProgress,
  button,
  el,
  empty,
  field,
  lede,
  type MerchantSuggestion,
  type MoneyLine,
  type MoneyPaper,
  type MoneyTally,
  matchPaper,
  merchantSuggestions,
  moneyLine,
  moneyPaper,
  moneyPapers,
  moneyQueue,
  moneyTally,
  on,
  type PaperName,
  type PaperSuggestion,
  paperNames,
  paperPhotoUrl,
  paperSuggestions,
  recordPaper,
  rows,
  signIn,
  summaryRow,
  type Term,
  terms,
  uploadPaperPhoto,
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

// The score, drawn from the kernel's count. Used on the front and in the deck.
function scoreCard(p: BooksProgress, extra?: HTMLElement | null): HTMLElement {
  const done = p.total === 0 ? 0 : Math.round((p.settled / p.total) * 100);
  return el(
    "section",
    { class: "score" },
    el(
      "div",
      { class: "score-row" },
      stat(String(p.filed_today), "today"),
      stat(String(p.filed_week), "this week"),
      stat(String(p.streak_days), "day streak", p.streak_days >= 3 ? "score-hot" : ""),
    ),
    el(
      "div",
      {
        class: "bar",
        role: "progressbar",
        "aria-valuemin": 0,
        "aria-valuemax": p.total,
        "aria-valuenow": p.settled,
        "aria-label": "Transactions settled",
      },
      el("span", { class: "bar-fill", style: `width:${done}%` }),
    ),
    el("p", {
      class: "score-caption",
      text:
        p.total === 0
          ? "Nothing imported yet."
          : p.left_to_file === 0
            ? `All ${p.total} settled. Nothing left to file.`
            : `${p.settled} of ${p.total} settled, ${p.left_to_file} left to file.`,
    }),
    extra ?? null,
  );
}

function stat(value: string, label: string, extraClass = ""): HTMLElement {
  return el(
    "div",
    { class: `score-stat ${extraClass}`.trim() },
    el("span", { class: "score-num", text: value }),
    el("span", { class: "score-label", text: label }),
  );
}

async function moneyScreen(): Promise<HTMLElement> {
  const [tally, papers, progress] = await Promise.all([
    moneyTally(),
    moneyPapers(),
    booksProgress(),
  ]);
  const overdue = papers.filter((p) => p.overdue).length;
  const owed = papers.filter((p) => p.owed).length;
  const loose = papers.filter((p) => !p.matched).length;
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

  // The two things somebody opens this app to do, as the two biggest targets on
  // the screen: work through transactions, or deal with the paper in their hand.
  const deckButton = button(
    progress.left_to_file === 0 ? "Nothing to file" : "Clear the deck",
    () => go({ at: "deck" }),
  );
  deckButton.classList.add("hero-action");
  deckButton.disabled = progress.left_to_file === 0;

  const camera = el(
    "button",
    { class: "tile-camera tile-compact", type: "button" },
    cameraGlyph(),
    el("span", { class: "tile-title", text: "Photograph a paper" }),
    el("span", { class: "tile-note", text: "A receipt, a check, an invoice" }),
  );
  on(camera, "click", () => go({ at: "paper", id: "new" }));

  const paperNote =
    papers.length === 0
      ? null
      : el(
          "button",
          {
            class: `paper-summary${overdue ? " paper-summary-bad" : ""}`,
            type: "button",
          },
          el("span", { class: "paper-summary-count", text: String(loose) }),
          el(
            "span",
            { class: "pile-body" },
            el("span", {
              class: "pile-title",
              text: loose === 1 ? "paper to match" : "papers to match",
            }),
            el("span", {
              class: "pile-blurb",
              text: `${[
                owed ? `${owed} invoice${owed === 1 ? "" : "s"} owed` : null,
                overdue ? `${overdue} overdue` : null,
                `${papers.length} in all`,
              ]
                .filter(Boolean)
                .join(", ")}.`,
            }),
          ),
        );
  if (paperNote) on(paperNote, "click", () => go({ at: "papers" }));

  return screen(
    "money",
    "Books",
    scoreCard(progress, deckButton),
    el("h2", { class: "section-head", text: "Papers" }),
    camera,
    paperNote,
    el("h2", { class: "section-head", text: "Or work a pile" }),
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

// A camera drawn in SVG rather than an emoji, because an emoji is a different
// picture on every phone and this one should look like it belongs here.
function cameraGlyph(): SVGElement {
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", "0 0 48 40");
  svg.setAttribute("class", "tile-glyph");
  svg.setAttribute("aria-hidden", "true");
  const body = document.createElementNS(ns, "path");
  body.setAttribute(
    "d",
    "M6 11h9l3-5h12l3 5h9a3 3 0 0 1 3 3v19a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V14a3 3 0 0 1 3-3z",
  );
  const lens = document.createElementNS(ns, "circle");
  lens.setAttribute("cx", "24");
  lens.setAttribute("cy", "23");
  lens.setAttribute("r", "8");
  for (const shape of [body, lens]) {
    shape.setAttribute("fill", "none");
    shape.setAttribute("stroke", "currentColor");
    shape.setAttribute("stroke-width", "2.5");
    shape.setAttribute("stroke-linejoin", "round");
    svg.append(shape);
  }
  return svg;
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
// Clear the deck: the same work, as a game
// ---------------------------------------------------------------------------
//
// "Maybe even gamify one." The piles are the right tool for finding a
// transaction and the wrong one for eight hundred of them: a list says how much
// is left every time you look at it. The deck shows one card. Right is yes,
// left is later, and the only number that moves is the one going up.
//
// What makes it a game is small and all of it is honest. The score is the
// kernel's count (`books_progress`), so the phone and the tablet agree about a
// streak. The goal is this device's choice, because how much of an evening to
// give the books is a person's business and not the ledger's. Nothing here
// files anything the pile screen would not: every card ends in `attestLine`
// with `confirm: true`, pressed by a person, exactly as in the list.

const GOAL_KEY = "vsv.books.goal";
const GOALS = [10, 25, 50];

function dailyGoal(): number {
  try {
    const v = Number(localStorage.getItem(GOAL_KEY));
    return GOALS.includes(v) ? v : 25;
  } catch {
    return 25;
  }
}

function setDailyGoal(n: number): void {
  try {
    localStorage.setItem(GOAL_KEY, String(n));
  } catch {
    // A browser that will not remember simply asks again. Not worth a branch.
  }
}

function stillMotion(): boolean {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
}

// A short message at the bottom of the screen that leaves by itself.
function toast(text: string): void {
  const t = el("div", { class: "toast", role: "status", text });
  document.body.append(t);
  window.setTimeout(() => t.classList.add("toast-out"), 2200);
  window.setTimeout(() => t.remove(), 2700);
}

function confetti(): void {
  if (stillMotion()) return;
  const layer = el("div", { class: "confetti", "aria-hidden": "true" });
  for (let i = 0; i < 28; i++) {
    layer.append(
      el("span", {
        class: `confetti-bit confetti-${i % 3}`,
        style: `left:${Math.round(Math.random() * 100)}%;animation-delay:${Math.round(
          Math.random() * 400,
        )}ms;transform:rotate(${Math.round(Math.random() * 360)}deg)`,
      }),
    );
  }
  document.body.append(layer);
  window.setTimeout(() => layer.remove(), 2600);
}

async function deckScreen(): Promise<HTMLElement> {
  if (vocabulary.length === 0) vocabulary = await terms("money_class");
  let progress = await booksProgress();
  const startedAt = progress.filed_today;

  let session = 0;
  let sessionSum = 0;
  let combo = 0;
  let celebrated = progress.filed_today >= dailyGoal();
  let last: MoneyLine | null = null;
  let deck: MoneyLine[] = [];
  // Filed or skipped this sitting, so a refill does not deal them again.
  const seen = new Set<string>();
  const skipped: MoneyLine[] = [];

  const hud = el("div", { class: "deck-hud" });
  const table = el("div", { class: "deck-table" });
  const said = el("div", { class: "banner-slot" });
  const view = screen(
    "deck",
    "Clear the deck",
    backTo({ at: "money" }, "Books"),
    hud,
    said,
    table,
  );

  // Cards with an answer ready come first. They are one tap each, and an
  // evening that starts with twenty quick wins is an evening that continues.
  async function refill(): Promise<void> {
    const [guessed, open] = await Promise.all([
      moneyQueue({ queue: "unconfirmed", limit: 40, offset: 0 }),
      moneyQueue({ queue: "unexplained", limit: 60, offset: 0 }),
    ]);
    const fresh = [...guessed, ...open].filter((l) => !seen.has(l.id));
    deck = [
      ...fresh.filter((l) => l.class ?? l.suggested),
      ...fresh.filter((l) => !(l.class ?? l.suggested)),
    ];
  }

  function drawHud(): void {
    const goal = dailyGoal();
    // The kernel's count, or what this sitting has added to where it started if
    // the kernel's answer has not caught up yet. Never lower than either.
    const today = Math.max(progress.filed_today, startedAt + session);
    const pct = Math.min(100, Math.round((today / goal) * 100));
    hud.replaceChildren(
      el(
        "div",
        { class: "score-row" },
        stat(String(today), "today"),
        stat(
          `${Math.min(today, goal)}/${goal}`,
          "goal",
          today >= goal ? "score-hot" : "",
        ),
        stat(
          String(progress.streak_days),
          "day streak",
          progress.streak_days >= 3 ? "score-hot" : "",
        ),
      ),
      el(
        "div",
        {
          class: `bar${today >= goal ? " bar-done" : ""}`,
          role: "progressbar",
          "aria-valuemin": 0,
          "aria-valuemax": goal,
          "aria-valuenow": Math.min(today, goal),
          "aria-label": "Today's goal",
        },
        el("span", { class: "bar-fill", style: `width:${pct}%` }),
      ),
      el(
        "div",
        { class: "deck-meta" },
        combo >= 3 ? el("span", { class: "combo", text: `${combo} in a row` }) : null,
        el("span", {
          class: "deck-left",
          text: `${progress.left_to_file} left in the books`,
        }),
      ),
      last
        ? button(
            "That last one was wrong",
            () => {
              if (last) go({ at: "line", id: last.id });
            },
            "quiet",
          )
        : "",
    );
  }

  function refreshScore(): void {
    void booksProgress()
      .then((p) => {
        progress = p;
        drawHud();
      })
      .catch(() => {
        // The score is a nicety. A failed refresh leaves the last one showing.
      });
  }

  function fly(card: HTMLElement, way: "left" | "right"): Promise<void> {
    if (stillMotion()) return Promise.resolve();
    // Inline, like the drag it continues from, so nothing has to outrank it.
    card.style.transform =
      way === "right"
        ? "translateX(120%) rotate(12deg)"
        : "translateX(-120%) rotate(-12deg)";
    card.style.opacity = "0";
    return new Promise((done) => window.setTimeout(done, 220));
  }

  async function file(
    line: MoneyLine,
    card: HTMLElement,
    klass: string,
    label: string,
  ) {
    try {
      await attestLine({ lineId: line.id, klass, confirm: true });
    } catch (e) {
      said.replaceChildren(
        banner(e instanceof Error ? e.message : "That did not save.", "error"),
      );
      card.style.transform = "";
      return;
    }
    said.replaceChildren();
    seen.add(line.id);
    last = line;
    session += 1;
    combo += 1;
    sessionSum += Math.abs(line.signed_amount);
    await fly(card, "right");

    const today = Math.max(progress.filed_today, startedAt + session);
    if (!celebrated && today >= dailyGoal()) {
      celebrated = true;
      confetti();
      toast(`Goal met: ${today} today. Keep going or call it a night.`);
    } else if (session % 10 === 0) {
      toast(
        `${session} this sitting, ${money(sessionSum)} filed. ${label} was the last.`,
      );
    }
    refreshScore();
    await deal();
  }

  async function skip(line: MoneyLine, card: HTMLElement): Promise<void> {
    seen.add(line.id);
    skipped.push(line);
    combo = 0;
    await fly(card, "left");
    await deal();
  }

  function cardFor(line: MoneyLine): HTMLElement {
    const guessValue = line.class ?? line.suggested;
    const guessLabel = line.class_label ?? line.suggested_label;
    const memo = (line.raw?.memo ?? "").trim();

    const chips = el("div", { class: "classes deck-chips", hidden: "hidden" });
    const stampYes = el("span", { class: "stamp stamp-yes", text: "Yes" });
    const stampNo = el("span", { class: "stamp stamp-later", text: "Later" });

    const card = el(
      "article",
      {
        class: `deck-card ${line.signed_amount < 0 ? "deck-out" : "deck-in"}`,
        "aria-label": `${money(line.signed_amount)}, ${line.description}`,
      },
      stampYes,
      stampNo,
      el("span", { class: "deck-when", text: day(line.at) }),
      el("span", { class: "deck-amount", text: money(line.signed_amount) }),
      el("span", {
        class: "deck-what",
        text: line.description || line.txn_type || "No description",
      }),
      guessLabel
        ? el("span", {
            class: "deck-why",
            text: line.class
              ? "Guessed on import. Nobody has confirmed it."
              : `Filed as ${guessLabel} ${line.suggested_on ?? 0} time${
                  line.suggested_on === 1 ? "" : "s"
                } before.`,
          })
        : el("span", { class: "deck-why", text: "Nothing to go on. You say." }),
      memo
        ? el(
            "details",
            { class: "deck-memo" },
            el("summary", { text: "What the bank sent" }),
            el("pre", { class: "memo", text: memo }),
          )
        : null,
      chips,
    );

    // The rest of the categories, on the card, so "something else" is one more
    // tap and not a trip to another screen and back.
    function openChips(): void {
      if (chips.childElementCount === 0) {
        for (const t of vocabulary) {
          const side = (t.attributes as { side?: string } | null)?.side;
          const chip = button(
            t.label,
            () => void file(line, card, t.value, t.label),
            "secondary",
          );
          chip.classList.add("class-chip");
          if (side) chip.classList.add(`class-${side}`);
          chips.append(chip);
        }
      }
      chips.hidden = false;
      chips.scrollIntoView({
        behavior: stillMotion() ? "auto" : "smooth",
        block: "nearest",
      });
    }

    const yes =
      guessValue && guessLabel
        ? button(
            `Yes, ${guessLabel}`,
            () => void file(line, card, guessValue, guessLabel),
          )
        : null;
    const other = button(
      guessValue ? "Something else" : "Say what it was",
      () => openChips(),
      guessValue ? "secondary" : "primary",
    );
    const later = button("Later", () => void skip(line, card), "quiet");
    const actions = el("div", { class: "deck-actions" }, later, other, yes);
    card.append(actions);

    // Swiping. Right is yes where there is an answer and opens the categories
    // where there is not; left is later. Buttons and the memo are left alone so
    // tapping them is never read as the start of a swipe.
    let startX = 0;
    let dx = 0;
    let dragging = false;
    const THRESHOLD = 110;
    card.addEventListener("pointerdown", (e) => {
      const target = e.target as HTMLElement;
      if (target.closest("button, summary, pre, .deck-chips")) return;
      dragging = true;
      startX = e.clientX;
      dx = 0;
      card.setPointerCapture(e.pointerId);
      card.classList.add("dragging");
    });
    card.addEventListener("pointermove", (e) => {
      if (!dragging) return;
      dx = e.clientX - startX;
      card.style.transform = `translateX(${dx}px) rotate(${dx / 24}deg)`;
      stampYes.style.opacity = String(Math.max(0, Math.min(1, dx / THRESHOLD)));
      stampNo.style.opacity = String(Math.max(0, Math.min(1, -dx / THRESHOLD)));
    });
    const release = () => {
      if (!dragging) return;
      dragging = false;
      card.classList.remove("dragging");
      stampYes.style.opacity = "0";
      stampNo.style.opacity = "0";
      if (dx > THRESHOLD && guessValue && guessLabel) {
        void file(line, card, guessValue, guessLabel);
      } else if (dx > THRESHOLD) {
        card.style.transform = "";
        openChips();
      } else if (dx < -THRESHOLD) {
        void skip(line, card);
      } else {
        card.style.transform = "";
      }
    };
    card.addEventListener("pointerup", release);
    card.addEventListener("pointercancel", release);

    // Keys, for the desktop. Right, left, down.
    (card as HTMLElement & { keys?: (k: string) => void }).keys = (k: string) => {
      if (k === "ArrowRight" && guessValue && guessLabel)
        void file(line, card, guessValue, guessLabel);
      else if (k === "ArrowRight" || k === "ArrowDown") openChips();
      else if (k === "ArrowLeft") void skip(line, card);
    };
    return card;
  }

  async function deal(): Promise<void> {
    if (deck.length < 3) {
      try {
        await refill();
      } catch (e) {
        said.replaceChildren(
          banner(
            e instanceof Error ? e.message : "Could not load the next cards.",
            "error",
          ),
        );
      }
    }
    drawHud();
    const next = deck.shift();
    if (!next) {
      table.replaceChildren(
        el(
          "div",
          { class: "deck-empty" },
          el("p", { class: "deck-empty-title", text: "Deck cleared." }),
          lede(
            session === 0
              ? "Nothing waiting to be filed."
              : `${session} filed this sitting, ${money(sessionSum)} of it.`,
          ),
          skipped.length > 0
            ? button(`Go back through the ${skipped.length} you left for later`, () => {
                for (const s of skipped) seen.delete(s.id);
                deck = skipped.splice(0);
                void deal();
              })
            : null,
          button("Back to the books", () => go({ at: "money" }), "secondary"),
        ),
      );
      return;
    }
    // Two ghost cards behind the live one, so it reads as a stack with more
    // under it rather than as a form with one row.
    table.replaceChildren(
      el("div", { class: "deck-ghost deck-ghost-2" }),
      el("div", { class: "deck-ghost deck-ghost-1" }),
      cardFor(next),
    );
  }

  const onKey = (e: KeyboardEvent) => {
    if (!view.isConnected) {
      document.removeEventListener("keydown", onKey);
      return;
    }
    const tag = (e.target as HTMLElement | null)?.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
    const card = table.querySelector<HTMLElement & { keys?: (k: string) => void }>(
      ".deck-card",
    );
    if (card?.keys && ["ArrowRight", "ArrowLeft", "ArrowDown"].includes(e.key)) {
      e.preventDefault();
      card.keys(e.key);
    }
  };
  document.addEventListener("keydown", onKey);

  const goalPick = el(
    "div",
    { class: "deck-goal" },
    el("span", { class: "field-label", text: "Today's goal" }),
    ...GOALS.map((g) => {
      const b = button(
        String(g),
        () => {
          setDailyGoal(g);
          celebrated = Math.max(progress.filed_today, startedAt + session) >= g;
          for (const other of goalPick.querySelectorAll("button")) {
            other.classList.toggle("btn-primary", other === b);
            other.classList.toggle("btn-quiet", other !== b);
          }
          drawHud();
        },
        g === dailyGoal() ? "primary" : "quiet",
      );
      return b;
    }),
  );
  view.append(goalPick);

  await deal();
  return view;
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
  // Papers somebody matched to this transaction. 0144. The receipt is the
  // answer to "what was this" more often than the description is.
  const papers = await moneyPapers(line.id);

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
    papers.length > 0
      ? el(
          "div",
          {},
          el("h2", { class: "section-head", text: "Papers" }),
          el("div", { class: "ledger" }, ...papers.map(paperRow)),
        )
      : null,
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
// Papers: a receipt, check or invoice, photographed and read
// ---------------------------------------------------------------------------
//
// "I also want in books to be able to take a picture (receipt, check, invoice,
// etc) and then manually fill in information about it." The photograph first,
// because the paper is in your hand now and in a pocket in ten minutes; what it
// says second, typed while it is still in front of you; which bank transaction
// it is last, because that transaction may not exist yet. A receipt from this
// morning posts in a day or two, a check when somebody cashes it.
//
// Everything the kernel works out stays in the kernel: which transactions could
// be this paper (`paper_match_suggestion`), whether an invoice is still owed or
// overdue (`money_paper_now`). This screen shows those and asks a person.

let paperKinds: Term[] = [];

function signed(p: MoneyPaper): string {
  if (p.amount === null) return "no amount";
  return money(p.direction === "out" ? -p.amount : p.amount);
}

// What state a paper is in, in the words somebody would use.
function paperState(p: MoneyPaper): { text: string; tone: string } {
  if (p.matched) return { text: p.due_on ? "paid" : "matched", tone: "good" };
  if (p.overdue) return { text: `overdue since ${day(p.due_on ?? "")}`, tone: "bad" };
  if (p.owed) return { text: `due ${day(p.due_on ?? "")}`, tone: "note" };
  return { text: "not matched yet", tone: "quiet" };
}

// A thumbnail per row, fetched as the rows are drawn. Signed URLs last ten
// minutes, which is longer than anybody looks at a list.
function thumb(p: MoneyPaper): HTMLElement {
  const box = el("span", { class: "thumb", "aria-hidden": "true" });
  if (p.photo_path) {
    void paperPhotoUrl(p.photo_path).then((url) => {
      if (url) box.append(el("img", { src: url, alt: "", loading: "lazy" }));
    });
  } else {
    box.classList.add("thumb-none");
  }
  return box;
}

function paperRow(p: MoneyPaper): HTMLElement {
  const state = paperState(p);
  const open = el(
    "button",
    { class: "paper-row", type: "button" },
    thumb(p),
    el(
      "span",
      { class: "paper-row-body" },
      el(
        "span",
        { class: "entry-head" },
        el("span", {
          class: "entry-what",
          text: p.who ?? `${p.kind_label}, nobody named`,
        }),
        el("span", { class: "entry-sum", text: signed(p) }),
      ),
      el(
        "span",
        { class: "paper-row-foot" },
        el("span", {
          class: "entry-when",
          text: `${p.kind_label}${p.on_date ? `, ${day(p.on_date)}` : ""}`,
        }),
        el("span", { class: `pill pill-${state.tone}`, text: state.text }),
      ),
    ),
  );
  on(open, "click", () => go({ at: "paper", id: p.id }));
  return open;
}

// Which filter the papers list is showing, per device, because somebody who
// comes here to chase invoices comes here to chase invoices every time.
const PAPER_FILTER_KEY = "vsv.books.paperFilter";
type PaperFilter = "loose" | "owed" | "matched" | "all";

function paperFilter(): PaperFilter {
  try {
    const v = localStorage.getItem(PAPER_FILTER_KEY);
    return v === "owed" || v === "matched" || v === "all" ? v : "loose";
  } catch {
    return "loose";
  }
}

async function papersScreen(): Promise<HTMLElement> {
  const all = await moneyPapers();
  const sets: Record<PaperFilter, MoneyPaper[]> = {
    loose: all.filter((p) => !p.matched && !p.owed),
    // Overdue first inside owed, because it is the only list here that costs
    // money by waiting.
    owed: [...all.filter((p) => p.overdue), ...all.filter((p) => p.owed && !p.overdue)],
    matched: all.filter((p) => p.matched),
    all,
  };
  const labels: Record<PaperFilter, string> = {
    loose: "To match",
    owed: "Invoices owed",
    matched: "Matched",
    all: "All",
  };

  const list = el("div", { class: "ledger" });
  const chips = el("div", { class: "filter-chips", role: "tablist" });

  function draw(f: PaperFilter): void {
    try {
      localStorage.setItem(PAPER_FILTER_KEY, f);
    } catch {
      // Remembering the tab is a convenience.
    }
    chips.replaceChildren(
      ...(Object.keys(labels) as PaperFilter[]).map((k) => {
        const b = button(
          `${labels[k]} ${sets[k].length}`,
          () => draw(k),
          k === f ? "primary" : "quiet",
        );
        b.setAttribute("role", "tab");
        b.setAttribute("aria-selected", String(k === f));
        if (k === "owed" && sets.owed.some((p) => p.overdue))
          b.classList.add("chip-alarm");
        return b;
      }),
    );
    const shown = sets[f];
    list.replaceChildren(
      ...(shown.length > 0
        ? shown.map(paperRow)
        : [
            empty(
              f === "loose"
                ? "Every paper is matched to its transaction."
                : f === "owed"
                  ? "No invoices owed."
                  : f === "matched"
                    ? "Nothing matched yet."
                    : "No papers yet.",
            ),
          ]),
    );
  }
  draw(all.length === 0 ? "all" : paperFilter());

  const camera = el(
    "button",
    { class: "tile-camera tile-compact", type: "button" },
    cameraGlyph(),
    el("span", { class: "tile-title", text: "Photograph a paper" }),
  );
  on(camera, "click", () => go({ at: "paper", id: "new" }));

  return screen(
    "papers",
    "Papers",
    backTo({ at: "money" }, "Books"),
    camera,
    chips,
    list,
  );
}

// Picks one of a few answers with a row of buttons. The selected one is
// primary. What the kernel accepts is decided by the kernel; this only lays out
// the choices it was given.
function segmented<T extends string>(
  options: readonly (readonly [T, string])[],
  initial: T,
  onPick: (v: T) => void,
): { root: HTMLElement; value: () => T; set: (v: T) => void } {
  let current = initial;
  const root = el("div", { class: "segmented", role: "radiogroup" });
  function draw(): void {
    root.replaceChildren(
      ...options.map(([v, label]) => {
        const b = button(
          label,
          () => {
            current = v;
            draw();
            onPick(v);
          },
          v === current ? "primary" : "secondary",
        );
        b.setAttribute("role", "radio");
        b.setAttribute("aria-checked", String(v === current));
        return b;
      }),
    );
  }
  draw();
  return {
    root,
    value: () => current,
    set: (v: T) => {
      current = v;
      draw();
    },
  };
}

function localDate(offsetDays = 0): string {
  const d = new Date();
  d.setDate(d.getDate() - offsetDays);
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 10);
}

// The form for what a paper says. The order is the order a paper is read in:
// what it is, how much, when, who, and what it was for. The total is the
// biggest field on the screen because it is the one matching runs on.
function paperForm(
  before: MoneyPaper | null,
  names: PaperName[],
): {
  root: HTMLElement;
  focusTotal: () => void;
  read: () => Omit<Parameters<typeof recordPaper>[0], "id" | "photoPath"> | string;
} {
  const kinds = paperKinds.map((t) => [t.value, t.label] as const);
  const kind = segmented(kinds, before?.kind ?? kinds[0]?.[0] ?? "receipt", () =>
    sync(),
  );
  const way = segmented(
    [
      ["out", "Money out"],
      ["in", "Money in"],
    ] as const,
    before?.direction ?? "out",
    () => undefined,
  );

  // The total, big, with the dollar sign outside the input so the keypad is the
  // only thing a thumb has to deal with.
  const amount = el("input", {
    class: "amount-input",
    type: "number",
    inputmode: "decimal",
    step: "0.01",
    min: "0",
    placeholder: "0.00",
    "aria-label": "Total",
    value:
      before?.amount === null || before?.amount === undefined
        ? ""
        : String(before.amount),
  });
  const amountRow = el(
    "label",
    { class: "amount-field" },
    el("span", { class: "field-label", text: "Total" }),
    el(
      "span",
      { class: "amount-box" },
      el("span", { class: "amount-sign", text: "$" }),
      amount,
    ),
  );

  // When. Today and yesterday are one tap each, which covers most papers; a
  // date picker for the rest.
  const dateInput = el("input", { class: "input", type: "date" });
  const start = before?.on_date ?? localDate(0);
  const startWhich =
    start === localDate(0) ? "today" : start === localDate(1) ? "yesterday" : "earlier";
  dateInput.value = start;
  const dateBox = el("div", {}, dateInput);
  dateBox.hidden = startWhich !== "earlier";
  const when = segmented(
    [
      ["today", "Today"],
      ["yesterday", "Yesterday"],
      ["earlier", "Earlier"],
    ] as const,
    startWhich,
    (v) => {
      if (v === "today") dateInput.value = localDate(0);
      if (v === "yesterday") dateInput.value = localDate(1);
      dateBox.hidden = v !== "earlier";
      if (v === "earlier") dateInput.focus();
    },
  );

  // Who, with the names the books have seen before. Picking one that has been
  // filed before offers what it was filed as, which is the kernel's memory
  // (`paper_who_memory`) and never a guess made here.
  const listId = `paper-names-${Math.random().toString(36).slice(2)}`;
  const who = el("input", {
    class: "input",
    list: listId,
    autocomplete: "off",
    placeholder: "the store, the vendor, the payee",
    value: before?.who ?? "",
  });
  const datalist = el(
    "datalist",
    { id: listId },
    ...names.map((n) => el("option", { value: n.who })),
  );
  const lastTime = el("span", { class: "field-hint" });

  // What it was for, as chips. The one it will be filed as is marked, and
  // "Not decided" is an answer, the same one the books already use.
  let klass: string | null = before?.class ?? null;
  const classChips = el("div", { class: "classes paper-classes" });
  function drawClasses(): void {
    classChips.replaceChildren(
      ...[{ value: "", label: "Not decided" } as const, ...vocabulary].map((t) => {
        const chosen = (klass ?? "") === t.value;
        const b = button(
          t.label,
          () => {
            klass = t.value || null;
            drawClasses();
          },
          chosen ? "primary" : "secondary",
        );
        b.classList.add("class-chip");
        return b;
      }),
    );
  }
  drawClasses();

  function remembered(): void {
    const key = who.value.trim().toLowerCase();
    const hit = names.find((n) => n.key === key);
    if (!hit) {
      lastTime.textContent = "";
      return;
    }
    lastTime.textContent = hit.class_label
      ? `Last time: ${hit.class_label}${hit.times > 1 ? `, ${hit.times} papers` : ""}.`
      : `Seen ${hit.times} time${hit.times === 1 ? "" : "s"} before.`;
    // Offered, and only where nothing has been chosen yet. Somebody who has
    // already picked a category has answered, and memory does not overrule them.
    if (!klass && hit.class) {
      klass = hit.class;
      drawClasses();
    }
    if (!before) way.set(hit.direction);
  }
  on(who, "change", remembered);
  on(who, "input", () => {
    if (names.some((n) => n.key === who.value.trim().toLowerCase())) remembered();
  });

  const checkNumber = field({
    label: "Check number",
    value: before?.check_number ?? "",
  });
  const dueOn = field({ label: "Due", type: "date", value: before?.due_on ?? "" });
  const note = field({ label: "Anything worth knowing", value: before?.note ?? "" });
  const checkBox = el("div", {}, checkNumber.root);
  const dueBox = el("div", {}, dueOn.root);
  function sync(): void {
    const term = paperKinds.find((t) => t.value === kind.value());
    checkBox.hidden = kind.value() !== "check";
    dueBox.hidden = !(term?.attributes as { has_due?: boolean } | null)?.has_due;
  }
  sync();

  const root = el(
    "div",
    { class: "paper-form" },
    el("span", { class: "field-label", text: "What it is" }),
    kind.root,
    amountRow,
    way.root,
    el("span", { class: "field-label", text: "Date on it" }),
    when.root,
    dateBox,
    el(
      "label",
      { class: "field" },
      el("span", { class: "field-label", text: "Who" }),
      who,
      datalist,
      lastTime,
    ),
    checkBox,
    dueBox,
    el("span", { class: "field-label", text: "What it was for" }),
    classChips,
    note.root,
  );

  return {
    root,
    focusTotal: () => amount.focus(),
    read: () => {
      const raw = amount.value.trim();
      const n = raw ? Number(raw) : null;
      if (n !== null && !(n > 0)) return "The total is a number above nothing.";
      return {
        kind: kind.value(),
        direction: way.value(),
        onDate: dateInput.value || null,
        amount: n,
        who: who.value.trim() || null,
        klass,
        checkNumber: kind.value() === "check" ? checkNumber.value() || null : null,
        dueOn: dueBox.hidden ? null : dueOn.value() || null,
        note: note.value() || null,
      };
    },
  };
}

// The camera, as the biggest thing on the screen until it has been used, and
// then as the photograph with a way to take it again.
function cameraInput(onChosen?: () => void): {
  root: HTMLElement;
  file: () => File | null;
} {
  const input = el("input", {
    type: "file",
    accept: "image/*",
    capture: "environment",
    class: "visually-hidden",
  });
  const tile = el(
    "label",
    { class: "tile-camera" },
    input,
    cameraGlyph(),
    el("span", { class: "tile-title", text: "Take the photo" }),
    el("span", { class: "tile-note", text: "Flat, in good light, the total readable" }),
  );
  const preview = el("div", { class: "paper-photo" });
  const again = el("label", { class: "btn btn-quiet retake" }, "Take it again");
  on(input, "change", () => {
    const f = input.files?.[0];
    if (!f) return;
    preview.replaceChildren(
      el("img", { src: URL.createObjectURL(f), alt: "The paper" }),
    );
    // The input moves into the retake control, so taking it again reuses it
    // and `file()` keeps reading the same element.
    again.prepend(input);
    tile.hidden = true;
    root.append(again);
    onChosen?.();
  });
  const root = el("div", { class: "camera" }, tile, preview);
  return { root, file: () => input.files?.[0] ?? null };
}

async function newPaperScreen(): Promise<HTMLElement> {
  const names = await paperNames();
  const form = paperForm(null, names);
  const photo = cameraInput(() => form.focusTotal());
  const said = el("div", { class: "banner-slot" });
  // Made once, here. A save that times out and is tapped again writes the same
  // paper rather than a second one, and the photograph is filed under it first.
  const id = crypto.randomUUID();

  const save = button("Save the paper", async () => {
    const r = form.read();
    if (typeof r === "string") {
      said.replaceChildren(banner(r, "error"));
      return;
    }
    // The photograph goes up first. If it cannot, what was typed is kept
    // anyway and the paper says it has no photograph, because losing the
    // typing to a bad signal is the worse of the two.
    let path: string | null = null;
    let failed: string | null = null;
    const f = photo.file();
    if (f) {
      try {
        path = await uploadPaperPhoto(id, f);
      } catch (e) {
        failed = e instanceof Error ? e.message : String(e);
      }
    }
    try {
      const out = await recordPaper({ id, photoPath: path, ...r });
      toast(
        failed
          ? "Saved. The photograph did not upload; add it from the paper."
          : out.suggestions > 0
            ? `Saved. ${out.suggestions} transaction${out.suggestions === 1 ? "" : "s"} could be this.`
            : "Saved.",
      );
      go({ at: "paper", id });
    } catch (e) {
      said.replaceChildren(
        banner(e instanceof Error ? e.message : "That did not save.", "error"),
      );
    }
  });

  return screen(
    "paper",
    "Photograph a paper",
    backTo({ at: "papers" }, "Papers"),
    photo.root,
    form.root,
    said,
    // Stays at the bottom of the screen, so the save is where the thumb is
    // however far down the categories somebody scrolled.
    el("div", { class: "save-bar" }, save),
  );
}

async function paperScreen(id: string): Promise<HTMLElement> {
  const p = await moneyPaper(id);
  if (!p) {
    return screen(
      "paper",
      "Not found",
      backTo({ at: "papers" }, "Papers"),
      banner("That paper is not there.", "error"),
    );
  }
  const [suggested, url, names] = await Promise.all([
    p.matched ? Promise.resolve([] as PaperSuggestion[]) : paperSuggestions(p.id),
    p.photo_path ? paperPhotoUrl(p.photo_path) : Promise.resolve(null),
    paperNames(),
  ]);
  const said = el("div", { class: "banner-slot" });
  const state = paperState(p);

  // The transactions it is matched to, each with a way to take it back.
  const matchedLines = await Promise.all(p.line_ids.map((l) => moneyLine(l)));
  const matchedBlock = matchedLines
    .filter((l): l is MoneyLine => l !== null)
    .map((l) =>
      el(
        "div",
        { class: "entry match-done" },
        el(
          "span",
          { class: "entry-head" },
          el("span", { class: "entry-when", text: day(l.at) }),
          el("span", { class: "entry-sum", text: money(l.signed_amount) }),
        ),
        el("span", { class: "entry-what", text: l.description }),
        el(
          "div",
          { class: "match-actions" },
          button(
            "Open the transaction",
            () => go({ at: "line", id: l.id }),
            "secondary",
          ),
          button(
            "Not this one",
            async () => {
              await matchPaper(p.id, l.id, false);
              toast("Taken back.");
              await draw();
            },
            "quiet",
          ),
        ),
      ),
    );

  function why(s: PaperSuggestion): string {
    if (s.check_number_agrees) return `check ${s.check_number}, the same number`;
    if (s.days_after === 0) return "the same day";
    const n = Math.abs(s.days_after);
    return `${n} day${n === 1 ? "" : "s"} ${s.days_after > 0 ? "after" : "before"}`;
  }

  const paperId = p.id;
  const isInvoice = p.due_on !== null;
  async function take(s: PaperSuggestion): Promise<void> {
    try {
      await matchPaper(paperId, s.line_id, true);
      toast(isInvoice ? "Matched. That invoice is paid." : "Matched.");
      await draw();
    } catch (e) {
      said.replaceChildren(
        banner(e instanceof Error ? e.message : "That did not save.", "error"),
      );
    }
  }

  // The best one is shown as the answer, and the rest as alternatives. The
  // ranking only decides the order; every one of them is a person's tap away
  // and none is written without it.
  const [best, ...rest] = suggested;
  const suggestionBlock = best
    ? el(
        "div",
        {},
        el(
          "div",
          { class: "match-best" },
          el("span", { class: "match-best-label", text: "Looks like this one" }),
          el(
            "span",
            { class: "entry-head" },
            el("span", { class: "entry-when", text: day(best.at) }),
            el("span", {
              class: "entry-sum",
              text: money(best.direction === "Debit" ? -best.amount : best.amount),
            }),
          ),
          el("span", { class: "entry-what", text: best.description }),
          el("span", { class: "entry-why", text: why(best) }),
          button("This is it", () => take(best)),
        ),
        rest.length > 0
          ? el(
              "details",
              { class: "more" },
              el("summary", {
                text: `Or one of ${rest.length} other${rest.length === 1 ? "" : "s"}`,
              }),
              el(
                "div",
                { class: "ledger" },
                ...rest.map((s) =>
                  el(
                    "div",
                    { class: "entry" },
                    el(
                      "span",
                      { class: "entry-head" },
                      el("span", { class: "entry-when", text: day(s.at) }),
                      el("span", {
                        class: "entry-sum",
                        text: money(s.direction === "Debit" ? -s.amount : s.amount),
                      }),
                    ),
                    el("span", { class: "entry-what", text: s.description }),
                    el("span", { class: "entry-why", text: why(s) }),
                    button("This one", () => take(s), "secondary"),
                  ),
                ),
              ),
            )
          : null,
      )
    : empty(
        p.amount === null || p.on_date === null
          ? "It needs a total and a date before anything can be suggested."
          : "Nothing in the bank matches yet. A receipt usually posts in a day or two, a check when it is cashed. Come back after the next import.",
      );

  // Reading it again. Shut by default: most papers are read once.
  const again = paperForm(p, names);
  const latePhoto = p.photo_path ? null : cameraInput();
  const correct = el(
    "details",
    { class: "bank" },
    el("summary", {
      class: "bank-head",
      text: p.photo_path
        ? "Correct what it says"
        : "Add the photograph, or correct what it says",
    }),
    latePhoto?.root ?? null,
    again.root,
    button(
      "Save the correction",
      async () => {
        const r = again.read();
        if (typeof r === "string") {
          said.replaceChildren(banner(r, "error"));
          return;
        }
        try {
          const f = latePhoto?.file() ?? null;
          const path = f ? await uploadPaperPhoto(p.id, f) : null;
          await recordPaper({ id: p.id, photoPath: path, ...r });
          toast("Corrected. The earlier reading is kept.");
          await draw();
        } catch (e) {
          said.replaceChildren(
            banner(e instanceof Error ? e.message : "That did not save.", "error"),
          );
        }
      },
      "secondary",
    ),
  );

  const photo = url
    ? el(
        "a",
        { class: "paper-photo", href: url, target: "_blank", rel: "noopener" },
        el("img", { src: url, alt: "The paper. Tap for full size." }),
      )
    : el("div", { class: "paper-photo paper-photo-none", text: "No photograph yet" });

  return screen(
    "paper",
    p.who ?? p.kind_label,
    backTo({ at: "papers" }, "Papers"),
    el(
      "div",
      { class: "paper-head" },
      el("span", { class: "paper-amount", text: signed(p) }),
      el("span", { class: `pill pill-${state.tone}`, text: state.text }),
    ),
    photo,
    rows(
      summaryRow("What", p.kind_label),
      summaryRow("Date on it", p.on_date ? day(p.on_date) : "not said"),
      summaryRow("Which way", p.direction === "out" ? "Money out" : "Money in"),
      summaryRow("For", p.class_label ?? "not decided"),
      ...(p.check_number ? [summaryRow("Check number", p.check_number)] : []),
      ...(p.due_on ? [summaryRow("Due", day(p.due_on))] : []),
      ...(p.note ? [summaryRow("Note", p.note)] : []),
      ...(p.readings > 1
        ? [summaryRow("Read", `${p.readings} times, the latest counts`)]
        : []),
    ),
    said,
    el(
      "h2",
      { class: "section-head" },
      matchedBlock.length > 0 ? "The transaction" : "Which transaction is it?",
    ),
    matchedBlock.length > 0
      ? el("div", { class: "ledger" }, ...matchedBlock)
      : suggestionBlock,
    correct,
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
    if (place.at === "paper" || place.at === "papers") {
      if (vocabulary.length === 0) vocabulary = await terms("money_class");
      if (paperKinds.length === 0) paperKinds = await terms("paper_kind");
    }
    const view =
      place.at === "money"
        ? await moneyScreen()
        : place.at === "pile"
          ? await pileScreen(place.id)
          : place.at === "line"
            ? await lineScreen(place.id)
            : place.at === "deck"
              ? await deckScreen()
              : place.at === "papers"
                ? await papersScreen()
                : place.at === "paper"
                  ? place.id === "new"
                    ? await newPaperScreen()
                    : await paperScreen(place.id)
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
