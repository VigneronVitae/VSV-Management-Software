-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "register_bins names its local variable want_type, because type_id
--           is also a column on the table it queries and Postgres cannot tell
--           which one was meant."
-- Depends on: [supabase/migrations/0085_a_stack_of_bins_is_inventory.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: none. This is a defect fix.
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0085` declared `type_id uuid` and then asked
-- `where v.type_id = type_id`, which raises `column reference "type_id" is
-- ambiguous` the first time the line runs. The function was written, granted,
-- declared in the contract and applied to the cellar without anybody calling
-- it, and the assertion written half an hour later called it and found this
-- immediately.
--
-- **This is the same class as the `where code = code` in the assertion suite
-- two sessions ago**, and it is worth naming as a class rather than fixing
-- twice in silence: a plpgsql variable sharing a name with a column of a table
-- in the same statement is either an ambiguity error or, where Postgres picks
-- one, a silent wrong answer. The suite's version resolved in favour of the
-- column and made an assertion that checked nothing. This one raised, which is
-- the better of the two outcomes and still a defect.

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
  prefix    text := btrim(coalesce(p_name_prefix, 'PB'));
  lender    text := nullif(btrim(coalesce(p_on_loan_from, '')), '');
  -- Not type_id. See the header.
  want_type uuid := p_type_id;
  bag       jsonb := '{}'::jsonb;
  next_n    int;
  cap       numeric;
  made      text[] := '{}';
  i         int;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here registers bins'
      using errcode = 'insufficient_privilege';
  end if;

  if coalesce(p_count, 0) <= 0 then
    raise exception 'how many bins?';
  end if;
  if p_count > 40 then
    raise exception '% is not a number of bins to register at once', p_count;
  end if;
  if prefix = '' then
    raise exception 'new bins need something to be called';
  end if;

  if want_type is null then
    select t.id into want_type
      from term t
     where t.kind = 'vessel_type' and t.active
       and coalesce((t.attributes ->> 'intake_bin')::boolean, false)
     limit 2;
    if want_type is null then
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
     where id = want_type and kind = 'vessel_type'
       and coalesce((attributes ->> 'intake_bin')::boolean, false)
  ) then
    raise exception 'that is not a picking bin type, so fruit is not weighed in it';
  end if;

  if lender is not null and p_owner_id is not null then
    raise exception
      'a bin is either on loan from % or owned by a party here, and this says both', lender;
  end if;

  if lender is not null then
    bag := jsonb_build_object('borrowed', true, 'on_loan_from', lender);
  elsif p_owner_id is not null and p_owner_id is distinct from facility_party_id() then
    bag := jsonb_build_object('borrowed', true);
  end if;

  select coalesce(max((regexp_match(v.name, '^' || prefix || '\s*(\d+)$'))[1]::int), 0) + 1
    into next_n
    from vessel v
   where v.name ~ ('^' || prefix || '\s*\d+$');

  select v.capacity_l into cap
    from vessel v
   where v.type_id = want_type
   order by v.created_at desc
   limit 1;

  for i in 0 .. p_count - 1
  loop
    insert into vessel (id, type_id, name, capacity_l, owner_id, attributes)
    values (gen_random_uuid(), want_type, prefix || (next_n + i)::text, cap,
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

commit;
