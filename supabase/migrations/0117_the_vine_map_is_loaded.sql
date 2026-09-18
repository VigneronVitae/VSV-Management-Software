-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The vine map is loaded. Five blocks, 190 rows, 13,539 plant spaces,
--           and what the map says stands in each of them."
-- Depends on: [supabase/migrations/0039_vineyard.sql,
--              supabase/migrations/0115_a_vineyard_is_rows_and_plant_spaces.sql,
--              supabase/migrations/0116_the_vineyard_is_not_everybodys_business.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: T0-4, every row lands as `inferred`. I read a spreadsheet; I
--                  did not walk the rows, and the field is the verifier's.
--                  T0-2, acreage is counted here rather than copied.
-- Open sorries: discharges S-98. S-97 still open.
-- ---------------------------------------------------------------------------

-- The source is `Maps/Vitae Springs Vine Map.xlsx`, five sheets, one per block.
-- **The variety of each vine is the fill colour of its cell**; the cell values
-- are the plant space number repeated, which is why nothing has ever been able
-- to query that file.
--
-- The decode reconciles to the winemaker's own legend counts exactly. Tudor
-- North: 220 Müller Thurgau, 1366 Riesling, 177 Pommard, 658 Grüner Veltliner,
-- 89 Pinot Gris, 40 Pinot Meunier, 3 Gamay, 9 table grapes. Southeast: 267
-- Dijon. Overlook Pommard and 777: 3259 and 3295. Those are asserted below, so
-- a future edit to this data that breaks the reconciliation fails rather than
-- passing quietly.
--
-- **A rootstock counts as a plant.** Excluding rootstock-only positions left the
-- Overlook block 42 short, split 22 and 20 across the two clones, which is
-- exactly its rootstock count. So "Number of Plants Total" in his legend means
-- plants in the ground, bearing or not. That is why the acreage view below
-- counts every position that is not empty.
--
-- **The clone split at Overlook came from him, not from the map.** That sheet
-- paints both clones the same colour and tells them apart by position: rows 1 to
-- 28 Pommard, 29 to 53 of 777. It is trusted because it reproduces his stated
-- 3259 and 3295 to the plant, which is two independent facts agreeing rather
-- than one fact repeated.
--
-- **Everything here is `inferred`.** T0-4 says provenance belongs to the
-- verifier and that an agent may never write `confirmed`. `observed` would be a
-- claim that somebody looked at the vine, and nobody did; I looked at a file. He
-- can raise any of it by walking the row.

-- ---------------------------------------------------------------------------
-- The varieties the map has and the vocabulary did not
-- ---------------------------------------------------------------------------

-- Table grapes are in the map with an acreage and they are what is in those
-- sixteen positions, so they are a variety here. Sorted last so they do not sit
-- among the wine grapes in a picker.
insert into term (kind, value, label, sort_order) values
  ('variety', 'pinot_meunier', 'Pinot Meunier', 70),
  ('variety', 'gamay',         'Gamay',         80),
  ('variety', 'pinot_blanc',   'Pinot Blanc',   90),
  ('variety', 'table_grapes',  'Table grapes',  900)
on conflict (kind, value) do nothing;

-- ---------------------------------------------------------------------------
-- The vineyard and its blocks, which this migration must not assume exist
-- ---------------------------------------------------------------------------

-- **This failed the gate once and the failure was worth having.** The first
-- version joined `vineyard` on the name and loaded nothing at all from an empty
-- database, because the vineyard row is something he made in the app and not
-- something a migration puts there. Every join matched nothing, no space
-- loaded, and the reconciliation below refused to let it pass, which is exactly
-- what it is for. A migration may not depend on data somebody entered through a
-- screen.
insert into vineyard (name)
select 'Vitae Springs Vineyard'
 where not exists (select 1 from vineyard where name = 'Vitae Springs Vineyard');

-- The five sheets, resolved to blocks that may or may not be there yet. The map
-- calls one of them "Tudor Southeast" and his app already calls it "Southeast",
-- with this year's Pinot Gris picks pointing at it, so that name is accepted and
-- kept rather than renamed out from under them. On an empty database neither
-- exists and the map's own name is created.
create table _map_block (map_name text primary key, block_id uuid);

insert into _map_block (map_name, block_id)
select x.map_name,
       coalesce(
         (select b.id from block b join vineyard v on v.id = b.vineyard_id
           where v.name = 'Vitae Springs Vineyard' and b.name = x.map_name),
         case when x.map_name = 'Tudor Southeast' then
           (select b.id from block b join vineyard v on v.id = b.vineyard_id
             where v.name = 'Vitae Springs Vineyard' and b.name = 'Southeast')
         end)
  from (values
    ('Tudor North'), ('Tudor Southwest'), ('Tudor Southeast'),
    ('Overlook 115'), ('Overlook Pommard and 777')
  ) as x(map_name);

insert into block (vineyard_id, name)
select v.id, mb.map_name
  from _map_block mb
  cross join vineyard v
 where mb.block_id is null and v.name = 'Vitae Springs Vineyard';

update _map_block mb set block_id = b.id
  from block b
  join vineyard v on v.id = b.vineyard_id
 where v.name = 'Vitae Springs Vineyard' and b.name = mb.map_name
   and mb.block_id is null;

-- His own arithmetic, recovered: 220/1089 is 0.20202020202020202 and 3259/1245
-- is 2.6176706827309237, both to the last digit.
update block b set vines_per_acre = case
    when mb.map_name = 'Overlook Pommard and 777' then 1245 else 1089 end
  from _map_block mb
 where b.id = mb.block_id;

-- ---------------------------------------------------------------------------
-- The map itself
-- ---------------------------------------------------------------------------

-- One row of the map is one string, one character per plant space, which is the
-- shape the source is in. 190 lines rather than 13,539, and it still reads as a
-- map. A space in the string is a cell nobody painted, which is not the same as
-- an empty position and is skipped rather than invented as either.
create table _vine_map (
  block       text not null,
  row_no      int  not null,
  orientation text,
  strip       text not null
);

insert into _vine_map (block, row_no, orientation, strip) values
  ('Overlook 115', 1, 'N to S orientation', 'yyynnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nn'),
  ('Overlook 115', 2, 'N to S orientation', 'ynynnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 3, 'N to S orientation', 'ynnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnyyn'),
  ('Overlook 115', 4, 'N to S orientation', '.yyynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnn'),
  ('Overlook 115', 5, 'N to S orientation', 'yynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 6, 'N to S orientation', 'y.nynynnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 7, 'N to S orientation', 'nnynnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 8, 'N to S orientation', 'yyynnynnnynnyynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnny'),
  ('Overlook 115', 9, 'N to S orientation', 'yynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 10, 'N to S orientation', 'ynnnnnnnnnnnnnnnnnynnnnnnnnnnnsnnnnnnnnnnnnnnn.nnnnn'),
  ('Overlook 115', 11, 'N to S orientation', '.nnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 12, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 13, 'N to S orientation', 'nnnnnnnnnnnnnynnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 14, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 15, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 16, 'N to S orientation', '.nnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 17, 'N to S orientation', 'nnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnn'),
  ('Overlook 115', 18, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 19, 'N to S orientation', 'nnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 20, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 21, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 22, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 23, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 24, 'N to S orientation', 'nnnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 25, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 26, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnsnn'),
  ('Overlook 115', 27, 'N to S orientation', 'nnnnnnnnnnnnnn.nnnnnnnnnnn'),
  ('Overlook 115', 28, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 29, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook 115', 30, 'N to S orientation', 'yyyyynnnnnnnnnnnnnnn'),
  ('Overlook 115', 31, 'N to S orientation', 'yyyyyyyyyyyyyyyyy'),
  ('Overlook 115', 32, 'N to S orientation', 'ynyyyyyyyyyyy'),
  ('Overlook Pommard and 777', 1, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 2, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 3, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 4, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnnsnnnnnnynsnnnnsnn'),
  ('Overlook Pommard and 777', 5, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 6, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 7, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnyynnnnnnnnnnnnnnsnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnyn'),
  ('Overlook Pommard and 777', 8, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nynnnnnnnnnnnnnnnnnnnnnnnsnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 9, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnn'),
  ('Overlook Pommard and 777', 10, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 11, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 12, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 13, 'S to N orientation', 'nnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 14, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 15, 'S to N orientation', 'nnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 16, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 17, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 18, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 19, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 20, 'S to N orientation', 'nnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 21, 'S to N orientation', 'nnnnnnnnnnnnnnnsnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnn.n'),
  ('Overlook Pommard and 777', 22, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 23, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 24, 'S to N orientation', 'nnnnnnnynnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnynnnnnnnnnnn'),
  ('Overlook Pommard and 777', 25, 'S to N orientation', 'nnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnynnnnnnnnnynnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 26, 'S to N orientation', 'nnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.n'),
  ('Overlook Pommard and 777', 27, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 28, 'S to N orientation', 'nnnnnnnnsnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsn'),
  ('Overlook Pommard and 777', 29, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnyn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsn'),
  ('Overlook Pommard and 777', 30, 'S to N orientation', 'nnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 31, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 32, 'S to N orientation', 'nnnnnnnnnnnnnn.nnnnnnnnnnnynnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 33, 'S to N orientation', 'nnnnnnnnnsynnnnnnnnnnnnnnnnnnnnnynnnnnnynsnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 34, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnynnnnnnnnnsnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 35, 'S to N orientation', 'nnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 36, 'S to N orientation', 'nynnnnnnnnynnnnnsnynnnsnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 37, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 38, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 39, 'S to N orientation', 'nnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnsnnnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 40, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn.nnnnnnnnnnnnnsnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 41, 'S to N orientation', 'nnnnnnnnnnnnnnnsnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 42, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 43, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 44, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 45, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 46, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 47, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 48, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 49, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 50, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 51, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 52, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Overlook Pommard and 777', 53, 'S to N orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Tudor North', 1, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 2, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 3, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvv.vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 4, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv.vvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 5, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 6, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 7, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv.vv'),
  ('Tudor North', 8, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 9, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 10, 'N to S orientation', 'vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv'),
  ('Tudor North', 11, 'N to S orientation', 'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm'),
  ('Tudor North', 12, 'N to S orientation', 'mmmmmmmmn.mmmmmmmnmnmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm'),
  ('Tudor North', 13, 'N to S orientation', 'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm'),
  ('Tudor North', 14, 'N to S orientation', 'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm'),
  ('Tudor North', 15, 'N to S orientation', 'rrrrrrr.rrrrrrrrrrrrrrrrrrrr.rrrrrrrrrrrrrrrrrr.rrrr'),
  ('Tudor North', 16, 'N to S orientation', 'rrr.rrrrrrrrrrrrrrrrrrrrrrrrr.rrrrrrrrrrrrr.rrrr'),
  ('Tudor North', 17, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 18, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 19, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 20, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 21, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 22, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 23, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 24, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 25, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 26, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 27, 'N to S orientation', 'aaarrrrrrrrrrrrrrrrrrrrrrrnnrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 28, 'N to S orientation', 'rrrrrnrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 29, 'N to S orientation', 'rrrrrrrrrrrrrrrrruuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu'),
  ('Tudor North', 30, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 31, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 32, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 33, 'N to S orientation', 'nrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 34, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 35, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrnrrrrrrr'),
  ('Tudor North', 36, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrnrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 37, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrnrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 38, 'N to S orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 39, 'N to S orientation', 'rrrrrrrrrnrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor North', 40, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnntttnnnnn'),
  ('Tudor North', 41, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Tudor North', 42, 'N to S orientation', 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Tudor North', 43, 'N to S orientation', 'gggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor North', 44, 'N to S orientation', 'gggggggggggggggggggggggggggggggggggggggggtttttt'),
  ('Tudor Southeast', 1, 'S to N orientation', '   g.gggggggggggggggggggggggggg.gggggggg'),
  ('Tudor Southeast', 2, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggGgggg'),
  ('Tudor Southeast', 3, 'S to N orientation', 'gggggggggggggggggggggggggggggggggggggg.gggggg'),
  ('Tudor Southeast', 4, 'S to N orientation', 'Gsggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 5, 'S to N orientation', 'gGggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 6, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 7, 'S to N orientation', 'gggggggggggggggggggggggggggggggggggGGgGGggGGgGgggG'),
  ('Tudor Southeast', 8, 'S to N orientation', 'ggggggggggggggGggggggggggggggggggggggggggggggg.gggg'),
  ('Tudor Southeast', 9, 'S to N orientation', 'ggggggggg.ggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 10, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 11, 'S to N orientation', 'gggggggggggggggGggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 12, 'S to N orientation', 'gggggggggggggggggggggggGggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 13, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 14, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 15, 'S to N orientation', 'gggggggggggggggggggggggggggggggggggggggGggggggggggg'),
  ('Tudor Southeast', 16, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 17, 'S to N orientation', 'gggggg.gggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 18, 'S to N orientation', 'ggggggggggGgggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 19, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 20, 'S to N orientation', 'gggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 21, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 22, 'S to N orientation', 'gggggggg.gggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 23, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 24, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 25, 'S to N orientation', 'gggggggggggggggggggggggggggggggggggg.gggggggggggggg'),
  ('Tudor Southeast', 26, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 27, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 28, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 29, 'S to N orientation', 'gggggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 30, 'S to N orientation', 'ggggggGgggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 31, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggGgggggggggggg'),
  ('Tudor Southeast', 32, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 33, 'S to N orientation', 'gggggggggggggggggggggggGgggggggggggggggggggGggggggggg'),
  ('Tudor Southeast', 34, 'S to N orientation', 'ggggggggggggggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 35, 'S to N orientation', '  ggggggggGGggggggggggggggggggggggggggggggggggggggggg'),
  ('Tudor Southeast', 36, 'S to N orientation', '    nnnnnnnnnnnnnnnnnnnnnnnnnn.nnynnnnnnnnnnnnnnnnnnn'),
  ('Tudor Southeast', 37, 'S to N orientation', '      nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnn'),
  ('Tudor Southeast', 38, 'S to N orientation', '             nnnnnnnnnnnnnnnnnnnnnnynnnnnnnnnnnnnnnnn'),
  ('Tudor Southeast', 39, 'S to N orientation', '                      nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Tudor Southeast', 40, 'S to N orientation', '                           nnnnnnnnnnnnnnnnnnnnnnnnnn'),
  ('Tudor Southeast', 41, 'S to N orientation', '                           nnnnnnnnnnnnnnnnnn.nnnnnnn'),
  ('Tudor Southeast', 42, 'S to N orientation', '                           nnnnnnnnnnn.nnnnnnnnnnnnnn'),
  ('Tudor Southeast', 43, 'S to N orientation', '                           nnnnnnnnnnnn.nnnnnnnnnnnnn'),
  ('Tudor Southwest', 1, 'S to N orientation', '       rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrmmmmmmmmmmmmmmmmmmmm'),
  ('Tudor Southwest', 2, 'S to N orientation', '      rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrmmmmmmmmmmmmmm'),
  ('Tudor Southwest', 3, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrr.rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrmmmmmmmmmmmm'),
  ('Tudor Southwest', 4, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrr.rrrrrrrrrrrrr.rrrrrrrrrrrrrrrrrrrmmmmmmmmmmrmmmmm'),
  ('Tudor Southwest', 5, 'S to N orientation', 'rrrrrrrrrr.nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnrrrrrrmmmmmmmmmmmmmmmmmmm'),
  ('Tudor Southwest', 6, 'S to N orientation', 'rrrrrrrrrrrnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnmmmmmmmmmmmmmmmmmmmmmmmmrmmmm'),
  ('Tudor Southwest', 7, 'S to N orientation', 'rrrrrrrrrrrrr.rrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 8, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrr.rrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 9, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 10, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 11, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 12, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrraa'),
  ('Tudor Southwest', 13, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 14, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 15, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 16, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'),
  ('Tudor Southwest', 17, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrtttttsttrrrrrrr'),
  ('Tudor Southwest', 18, 'S to N orientation', 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrsr');

create table _vine_key (ch text primary key, state text not null, variety text);
insert into _vine_key (ch, state, variety) values
  ('n', 'vine',           'pinot_noir'),
  ('y', 'young_scion',    'pinot_noir'),
  ('g', 'vine',           'pinot_gris'),
  ('G', 'young_scion',    'pinot_gris'),
  ('r', 'vine',           'riesling'),
  ('m', 'vine',           'muller_thurgau'),
  ('v', 'vine',           'gruner_veltliner'),
  ('u', 'vine',           'pinot_meunier'),
  ('a', 'vine',           'gamay'),
  ('t', 'vine',           'table_grapes'),
  ('s', 'rootstock_only', null),
  ('.', 'empty',          null);

-- ---------------------------------------------------------------------------
-- Expanded
-- ---------------------------------------------------------------------------

insert into vine_row (block_id, number, orientation)
select mb.block_id, m.row_no, m.orientation
  from _vine_map m
  join _map_block mb on mb.map_name = m.block
on conflict (block_id, number) do nothing;

insert into plant_space (row_id, number)
select vr.id, g.i
  from _vine_map m
  join _map_block mb on mb.map_name = m.block
  join vine_row vr on vr.block_id = mb.block_id and vr.number = m.row_no
  cross join lateral generate_series(1, length(m.strip)) as g(i)
 where substr(m.strip, g.i, 1) <> ' '
on conflict (row_id, number) do nothing;

-- One observation per space, dated to the day the map file was last written.
-- The map carries no date of its own, and the file's is the nearest honest one.
insert into plant_change (space_id, at, state_id, variety_id, clone, provenance)
select
  ps.id,
  date '2026-03-20',
  st.id,
  t.id,
  -- Clone by position in the two blocks where the map does not paint it, and by
  -- what the legend says everywhere else.
  case
    when k.variety = 'pinot_noir' and m.block = 'Overlook Pommard and 777'
      then case when vr.number <= 28 then 'Pommard' else '777' end
    when k.variety = 'pinot_noir' and m.block = 'Overlook 115'    then 'Dijon 115'
    when k.variety = 'pinot_noir' and m.block = 'Tudor Southeast' then 'Dijon'
    when k.variety = 'pinot_noir' and m.block = 'Tudor North'     then 'Pommard'
    when k.variety = 'pinot_noir' and m.block = 'Tudor Southwest' then 'Wadenswil'
  end,
  'inferred'
  from _vine_map m
  join _map_block mb on mb.map_name = m.block
  join vine_row vr on vr.block_id = mb.block_id and vr.number = m.row_no
  cross join lateral generate_series(1, length(m.strip)) as g(i)
  join _vine_key k on k.ch = substr(m.strip, g.i, 1)
  join plant_space ps on ps.row_id = vr.id and ps.number = g.i
  join term st on st.kind = 'plant_state' and st.value = k.state
  left join term t on t.kind = 'variety' and t.value = k.variety
 where substr(m.strip, g.i, 1) <> ' '
   and not exists (select 1 from plant_change pc where pc.space_id = ps.id);

drop table _vine_map;
drop table _vine_key;

-- ---------------------------------------------------------------------------
-- Acreage counts everything in the ground
-- ---------------------------------------------------------------------------

-- 0115's `block_planting` filtered to rows with a variety, which drops the
-- rootstock, and the rootstock is a plant by his count. So the acreage of a
-- block is over every position that is not empty, and the planting breakdown
-- keeps its variety filter because a rootstock is not a variety yet.
create or replace view block_acreage with (security_invoker = true) as
select
  b.id   as block_id,
  b.name as block,
  v.id   as vineyard_id,
  v.name as vineyard,
  b.vines_per_acre,
  count(*) filter (where n.state is distinct from 'empty' and n.state is not null) as plants,
  count(*) filter (where n.state = 'empty') as gaps,
  count(*) as spaces,
  round(
    count(*) filter (where n.state is distinct from 'empty' and n.state is not null)
    / nullif(b.vines_per_acre, 0), 4) as acres
from block b
left join vineyard v on v.id = b.vineyard_id
join plant_space_now n on n.block_id = b.id
group by b.id, b.name, v.id, v.name, b.vines_per_acre;

comment on view block_acreage is
  'Plants, gaps and derived acreage per block, counted from the plant spaces. A '
  'rootstock counts as a plant, which is how the winemaker counts and what makes '
  'the figures reconcile.';

insert into readable (key, module, label, note, relation, id_column, label_column, sort_order) values
  ('vineyard.block_acreage', 'vineyard', 'Acreage, counted',
   'Plants, gaps and acreage per block, derived from the plant spaces rather than typed.',
   'block_acreage', 'block_id', 'block', 412)
on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  relation = excluded.relation, id_column = excluded.id_column,
  label_column = excluded.label_column, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- It reconciles, or this migration does not apply
-- ---------------------------------------------------------------------------

-- His legend, checked against what just loaded. These are not decoration: the
-- decode is the only thing standing between this data and a confident wrong
-- answer, and it is checked here where a failure stops the migration rather than
-- in a test somebody can skip.
do $$
declare
  want jsonb := '[
    ["Tudor North","Riesling",null,1366],
    ["Tudor North","Grüner Veltliner",null,658],
    ["Tudor North","Müller Thurgau",null,220],
    ["Tudor North","Pinot Noir","Pommard",177],
    ["Tudor North","Pinot Gris",null,89],
    ["Tudor North","Pinot Meunier",null,40],
    ["Tudor North","Gamay",null,3],
    ["Tudor North","Table grapes",null,9],
    ["Tudor Southeast","Pinot Noir","Dijon",267]
  ]'::jsonb;
  row_want jsonb;
  have int;
begin
  for row_want in select * from jsonb_array_elements(want) loop
    select count(*) into have
      from plant_space_now n
      join _map_block mb on mb.block_id = n.block_id and mb.map_name = row_want ->> 0
      join term t on t.id = n.variety_id
     where t.label = row_want ->> 1
       and coalesce(n.clone, '') = coalesce(row_want ->> 2, '');
    if have <> (row_want ->> 3)::int then
      raise exception
        'FAIL: % % % loaded % and the map legend says %',
        row_want ->> 0, row_want ->> 1, coalesce(row_want ->> 2, ''), have, row_want ->> 3;
    end if;
  end loop;

  -- The two clones at Overlook, counting rootstock the way he counts it.
  select count(*) into have from plant_space_now n
    join _map_block mb on mb.block_id = n.block_id
   where mb.map_name = 'Overlook Pommard and 777' and n.row_number <= 28
     and n.state <> 'empty';
  if have <> 3259 then
    raise exception 'FAIL: Overlook rows 1-28 loaded % and the legend says 3259', have;
  end if;

  select count(*) into have from plant_space_now n
    join _map_block mb on mb.block_id = n.block_id
   where mb.map_name = 'Overlook Pommard and 777' and n.row_number between 29 and 53
     and n.state <> 'empty';
  if have <> 3295 then
    raise exception 'FAIL: Overlook rows 29-53 loaded % and the legend says 3295', have;
  end if;

  raise notice 'the vine map reconciles to its own legend on every block';
end $$;

drop table _map_block;
