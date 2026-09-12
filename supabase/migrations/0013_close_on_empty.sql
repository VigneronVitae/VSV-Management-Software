-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A lot closes when it is empty, not when it first feeds something.
--           Taking 228 L off a 2000 L lot leaves 1772 L of that lot, still
--           open. Lineage goes back to recording only where material came
--           from."
-- Depends on: [supabase/migrations/0001_core_schema.sql,
--              packages/cellar/docs/spec.md]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql, supabase/migrations/0014_rack.sql, supabase/migrations/0015_fork_and_history.sql]
-- Axioms enforced: T0-2 (derived over stored: lineage describes origin and
--                  stops standing in for how much is left)
-- Discharges: S-3
-- Open sorries: S-21 (quantity is stored and also derivable from placements,
--               and every rack writes both)
-- ---------------------------------------------------------------------------

-- The rule this replaces came from the winemaker and so does the replacement.
-- 0001 said "a node that has fed something is spent", which is true of a bin
-- pressed whole and false of everything else. Breaking one barrel out of a
-- 2000 L lot for topping wine does not spend the lot, it makes it smaller.
--
-- This was also written into spec.md, which said closed_at is "set by trigger
-- when the node becomes a parent". That line has been corrected in the same
-- change, because a schema disagreeing with the spec is worse than either being
-- wrong on its own.
--
-- Lineage now means only what it says: where this material came from. It no
-- longer doubles as an assertion that the source is finished.

drop trigger if exists lineage_closes_parent on lineage;
drop function if exists close_parent_on_lineage();

-- Empty is the condition, and quantity is what says so. A lot with no quantity
-- recorded is left alone rather than guessed at: unknown is not zero, and
-- closing a lot nobody measured would be the same class of mistake as the rule
-- being replaced here.
create or replace function close_node_when_empty()
returns trigger
language plpgsql
as $$
begin
  if new.quantity is not null and new.quantity <= 0 then
    if new.status <> 'closed' then
      new.status := 'closed';
      new.closed_at := coalesce(new.closed_at, now());
    end if;
  elsif new.quantity is not null and new.quantity > 0 and new.status = 'closed'
        and new.closed_at is not null and old.quantity is not null
        and old.quantity <= 0 then
    -- Refilling something that was emptied is a correction, not a resurrection,
    -- and it is rare enough that reopening quietly would hide a mistake. The
    -- lot stays closed and the correction is a new lot.
    raise exception 'lot % is closed; record the wine as a new lot rather than refilling this one', new.id;
  end if;
  return new;
end;
$$;

create trigger node_closes_when_empty
  before update of quantity on node
  for each row execute function close_node_when_empty();
