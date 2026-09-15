// A second periphery, built from the contract and nothing else.
//
// AR-Q8 says an interface is a periphery over a read and write contract, and
// that the way to find out whether that is true is the Knowledge Game's own
// falsifier: can a second interface be built from the declaration alone, without
// its author reading the first one's source?
//
// **This file is that test, so the rule it is under matters more than the code.**
// Nothing here may import from `cellar`, and nothing here may name a table, a
// view, a function, a column or a field. Every one of those arrives from
// `contract()` at runtime. If this file ever has to hardcode something to work,
// the contract was incomplete and the honest response is to fix the contract
// rather than this.
//
// Two things are hardcoded and both are deliberate: the name of the contract
// function itself, which is the one door, and how to sign in, which happens
// before there is a caller to have capabilities.
//
// It is a terminal interface because the winemaker's framing was that text,
// visual and audio are peripheries over one contract, and text is the cheapest
// of the three to build honestly. An audio one would differ from this in how it
// asks and not at all in what it asks.

import { stdin, stdout } from "node:process";
import { createInterface } from "node:readline/promises";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

type Field = {
  key: string;
  param: string;
  type: string;
  required?: boolean;
  label?: string;
  hint?: string;
  source?: { terms?: string; readable?: string };
};

type Capability = {
  key: string;
  module: string;
  label: string;
  note: string | null;
  fn: string;
  subject: string | null;
  fields: Field[];
};

type Readable = {
  key: string;
  module: string;
  label: string;
  note: string | null;
  relation: string;
  id_column: string | null;
  label_column: string | null;
};

type Contract = {
  viewer: Record<string, unknown>;
  readables: Readable[];
  capabilities: Capability[];
};

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
if (!url || !anonKey) {
  console.error(
    "Set SUPABASE_URL and SUPABASE_ANON_KEY. They are the same two values\n" +
      "apps/web/.env.local carries as VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.",
  );
  process.exit(2);
}

const db: SupabaseClient = createClient(url, anonKey);
const ask = createInterface({ input: stdin, output: stdout });

function say(line = ""): void {
  stdout.write(`${line}\n`);
}

// Every refusal in this kernel is a sentence somebody wrote for a person. That
// is the whole of this periphery's error handling, and it is the evidence that
// the contract framing fits: a kernel whose refusals are sentences was already
// being written for more than one modality.
function refusal(error: { message?: string } | null): string {
  return error?.message ?? "something went wrong and said nothing";
}

async function signIn(): Promise<boolean> {
  const email = await ask.question("email: ");
  const password = await ask.question("password: ");
  const { error } = await db.auth.signInWithPassword({ email, password });
  if (error) {
    say(refusal(error));
    return false;
  }
  return true;
}

// Reading a readable. The relation, the id column and the label column all come
// from the contract; this function has never heard of a press.
async function rowsOf(r: Readable): Promise<Record<string, unknown>[]> {
  const { data, error } = await db.from(r.relation).select("*").limit(50);
  if (error) {
    say(`could not read ${r.label}: ${refusal(error)}`);
    return [];
  }
  return (data ?? []) as Record<string, unknown>[];
}

function describe(r: Readable, row: Record<string, unknown>): string {
  if (r.label_column && row[r.label_column] != null) return String(row[r.label_column]);
  // No label column is a real state rather than an error: some lists are of
  // things nobody has a name for. Show what there is.
  return Object.entries(row)
    .slice(0, 3)
    .map(([k, v]) => `${k}=${String(v)}`)
    .join(" ");
}

async function pickFrom(
  contract: Contract,
  readableKey: string,
): Promise<string | null> {
  const r = contract.readables.find((x) => x.key === readableKey);
  if (!r) {
    say(`the contract offers no list called ${readableKey}`);
    return null;
  }
  const rows = await rowsOf(r);
  if (rows.length === 0) {
    say(`${r.label}: nothing there.`);
    return null;
  }
  say();
  rows.forEach((row, i) => {
    say(`  ${i + 1}. ${describe(r, row)}`);
  });
  const answer = await ask.question("  which (number, or blank to skip): ");
  const n = Number(answer);
  if (!answer || Number.isNaN(n) || n < 1 || n > rows.length) return null;
  const chosen = rows[n - 1];
  return r.id_column && chosen ? String(chosen[r.id_column]) : null;
}

