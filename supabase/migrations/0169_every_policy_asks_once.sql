-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "Every policy asks who you are once a query, not once a row."
-- Depends on: [supabase/migrations/0167_the_vineyard_asks_once.sql]
-- Depended on by: [docs/status-ledger.md, tests/schema_assertions.sql]
-- Axioms enforced: none new. The same predicate for the same person: who may
--                  read or write any row is exactly what it was.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0167 found the vine map export spending a minute asking `is_facility_user()`
-- once a plant space, and wrapped the vineyard's six policies so Postgres asks
-- once a query. The same shape is in nearly every other policy in the schema,
-- 142 of them here, and every screen pays it in proportion to the rows it reads:
-- a cellar list, a lot's history, the books.
--
-- **Only calls that cannot change within a query are wrapped**: `is_admin()`,
-- `is_facility_user()`, `current_party_id()`, `auth.uid()`, and `may()` of a
-- fixed setting. Anything given a row's own values, `may_see_all_of(owner_id,
-- hidden)` and the like, is left exactly as it was, because its answer does
-- differ row to row. Each statement below is the policy as it stood with those
-- calls inside `( SELECT ... )`, generated from the database and written out
-- here in full so the change can be read rather than trusted. `alter policy`,
-- so no table is ever unguarded, even inside this migration.
--
-- The assertion suite now refuses a policy that calls one of these bare, so
-- the slow form cannot come back one migration at a time.

alter policy app_user_admin_write on app_user
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy attachment_admin_delete on attachment
  using (( SELECT is_admin()));

alter policy attachment_caption on attachment
  using ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))))
  with check ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))));

alter policy attachment_insert on attachment
  with check ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))));

alter policy attachment_read on attachment
  using (( SELECT is_facility_user()));

alter policy attachment_mark_admin_delete on attachment_mark
  using (( SELECT is_admin()));

alter policy attachment_mark_insert on attachment_mark
  with check ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))));

alter policy attachment_mark_read on attachment_mark
  using (( SELECT is_facility_user()));

alter policy bank_import_read on bank_import
  using (( SELECT is_admin()));

alter policy bank_import_write on bank_import
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy bank_line_read on bank_line
  using (( SELECT is_admin()));

alter policy bank_line_write on bank_line
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy block_admin_write on block
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy block_insert_if_allowed on block
  with check (( SELECT may('vineyard.edit'::text)));

alter policy block_update_if_allowed on block
  using (( SELECT may('vineyard.edit'::text)))
  with check (( SELECT may('vineyard.edit'::text)));

alter policy capability_admin_write on capability
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy capability_exemption_admin_write on capability_exemption
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy day_note_insert on day_note
  with check ((( SELECT is_facility_user()) AND (author_id = ( SELECT auth.uid()))));

alter policy day_note_own_delete on day_note
  using ((author_id = ( SELECT auth.uid())));

alter policy day_note_own_update on day_note
  using ((author_id = ( SELECT auth.uid())))
  with check ((author_id = ( SELECT auth.uid())));

alter policy day_note_read on day_note
  using ((((NOT private) AND ( SELECT is_facility_user())) OR (author_id = ( SELECT auth.uid()))));

alter policy event_admin_update on event
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy event_insert on event
  with check (((by_user = ( SELECT auth.uid())) AND (by_sensor IS NULL)));

alter policy event_read on event
  using ((( SELECT is_admin()) OR ( SELECT is_facility_user()) OR ((subject_type = 'node'::text) AND (EXISTS ( SELECT 1
   FROM node n
  WHERE ((n.id = event.subject_id) AND (n.owner_id = ( SELECT current_party_id()))))))));

alter policy glycol_hookup_read on glycol_hookup
  using (( SELECT is_facility_user()));

alter policy glycol_hookup_write on glycol_hookup
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy glycol_machine_read on glycol_machine
  using (( SELECT is_facility_user()));

alter policy glycol_machine_write on glycol_machine
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy import_batch_read on import_batch
  using (( SELECT is_admin()));

alter policy import_batch_write on import_batch
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy import_step_read on import_step
  using (( SELECT is_facility_user()));

alter policy import_step_write on import_step
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy invite_admin on invite
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy ledger_account_read on ledger_account
  using (( SELECT is_admin()));

alter policy ledger_account_write on ledger_account
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy line_attestation_read on line_attestation
  using (( SELECT is_admin()));

alter policy line_attestation_write on line_attestation
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy lineage_admin_delete on lineage
  using (( SELECT is_admin()));

alter policy lineage_admin_update on lineage
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy lineage_read on lineage
  using ((( SELECT is_admin()) OR ( SELECT is_facility_user()) OR (EXISTS ( SELECT 1
   FROM node n
  WHERE ((n.id = lineage.child_id) AND (n.owner_id = ( SELECT current_party_id())))))));

alter policy location_admin_write on location
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy location_insert_if_allowed on location
  with check (( SELECT may('places.edit'::text)));

alter policy location_update_if_allowed on location
  using (( SELECT may('places.edit'::text)))
  with check (( SELECT may('places.edit'::text)));

alter policy location_tag_read on location_domain
  using (( SELECT is_facility_user()));

alter policy location_tag_write on location_domain
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy machine_read on machine
  using (( SELECT is_facility_user()));

alter policy machine_write on machine
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy machine_document_read on machine_document
  using (( SELECT is_facility_user()));

alter policy machine_document_write on machine_document
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy machine_model_read on machine_model
  using (( SELECT is_facility_user()));

alter policy machine_model_write on machine_model
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy machine_part_change_read on machine_part_change
  using (( SELECT is_facility_user()));

alter policy machine_part_change_write on machine_part_change
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy machine_work_read on machine_work
  using (( SELECT is_facility_user()));

alter policy machine_work_write on machine_work
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy model_part_read on model_part
  using (( SELECT is_facility_user()));

alter policy model_part_write on model_part
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy module_write on module
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy money_paper_late_photo on money_paper
  using ((( SELECT is_admin()) AND (photo_path IS NULL)))
  with check (( SELECT is_admin()));

alter policy money_paper_read on money_paper
  using (( SELECT is_admin()));

alter policy money_paper_write on money_paper
  with check (( SELECT is_admin()));

alter policy money_paper_reading_read on money_paper_reading
  using (( SELECT is_admin()));

alter policy money_paper_reading_write on money_paper_reading
  with check (( SELECT is_admin()));

alter policy node_admin_delete on node
  using (( SELECT is_admin()));

alter policy node_admin_update on node
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy node_cellar_update on node
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy node_read on node
  using ((( SELECT is_admin()) OR (owner_id = ( SELECT current_party_id())) OR (( SELECT is_facility_user()) AND (cardinality(hidden) = 0))));

alter policy note_admin_delete on note
  using (( SELECT is_admin()));

alter policy note_edit on note
  using ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))))
  with check ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))));

alter policy note_insert on note
  with check ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))));

alter policy note_read on note
  using (( SELECT is_facility_user()));

alter policy note_source_admin_write on note_source
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy note_source_read on note_source
  using (( SELECT is_facility_user()));

alter policy paper_match_read on paper_match
  using (( SELECT is_admin()));

alter policy paper_match_write on paper_match
  with check (( SELECT is_admin()));

alter policy paper_record_admin_write on paper_record
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy paper_record_read on paper_record
  using (( SELECT is_facility_user()));

alter policy paper_record_operation_admin_write on paper_record_operation
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy paper_record_operation_read on paper_record_operation
  using (( SELECT is_facility_user()));

alter policy party_admin_write on party
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy permission_admin_write on permission
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy placement_admin_delete on placement
  using (( SELECT is_admin()));

alter policy placement_admin_update on placement
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy placement_cellar_update on placement
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy placement_read on placement
  using ((( SELECT is_admin()) OR ( SELECT is_facility_user()) OR (EXISTS ( SELECT 1
   FROM node n
  WHERE ((n.id = placement.node_id) AND (n.owner_id = ( SELECT current_party_id())))))));

alter policy plant_space_insert_if_allowed on plant_space
  with check (( SELECT may('vineyard.edit'::text)));

alter policy plant_space_update_if_allowed on plant_space
  using (( SELECT may('vineyard.edit'::text)))
  with check (( SELECT may('vineyard.edit'::text)));

alter policy planting_admin_write on planting
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy planting_insert_if_allowed on planting
  with check (( SELECT may('vineyard.edit'::text)));

alter policy planting_update_if_allowed on planting
  using (( SELECT may('vineyard.edit'::text)))
  with check (( SELECT may('vineyard.edit'::text)));

alter policy procedure_admin_write on procedure
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy procedure_read on procedure
  using (( SELECT is_facility_user()));

alter policy procedure_run_read on procedure_run
  using (( SELECT is_facility_user()));

alter policy procedure_run_write on procedure_run
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy procedure_run_step_read on procedure_run_step
  using (( SELECT is_facility_user()));

alter policy procedure_run_step_write on procedure_run_step
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy procedure_session_read on procedure_session
  using (( SELECT is_facility_user()));

alter policy procedure_session_write on procedure_session
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy procedure_step_admin_write on procedure_step
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy procedure_step_read on procedure_step
  using (( SELECT is_facility_user()));

alter policy propagation_admin_delete on propagation
  using (( SELECT is_admin()));

alter policy propagation_insert on propagation
  with check ((( SELECT is_facility_user()) AND (written_by = ( SELECT auth.uid()))));

alter policy propagation_read on propagation
  using (( SELECT is_facility_user()));

alter policy readable_admin_write on readable
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy screen_read on screen
  using (( SELECT is_facility_user()));

alter policy screen_write on screen
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy shopping_item_read on shopping_item
  using (( SELECT is_facility_user()));

alter policy shopping_item_write on shopping_item
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy source_admin_write on source
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy source_read on source
  using (( SELECT is_facility_user()));

alter policy subject_resolver_admin_write on subject_resolver
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy supply_admin_write on supply
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy supply_insert_if_allowed on supply
  with check (( SELECT may('stores.edit'::text)));

alter policy supply_read on supply
  using (( SELECT is_facility_user()));

alter policy supply_update_if_allowed on supply
  using (( SELECT may('stores.edit'::text)))
  with check (( SELECT may('stores.edit'::text)));

alter policy supply_domain_read on supply_domain
  using (( SELECT is_facility_user()));

alter policy supply_domain_write on supply_domain
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy supply_material_kind_admin_write on supply_material_kind
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy supply_material_kind_read on supply_material_kind
  using (( SELECT is_facility_user()));

alter policy supply_movement_admin_delete on supply_movement
  using (( SELECT is_admin()));

alter policy supply_movement_insert on supply_movement
  with check ((( SELECT is_facility_user()) AND (by_user = ( SELECT auth.uid()))));

alter policy supply_movement_read on supply_movement
  using (( SELECT is_facility_user()));

alter policy task_admin_write on task
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy task_own_update on task
  using (((claimed_by = ( SELECT auth.uid())) OR (assignee = ( SELECT auth.uid()))))
  with check (((claimed_by = ( SELECT auth.uid())) OR (assignee = ( SELECT auth.uid()))));

alter policy claim_log_insert on task_claim_log
  with check ((user_id = ( SELECT auth.uid())));

alter policy template_admin_write on template
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy template_step_admin_write on template_step
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy term_admin_write on term
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy term_insert_if_allowed on term
  with check (( SELECT may('vocabulary.add'::text)));

alter policy term_kind_admin_write on term_kind
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy vessel_admin_write on vessel
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy vessel_cellar_update on vessel
  using (( SELECT is_facility_user()))
  with check (( SELECT is_facility_user()));

alter policy vessel_insert_if_allowed on vessel
  with check (( SELECT may('vessels.register'::text)));

alter policy vessel_code_admin_write on vessel_code
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy vessel_code_cellar_insert on vessel_code
  with check (( SELECT is_facility_user()));

alter policy vessel_type_note_insert on vessel_type_note
  with check ((created_by = ( SELECT auth.uid())));

alter policy vessel_type_note_resolve on vessel_type_note
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy vine_row_insert_if_allowed on vine_row
  with check (( SELECT may('vineyard.edit'::text)));

alter policy vine_row_update_if_allowed on vine_row
  using (( SELECT may('vineyard.edit'::text)))
  with check (( SELECT may('vineyard.edit'::text)));

alter policy vineyard_admin_write on vineyard
  using (( SELECT is_admin()))
  with check (( SELECT is_admin()));

alter policy vineyard_insert_if_allowed on vineyard
  with check (( SELECT may('vineyard.edit'::text)));

alter policy vineyard_update_if_allowed on vineyard
  using (( SELECT may('vineyard.edit'::text)))
  with check (( SELECT may('vineyard.edit'::text)));

