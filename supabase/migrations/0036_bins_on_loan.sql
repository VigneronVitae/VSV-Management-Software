-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Fruit arrives in the grower's bins. Those bins go back, and the
--           record has to say whose they are without pretending the grower is
--           a party at this winery."
-- Depends on: [supabase/migrations/0034_press.sql,
--              supabase/migrations/0035_bins_in_bulk.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: T1-4 (intake must be fast before it is complete)
-- Open sorries: S-53 (a grower is a string in two places and nothing joins
--               them)
-- ---------------------------------------------------------------------------
--
-- Asked for during the first pick: "if I receive chardonnay from Pearlstaad
-- there's no option to save it in a new temporary bin owned by Pearlstaad".
--
-- **A grower is not a party.** `party.kind` is `facility` or `client`, and a
-- client is somebody whose wine this winery makes and who signs in to see it.
-- Pearlstaad sells fruit. Making them a client to borrow their bins would put a
-- row in the table that `node_read` scopes lot visibility by, to record a fact
-- about a plastic box, and that is the kind of convenience that turns into a
-- privacy incident two vintages later.
--
-- **The schema already had the answer.** `block.vineyard` is free text, because a
-- vineyard is where fruit came from rather than somebody with standing here. A
-- bin on loan from a vineyard is the same shape, so it is recorded the same way,
-- and `owner_id` stays for the case it was built for: a bin that belongs to a
-- custom crush client who does have standing.
--
-- The two halves the winemaker asked for in W-11 stay separate, as he said they
-- should: **who owns it** and **whether it travels with the fruit**. A client's
-- bin sitting in the barn is owned and not on loan. A grower's bin is on loan
-- and has no party at all.

begin;

-- Offered on the vessel screen as well as at intake, so a bin registered the
-- slow way can say the same thing. `borrowed` already exists from 0033; this is
-- the other half of the sentence it starts.
update term
   set attributes = jsonb_set(
     attributes,
     '{fields}',
     (attributes -> 'fields') || jsonb_build_array(
       jsonb_build_object(
         'key', 'on_loan_from', 'kind', 'text', 'open', false,
         'label', 'On loan from',
         'hint', 'The grower whose bin this is. Free text, because a vineyard you buy fruit from is not a party at this winery.',
         'sort_order', 30))
   )
 where kind = 'vessel_type'
   and coalesce((attributes ->> 'intake_bin')::boolean, false)
   and not exists (
     select 1 from jsonb_array_elements(attributes -> 'fields') f
      where f ->> 'key' = 'on_loan_from'
   );

-- Whose it is, however that is recorded. A party where there is one, the
-- grower's name where there is not, and null only when nobody said, which is a
-- third answer rather than a blank standing in for one of the other two.
create or replace view bin_to_return with (security_invoker = true) as
select
  v.id     as vessel_id,
  v.name   as bin_name,
  vt.label as bin_type,
  v.owner_id,
  -- The lender first. A bin on loan says who it goes back to in its own words,
  -- and a party on the row is about who owns the record rather than who is
  -- standing at the gate waiting for their bins.
  coalesce(nullif(btrim(v.attributes ->> 'on_loan_from'), ''), p.name) as owed_to,
  v.location_id
from vessel v
join term vt on vt.id = v.type_id and vt.kind = 'vessel_type'
left join party p on p.id = v.owner_id
where v.active
  and coalesce((v.attributes ->> 'borrowed')::boolean, false)
  and not exists (
    select 1 from placement pl where pl.vessel_id = v.id and pl.to_at is null
  );

comment on view bin_to_return is
  'Borrowed bins with nothing in them. Empty is not the same as available: these '
  'are owed back, to a party where there is one and to a named grower where '
  'there is not. See 0034 and 0036.';

-- Bulk registration learns the same two facts.
--
-- **Dropped first, not replaced.** `create or replace function` keys on the
-- argument list, so adding two parameters with defaults creates a second
-- function rather than replacing the first, and every call then fails with "is
-- not unique" because neither candidate is better. Found by the test doing
-- exactly what the client would have done an hour later.
drop function if exists add_bins_to_pick(jsonb, uuid[], int, uuid, text, numeric);
create or replace function add_bins_to_pick(
  p_pick         jsonb,
  p_vessel_ids   uuid[]  default null,
  p_new_count    int     default 0,
  p_new_type_id  uuid    default null,
  p_name_prefix  text    default null,
  p_fill_pct     numeric default null,
  p_owner_id     uuid    default null,
  p_on_loan_from text    default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  pick_id  uuid := coalesce((p_pick ->> 'id')::uuid, gen_random_uuid());
  prefix   text := btrim(coalesce(p_name_prefix, 'Bin'));
  lender   text := nullif(btrim(coalesce(p_on_loan_from, '')), '');
  bag      jsonb;
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
    raise exception '% is not a number of bins to register at once', p_new_count;
  end if;

  -- A bin cannot be a named grower's and a party's at once. Those are the two
  -- different situations the winemaker separated, and a row claiming both would
  -- make `owed_to` pick one silently.
  if lender is not null and p_owner_id is not null then
    raise exception
      'a bin is either on loan from % or owned by a party here, and this says both', lender;
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

    -- Borrowed is set by the presence of a lender or of an owner who is not this
    -- winery: both mean the bin goes back, which is what `bin_to_return` reads.
    bag := '{}'::jsonb;
    if lender is not null then
      bag := jsonb_build_object('borrowed', true, 'on_loan_from', lender);
    elsif p_owner_id is not null and p_owner_id is distinct from facility_party_id() then
      bag := jsonb_build_object('borrowed', true);
    end if;

    -- Carry on from the highest number already worn by a bin with this prefix,
    -- rather than counting how many exist: a bin that was retired leaves a gap,
    -- and reusing its number would put two different objects under one name.
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
      insert into vessel (id, type_id, name, capacity_l, owner_id, attributes)
      values (new_id, p_new_type_id, prefix || (next_n + i)::text, cap,
              p_owner_id, bag);
      made := made || (prefix || (next_n + i)::text);
      p_vessel_ids := coalesce(p_vessel_ids, '{}'::uuid[]) || new_id;
    end loop;
  end if;

  -- Attached one at a time through the function that already knows what a bin
  -- may be, so every guard 0033 wrote applies to each and this adds no second
  -- opinion about it.
  foreach v_id in array p_vessel_ids
  loop
    result := add_bin_to_pick(p_pick || jsonb_build_object('id', pick_id), v_id, p_fill_pct);
    pick_id := (result ->> 'node_id')::uuid;
  end loop;

  return jsonb_build_object(
    'node_id',    pick_id,
    'registered', to_jsonb(made),
    'bins',       (select count(*) from placement
                    where node_id = pick_id and to_at is null),
    'unweighed',  (select count(*) from unweighed_bin where node_id = pick_id)
  );
end;
$$;

commit;