async function pickTerm(kind: string): Promise<string | null> {
  const { data, error } = await db
    .from("term")
    .select("id,label")
    .eq("kind", kind)
    .eq("active", true)
    .order("sort_order");
  if (error) {
    say(refusal(error));
    return null;
  }
  const rows = (data ?? []) as { id: string; label: string }[];
  if (rows.length === 0) return null;
  say();
  rows.forEach((row, i) => {
    say(`  ${i + 1}. ${row.label}`);
  });
  const answer = await ask.question("  which (number, or blank to skip): ");
  const n = Number(answer);
  if (!answer || Number.isNaN(n) || n < 1 || n > rows.length) return null;
  return rows[n - 1]?.id ?? null;
}

// The whole of how this periphery renders a form: walk the declared fields, ask
// for each one the way its type and source say, and hand the result back under
// the parameter name the contract gave.
async function gather(
  contract: Contract,
  cap: Capability,
): Promise<Record<string, unknown> | null> {
  const args: Record<string, unknown> = {};

  for (const f of cap.fields) {
    const label = f.label ?? f.key;
    if (f.hint) say(`  (${f.hint})`);

    if (f.source?.readable) {
      say(`${label}${f.required ? "" : ", optional"}:`);
      const many = f.type.endsWith("[]");
      const picked: string[] = [];
      // An array field asks until somebody stops, because "which bins were on
      // the scale" is genuinely more than one and the contract says so in the
      // type rather than in prose.
      for (;;) {
        const id = await pickFrom(contract, f.source.readable);
        if (!id) break;
        picked.push(id);
        if (!many) break;
        const more = await ask.question("  another? (y/N): ");
        if (more.toLowerCase() !== "y") break;
      }
      if (picked.length === 0) {
        if (f.required) {
          say(`${label} is needed.`);
          return null;
        }
        continue;
      }
      args[f.param] = many ? picked : picked[0];
      continue;
    }

    if (f.source?.terms) {
      say(`${label}${f.required ? "" : ", optional"}:`);
      const id = await pickTerm(f.source.terms);
      if (id) args[f.param] = id;
      else if (f.required) {
        say(`${label} is needed.`);
        return null;
      }
      continue;
    }

    const typed = await ask.question(`${label}${f.required ? "" : ", optional"}: `);
    if (!typed) {
      if (f.required) {
        say(`${label} is needed.`);
        return null;
      }
      continue;
    }
    if (f.type === "numeric") args[f.param] = Number(typed);
    else if (f.type === "boolean") args[f.param] = typed.toLowerCase().startsWith("y");
    else if (f.type === "jsonb") {
      try {
        args[f.param] = JSON.parse(typed);
      } catch {
        say("that is not json; skipped.");
      }
    } else args[f.param] = typed;
  }
  return args;
}

async function main(): Promise<void> {
  say("A text periphery over the cellar contract.");
  say("It knows the word `contract` and nothing else about this winery.");
  say();

  if (!(await signIn())) {
    ask.close();
    process.exit(1);
  }

  const { data, error } = await db.rpc("contract");
  if (error) {
    say(`could not read the contract: ${refusal(error)}`);
    ask.close();
    process.exit(1);
  }
  const contract = data as Contract;

  say();
  say(`You are ${JSON.stringify(contract.viewer)}`);
  say(
    `The contract offers ${contract.capabilities.length} things to do and ` +
      `${contract.readables.length} things to look at.`,
  );

  for (;;) {
    say();
    say("What would you like to do?");
    contract.capabilities.forEach((c, i) => {
      say(`  ${i + 1}. ${c.label}`);
    });
    say(`  r. look at something`);
    say(`  q. quit`);
    const answer = await ask.question("> ");

    if (answer === "q") break;

    if (answer === "r") {
      contract.readables.forEach((r, i) => {
        say(`  ${i + 1}. ${r.label}`);
      });
      const which = Number(await ask.question("> "));
      const r = contract.readables[which - 1];
      if (!r) continue;
      say();
      if (r.note) say(r.note);
      const rows = await rowsOf(r);
      if (rows.length === 0) say("Nothing there.");
      for (const row of rows) say(`  ${describe(r, row)}`);
      continue;
    }

    const cap = contract.capabilities[Number(answer) - 1];
    if (!cap) continue;

    say();
    say(cap.label);
    if (cap.note) say(cap.note);
    say();

    const args = await gather(contract, cap);
    if (!args) continue;

    const { data: out, error: err } = await db.rpc(cap.fn, args);
    say();
    if (err) say(refusal(err));
    else say(`Done. ${JSON.stringify(out)}`);
  }

  ask.close();
}

void main();
