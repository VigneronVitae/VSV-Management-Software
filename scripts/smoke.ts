// ---------------------------------------------------------------------------
// Type: tool
// Purpose: "Runs a harvest day through the apps' own client code, signed in as an ordinary cellar hand and as an administrator, against the practice stack, and says which steps worked."
// Depends on: [scripts/practice.sh, supabase/migrations/0147_a_pressing_knows_what_went_in.sql]
// Depended on by: [docs/status-ledger.md]
// ---------------------------------------------------------------------------
//
//   bun scripts/smoke.ts
//
// **Why this exists.** The books' one-tap "Yes" failed on every tap from 0126
// until 0145 and nothing noticed, because the assertion suite runs as the
// database owner: it sets a user id and never becomes the role a phone is.
// Row level security, grants, PostgREST's argument matching and the client's
// own mapping from a screen to an rpc are all things the suite cannot see.
// This sees them. It imports `packages/core/src/kernel.ts`, the same functions
// the apps call, points them at the practice stack, signs in over the real
// auth API, and walks a pick from bins to a racked, sampled, dosed lot, then
// the books, then checks that a cellar hand is refused what is not theirs.
//
// **It can only ever reach practice.** The URL comes from `supabase status`
// for the sandbox workdir and is refused unless it is the practice port.
// Everything it writes is named SMOKE and lands in a database whose purpose is
// being written to and thrown away.
//
// **The accounts are made here and kept out of git.** Two practice-only logins,
// a cellar hand and an administrator, created through the practice stack's own
// admin API with generated passwords written to `sandbox/smoke-accounts.local.json`,
// which .gitignore excludes. A practice reset keeps `auth.users` and drops
// `app_user`, so each run puts the `app_user` rows back.

import { spawnSync } from "node:child_process";
import { randomBytes, randomUUID } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const PRACTICE_PORT = "54421";
const ACCOUNTS = "sandbox/smoke-accounts.local.json";

type Account = {
  email: string;
  password: string;
  role: "cellar" | "admin";
  id?: string;
};

function status(): { url: string; anon: string; service: string } {
  const run = spawnSync("supabase", ["status", "-o", "env", "--workdir", "sandbox"], {
    encoding: "utf8",
    shell: true,
  });
  const env = Object.fromEntries(
    (run.stdout ?? "")
      .split(/\r?\n/)
      .map((l) => /^([A-Z_]+)="(.*)"$/.exec(l))
      .filter((m): m is RegExpExecArray => m !== null)
      .map((m) => [m[1], m[2]]),
  );
  const url = env.API_URL ?? "";
  if (!url || new URL(url).port !== PRACTICE_PORT) {
    throw new Error(
      `refusing to run: the stack answering is ${url || "nothing"}, and this only ever runs against practice on ${PRACTICE_PORT}. Start it with scripts/practice.sh start.`,
    );
  }
  return { url, anon: env.ANON_KEY ?? "", service: env.SERVICE_ROLE_KEY ?? "" };
}

async function ensureAccounts(url: string, service: string): Promise<Account[]> {
  const accounts: Account[] = existsSync(ACCOUNTS)
    ? JSON.parse(readFileSync(ACCOUNTS, "utf8"))
    : (["cellar", "admin"] as const).map((role) => ({
        email: `smoke-${role}@vsv.test`,
        password: randomBytes(18).toString("base64url"),
        role,
      }));
  const headers = {
    apikey: service,
    Authorization: `Bearer ${service}`,
    "Content-Type": "application/json",
  };
  for (const a of accounts) {
    // Made if missing. An existing one is found by signing in, which also
    // proves the stored password is still the one the stack has.
    const made = await fetch(`${url}/auth/v1/admin/users`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        email: a.email,
        password: a.password,
        email_confirm: true,
      }),
    });
    const body = (await made.json()) as { id?: string };
    if (made.ok && body.id) {
      a.id = body.id;
    } else {
      const list = await fetch(`${url}/auth/v1/admin/users?per_page=200`, { headers });
      const users = ((await list.json()) as { users: { id: string; email: string }[] })
        .users;
      a.id = users.find((u) => u.email === a.email)?.id;
      // It exists, perhaps from a run that stopped before the password file
      // was written. Set its password to the one on file, so the file is
      // always the truth.
      if (a.id) {
        await fetch(`${url}/auth/v1/admin/users/${a.id}`, {
          method: "PUT",
          headers,
          body: JSON.stringify({ password: a.password }),
        });
      }
    }
    if (!a.id) throw new Error(`could not make or find ${a.email}`);
    // The app's own row, which a practice reset drops.
    const row = await fetch(`${url}/rest/v1/app_user?on_conflict=id`, {
      method: "POST",
      headers: { ...headers, Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify({
        id: a.id,
        name: `Smoke ${a.role}`,
        role: a.role,
        active: true,
      }),
    });
    if (!row.ok)
      throw new Error(`could not give ${a.email} an app_user row: ${await row.text()}`);
  }
  writeFileSync(ACCOUNTS, JSON.stringify(accounts, null, 2));
  return accounts;
}

