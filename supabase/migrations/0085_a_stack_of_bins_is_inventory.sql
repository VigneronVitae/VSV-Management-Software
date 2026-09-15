-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Register a stack of picking bins as inventory, without a pick to
--           attach them to, because bins are interchangeable and counting them
--           is the whole of what anybody knows about them."
-- Depends on: [supabase/migrations/0036_bins_on_loan.sql,
--              supabase/migrations/0081_a_borrowed_bin_is_not_ours.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0086_a_variable_named_like_a_column.sql]
-- Axioms enforced: T1-4 (intake fast before complete: registering the fleet
--                  once is what keeps a pick down to choosing bins)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker: *"Also batch add for picking bins. I'd rather just inventory
-- and add as they don't really differ."*
--
-- **The batch existed and the inventory did not.** `add_bins_to_pick` has taken
-- a count and a prefix since `0036`, and it is how five bins appeared this
-- afternoon, but it only ever creates them *onto a pick*. There was no way to
-- say "there are thirty of these in the shed" outside of picking fruit into
-- them, so the fleet gets registered in dribs during harvest, which is the
-- worst possible time.
--
-- **They do not differ, and the schema should stop pretending they might.** A
-- barrel has a maker, a toast, a year and a history worth arguing about. A
-- picking bin has a number written on the side. Sixty of them are sixty rows
-- that differ in one integer, and a form that asks about each one separately is
-- asking a question with no answer.
--
-- So: a count, a prefix, and who lent them if anybody did. Everything else is
-- taken from the stack that is already there, which is the same guess `0036`
-- makes and for the same reason: a stack of bins is a stack of one thing.

begin;

create or replace function register_bins(
  p_count        int,
  p_type_id      uuid    default null,
  p_name_prefix  text    default null,
  p_owner_id     uuid    default null,
  p_on_loan_from text    default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  prefix  text := btrim(coalesce(p_name_prefix, 'PB'));
  lender  text := nullif(btrim(coalesce(p_on_loan_from, '')), '');
  type_id uuid := p_type_id;
  bag     jsonb := '{}'::jsonb;
  next_n  int;
  cap     numeric;
  made    text[] := '{}';
  i       int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here registers bins'
      using errcode = 'insufficient_privilege';
  end if;

  if coalesce(p_count, 0) <= 0 then
    raise exception 'how many bins?';
  end if;
  -- The same ceiling add_bins_to_pick uses. Forty is more than anybody carries
  -- in one go and a mistyped count is the thing it is there to catch.
  if p_count > 40 then
    raise exception '% is not a number of bins to register at once', p_count;
  end if;
  if prefix = '' then
    raise exception 'new bins need something to be called';
  end if;

  -- The one picking bin type, if this winery has only one. Naming it every time
  -- is a question with one possible answer, which is R-4 in a form.
  if type_id is null then
    select t.id into type_id
      from term t
     where t.kind = 'vessel_type' and t.active
       and coalesce((t.attributes ->> 'intake_bin')::boolean, false)
     limit 2;
    if type_id is null then
      raise exception 'no picking bin type is registered, so there is nothing to make these as';
    end if;
    if (select count(*) from term t
         where t.kind = 'vessel_type' and t.active
           and coalesce((t.attributes ->> 'intake_bin')::boolean, false)) > 1 then
      raise exception 'this winery has more than one kind of picking bin, so say which';
    end if;
  end if;

  if not exists (
    select 1 from term
     where id = type_id and kind = 'vessel_type'
       and coalesce((attributes ->> 'intake_bin')::boolean, false)
  ) then
    raise exception 'that is not a picking bin type, so fruit is not weighed in it';
  end if;

  -- 0036's rule, unchanged: a bin is a named grower's or a party's, never both.
  if lender is not null and p_owner_id is not null then
    raise exception
      'a bin is either on loan from % or owned by a party here, and this says both', lender;
  end if;

  if lender is not null then
    bag := jsonb_build_object('borrowed', true, 'on_loan_from', lender);
  elsif p_owner_id is not null and p_owner_id is distinct from facility_party_id() then
    bag := jsonb_build_object('borrowed', true);
  end if;

  -- Carry on from the highest number already worn, rather than counting rows: a
  -- retired bin leaves a gap and reusing its number would put two objects under
  -- one name. Same rule as 0036, same reason.
  select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
    into next_n
    from vessel v
   where v.name ~ ('^' || prefix || '\s*\d+$');

  select v.capacity_l into cap
    from vessel v
   where v.type_id = type_id
   order by v.created_at desc
   limit 1;

  for i in 0 .. p_count - 1
  loop
    insert into vessel (id, type_id, name, capacity_l, owner_id, attributes)
    values (gen_random_uuid(), type_id, prefix || (next_n + i)::text, cap,
            p_owner_id, bag);
    made := made || (prefix || (next_n + i)::text);
  end loop;

  return jsonb_build_object(
    'registered', to_jsonb(made),
    'count',      p_count,
    'from',       prefix || next_n::text,
    'to',         prefix || (next_n + p_count - 1)::text);
end;
$$;

revoke all on function register_bins(int, uuid, text, uuid, text) from public;
grant execute on function register_bins(int, uuid, text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- What the shed holds
-- ---------------------------------------------------------------------------

-- Counted, not listed. "I'd rather just inventory": the useful facts about
-- sixty interchangeable objects are how many there are, how many are in use and
-- how many are somebody else's, and a list of sixty names answers none of them
-- without somebody doing arithmetic on a phone.
create or replace view bin_inventory with (security_invoker = true) as
select
  vt.id                as type_id,
  vt.label             as bin_type,
  coalesce(nullif(btrim(v.attributes ->> 'on_loan_from'), ''), p.name) as whose,
  coalesce((v.attributes ->> 'borrowed')::boolean, false) as borrowed,
  count(*)             as bins,
  count(*) filter (where pl.vessel_id is not null)     as in_use,
  count(*) filter (where pl.vessel_id is null)         as empty,
  min(v.capacity_l)    as capacity_l
from vessel v
join term vt on vt.id = v.type_id
  and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
left join party p on p.id = v.owner_id
left join placement pl on pl.vessel_id = v.id and pl.to_at is null
where v.active
group by vt.id, vt.label,
         coalesce(nullif(btrim(v.attributes ->> 'on_loan_from'), ''), p.name),
         coalesce((v.attributes ->> 'borrowed')::boolean, false);

comment on view bin_inventory is
  'Picking bins counted rather than listed, split by whose they are. The useful '
  'facts about sixty interchangeable objects are how many, how many are in use, '
  'and how many go back. See 0085.';

grant select on bin_inventory to authenticated;

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('cellar.bin_inventory', 'cellar', 'Picking bins',
   'How many bins there are, how many hold fruit, and how many are somebody else''s.',
   'bin_inventory', 'type_id', 'bin_type', 160)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.register_bins', 'cellar', 'Register a stack of bins',
   'A count and a prefix. Bins do not differ, so nothing is asked about them one '
   'at a time.',
   'register_bins', 'cellar.bin_inventory',
   '[{"key":"count","param":"p_count","type":"integer","required":true,
      "label":"How many"},
     {"key":"prefix","param":"p_name_prefix","type":"text","required":false,
      "label":"Called",
      "note":"PB by default. Numbering carries on from the highest already used."},
     {"key":"lender","param":"p_on_loan_from","type":"text","required":false,
      "label":"On loan from",
      "note":"A grower who lent them. Leave blank if they are this winery''s."}]'::jsonb, 250)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
