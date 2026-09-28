-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "One question the database can be asked at any time: is anything
--           here pointing at nothing, holding two things at once, or
--           otherwise in a state no sequence of real events produces."
-- Depends on: [supabase/migrations/0153_a_bin_can_change_parts.sql,
--              supabase/migrations/0154_a_fermenter_shows_its_fruit.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql,
--                  scripts/doctor.sh,
--                  supabase/migrations/0156_a_blend_stays_whole.sql]
-- Axioms enforced: A13. A record that points at nothing fails silently
--                  everywhere it is read; this is where it fails out loud.
-- Open sorries: S-4 is discharged here for the cellar and the practice stack;
--               replay fixtures are still Specified.
-- ---------------------------------------------------------------------------

-- `event.subject_id` cannot be a foreign key, because one events table serves
-- every kind of subject (S-4), and nor can the same column on notes,
-- attachments, attachment marks and tasks. Since 0001 the answer has been
-- "`doctor` checks it", and `bun run doctor` has printed "not implemented" and
-- exited 1. This is `doctor`.
--
-- **Two kinds of finding.** `wrong` is a state no sequence of real events can
-- produce: a note about a vessel that does not exist, a vessel holding two
-- lots, shares of a blend that do not add to one, a photograph the record
-- names and storage does not have. Any `wrong` fails the command. `look` is
-- true and worth a person's eye: bins that have waited more than a day for the
-- scale, a vessel holding more than it holds. A `look` that is a known gap names
-- its sorry, so a later session can tell the known from the new.
--
-- **In the kernel, not in a script.** A client that wants to show it later calls
-- the same function the command does, and the checks cannot disagree. It reads
-- everything and so runs as its definer; an administrator may ask, and nobody
-- else.

