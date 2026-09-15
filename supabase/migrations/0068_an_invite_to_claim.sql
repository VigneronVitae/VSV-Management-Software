-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Claiming an account needs something only somebody already here can
--           hand out, so that reaching the sign-up page stops being the same
--           thing as working here."
-- Depends on: [supabase/migrations/0022_admission_and_authorship.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0069_the_contract_hears_about_the_invite.sql,
--                  supabase/migrations/0070_a_code_worth_guessing.sql,
--                  docs/getting-somebody-else-on-it.md]
-- Axioms enforced: A7 and A11 (the admission surface: who may become somebody
--                  this winery trusts)
-- Open sorries: S-77 (the keys are still Supabase's published demo keys, and
--                this migration is worth nothing until that is answered)
-- ---------------------------------------------------------------------------
--
-- The winemaker: "how could I do this so my interns don't need to download an
-- app besides the vitae springs app?"
--
-- The app is already the answer to that half: it is a progressive web app, and
-- an intern adds it to their home screen from a browser. What stands in the way
-- is that the only route to it is Tailscale, which is itself an app they would
-- have to install and which would put them on his network. Getting off Tailscale
-- means being reachable from the internet, and **two separate things make that
-- unsafe today**.
--
-- S-77 is the first and this migration does nothing about it: the keys are the
-- ones in Supabase's public documentation.
--
-- S-78 is this one. `enable_signup` is true and `claim_account` hands a `cellar`
-- role to any identity that asks, which `is_facility_user()` reads as somebody
-- who works here. On a private tailnet that is exactly right and it is why it
-- was built that way: handing a phone to a new intern should not need an
-- administrator. Reachable from the internet it means anybody signs up and reads
-- both custom crush clients' wine.
--
-- **The fix keeps the good half.** An administrator creates an invite, which is
-- a short code they read out or send; the intern signs up and claims with it.
-- No email round trip, because a winery hands somebody a phone in a barn rather
-- than asking them to check their inbox, and because email delivery is a service
-- this project would have to take a dependency on.
--
-- **First run still works without one.** A fresh install has nobody to issue an
-- invite, so the first claim needs none and becomes the administrator, which is
-- what `0005` established and what the assertions have checked ever since. The
-- gate applies from the second person onwards, which is exactly when there is
-- somebody able to open it.

begin;

create table if not exists invite (
  -- Short, readable over a noisy crush pad, and not guessable in the numbers
  -- that matter: six characters from an alphabet of thirty two is a billion,
  -- against a handful of live invites at a time.
  code       text primary key,
  -- What they will be when they claim it. An invite for an intern says cellar
  -- and an invite for a second winemaker says admin, and that decision is made
  -- when the invite is written rather than afterwards.
  role       user_role not null default 'cellar',
  note       text,
  created_by uuid references app_user (id),
  created_at timestamptz not null default now(),
  -- An invite nobody used is not evidence of anything, so it may be withdrawn.
  -- A used one is: it says who joined and on whose say-so, which is why using
  -- one stamps it rather than deleting it.
  used_by    uuid references app_user (id),
  used_at    timestamptz,
  expires_at timestamptz not null default now() + interval '7 days',
  constraint invite_code_is_long_enough check (length(code) >= 6)
);

comment on table invite is
  'Permission to become somebody this winery trusts, handed out by somebody it '
  'already does. Used rather than deleted, because who let somebody in is worth '
  'keeping. See 0068 and S-78.';

alter table invite enable row level security;

-- Only an administrator sees or writes them. An invite is a credential and a
-- cellar hand reading the list could admit their own second account.
drop policy if exists invite_admin on invite;
create policy invite_admin on invite for all to authenticated
  using (is_admin()) with check (is_admin());

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
  code     text := '';
  i        int;
begin
  if not is_admin() then
    raise exception 'only an administrator lets somebody in';
  end if;

  for i in 1..6 loop
    code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;

  insert into invite (code, role, note, created_by)
  values (code, p_role, nullif(btrim(coalesce(p_note, '')), ''), auth.uid());

  return jsonb_build_object('code', code, 'role', p_role,
                            'expires_at', now() + interval '7 days');
end;
$$;

revoke all on function make_invite(user_role, text) from public;
grant execute on function make_invite(user_role, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Claiming, with the gate
-- ---------------------------------------------------------------------------

-- Taken from the catalog and changed in the two places it needed changing,
-- rather than retyped. That rule was earned by 0027 and paid for again by 0040.
create or replace function claim_account(p_name text, p_invite text default null)
returns app_user
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  u         app_user;
  is_first  boolean;
  inv       invite;
  want_role user_role;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = 'insufficient_privilege';
  end if;

  select * into u from app_user where id = auth.uid();
  if found then
    return u;
  end if;

  -- Two people signing up in the same second would both read an empty table and
  -- both become admin. The window is small and the consequence is a second
  -- unintended admin, so it is cheaper to close it than to explain it.
  perform pg_advisory_xact_lock(hashtext('claim_account'));

  select count(*) = 0 into is_first from app_user;

  if is_first then
    -- A fresh install has nobody to issue an invite. This is the one claim that
    -- needs none, and it is the one that creates the person who issues the rest.
    want_role := 'admin';
  else
    if p_invite is null or btrim(p_invite) = '' then
      raise exception
        'somebody here has to let you in. Ask for an invite code and sign up with it'
        using errcode = 'insufficient_privilege';
    end if;

    select * into inv from invite
     where code = upper(btrim(p_invite));

    if inv.code is null then
      raise exception 'that invite code is not one of ours'
        using errcode = 'insufficient_privilege';
    end if;
    if inv.used_at is not null then
      raise exception 'that invite has already been used, by somebody else'
        using errcode = 'insufficient_privilege';
    end if;
    if inv.expires_at < now() then
      raise exception 'that invite has expired; ask for another'
        using errcode = 'insufficient_privilege';
    end if;

    want_role := inv.role;
  end if;

  insert into app_user (id, name, role)
  values (auth.uid(), p_name, want_role)
  returning * into u;

  -- Stamped rather than deleted. Who let somebody in is worth keeping, and it is
  -- the only record of it there will ever be.
  if not is_first then
    update invite set used_by = u.id, used_at = now() where code = inv.code;
  end if;

  return u;
end;
$$;

revoke all on function claim_account(text, text) from public;
grant execute on function claim_account(text, text) to authenticated;

-- The old one-argument signature would still satisfy every existing caller and
-- would be a way past the gate, which is the whole point of the gate. Dropped
-- rather than left: 0036 taught that a second signature is a call nobody can
-- choose between, and here it would be a call that skips a credential check.
drop function if exists claim_account(text);

commit;
