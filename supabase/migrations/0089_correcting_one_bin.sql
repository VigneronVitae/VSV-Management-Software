-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The fruit in one bin can be corrected after the bins went out,
--           because the figure is typed for a whole batch at once and bins
--           differ once somebody looks at them."
-- Depends on: [supabase/migrations/0087_a_bin_holds_pounds.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0092_gross_or_net_and_a_bulging_bin.sql]
-- Axioms enforced: T0-2 (still one of pounds or percent, never both), T0-5 (a
--                  correction is a new statement about the bin rather than a
--                  quiet overwrite of a weighing)
-- Open sorries: none
-- ---------------------------------------------------------------------------
--
-- The winemaker, looking at five bins of Chardonnay: *"it's hard for me to
-- actually look at the weights of each of the 5 bins of fruit I have right
-- now."*
--
-- Two things were missing and this is the smaller one. **Nothing could show him
-- the bins**, which is a screen. And nothing could change one: `0087` takes the
-- figure when the bins are added and `add_bins_to_pick` writes the same one
-- into every bin of a batch, deliberately, because they went out together. The
-- moment somebody walks the row and sees that the last one is half empty, that
-- becomes wrong and there is no way to say so.
--
-- **It corrects an estimate and never a weighing.** The lot's `quantity` is
-- what the scale said and nothing here touches it. If a correction ever needs
-- to move a weighed figure, that is `weigh_bins` with `supersedes`, which
-- already exists and already writes an event.

begin;

create or replace function set_bin_fruit(
  p_vessel_id uuid,
  p_fruit_lbs numeric default null,
  p_fill_pct  numeric default null
)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
declare
  pl placement%rowtype;
  nm text;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here says what is in a bin'
      using errcode = 'insufficient_privilege';
  end if;

  if p_fruit_lbs is not null and p_fill_pct is not null then
    raise exception
      'say pounds or say how full, not both: one of them would be a guess written next to a figure somebody actually gave';
  end if;
  if p_fruit_lbs is null and p_fill_pct is null then
    raise exception 'say how much is in it';
  end if;
  if p_fruit_lbs is not null and p_fruit_lbs <= 0 then
    raise exception 'a bin with no fruit in it is empty, and emptying a bin is a different act';
  end if;
  if p_fill_pct is not null and (p_fill_pct <= 0 or p_fill_pct > 100) then
    raise exception '% is not how full a bin is', p_fill_pct;
  end if;

  select p.* into pl
    from placement p
    join vessel v on v.id = p.vessel_id
    join term vt on vt.id = v.type_id
     and coalesce((vt.attributes ->> 'intake_bin')::boolean, false)
   where p.vessel_id = p_vessel_id and p.to_at is null;

  if pl.id is null then
    raise exception
      'that bin has nothing in it, or it is not a picking bin, so there is no amount to correct';
  end if;

  update placement
     set fruit_lbs = p_fruit_lbs,
         fill_pct  = p_fill_pct
   where id = pl.id;

  select name into nm from vessel where id = p_vessel_id;

  return jsonb_build_object(
    'vessel', p_vessel_id, 'bin', nm,
    'lbs', (select lbs from bin_fruit where placement_id = pl.id),
    'tons', (select tons from bin_fruit where placement_id = pl.id));
end;
$$;

revoke all on function set_bin_fruit(uuid, numeric, numeric) from public;
grant execute on function set_bin_fruit(uuid, numeric, numeric) to authenticated;

insert into capability (key, module, label, note, fn, subject, fields, sort_order) values
  ('cellar.set_bin_fruit', 'cellar', 'Correct what is in a bin',
   'The figure is typed once for a whole batch of bins. This is for the one that '
   'went out half full.',
   'set_bin_fruit', 'cellar.bin_fruit',
   '[{"key":"bin","param":"p_vessel_id","type":"uuid","required":true,
      "label":"Which bin",
      "source":{"readable":"cellar.bin_fruit"}},
     {"key":"lbs","param":"p_fruit_lbs","type":"numeric","required":false,
      "label":"Pounds of fruit"},
     {"key":"pct","param":"p_fill_pct","type":"numeric","required":false,
      "label":"Or how full, percent"}]'::jsonb, 270)

on conflict (key) do update set
  module = excluded.module, label = excluded.label, note = excluded.note,
  fn = excluded.fn, subject = excluded.subject, fields = excluded.fields,
  sort_order = excluded.sort_order;

commit;