// --- the run ----------------------------------------------------------------

type Result = { step: string; ok: boolean; said: string };
const results: Result[] = [];

async function step(name: string, fn: () => Promise<string>): Promise<boolean> {
  try {
    const said = await fn();
    results.push({ step: name, ok: true, said });
    return true;
  } catch (e) {
    results.push({
      step: name,
      ok: false,
      said: e instanceof Error ? e.message : String(e),
    });
    return false;
  }
}

function must(cond: unknown, why: string): void {
  if (!cond) throw new Error(why);
}

// Expected to be refused, with a sentence a person could act on.
async function refused(fn: () => Promise<unknown>, like: RegExp): Promise<string> {
  try {
    await fn();
  } catch (e) {
    const m = e instanceof Error ? e.message : String(e);
    must(like.test(m), `refused, but with "${m}"`);
    return `refused: ${m}`;
  }
  throw new Error("was accepted and should have been refused");
}

const { url, anon, service } = status();
const accounts = await ensureAccounts(url, service);
const cellarHand = accounts.find((a) => a.role === "cellar") as Account;
const admin = accounts.find((a) => a.role === "admin") as Account;

// Pointed at practice before the kernel reads its configuration.
process.env.VITE_SUPABASE_URL = url;
process.env.VITE_SUPABASE_ANON_KEY = anon;
const k = await import("../packages/core/src/kernel.ts");

const stamp = new Date().toISOString().slice(5, 16).replace(/[-:T]/g, "");
const year = new Date().getFullYear();
const hoursAgo = (h: number) => new Date(Date.now() - h * 3600_000).toISOString();

// --- setting up, as an administrator ----------------------------------------
//
// Vessels are an administrator's to register (`vessel_admin_write`), so the
// press, the tanks and the bins are made here, and the cellar hand works with
// them. Whether a cellar hand should be able to register a bin mid-pick is a
// question for the winemaker, filed as S-145; the step after the pick records
// what happens today rather than deciding it.

// Read after signing in: the vocabulary is `term_read` to the authenticated
// role, and signed out it is an empty list rather than a refusal.
let types: Awaited<ReturnType<typeof k.terms>> = [];
const typeId = (v: string) => types.find((t) => t.value === v)?.id ?? "";
let chardonnay: string | null = null;
let freeRun: string | null = null;

let press = "";
let tankA = "";
let tankB = "";
let bins: string[] = [];
await step("an administrator registers a press, two tanks and two bins", async () => {
  await k.signIn(admin.email, admin.password);
  types = await k.terms("vessel_type");
  chardonnay =
    (await k.terms("variety")).find((t) => t.value === "chardonnay")?.id ?? null;
  freeRun =
    (await k.terms("press_cut")).find((t) => t.value === "free_run")?.id ?? null;
  must(
    typeId("press") && typeId("tank") && typeId("picking_bin"),
    "the vessel types did not load",
  );
  const p = await k.addVessels({
    id: randomUUID(),
    type_id: typeId("press"),
    name: `SMOKE press ${stamp}`,
  });
  const t = await k.addVessels(
    {
      id: randomUUID(),
      type_id: typeId("tank"),
      name: `SMOKE tank ${stamp}`,
      capacity_l: 1000,
    },
    2,
  );
  const b = await k.addVessels(
    { id: randomUUID(), type_id: typeId("picking_bin"), name: `SMOKE bin ${stamp}` },
    2,
  );
  press = p.ids[0] ?? "";
  tankA = t.ids[0] ?? "";
  tankB = t.ids[1] ?? "";
  bins = b.ids;
  await k.signOut();
  must(press && tankA && tankB && bins.length === 2, "no ids came back");
  return `${p.made.join(", ")}; ${t.made.join(", ")}; ${b.made.join(", ")}`;
});

