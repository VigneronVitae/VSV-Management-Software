-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A wine says whether it is red, orange, rose or white, because that
--           is the fact a barrel's own colour is derived from and no other
--           field in the schema can answer it."
-- Depends on: [supabase/migrations/0027_term_kind_registry.sql,
--              supabase/migrations/0049_every_lot_says_its_vintage.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0072_a_barrel_remembers.sql,
--                  supabase/migrations/0073_the_contract_hears_about_colour.sql,
--                  supabase/migrations/0074_an_unknown_colour_is_not_a_safe_one.sql,
--                  supabase/migrations/0075_two_parents_that_disagree.sql,
--                  supabase/migrations/0078_the_wine_in_a_vessel.sql]
-- Axioms enforced: T0-2 (a child's colour is derived from its parents rather
--                  than copied down the lineage), AR-E6 and AR-E7 (the colours
--                  are registry rows, so a fifth one is an insert)
-- Open sorries: S-10 (tax class, which is the other half of what the winemaker
--                asked for and is blocked on the compliance advisor)
-- ---------------------------------------------------------------------------
--
-- The winemaker asked for red and white barrels, and then said the better
-- answer: *"obviously this is something we are missing in the wine type, which
-- should be red/orange/rose/white"*. He is right, and it is the difference
-- between a property of a barrel and a fact about a wine that a barrel's own
-- state is derived from.
--
-- **Variety cannot answer this.** Five of the six varieties here are white and
-- Pinot Noir is the sixth, and Pinot Noir is made as a red, a rose and a blanc
-- de noir, sometimes in the same vintage from the same block. Guessing from the
-- variety would be right most of the time, which is the worst available
-- behaviour: a rose lot silently typed red would stain the record of a barrel
-- that is still perfectly good for white.
--
-- **Staining lives on the vocabulary, not in a function.** `red` carries
-- `{"stains": true}` and the others do not, so the rule a later function asks is
-- "does this colour stain", answered by a row. A fifth colour is an insert and a
-- change of mind about orange is an update. **Orange is set not to stain and
-- that is a guess**, from skin contact on white grapes carrying tannin and
-- almost no anthocyanin. It is one `update term` away if the winemaker says
-- otherwise, which is the whole reason it is a row.
--
-- **Colour is told once and inherited after that.** A press cut of a red lot is
-- red, and so is everything racked out of it. Copying the value down the lineage
-- at each step would be storing what is derived, which is C-3, so the column
-- holds only what somebody said and `lot_colour` resolves the rest by walking
-- up. Saying it on the pick is enough for every lot that ever comes off it.

begin;

insert into term_kind (kind, module, label, sort_order) values
  ('wine_colour', 'cellar', 'Colour', 60)
on conflict (kind) do nothing;

insert into term (kind, value, label, sort_order, attributes) values
  ('wine_colour', 'red',    'Red',    10, '{"stains": true}'::jsonb),
  ('wine_colour', 'orange', 'Orange', 20, '{"stains": false}'::jsonb),
  ('wine_colour', 'rose',   'Rose',   30, '{"stains": false}'::jsonb),
  ('wine_colour', 'white',  'White',  40, '{"stains": false}'::jsonb)
on conflict (kind, value) do nothing;

-- Nullable, unlike vintage. A lot with no colour yet refuses nothing and blocks
-- nothing: it turns up in a worklist and it is asked for at the one moment it
-- matters, which is the moment it meets a barrel. T1-4, intake fast before
-- complete, and 0049 is the precedent for the worklist.
alter table node add column if not exists colour_id uuid;
alter table node add column if not exists colour_kind text
  generated always as ('wine_colour'::text) stored;

do $$ begin
  alter table node add constraint node_colour_is_a_wine_colour
    foreign key (colour_id, colour_kind) references term (id, kind);
exception when duplicate_object then null;
end $$;

comment on column node.colour_id is
  'What somebody said this wine is. Null means nobody has said yet, which is not '
  'the same as white. Read lot_colour rather than this column: a child inherits '
  'from its parents and only the told value is stored. See 0071.';

