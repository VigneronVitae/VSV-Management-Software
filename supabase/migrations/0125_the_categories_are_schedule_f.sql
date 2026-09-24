-- ---------------------------------------------------------------------------
-- Type: migration
-- Purpose: "The list of what a transaction can be is his own, and his own is
--           IRS Schedule F."
-- Depends on: [supabase/migrations/0122_money_that_has_already_moved.sql]
-- Depended on by: [docs/status-ledger.md,
--                  supabase/migrations/0128_three_categories_nobody_issues.sql,
--                  packages/books/src/books.ts,
--                  supabase/migrations/0129_not_yet_decided_is_an_answer.sql,
--                  supabase/migrations/0138_the_repository_names_no_vendor.sql,
--                  supabase/migrations/0144_a_paper_says_what_money_was.sql]
-- Axioms enforced: AR-E5, and the argument for it is in his own data: the free
--                  text column has already drifted off its own list.
-- Open sorries: none new.
-- ---------------------------------------------------------------------------

-- 0122 seeded categories reverse-engineered from bank descriptions, including
-- one named after a person. That was the wrong source and the wrong place.
--
-- **What ships here is IRS Schedule F**, which is a public tax form, the same
-- for every farm in the country, and the reason a farm classifies anything in
-- the first place. A winery that adds categories of its own loads them from
-- `data/books/money-classes.tsv`, which is not committed, because those
-- describe how one operation is run.
--
-- **The point of classifying a transaction is that it lands on a tax form.** A
-- vocabulary invented from bank descriptions cannot do that. Schedule F can.
--
-- **A hand-kept spreadsheet is the argument for a registry rather than free
-- text.** One year of a free text Type column drifts off the list it is supposed
-- to come from in at least four ways: the same category capitalised two ways, a
-- plural where the list has a singular, a shortened name that matches nothing,
-- and a name missing the qualifier the list carries. A foreign key to a registry
-- makes all four impossible, which is AR-E5 argued from evidence rather than
-- from taste.
--
-- `attributes.side` says whether a category is money out, money in, or neither.
-- A transfer between the winery's own accounts is not income, and counting it as
-- income is the easiest way to be badly wrong about a year: movements between
-- related accounts can be larger than the revenue they sit beside.


insert into term (kind, value, label, sort_order, attributes) values
  ('money_class', 'chemicals',            'Chemicals',                      10, '{"side":"out","schedule_f":true}'),
  ('money_class', 'conservation',         'Conservation Expenses',          20, '{"side":"out","schedule_f":true}'),
  ('money_class', 'custom_hire',          'Custom Hire',                    30, '{"side":"out","schedule_f":true}'),
  ('money_class', 'employee',             'Employee',                       40, '{"side":"out","schedule_f":true}'),
  ('money_class', 'employee_taxes',       'Employee - Taxes',               50, '{"side":"out","schedule_f":true}'),
  ('money_class', 'equipment_rental',     'Equipment Rental',               60, '{"side":"out","schedule_f":true}'),
  ('money_class', 'farm_asset',           'Farm Asset',                     70, '{"side":"out","schedule_f":true}'),
  ('money_class', 'feed_purchased',       'Feed Purchased',                 80, '{"side":"out","schedule_f":true}'),
  ('money_class', 'fertilizers_and_lime', 'Fertilizers and Lime',           90, '{"side":"out","schedule_f":true}'),
  ('money_class', 'freight_and_trucking', 'Freight and Trucking',          100, '{"side":"out","schedule_f":true}'),
  ('money_class', 'fuel',                 'Gasoline, Fuel and Oil',        110, '{"side":"out","schedule_f":true}'),
  ('money_class', 'insurance',            'Insurance (not Health)',        120, '{"side":"out","schedule_f":true}'),
  ('money_class', 'marketing',            'Marketing',                     130, '{"side":"out","schedule_f":true}'),
  ('money_class', 'mortgage_interest',    'Mortgage Interest',             150, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_business',       'Other Business',                160, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_employee_benefits', 'Other Employee Benefits',    170, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_fees',           'Other Fees',                    180, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_interest',       'Other Interest',                190, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_legal',          'Other Legal',                   200, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_marketing',      'Other Marketing',               210, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_miscellaneous',  'Other Miscellaneous Expenses',  220, '{"side":"out","schedule_f":true}'),
  ('money_class', 'other_rental',         'Other Rental',                  230, '{"side":"out","schedule_f":true}'),
  ('money_class', 'pension_startup',      'Pension Plan Startup Costs',    240, '{"side":"out","schedule_f":true}'),
  ('money_class', 'pension_plans',        'Pension Plans',                 250, '{"side":"out","schedule_f":true}'),
  ('money_class', 'repairs_maintenance',  'Repairs and Maintenance',       260, '{"side":"out","schedule_f":true}'),
  ('money_class', 'room_lease',           'Room Lease',                    270, '{"side":"out","schedule_f":true}'),
  ('money_class', 'seed_and_plants',      'Seed and Plants',               280, '{"side":"out","schedule_f":true}'),
  ('money_class', 'storage_warehousing',  'Storage and Warehousing',       290, '{"side":"out","schedule_f":true}'),
  ('money_class', 'supplies',             'Supplies Purchased',            300, '{"side":"out","schedule_f":true}'),
  ('money_class', 'taxes',                'Taxes',                         310, '{"side":"out","schedule_f":true}'),
  ('money_class', 'utilities',            'Utilities',                     320, '{"side":"out","schedule_f":true}'),
  ('money_class', 'veterinary',           'Veterinary, Breeding, Medicine',330, '{"side":"out","schedule_f":true}'),

  -- Money in. Schedule F does not list these because it is the expense half of
  -- the form, and his ledger keeps income in a separate column for the same
  -- reason.
  ('money_class', 'till_income',         'Counter sales',             400, '{"side":"in"}'),
  ('money_class', 'gateway_income',         'Online sales',                410, '{"side":"in"}'),
  ('money_class', 'card_income',            'Card sales',                420, '{"side":"in"}'),
  ('money_class', 'wholesale_income',     'Wholesale',                     430, '{"side":"in"}'),
  ('money_class', 'processor_fee',        'Processor Fee',                 440, '{"side":"out"}'),

  -- Neither. The difference between a year that made money and one that did not.
  ('money_class', 'owner_draw',           'Draw',                          500, '{"side":"neither"}'),
  ('money_class', 'owner_contribution',   'Capital In',                    510, '{"side":"neither"}'),
  ('money_class', 'internal_transfer',    'Transfer between our accounts', 520, '{"side":"neither"}')
on conflict (kind, value) do update set
  label = excluded.label, sort_order = excluded.sort_order,
  attributes = excluded.attributes, active = true;

