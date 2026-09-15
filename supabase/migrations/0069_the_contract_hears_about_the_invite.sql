-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Declare `make_invite` in the contract, because a periphery that
--           cannot let somebody in is a periphery only one person can start."
-- Depends on: [supabase/migrations/0057_the_contract.sql,
--              supabase/migrations/0068_an_invite_to_claim.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: AR-Q8 (the interface is periphery over a read and write
--                  contract, so anything a person can do is declared once)
-- Open sorries: S-77 (unchanged, and still the thing that makes 0068 worth
--                nothing until it is answered)
-- ---------------------------------------------------------------------------
--
-- 0068 added a callable function and said nothing to the contract, and the
-- contract's reverse check caught it inside the same hour. That check has now
-- found four things: a relation that did not exist, a missing column, twenty
-- nine undeclared functions, and this. It is the cheapest apparatus in the repo.
--
-- **Why declared and not exempt.** `claim_account` sits in the exemption list
-- for a bootstrap reason: there is no caller yet to have capabilities. This one
-- has a caller, an administrator, and issuing an invite is a thing somebody
-- genuinely does. A second periphery that cannot hand out an invite is one only
-- the person who set it up can ever use, which is the opposite of what a
-- contract is for.
--
-- **The first module that is not `cellar`.** Admission is core: it says who
-- works at this winery rather than what happened to its wine, and a later
-- `cases` or `sales` module would want the same invite rather than its own.

begin;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('core.make_invite', 'core', 'Let somebody in',
   'A code somebody types when they sign up. Six characters, good for a week, '
   'usable once. Only an administrator can make one.',
   'make_invite', null,
   -- Both parameters carry defaults in the kernel, so both are optional here.
   -- The contract may be stricter than the kernel and never looser, which is
   -- asserted, and there is no reason to be stricter: an invite for a cellar
   -- hand with no note is the common case and it should be one tap.
   '[{"key":"role","param":"p_role","type":"text","required":false,
      "label":"What they will be",
      "note":"cellar for somebody who works here, admin for somebody who can also let others in."},
     {"key":"note","param":"p_note","type":"text","required":false,
      "label":"Who is it for",
      "note":"So that a code sitting unused in a month still means something."}]'::jsonb,
   900)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
