#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Refuses to reset a database with a real cellar in it, because
#           CLAUDE.md has said so in prose for eleven sessions and prose does
#           not refuse anything."
# Depends on: [scripts/practice.sh]
# Depended on by: [docs/practice-mode.md]
# ---------------------------------------------------------------------------
#
# `bun run db:reset` was `supabase db reset`, which destroys everything in the
# database, and the only thing standing between that command and this winery's
# harvest was a paragraph asking people not to run it. That paragraph is still
# right and it is not a control.
#
# It matters more now than it did. Practice mode exists precisely so that
# resetting is a normal thing to do, and a person who has spent an afternoon
# resetting practice is a person who will eventually run the reset in the other
# window. **The whole point of a second stack is that the two are different, and
# the two commands must therefore be different too.**
#
# So: this refuses when the target has lots in it, and points at the practice
# stack, which is the thing the person almost certainly meant.
#
# The escape hatch is deliberately awkward. `VSV_I_MEAN_IT=yes` is not a flag
# somebody types by muscle memory, and it appears nowhere in any script, so the
# only way to use it is to have read this file.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"

if ! docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then
  echo "The cellar database is not running, so there is nothing to reset."
  exit 1
fi

lots=$(docker exec "$CONTAINER" psql -U postgres -At -d postgres \
         -c "select count(*) from node;" 2>/dev/null || echo 0)
vessels=$(docker exec "$CONTAINER" psql -U postgres -At -d postgres \
            -c "select count(*) from vessel;" 2>/dev/null || echo 0)

if [ "${lots:-0}" -eq 0 ] && [ "${vessels:-0}" -eq 0 ]; then
  echo "The cellar is empty, so resetting it destroys nothing."
  exec supabase db reset
fi

if [ "${VSV_I_MEAN_IT:-}" = "yes" ]; then
  echo "VSV_I_MEAN_IT is set. Resetting a cellar holding $lots lots and $vessels vessels."
  exec supabase db reset
fi

cat <<MESSAGE
Refused.

This is the cellar. It holds $lots lots and $vessels vessels, and a reset
destroys all of it. Restoring is imperfect even from a backup: seeded
vocabulary is reissued with new ids, so lots restored afterwards point at
varieties that no longer exist. That is sorry S-29 and it is unfixed.

If what you wanted was somewhere to try something and throw it away:

    bun run practice reset

which does exactly that, to the other stack, and cannot reach this one.

If you genuinely meant this database, take a backup first:

    bun run db:backup

and then read scripts/db-reset-guard.sh, which says how.
MESSAGE
exit 1