// --- as a cellar hand ---------------------------------------------------------

await step("sign in as a cellar hand", async () => {
  await k.signIn(cellarHand.email, cellarHand.password);
  const scope = await k.viewerScope();
  must(
    scope.signed_in && scope.sees === "everything",
    `scope says ${JSON.stringify(scope)}`,
  );
  return `sees ${scope.sees}, may_admin ${scope.may_admin}`;
});

const pick = randomUUID();
await step(
  "a pick of two bins, entered this evening with the morning's time",
  async () => {
    const out = await k.addBinsToPick({
      pick: { id: pick, variety_id: chardonnay, vintage: year },
      vesselIds: bins,
      fillPct: 100,
      at: hoursAgo(6),
    });
    const row = (await k.fruitLog()).find((f) => f.id === pick);
    must(row && row.bins === 2, `the pick list says ${JSON.stringify(row)}`);
    return `${out.bins} bins on ${row?.name}`;
  },
);

await step("S-145: a cellar hand registering a new bin mid-pick", async () => {
  try {
    await k.addBinsToPick({
      pick: { id: randomUUID(), variety_id: chardonnay, vintage: year },
      newCount: 1,
      newTypeId: typeId("picking_bin"),
      namePrefix: `SMN${stamp.slice(-4)}`,
      fillPct: 100,
    });
    return "allowed";
  } catch (e) {
    // Recorded, not failed: what should happen is the winemaker's answer.
    return `refused today: ${e instanceof Error ? e.message : String(e)}`;
  }
});

await step("weigh both bins in one reading, the next hour", async () => {
  const held = (await k.vessels()).filter((v) => v.node_id === pick).map((v) => v.id);
  must(held.length === 2, `the pick is in ${held.length} vessels`);
  const w = await k.weighBins({
    nodeId: pick,
    vesselIds: held,
    grossLbs: 1520,
    at: hoursAgo(5),
  });
  const row = (await k.fruitLog()).find((f) => f.id === pick);
  must(
    row?.bins_weighed === 2,
    `two bins weighed together count as ${row?.bins_weighed}`,
  );
  return `${w.net_lbs} lbs net, both bins counted as weighed`;
});

let load = "";
await step("start pressing, backdated", async () => {
  const out = await k.startPress({
    vesselIds: bins,
    pressVesselId: press,
    at: hoursAgo(4),
  });
  load = out.node_id;
  return `${out.lbs_in} lbs in, ${out.bins_emptied} bins free`;
});

await step("draw a free-run cut into the first tank", async () => {
  const out = await k.drawCut({
    loadId: load,
    vesselId: tankA,
    volumeL: 400,
    cutId: freeRun,
    at: hoursAgo(3.5),
  });
  return `${out.volume_l} L of ${out.cut}`;
});

await step("finish the press", async () => {
  const out = await k.finishPress(load, { program: "SMOKE" }, hoursAgo(3));
  return `${out.litres_out} L off ${out.lbs_in} lbs, ${out.yield_l_per_ton ?? "no"} L/ton`;
});

let lot = "";
await step("the history says the pressing was entered late", async () => {
  lot = (await k.vessels()).find((v) => v.id === tankA)?.node_id ?? "";
  must(lot, "the first tank holds nothing");
  const h = await k.nodeHistory(load);
  must(
    h.some((r) => r.entered_late),
    "no event of a backdated pressing says it was entered late",
  );
  return `${h.length} events on the load, ${h.filter((r) => r.entered_late).length} entered late`;
});

await step("rack 100 L into the second tank, gravity", async () => {
  const out = await k.rackTransfer({
    sources: [{ vessel_id: tankA, volume_l: 100 }],
    destinations: [{ vessel_id: tankB, volume_l: 100, measured: false }],
    data: { method: "gravity", gas_destination: "argon" },
  });
  return `${out.kind}, ${out.in_l} L in`;
});

await step(
  "a rack that would put wine in a tank before it was filled is refused",
  async () =>
    refused(
      () =>
        k.rackTransfer({
          sources: [{ vessel_id: tankA, volume_l: 10 }],
          destinations: [{ vessel_id: press, volume_l: 10 }],
          at: hoursAgo(8),
        }),
      /before it went in|already held something/,
    ),
);

