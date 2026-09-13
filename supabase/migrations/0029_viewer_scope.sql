-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Answers what the caller is entitled to see, so that a client can say
--           'nothing here that is yours' instead of 'nothing here', and can stop
--           deciding for itself who is staff."
-- Depends on: [supabase/migrations/0003_parties_and_products.sql,
--              supabase/migrations/0005_account_and_walk.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: R-4, a client may not encode a business rule. AR-E10, in the
--                  sense that this reports standing and never existence.
-- Open sorries: none.
-- ---------------------------------------------------------------------------
--
-- W-8 found that a refusal reaches a person in three different ways. A kernel
-- raise arrives intact and in the kernel's own voice. A row level security denial
-- on a write arrives as `new row violates row-level security policy for table
-- "party"`. A denial on a read arrives as nothing at all, because a policy has no
-- message to carry.
--
-- The third is the hard one and it cannot be solved by asking about the rows. A
-- second query to check whether something exists discloses that it exists, which
-- is what AR-E10 has just ruled out. A count endpoint under different policies is
-- two sources of truth for one question. Encoding the answer in the policy set
-- couples every screen to the policy list.
--
-- So this does not answer "was I refused". **It answers what the caller is, and
-- lets emptiness be read in that light.** An empty result plus a known standing
-- is a complete and true statement: there is nothing here that you are entitled
-- to see. That is weaker than naming what was withheld, and naming it is the
-- thing that must not be built, so the weaker statement is the honest ceiling
-- rather than a compromise.
--
-- It discloses nothing. Every field is about the caller, who already knows all of
-- it. A caller learns their own role and their own party and no fact about any
-- lot, any vessel or any other party.
--
-- The second reason this is in the kernel rather than the client is ledger B10.
-- `walk.ts` decides who may reach which screen by reading `app_user.role` and
-- comparing it to the string `admin`, which reimplements `is_admin()` and drops
-- its `active` conjunct, so a deactivated account reaches every screen. That is
-- the R-4 class exactly: a rule the kernel owns, copied into a client, and drifting.
-- `sees` and `may_admin` below are the kernel's own answer to the same question,
-- and the client asks instead of remembering.
--
-- Written in SQL rather than plpgsql on purpose. It has no branches to get wrong
-- and therefore no refusal sites, which keeps it out of the W-7 surface it would
-- otherwise be added to for no gain.

begin;

create or replace function viewer_scope()
returns table (
  signed_in   boolean,
  account     boolean,   -- there is an app_user row and it is active
  role        text,
  party_id    uuid,
  party_name  text,
  party_kind  text,
  may_admin   boolean,
  -- 'everything' staff, who see the cellar they work in
  -- 'own'        a client party, who see the wine they own
  -- 'nothing'    signed in with no usable account: no row, or deactivated
  sees        text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    auth.uid() is not null,
    exists (select 1 from app_user u where u.id = auth.uid() and u.active),
    (select u.role::text from app_user u where u.id = auth.uid() and u.active),
    p.id, p.name, p.kind::text,
    is_admin(),
    case
      when is_facility_user() then 'everything'
      when p.id is not null then 'own'
      else 'nothing'
    end
  from (select 1) one
  left join party p on p.app_user_id = auth.uid() and p.active;
$$;

comment on function viewer_scope() is
  'What the caller is entitled to see. Reports standing, never existence: every '
  'field is a fact about the caller, who already knows it. See 0029 and AR-E10.';

grant execute on function viewer_scope() to authenticated, anon;

commit;
