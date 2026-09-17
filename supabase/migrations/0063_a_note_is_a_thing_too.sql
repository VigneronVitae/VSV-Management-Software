-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "A note and a photograph are themselves things, so a note can hang
--           off a note and a photograph can hang off either."
-- Depends on: [supabase/migrations/0062_a_note_on_anything.sql]
-- Depended on by: [tests/schema_assertions.sql,
--                  supabase/migrations/0101_a_note_can_be_about_a_screen.sql]
-- Axioms enforced: AR-E5 (what kinds of thing exist is a registry, so adding
--                  two costs two rows and no code)
-- ---------------------------------------------------------------------------
--
-- The winemaker, one minute after `0062` went in: "a good thought is that notes
-- themselves could be tied to objects, if desired?"
--
-- **Two rows.** `note` and `attachment` become subject types, and everything
-- that already works on a subject works on them: a note about a note is a reply,
-- a note about a photograph is a discussion of what it shows, and a photograph
-- about a note is the picture somebody should have taken at the time. Threads
-- fall out rather than being built, which is what AR-E5 is for. `0023` said a
-- winery with no vineyard module deletes the block row and everything else keeps
-- working; this is that argument run forwards.
--
-- It is also his reference's shape arriving on its own. Knowledge Game keeps
-- comments as discussion threads, and a thread is exactly a comment whose
-- subject is another comment.
--
-- **What this deliberately is not.** A note still has one subject. Tying one
-- note to several objects at once, so that a remark about the Pinot Gris also
-- surfaces on the block it came from, needs a join table and a decision about
-- what "about" means when there are three answers. That is the other reading of
-- his question and it is not this: one subject with recursion covers threads,
-- and multiple subjects is a different feature that should wait until somebody
-- wants to write the note that needs it.
--
-- The recursion is unbounded on purpose. A reply to a reply to a reply is fine,
-- nothing walks the chain, and a depth limit would be a rule invented here
-- rather than one anybody asked for.

begin;

insert into subject_resolver (subject_type, relation, name_expression, module) values
  -- Named by what it says, shortened, because a subject's name is for a person
  -- picking it out of a list and a note can be a paragraph.
  ('note', 'note',
   'left(body, 60) || case when length(body) > 60 then ''...'' else '''' end',
   'core'),
  -- A photograph's name is its caption when it has one, because that is what
  -- somebody wrote for exactly this purpose, and its path when it does not.
  ('attachment', 'attachment', 'coalesce(caption, path)', 'core')
on conflict (subject_type) do update
  set relation = excluded.relation,
      name_expression = excluded.name_expression,
      module = excluded.module;

commit;
