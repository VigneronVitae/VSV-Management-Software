-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "How much is in a module is counted the same for everybody, because
--           a count that reads zero because of who is asking is a lie told
--           confidently."
-- Depends on: [supabase/migrations/0110_the_front_door_opens_before_you_sign_in.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: A25 (the null-permit class, in its counting form: a row you
--                  may not read counts as nothing rather than as unknown), A13
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- `0110` made the module list readable before sign-in and the front door drew
-- correctly. It also drew "Cellar: 0 things you can do, 0 things you can look
-- at" beside a module with 31 capabilities and 30 readables.
--
-- **The counts are subqueries over `readable` and `capability`, which are not
-- public.** Under an anonymous session those tables return no rows, so
-- `count(*)` returns 0 rather than failing, and 0 is a number a screen will
-- print without hesitation. This is A25 wearing different clothes: the usual
-- form is a null that permits, and this is an empty set that counts as nothing.
-- Both are cases where an absence caused by permission is indistinguishable
-- from an absence that is true.
--
-- Found by looking at the page. It could not have been found by reading the
-- view, because the view is correct for anybody who can read the contract, which
-- is everybody who was tested.
--
-- So the counting runs as the owner, and returns the same numbers to everybody.
-- What that exposes is how many capabilities a module has, which is a shape
-- rather than a secret: not their names, not what they do, not a single row of
-- anybody's wine. The alternative was granting the whole contract to anonymous
-- sessions, which is a much wider door for a much smaller reason.

begin;

create or replace function module_contract_size(p_module text)
returns table (readables bigint, capabilities bigint)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select
    (select count(*) from readable r where r.module = p_module),
    (select count(*) from capability c where c.module = p_module);
$$;

comment on function module_contract_size(text) is
  'How many readables and capabilities a module owns, counted as the owner so '
  'the answer does not depend on who is asking. See 0111.';

revoke all on function module_contract_size(text) from public;
grant execute on function module_contract_size(text) to anon, authenticated;

create or replace view module_detail with (security_invoker = true) as
select
  m.key,
  m.label,
  m.note,
  m.path,
  m.sort_order,
  (m.path is not null) as openable,
  size.readables,
  size.capabilities
from module m
cross join lateral module_contract_size(m.key) size
where m.active
order by m.sort_order, m.label;

comment on view module_detail is
  'The modules, with how much of the contract each one owns, counted the same '
  'for everybody. The front door draws itself from this before anybody has '
  'signed in. See 0109, 0110 and 0111.';

grant select on module_detail to anon, authenticated;

-- Not a capability. It answers how big a module is, which arrives on every
-- module_detail row; a periphery calling it directly would be a screen doing the
-- view's job.
insert into capability_exemption (fn, reason) values
  ('module_contract_size', 'Counts what a module owns in the contract, as the owner so the answer does not depend on who is asking. Arrives on every module_detail row.')
on conflict (fn) do nothing;

commit;
