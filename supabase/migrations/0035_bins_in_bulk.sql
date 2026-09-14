-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Bins arrive by the stack, not one at a time, so registering three
--           and filling them with the same pick is one action rather than six."
-- Depends on: [supabase/migrations/0033_intake.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0036_bins_on_loan.sql]
-- Axioms enforced: T1-1 (pickers, not text fields: a bin's name is generated
--                  rather than typed three times), T1-4 (intake must be fast
--                  before it is complete)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- Asked for during the first pick, which is the right time to hear it: the
-- winemaker had just registered PB1, PB2 and PB3 one screen at a time and then
-- added them to a pick one tap at a time, which is six actions for a thing that
-- is one decision.
--
-- **The numbering is a rule, so it lives here.** "The next bin after PB3 is PB4"
-- is exactly the kind of three line calculation that a client reimplements and
-- then disagrees with the next client about, which is what `CLAUDE.md` forbids.
-- It reads the highest number already worn by a bin with that prefix and carries
-- on from there, so it does not collide with bins made before this existed and
-- does not renumber anything.
--
-- **One transaction.** Three vessels and three placements landing half way is
-- worse than none of them: a bin that exists and is not on the pick is a bin
-- somebody will fill twice.

begin;

create or replace function add_bins_to_pick(
  p_pick        jsonb,
  p_vessel_ids  uuid[]  default null,
  p_new_count   int     default 0,
  p_new_type_id uuid    default null,
  p_name_prefix text    default null,
  p_fill_pct    numeric default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  pick_id  uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  prefix   text := btrim(coalesce(p_name_prefix, 'Bin'));
  next_n   int;
  cap      numeric;
  new_id   uuid;
  made     text[] := '{}';
  v_id     uuid;
  i        int;
  result   jsonb;
begin
  if coalesce(p_new_count, 0) = 0
     and coalesce(array_length(p_vessel_ids, 1), 0) = 0 then
    raise exception 'no bins were named and none were asked for, so there is nothing to add';
  end if;
  if coalesce(p_new_count, 0) < 0 or coalesce(p_new_count, 0) > 40 then
    raise exception
      '% is not a number of bins to register at once', p_new_count;
  end if;

  if coalesce(p_new_count, 0) > 0 then
    if prefix = '' then
      raise exception 'new bins need something to be called';
    end if;
    if p_new_type_id is null then
      raise exception 'new bins need a type, so the scale knows what they weigh empty';
    end if;
    if not exists (
      select 1 from term
       where id = p_new_type_id and kind = 'vessel_type'
         and coalesce((attributes ->> 'intake_bin')::boolean, false)
    ) then
      raise exception 'that is not a picking bin type, so fruit is not weighed in it';
    end if;

    -- Carry on from the highest number already worn by a bin with this prefix,
    -- rather than counting how many exist: a bin that was retired leaves a gap,
    -- and reusing its number would put two different objects under one name in
    -- the record.
    select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
      into next_n
      from vessel v
     where v.name ~ ('^' || prefix || '\s*\d+$');

    -- A stack of bins is a stack of one thing, so the newest one of this type is
    -- the best guess at how big these are. Null is fine and stays null.
    select v.capacity_l into cap
      from vessel v
     where v.type_id = p_new_type_id
     order by v.created_at desc
     limit 1;

    for i in 0 .. p_new_count - 1
    loop
      new_id := gen_random_uuid();
      insert into vessel (id, type_id, name, capacity_l)
      values (new_id, p_new_type_id, prefix || (next_n + i)::text, cap);
      made := made || (prefix || (next_n + i)::text);
      p_vessel_ids := coalesce(p_vessel_ids, '{}'::uuid[]) || new_id;
    end loop;
  end if;

  -- Attached one at a time through the function that already knows what a bin
  -- may be, so every guard 0033 wrote applies to each of them and this adds no
  -- second opinion about it.
  foreach v_id in array p_vessel_ids
  loop
    result := add_bin_to_pick(p_pick || jsonb_build_object('id', pick_id), v_id, p_fill_pct);
    pick_id := (result ->> 'node_id')::uuid;
  end loop;

  return jsonb_build_object(
    'node_id',   pick_id,
    'registered', to_jsonb(made),
    'bins',      (select count(*) from placement
                   where node_id = pick_id and to_at is null),
    'unweighed', (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$$;

commit;
