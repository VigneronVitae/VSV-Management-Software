-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Record what the receiving tank reads now, rather than what came off
--           since last time, because the tank has a gauge on it and the press
--           does not."
-- Depends on: [supabase/migrations/0052_press_as_a_process.sql]
-- Depended on by: [tests/schema_assertions.sql, supabase/migrations/0057_the_contract.sql]
-- Axioms enforced: T0-2 (the increment is derived from what is already placed
--                  and is never a second stored number), AR-A3 (the arithmetic
--                  that turns a level into a draw is a rule, so it is here and
--                  not in a screen)
-- ---------------------------------------------------------------------------
--
-- The winemaker, on being offered three arrangements of the same form: "maybe
-- UX, even." Which is the harder and better version of the request. Three ways
-- of laying out one interaction is a comparison of nothing much; three ways of
-- working is a question worth answering.
--
-- **This is the second way of working.** `draw_cut` asks how much came off since
-- last time, which means somebody at a press doing subtraction in their head
-- against a number they last saw an hour ago. The tank has a sight glass on it.
-- Reading "the tank is at 450 now" is one number, read off a thing in front of
-- you, with no arithmetic and nothing to remember.
--
-- **The subtraction is a rule, so it lives here.** A screen that computed
-- `level - current` and called `draw_cut` would be a client encoding a kernel
-- rule, and the day a second client did the same subtraction slightly
-- differently the two would disagree about how much wine exists. The cost of
-- getting it wrong is a double-counted draw, which is invisible from every
-- screen.
--
-- **The cut is inferred rather than asked.** A vessel already holding a cut of
-- this press is receiving more of that cut: that is what a vessel holding wine
-- means. Asking again is a decision per entry that has exactly one right answer,
-- and the winemaker's own framing of the press was that the app should stop
-- asking things it can work out.

begin;

create or replace function draw_to_level(
  p_load_id   uuid,
  p_vessel_id uuid,
  p_level_l   numeric,
  p_cut_id    uuid default null,
  p_note      text default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  held      numeric;
  holder    uuid;
  cut_id    uuid := p_cut_id;
  increment numeric;
  v_name    text;
begin
  if p_level_l is null or p_level_l < 0 then
    raise exception 'a level of % is not a reading',
      coalesce(p_level_l::text, 'nothing');
  end if;

  select v.name into v_name from vessel v where v.id = p_vessel_id;
  if v_name is null then
    raise exception 'no vessel with id %', p_vessel_id;
  end if;

  select pl.volume_l, pl.node_id into held, holder
    from placement pl
   where pl.vessel_id = p_vessel_id and pl.to_at is null;
  held := coalesce(held, 0);

  -- Whatever is in there already, if it belongs to this press, is what is being
  -- topped up. A vessel holding somebody else's wine is refused by `draw_cut`
  -- further down, and this is not the place to say so twice.
  if holder is not null and cut_id is null then
    select (n.attributes ->> 'cut')::uuid into cut_id
      from node n
      join lineage l on l.child_id = n.id and l.parent_id = p_load_id
     where n.id = holder;
  end if;

  increment := p_level_l - held;

  -- **A level below what is already in the vessel is the interesting refusal.**
  -- It means either a misread gauge or wine having left the tank since, and
  -- neither is a draw. Silently recording a negative would be a subtraction
  -- nobody asked for; silently recording zero would be a success that did
  -- nothing, which A13 says must not look like a success that did something.
  if increment < 0 then
    raise exception
      '% already holds % L, so a reading of % L is not more wine arriving. Correct the earlier draw instead',
      v_name, held, p_level_l;
  end if;
  if increment = 0 then
    raise exception
      '% already reads % L, so nothing has come off since the last time this was recorded',
      v_name, held;
  end if;

  return draw_cut(p_load_id, p_vessel_id, increment, cut_id, null, p_note)
    || jsonb_build_object('was_at', held, 'now_at', p_level_l);
end;
$$;

revoke all on function draw_to_level(uuid, uuid, numeric, uuid, text) from public;
grant execute on function draw_to_level(uuid, uuid, numeric, uuid, text) to authenticated;

commit;