await step("take a sample of the racked wine", async () => {
  const racked = (await k.vessels()).find((v) => v.id === tankB)?.node_id ?? "";
  const out = await k.takeSample({
    subjectType: "node",
    subjectId: racked,
    note: "SMOKE",
  });
  return `sampled ${out.of}`;
});

await step("add something to the racked wine", async () => {
  const out = await k.addToWine({
    vesselIds: [tankB],
    amount: 5,
    unit: "g",
    what: "SMOKE SO2",
  });
  return JSON.stringify(out).slice(0, 80);
});

await step("pour 10 L away, as a loss", async () => {
  const out = await k.dumpWine({
    sources: [{ vessel_id: tankB, volume_l: 10 }],
    reason: "loss",
    note: "SMOKE",
  });
  return `${out.dumped_l} L dumped`;
});

await step("harvest weights count the pick", async () => {
  const rows = await k.harvestWeights("day_variety", year);
  const today = rows.find((r) => r.variety === "Chardonnay");
  must(today, "no Chardonnay row for this vintage");
  return `${rows.length} day and variety rows`;
});

await step("a cellar hand is refused the books", async () => {
  const q = await k.moneyQueue({ queue: "unconfirmed", limit: 1, offset: 0 });
  must(q.length === 0, `a cellar hand read ${q.length} bank lines`);
  return refused(
    () =>
      k.recordPaper({
        id: randomUUID(),
        kind: "receipt",
        direction: "out",
        onDate: null,
        amount: 1,
        who: null,
        klass: null,
        checkNumber: null,
        dueOn: null,
        note: null,
        photoPath: null,
      }),
    /administrators only/,
  );
});

await k.signOut();

// --- as an administrator ------------------------------------------------------

await step("sign in as an administrator", async () => {
  await k.signIn(admin.email, admin.password);
  const scope = await k.viewerScope();
  must(scope.may_admin, "the administrator may not administer");
  return "may administer";
});

await step("say yes to a guessed transaction, and the score moves", async () => {
  const before = await k.booksProgress();
  const [line] = [
    ...(await k.moneyQueue({ queue: "unconfirmed", limit: 1, offset: 0 })),
    ...(await k.moneyQueue({ queue: "unexplained", limit: 1, offset: 0 })),
  ];
  must(line, "nothing in the books to say yes to");
  const klass =
    line?.class ?? line?.suggested ?? (await k.terms("money_class"))[0]?.value ?? "";
  await k.attestLine({ lineId: line?.id ?? "", klass, confirm: true });
  const after = await k.booksProgress();
  must(
    after.filed_today === before.filed_today + 1,
    `filed today went ${before.filed_today} to ${after.filed_today}`,
  );
  return `filed today ${before.filed_today} to ${after.filed_today}, streak ${after.streak_days}`;
});

await step("photograph a receipt and read it", async () => {
  const id = randomUUID();
  // The smallest valid JPEG there is, so the upload is a real image and not text
  // pretending to be one.
  const jpeg = Uint8Array.from(
    Buffer.from(
      "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k=",
      "base64",
    ),
  );
  const path = await k.uploadPaperPhoto(
    id,
    new File([jpeg], "smoke.jpg", { type: "image/jpeg" }),
  );
  const out = await k.recordPaper({
    id,
    kind: "receipt",
    direction: "out",
    onDate: new Date().toISOString().slice(0, 10),
    amount: 12.34,
    who: "SMOKE Grocer",
    klass: null,
    checkNumber: null,
    dueOn: null,
    note: null,
    photoPath: path,
  });
  const url2 = await k.paperPhotoUrl(path);
  must(url2, "no signed url for the photograph");
  const got = await fetch(url2 as string);
  must(got.ok, `the photograph came back ${got.status}`);
  return `saved, ${out.suggestions} suggestion(s), the photograph opens`;
});

await k.signOut();

// --- what it says ---------------------------------------------------------------

const width = Math.max(...results.map((r) => r.step.length));
for (const r of results) {
  console.log(`${r.ok ? "ok  " : "FAIL"}  ${r.step.padEnd(width)}  ${r.said}`);
}
const failed = results.filter((r) => !r.ok).length;
console.log(
  failed === 0
    ? `\nall ${results.length} steps worked`
    : `\n${failed} of ${results.length} steps failed`,
);
process.exit(failed === 0 ? 0 : 1);
