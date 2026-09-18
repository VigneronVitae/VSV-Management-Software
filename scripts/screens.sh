#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Type: script
# Purpose: "Every screen the client can route to has a row in `screen`, so a
#           note about wording has something to point at."
# Depends on: [supabase/migrations/0101_a_note_can_be_about_a_screen.sql,
#              supabase/migrations/0107_the_shop_has_screens_too.sql,
#              supabase/migrations/0113_a_vineyard_is_a_place_you_can_open.sql,
#              supabase/migrations/0114_every_pick_stays_on_the_list.sql,
#              supabase/migrations/0118_the_vineyard_has_a_door.sql]
# Depended on by: [scripts/green.sh]
# ---------------------------------------------------------------------------
#
# 0101 makes a screen an object so a note can be about one, and the whole reason
# that is safe is this check. A registry of screens that can silently fall behind
# the client is worse than no registry: the failure is a person standing on a new
# screen, tapping the note button, and being told that nothing in this system is
# that, which reads as the notes feature being broken.
#
# Same shape as scripts/rpc-args.sh, for the same reason: the client names things
# in strings, and a string that stopped matching is invisible to the compiler.
#
# It reads packages/cellar/src/places.ts, which carries no typed header and so
# is not named in the field above, the same way scripts/rpc-args.sh reads the
# client without naming it.
#
# The place list is the two Sets in places.ts. Reading them with awk rather than
# by running TypeScript keeps this a shell check that needs no build.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONTAINER="${VSV_DB_CONTAINER:-supabase_db_vsv-management-software}"
DB="${1:-postgres}"
# Both clients. The shop arrived as a second periphery and its screens have to
# be registered for the same reason the cellar's are: a note about wording needs
# something to point at, and the person most likely to have wording feedback is
# the one using the newest screens.
SRC="${VSV_PLACES_SRC:-packages/cellar/src/places.ts packages/shop/src/places.ts packages/vineyard/src/places.ts}"

for f in $SRC; do
  if [ ! -f "$f" ]; then
    echo "FAIL  no place list at $f"
    exit 1
  fi
done

# Everything quoted inside WITHOUT_ID and WITH_ID. Both are flat lists of string
# literals, one per line, which is what makes this readable without a parser.
# The cellar names its two sets WITHOUT_ID and WITH_ID; the shop and the
# vineyard each name one set PLACES. All of them are flat lists of string
# literals, which is what makes this readable without a parser.
places=$(awk '
  # The opening line may carry literals of its own. A short set formats onto one
  # line, and the first version of this treated the opener as if it were always
  # bare: it skipped the rest of that line with `next`, never saw a closing
  # `]);`, and ran on through the file printing any quoted string it met. The
  # symptom was the word `id` appearing in the list of screens, off a line
  # reading `"id" in place`. So the opener is scanned rather than skipped, and a
  # set that closes on its own line closes there.
  /^(const|export const) (WITHOUT_ID|WITH_ID|PLACES) = new Set\(\[/ {
    inside = 1
    line = $0
    sub(/^[^[]*\[/, "", line)
    while (match(line, /"[^"]+"/)) {
      print substr(line, RSTART + 1, RLENGTH - 2)
      line = substr(line, RSTART + RLENGTH)
    }
    if (line ~ /\]\)/) inside = 0
    next
  }
  inside && /^\]\);/                                                 { inside = 0; next }
  inside && match($0, /"[^"]+"/) {
    print substr($0, RSTART + 1, RLENGTH - 2)
  }
' $SRC | sort -u)

if [ -z "$places" ]; then
  echo "FAIL  no places found in $SRC, which means this check is reading nothing"
  exit 1
fi

rows=$(docker exec "$CONTAINER" psql -U postgres -q -d "$DB" -At \
  -c "select key from screen order by key;" 2>/dev/null | sort -u)

if [ -z "$rows" ]; then
  echo "FAIL  the screen table is empty or unreadable in $DB"
  exit 1
fi

missing=$(comm -23 <(echo "$places") <(echo "$rows"))
extra=$(comm -13 <(echo "$places") <(echo "$rows"))

fails=0
if [ -n "$missing" ]; then
  echo "FAIL  these screens exist in the client and have no row, so a note cannot be about them:"
  echo "$missing" | sed 's/^/        /'
  fails=1
fi
# An extra row is not a failure. A screen can be removed from the client while
# notes about it survive, and deleting the row would orphan them, which is the
# thing this whole migration exists to avoid.
if [ -n "$extra" ]; then
  echo "note  these rows name screens the client no longer routes to, and are kept"
  echo "      so that notes already written about them still resolve:"
  echo "$extra" | sed 's/^/        /'
fi

if [ "$fails" -eq 0 ]; then
  echo "ok    $(echo "$places" | wc -l | tr -d ' ') screens in the client all have a row a note can point at"
fi
exit "$fails"
