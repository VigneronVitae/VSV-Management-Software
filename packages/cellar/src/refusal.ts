// One path for the three shapes a refusal takes.
//
// W-8 ran the client against live policies and found that being told no arrives
// three different ways. A kernel `raise exception` arrives intact and in the
// kernel's own voice, which is the one that works. A row level security denial on
// a write arrives as `new row violates row-level security policy for table
// "party"`, which is raw Postgres in front of somebody standing at a press. A
// denial on a read arrives as nothing at all, because a policy has no message to
// carry and PostgREST returns two hundred and an empty array.
//
// Three shapes is the defect rather than three bugs. A person cannot tell refused
// from absent from empty, and until this module existed neither could the code.
//
// The read case cannot be solved by asking about the rows, and every way of
// trying discloses the thing being withheld:
//
//   a second existence query tells you the row exists, which is what AR-E10 has
//   just ruled out;
//   a count endpoint under different policies is two sources of truth for one
//   question, and the difference between them is itself the disclosure;
//   encoding the answer in the policy set couples every screen to the policy
//   list, which is the R-4 class that section B exists to record.
//
// So this does not claim to say what was withheld. It says what the viewer is,
// which the kernel answers in `viewer_scope()`, and it reads emptiness in that
// light. "Nothing here" becomes "nothing here that is yours", which is weaker,
// complete, and true. Naming what was withheld is the thing that must not be
// built, so the weaker sentence is the honest ceiling rather than a compromise.

import type { ViewerScope } from "core";

/**
 * What Postgres itself says when a policy refuses. These two strings are the only
 * refusals in the system that no person wrote, and recognising them is the whole
 * of the discrimination this module performs.
 *
 * The first version of this keyed on the SQLSTATE, on the reasoning that P0001 is
 * a `raise` and 42501 is a policy. That is wrong, and the running client said so
 * within a minute: `cellar_writable_columns` raises **using errcode 42501**, on
 * purpose, so that PostgREST answers 403 rather than 500. So the kernel's best
 * message in the whole tree, "a cellar user may not change vessel.attributes; ask
 * an administrator", arrives under the same code as a bare policy denial, and
 * keying on the code replaced it with a generic sentence. It made the one shape
 * that already worked worse.
 *
 * The rule is therefore inverted, and the inversion is the safer default: relay
 * the message, because somebody wrote it, unless it is one of the two Postgres
 * generates on its own.
 */
const POSTGRES_OWN_WORDS = [
  /row-level security policy/i,
  /^permission denied for (table|relation|schema|function)/i,
];

/** The message, whatever shape the thrown thing is. */
function pg(error: unknown): { message: string | undefined } {
  if (error && typeof error === "object") {
    const e = error as Record<string, unknown>;
    return { message: typeof e.message === "string" ? e.message : undefined };
  }
  return { message: String(error) };
}

/** Who the viewer is, in a clause that can be dropped into a sentence. */
function standing(scope: ViewerScope | null): string {
  if (!scope?.signed_in) return "You are not signed in";
  if (!scope.account) return "Your account is not active here";
  if (scope.sees === "own")
    return `You are signed in for ${scope.party_name ?? "a client"}, so you see that party's wine`;
  if (scope.may_admin) return "You are signed in as an administrator";
  return "You are signed in as a cellar user";
}

/**
 * The single description of a refusal. Every error path in the client renders
 * through this, so that the three shapes stop being three.
 */
export function describeRefusal(error: unknown, scope: ViewerScope | null): string {
  const { message } = pg(error);

  // A transport failure is not a refusal and must not read as one. Ledger B16:
  // nothing in this client times out, so this is what a dead zone will look like
  // once something does.
  if (
    message === "Failed to fetch" ||
    /networkerror|load failed/i.test(message ?? "")
  ) {
    return "The winery database could not be reached. Nothing was saved. This is usually signal rather than the app.";
  }

  // A policy refused, and a policy has no words: Postgres supplies its own, and
  // they name an implementation rather than a rule. Say what is true and useful
  // instead, which is the standing the refusal happened under, because that is
  // the thing that would have to change.
  if (message && POSTGRES_OWN_WORDS.some((p) => p.test(message))) {
    return `That is not something this account may do. ${standing(scope)}. If it should be, an administrator changes that.`;
  }

  // Everything else was written by somebody for a person to read. Relay it and
  // add nothing: the reason the kernel raises in words is so that this layer does
  // not have to guess, and a second sentence under it would be this layer
  // guessing.
  return message ?? "Something went wrong and said nothing about what.";
}

/**
 * The silent shape. An empty list is only a complete statement when it says what
 * it is empty of, and this is the only place that sentence is written.
 *
 * `subject` is the plural noun the screen is listing, "vessels" or "lots".
 */
export function describeEmpty(subject: string, scope: ViewerScope | null): string {
  if (!scope || scope.sees === "nothing") {
    return `No ${subject} to show. ${standing(scope)}, so this list is empty for that reason rather than because the cellar is.`;
  }
  if (scope.sees === "own") {
    return `No ${subject} here that belong to ${scope.party_name ?? "your party"}. Wine other parties own is not counted, and this list cannot tell you whether there is any.`;
  }
  return `No ${subject} yet.`;
}

/**
 * Whether this viewer may reach the screens at all, asked of the kernel rather
 * than worked out from a role string.
 *
 * Ledger B10: `route()` compared `app_user.role` to "admin" and never looked at
 * `active`, so a deactivated account reached every screen in the client and was
 * then refused by the kernel one write at a time. The kernel already knows the
 * answer, `is_facility_user()` already includes the `active` conjunct, and
 * `viewer_scope()` is how it says so.
 */
export function mayEnter(scope: ViewerScope | null): boolean {
  return !!scope && scope.signed_in && scope.account && scope.sees !== "nothing";
}