-- ---------------------------------------------------------------------------
-- Told, then inherited
-- ---------------------------------------------------------------------------

-- Up the lineage, breadth first, taking the first told colour. A blend of a red
-- and a white parent is the case this cannot answer, so it does not: two
-- different told colours above a lot leave it untold, and it appears in the
-- worklist for somebody to settle. Guessing "red wins" would be inventing a
-- winemaking rule rather than reading one.
create or replace function lot_colour(p_node_id uuid)
returns uuid
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  with recursive up as (
    select n.id, n.colour_id, 0 as depth
      from node n where n.id = p_node_id
    union all
    select p.id, p.colour_id, up.depth + 1
      from up
      join lineage l on l.child_id = up.id
      join node p on p.id = l.parent_id
     where up.colour_id is null and up.depth < 20
  ),
  told as (
    select distinct on (depth) depth, colour_id
      from up where colour_id is not null
     order by depth, colour_id
  ),
  shallowest as (
    select depth from told order by depth limit 1
  )
  select t.colour_id from told t
   where t.depth = (select depth from shallowest)
     -- One told colour at that depth, or none at all. Two parents that disagree
     -- are a question, not an answer.
     and (select count(distinct colour_id) from told where depth = t.depth) = 1
   limit 1;
$$;

comment on function lot_colour(uuid) is
  'The colour of a lot: what somebody said, or what its parents said if nobody '
  'has said about this one. Null when nobody has said and when two parents '
  'disagree. See 0071.';

create or replace function colour_stains(p_colour_id uuid)
returns boolean
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
  select coalesce((attributes ->> 'stains')::boolean, false)
    from term where id = p_colour_id and kind = 'wine_colour';
$$;

comment on function colour_stains(uuid) is
  'Whether wine of this colour leaves colour in oak. A property of the '
  'vocabulary rather than a list in a function, so a fifth colour is an insert.';

create or replace function set_colour(p_node_id uuid, p_colour text)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  n   node%rowtype;
  cid uuid;
begin
  select * into n from node where id = p_node_id;
  if n.id is null then
    raise exception 'no lot with id %', p_node_id;
  end if;

  if p_colour is null or btrim(p_colour) = '' then
    raise exception 'say which colour this wine is';
  end if;

  select id into cid from term
   where kind = 'wine_colour' and value = lower(btrim(p_colour)) and active;
  if cid is null then
    raise exception '% is not a colour this winery records', p_colour;
  end if;

  update node set colour_id = cid where id = p_node_id;

  return jsonb_build_object(
    'id', p_node_id,
    'colour', lower(btrim(p_colour)),
    'left', (select count(*) from lot_without_colour));
end;
$$;

revoke all on function set_colour(uuid, text) from public;
grant execute on function set_colour(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- The worklist, which is how this is caught rather than refused
-- ---------------------------------------------------------------------------

-- Only what is worth asking about. A picking bin has no colour question and a
-- closed lot is finished, so neither belongs on a list somebody is meant to
-- clear. The name is the same shape as `lot_without_vintage` on purpose: these
-- two screens are the same screen.
create or replace view lot_without_colour with (security_invoker = true) as
select
  n.id,
  n.name,
  n.stage,
  n.status,
  n.created_at,
  v.label as variety,
  -- Offered, never written, exactly as 0049 offers a vintage. Five of six
  -- varieties here are white and the sixth is made three ways, so this is a
  -- starting point for a person and never a value the database chose.
  case when v.value = 'pinot_noir' then null else 'white' end as likely
from node n
left join term v on v.id = n.variety_id
where n.colour_id is null
  and lot_colour(n.id) is null
  and n.status <> 'closed'
  and n.stage <> 'bin'
order by n.created_at desc;

comment on view lot_without_colour is
  'Lots nobody has said a colour for, and whose parents have not said either. '
  'The catching mechanism for 0071: nothing refuses a lot with no colour, so '
  'this list is what stops one being forgotten. See 0072 for why it matters.';

grant select on lot_without_colour to authenticated;

commit;
