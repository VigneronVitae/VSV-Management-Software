-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "An invite code is a credential, so it comes from the random number
--           generator meant for credentials rather than the one meant for
--           shuffling rows."
-- Depends on: [supabase/migrations/0068_an_invite_to_claim.sql]
-- Depended on by: [tests/schema_assertions.sql]
-- Axioms enforced: A13 (a refusal indistinguishable from success: a guessable
--                  code refuses nobody while appearing to refuse everybody)
-- Open sorries: S-77 (unchanged)
-- ---------------------------------------------------------------------------
--
-- `0068` built the codes out of `random()`, which is a pseudo random sequence
-- seeded once per backend session. That is the right function for picking a
-- sample row and the wrong one for a credential: **anybody holding one code
-- issued by a session can work backwards toward the others issued by it.** A
-- winery hands an intern a cellar invite and issues an administrator invite the
-- same afternoon, quite possibly over the same pooled connection, which is
-- exactly the shape that attack wants.
--
-- `pgcrypto` is already installed, by Supabase, in `extensions`. This takes no
-- new dependency and adds no new surface. It is a three line change and the
-- reason it is its own migration rather than an edit to `0068` is that `0068`
-- is applied to the cellar already, and a migration that has run is history.
--
-- Six bytes, each masked to five bits. Thirty two divides two hundred and fifty
-- six exactly, so masking is unbiased and there is no modulo skew to argue
-- about: every character is equally likely, which is what makes the billion a
-- billion rather than a number with a shape.

begin;

create or replace function make_invite(
  p_role user_role default 'cellar',
  p_note text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no I, O, 0, 1
  bytes    bytea;
  code     text := '';
  i        int;
begin
  if not is_admin() then
    raise exception 'only an administrator lets somebody in';
  end if;

  -- Qualified rather than reached through search_path, which is pinned above
  -- and pinned on purpose: 0020 made every function in this schema say where
  -- it looks, and an extension in another schema is exactly the case that rule
  -- was written for.
  bytes := extensions.gen_random_bytes(6);
  for i in 1..6 loop
    code := code || substr(alphabet, 1 + (get_byte(bytes, i - 1) & 31), 1);
  end loop;

  insert into invite (code, role, note, created_by)
  values (code, p_role, nullif(btrim(coalesce(p_note, '')), ''), auth.uid());

  return jsonb_build_object('code', code, 'role', p_role,
                            'expires_at', now() + interval '7 days');
end;
$$;

revoke all on function make_invite(user_role, text) from public;
grant execute on function make_invite(user_role, text) to authenticated;

commit;