create or replace function doctor()
returns table (
  severity     text,
  check_name   text,
  subject_type text,
  subject_id   uuid,
  subject_name text,
  said         text,
  sorry        text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  r   record;
  t   text;
begin
  if auth.uid() is not null and not is_admin() then
    raise exception 'only an administrator asks the doctor'
      using errcode = 'insufficient_privilege';
  end if;

  -- 1. Pointing at nothing. Every table with a polymorphic subject, against
  -- every kind of subject it may name. A relation the resolver names that has
  -- no uuid id is itself a finding, because nothing could ever resolve to it.
  for r in select sr.subject_type, sr.relation from subject_resolver sr order by 1 loop
    if not exists (
      select 1 from information_schema.columns c
       where c.table_schema = 'public' and c.table_name = r.relation
         and c.column_name = 'id' and c.data_type = 'uuid'
    ) then
      return query select 'wrong', 'resolver names nothing', 'subject_type',
        null::uuid, r.subject_type,
        format('%s is registered as a kind of subject in %s, which has no uuid id to point at',
               r.subject_type, r.relation),
        null::text;
      continue;
    end if;
    foreach t in array array['event', 'note', 'attachment', 'attachment_mark', 'task'] loop
      return query execute format(
        'select ''wrong''::text, ''points at nothing''::text, %1$L::text, x.subject_id, null::text,
                format(''%%s %%s is about a %%s that does not exist'', %2$L, x.id, %1$L),
                ''S-4''::text
           from %2$I x
          where x.subject_type = %1$L
            and not exists (select 1 from %3$I s where s.id = x.subject_id)',
        r.subject_type, t, r.relation);
    end loop;
  end loop;

  -- 2. A vessel holding two lots. A unique index refuses it; this is the
  -- check that the index is still there doing it.
  return query
  select 'wrong', 'two lots in one vessel', 'vessel', v.id, v.name,
         format('%s holds %s lots at once', v.name, count(*)), null::text
    from placement p join vessel v on v.id = p.vessel_id
   where p.to_at is null
   group by v.id, v.name
  having count(*) > 1;

  -- 3. A closed lot still in a vessel. Closing is what emptying says.
  return query
  select 'wrong', 'closed and still held', 'node', n.id, n.name,
         format('%s is closed and still in %s', n.name, v.name), null::text
    from node n
    join placement p on p.node_id = n.id and p.to_at is null
    join vessel v on v.id = p.vessel_id
   where n.status = 'closed';

  -- 4. A blend whose shares do not make a whole. Every composition on a label
  -- is read from these.
  return query
  select 'wrong', 'shares do not add to one', 'node', n.id, n.name,
         format('%s comes from its sources in shares adding to %s', n.name, round(sum(l.fraction), 4)),
         null::text
    from lineage l join node n on n.id = l.child_id
   group by n.id, n.name
  having abs(sum(l.fraction) - 1) > 0.001;

  -- 5. A scale reading naming a bin that was never part of that pick.
  return query
  select 'wrong', 'weighed a bin the pick never had', 'node', n.id, n.name,
         format('a reading on %s names %s, which never held that pick',
                n.name, coalesce(v.name, b.bin)),
         null::text
    from event e
    join node n on n.id = e.subject_id
    cross join lateral jsonb_array_elements_text(e.data -> 'bins') b(bin)
    left join vessel v on v.id::text = b.bin
   where e.subject_type = 'node'
     and e.operation_id = term_id('operation', 'weigh')
     and not exists (select 1 from placement p
                      where p.node_id = e.subject_id and p.vessel_id::text = b.bin);

  -- 6. Something in a vessel nobody can see any more.
  return query
  select 'wrong', 'held in a retired vessel', 'vessel', v.id, v.name,
         format('%s is retired and still holds %s', v.name, n.name), null::text
    from placement p
    join vessel v on v.id = p.vessel_id
    join node n on n.id = p.node_id
   where p.to_at is null and not v.active;

  -- 7. A photograph the record names and storage does not have. What a
  -- restore that brought the rows back and not the files would look like.
  -- Dynamic, and skipped where there is no storage at all, which is the
  -- scratch database the gate builds from empty: there is nothing to check
  -- against, and saying every photograph is missing would be a lie.
  if to_regclass('storage.objects') is not null then
    return query execute $q$
    select 'wrong'::text, 'photograph missing'::text, ph.kind, ph.id, null::text,
           format('%s names %s, which is not in %s', ph.kind, ph.path, ph.bucket), null::text
      from (
        select 'event'::text as kind, e.id, e.data ->> 'photo_path' as path, 'vessel-photos'::text as bucket
          from event e where e.data ? 'photo_path' and e.data ->> 'photo_path' <> ''
        union all
        select 'attachment', a.id, a.path, 'vessel-photos' from attachment a
        union all
        select 'vessel', v.id, v.attributes ->> 'photo_path', 'vessel-photos'
          from vessel v where coalesce(v.attributes ->> 'photo_path', '') <> ''
        union all
        select 'money_paper', m.id, m.photo_path, 'money-papers'
          from money_paper m where coalesce(m.photo_path, '') <> ''
      ) ph
     where not exists (select 1 from storage.objects o
                        where o.bucket_id = ph.bucket and o.name = ph.path)
    $q$;
  end if;

  -- 8. A lot open and in no vessel. Wrong in general; the known case is a cut
  -- drawn wholly into a tank that already held wine, which blends into the
  -- resident lot and stays open with nowhere to be (S-148).
  return query
  select case when exists (select 1 from lineage l join node c on c.id = l.child_id
                            where l.parent_id = n.id and c.status <> 'closed')
              then 'look' else 'wrong' end,
         'open and in no vessel', 'node', n.id, n.name,
         format('%s is open and not in any vessel', n.name),
         case when exists (select 1 from lineage l join node c on c.id = l.child_id
                            where l.parent_id = n.id and c.status <> 'closed')
              then 'S-148' end
    from node n
   where n.status = 'open'
     and not exists (select 1 from placement p where p.node_id = n.id and p.to_at is null);

  -- 9. Bins that have waited more than a day for the scale. True and worth
  -- somebody's eye, not wrong: the weight is a separate act, on purpose.
  return query
  select 'look', 'waiting for the scale', 'node', u.node_id, u.pick_name,
         format('%s bin%s of %s, filled %s, not weighed',
                count(*), case when count(*) = 1 then '' else 's' end, u.pick_name,
                to_char(min(u.filled_at) at time zone 'America/Los_Angeles', 'Mon DD')),
         null::text
    from unweighed_bin u
   where u.filled_at < now() - interval '1 day'
   group by u.node_id, u.pick_name;

  -- 10. More in a vessel than it holds. The kernel allows it on purpose, a
  -- tank can be topped past its mark, so it is something to look at.
  return query
  select 'look', 'over capacity', 'vessel', v.id, v.name,
         format('%s holds %s L and is %s L', v.name, p.volume_l, v.capacity_l), null::text
    from placement p join vessel v on v.id = p.vessel_id
   where p.to_at is null and v.capacity_l > 0 and p.volume_l > v.capacity_l * 1.05;
end $$;

comment on function doctor is
  'Everything that looks wrong: records pointing at nothing, vessels holding two '
  'lots, blends that are not a whole, missing photographs, and what is worth a look.';

revoke all on function doctor() from public;
grant execute on function doctor() to authenticated;

insert into capability_exemption (fn, reason) values
  ('doctor', 'Reports what looks wrong and changes nothing. Administrators only; run by bun run doctor.')
on conflict (fn) do update set reason = excluded.reason;

-- ---------------------------------------------------------------------------
-- Found by the doctor on its first run against practice
-- ---------------------------------------------------------------------------

-- `move_bins_to_pick` (0153) could move every bin out of a pick and leave the
-- pick open with nothing in it: "open and in no vessel", a lot that is not
-- anywhere. Replaced with the one addition.
create or replace function move_bins_to_pick(
  p_vessel_ids uuid[],
  p_to_node    uuid,
  p_note       text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  target  node%rowtype;
  source  node%rowtype;
  sources uuid[];
  missing text;
  weighed text;
  moved   int;
  emptied boolean;
begin
  if not is_facility_user() then
    raise exception 'only somebody who works here says which pick a bin belongs to'
      using errcode = 'insufficient_privilege';
  end if;
  if p_vessel_ids is null or cardinality(p_vessel_ids) = 0 then
    raise exception 'say which bins';
  end if;

  select * into target from node where id = p_to_node;
  if target.id is null then
    raise exception 'there is no pick with that id';
  end if;
  if target.stage <> 'bin' then
    raise exception '% is not a pick, so bins cannot move into it', target.name;
  end if;
  if target.status = 'closed' then
    raise exception '% is closed; its fruit has already gone somewhere', target.name;
  end if;

  select string_agg(v.name, ', ') into missing
    from vessel v
   where v.id = any (p_vessel_ids)
     and not exists (
       select 1 from placement p join node n on n.id = p.node_id
        where p.vessel_id = v.id and p.to_at is null
          and n.stage = 'bin' and n.status <> 'closed');
  if missing is not null then
    raise exception '% % not holding fruit from a pick',
      missing, case when missing like '%,%' then 'are' else 'is' end;
  end if;

  select array_agg(distinct p.node_id) into sources
    from placement p
   where p.vessel_id = any (p_vessel_ids) and p.to_at is null;
  if cardinality(sources) > 1 then
    raise exception 'those bins are from different picks; move one pick''s bins at a time';
  end if;
  select * into source from node where id = sources[1];
  if source.id = target.id then
    raise exception 'those bins are already part of %', target.name;
  end if;
  if source.owner_id <> target.owner_id then
    raise exception
      '% and % are different owners'' fruit; changing whose fruit it is is Owner corrected, not a move',
      source.name, target.name;
  end if;
  if source.vintage is distinct from target.vintage then
    raise exception '% and % are different vintages', source.name, target.name;
  end if;

  -- S-149. A standing reading that names the bin, the same test unweighed_bin
  -- uses, so a bin the scale screen offers is a bin this accepts.
  select string_agg(v.name, ', ') into weighed
    from vessel v
   where v.id = any (p_vessel_ids)
     and not exists (select 1 from unweighed_bin u where u.vessel_id = v.id);
  if weighed is not null then
    raise exception
      '% % been weighed as part of %. A reading is of one pick''s fruit, so a weighed bin stays where it was weighed',
      weighed, case when weighed like '%,%' then 'have' else 'has' end, source.name;
  end if;

  update placement
     set node_id = target.id
   where vessel_id = any (p_vessel_ids) and to_at is null and node_id = source.id;
  get diagnostics moved = row_count;

  -- 0155. A pick every bin has moved out of was never a pick: the fruit was
  -- all the other part's. Left open it is a lot in no vessel, which is what
  -- doctor found. Closed, and the move says so.
  emptied := not exists (select 1 from placement where node_id = source.id and to_at is null);
  if emptied then
    update node set status = 'closed', closed_at = occurred_at() where id = source.id;
  end if;

  insert into event (operation_id, subject_type, subject_id, by_user, provenance, data)
  select term_id('operation', 'bins_moved'), 'node', s, auth.uid(), 'observed',
         jsonb_strip_nulls(jsonb_build_object(
           'bins', to_jsonb(p_vessel_ids),
           'from', source.id,
           'to',   target.id,
           'closed_empty', case when emptied then true end,
           'note', nullif(btrim(p_note), '')))
    from unnest(array[source.id, target.id]) s;

  return jsonb_build_object(
    'moved',     moved,
    'from',      source.id,
    'from_name', source.name,
    'from_bins', (select count(*) from placement where node_id = source.id and to_at is null),
    'to',        target.id,
    'to_name',   target.name,
    'to_bins',   (select count(*) from placement where node_id = target.id and to_at is null));
end $$;

comment on function move_bins_to_pick is
  'Moves unweighed bins recorded in the wrong part of a pick to the right one, '
  'writing the move into both picks'' histories.';

