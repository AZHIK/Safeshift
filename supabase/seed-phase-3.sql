-- ============================================================================
-- PHASE 3 SEED — run after seed.sql and seed-phase-2.sql.
-- Local/service-role execution only. It creates the Tanzanian LATRA tariff,
-- six Dar es Salaam pricing plans with published versions, a second van
-- version that demonstrates the supersede workflow, five promo codes and the
-- Phase 1 zone override resolution.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Permissions used by Phase 3 RLS and operations.
--    Migration 0049 installs these too; this keeps seed-only environments
--    aligned with the Phase 2 seed convention.
-- ---------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_pricing', 'Create pricing plans and publish plan versions', 'pricing'),
  ('manage_regulated_tariffs', 'Manage regulated tariff frameworks and legal bands', 'compliance'),
  ('manage_promotions', 'Create, edit and deactivate promo codes and rules', 'operations'),
  ('view_promotions', 'View all promo codes and redemption records', 'operations')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', permission_key
from public.admin_permissions_catalog
where permission_key in ('manage_pricing', 'manage_regulated_tariffs', 'manage_promotions', 'view_promotions')
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('finance_admin',    'manage_pricing'),
  ('finance_admin',    'manage_regulated_tariffs'),
  ('finance_admin',    'manage_promotions'),
  ('finance_admin',    'view_promotions'),
  ('operations_admin', 'manage_promotions'),
  ('operations_admin', 'view_promotions'),
  ('support_agent',    'view_promotions'),
  ('analyst',          'view_promotions')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. LATRA goods transport tariff (Tanzania) and legal bands.
-- ---------------------------------------------------------------------------
insert into public.regulated_tariffs (
  id, country_id, regulatory_body, name, vehicle_type_id, approval_reference,
  approval_date, published_gazette_date, effective_from, effective_to,
  tariff_structure, currency_code, source_document_url, notes, is_active
) values (
  '30000000-0000-4000-8000-000000000001',
  '33333333-0000-4000-8000-000000000001',
  'LATRA',
  'LATRA Goods Transport Tariff 2026',
  null,
  'LATRA/GT/2026/001',
  '2026-01-01',
  '2025-12-15',
  '2026-01-01 00:00:00+03',
  null,
  'distance_and_weight_band',
  'TZS',
  null,
  'Demonstration tariff seeded for local development. Legal values must be reviewed by compliance before production.',
  true
);

insert into public.regulated_tariff_bands (
  id, regulated_tariff_id, band_type, min_value, max_value, value_unit,
  min_fare, max_fare, display_order
) values
  ('30100000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'distance', 0,   5,   'km', 15000, 40000,  10),
  ('30100000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001', 'distance', 5,   10,  'km', 30000, 70000,  20),
  ('30100000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000001', 'distance', 10,  20,  'km', 50000, 120000, 30),
  ('30100000-0000-4000-8000-000000000004', '30000000-0000-4000-8000-000000000001', 'distance', 20,  50,  'km', 90000, 250000, 40),
  ('30100000-0000-4000-8000-000000000005', '30000000-0000-4000-8000-000000000001', 'distance', 50,  100, 'km', 180000, 450000, 50),
  ('30100000-0000-4000-8000-000000000006', '30000000-0000-4000-8000-000000000001', 'distance', 100, null, 'km', 300000, 800000, 60),
  ('30100000-0000-4000-8000-000000000007', '30000000-0000-4000-8000-000000000001', 'weight',   0,   1000, 'kg', 20000, 90000, 10),
  ('30100000-0000-4000-8000-000000000008', '30000000-0000-4000-8000-000000000001', 'weight',   1000, 3000, 'kg', 50000, 180000, 20),
  ('30100000-0000-4000-8000-000000000009', '30000000-0000-4000-8000-000000000001', 'weight',   3000, 7000, 'kg', 100000, 350000, 30),
  ('30100000-0000-4000-8000-000000000010', '30000000-0000-4000-8000-000000000001', 'weight',   7000, null, 'kg', 200000, 600000, 40);

-- ---------------------------------------------------------------------------
-- 3. Six Dar es Salaam pricing plans (one per vehicle type).
-- ---------------------------------------------------------------------------
insert into public.pricing_plans (
  id, country_id, city_id, service_zone_id, vehicle_type_id,
  code, name, description, display_order, is_active
) values
  ('31000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', null, '22000000-0000-4000-8000-000000000001', 'dar-van-standard', 'Dar es Salaam Small Van Standard', 'Everyday small-van deliveries across Dar es Salaam.', 10, true),
  ('31000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', null, '22000000-0000-4000-8000-000000000002', 'dar-pickup-standard', 'Dar es Salaam Pickup Standard', 'Open-bed pickup for bulky light cargo.', 20, true),
  ('31000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', null, '22000000-0000-4000-8000-000000000003', 'dar-mtruck-standard', 'Dar es Salaam Medium Truck Standard', 'Medium truck for household and commercial moves.', 30, true),
  ('31000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', null, '22000000-0000-4000-8000-000000000004', 'dar-ltruck-standard', 'Dar es Salaam Large Truck Standard', 'Large truck for industrial and high-volume loads.', 40, true),
  ('31000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', null, '22000000-0000-4000-8000-000000000005', 'dar-refrigerated-standard', 'Dar es Salaam Refrigerated Standard', 'Temperature-controlled transport, capped by the LATRA tariff.', 50, true),
  ('31000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', null, '22000000-0000-4000-8000-000000000006', 'dar-flatbed-standard', 'Dar es Salaam Flatbed Standard', 'Flatbed transport for machinery and oversized cargo, capped by the LATRA tariff.', 60, true);

-- ---------------------------------------------------------------------------
-- 4. Published version 1 for each plan.
-- ---------------------------------------------------------------------------
insert into public.pricing_plan_versions (
  id, pricing_plan_id, version_number, currency_code, effective_from, effective_to,
  published_at, published_by, regulated_tariff_id, notes
) values
  ('32000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), 'a0000000-0000-4000-8000-000000000001', null, 'Initial Dar es Salaam small-van version.'),
  ('32000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000002', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), 'a0000000-0000-4000-8000-000000000001', null, 'Initial Dar es Salaam pickup version.'),
  ('32000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000003', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), 'a0000000-0000-4000-8000-000000000001', null, 'Initial Dar es Salaam medium-truck version.'),
  ('32000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000004', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), 'a0000000-0000-4000-8000-000000000001', null, 'Initial Dar es Salaam large-truck version.'),
  ('32000000-0000-4000-8000-000000000005', '31000000-0000-4000-8000-000000000005', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), 'a0000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'Initial refrigerated version, regulated by LATRA.'),
  ('32000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), 'a0000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'Initial flatbed version, regulated by LATRA.');

insert into public.pricing_plan_base_rates (
  pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate,
  minimum_charge, loading_fee, unloading_fee, waiting_per_min_rate,
  waiting_free_minutes, multi_stop_fee, vat_rate
) values
  ('32000000-0000-4000-8000-000000000001', 'TZS',  5000.00, 1200.00,  50.00,  8000.00, 2000.00, 2000.00, 100.00, 5,  3000.00, 0.1800),
  ('32000000-0000-4000-8000-000000000002', 'TZS',  8000.00, 1500.00,  60.00, 12000.00, 2500.00, 2500.00, 120.00, 5,  3500.00, 0.1800),
  ('32000000-0000-4000-8000-000000000003', 'TZS', 20000.00, 2500.00, 100.00, 30000.00, 5000.00, 5000.00, 200.00, 10, 6000.00, 0.1800),
  ('32000000-0000-4000-8000-000000000004', 'TZS', 45000.00, 4000.00, 150.00, 60000.00, 8000.00, 8000.00, 300.00, 10, 10000.00, 0.1800),
  ('32000000-0000-4000-8000-000000000005', 'TZS', 35000.00, 3200.00, 130.00, 45000.00, 6000.00, 6000.00, 250.00, 10, 8000.00, 0.1800),
  ('32000000-0000-4000-8000-000000000006', 'TZS', 40000.00, 3500.00, 140.00, 50000.00, 7000.00, 7000.00, 280.00, 10, 9000.00, 0.1800);

-- Distance tiering demonstration on the van plan.
insert into public.pricing_distance_tiers (
  pricing_plan_version_id, currency_code, min_km, max_km, per_km_rate, display_order
) values
  ('32000000-0000-4000-8000-000000000001', 'TZS', 0, 10, 1200.00, 10),
  ('32000000-0000-4000-8000-000000000001', 'TZS', 10, null, 1000.00, 20);

-- Weight tiers: van uses 500 kg, trucks use 2,000 kg breakpoints.
insert into public.pricing_weight_tiers (
  pricing_plan_version_id, currency_code, min_kg, max_kg, surcharge_type, surcharge_value, display_order
) values
  ('32000000-0000-4000-8000-000000000001', 'TZS', 0, 500, 'flat_fee', 0, 10),
  ('32000000-0000-4000-8000-000000000001', 'TZS', 500, null, 'flat_fee', 2500, 20);

insert into public.pricing_weight_tiers (
  pricing_plan_version_id, currency_code, min_kg, max_kg, surcharge_type, surcharge_value, display_order
)
select v.id, 'TZS', w.min_kg, w.max_kg, 'flat_fee', w.fee, w.ord
from (values
  ('32000000-0000-4000-8000-000000000002'::uuid),
  ('32000000-0000-4000-8000-000000000003'::uuid),
  ('32000000-0000-4000-8000-000000000004'::uuid),
  ('32000000-0000-4000-8000-000000000005'::uuid),
  ('32000000-0000-4000-8000-000000000006'::uuid)
) v(id)
cross join (values
  (0::numeric, 2000::numeric, 0::numeric, 10),
  (2000::numeric, null::numeric, 15000::numeric, 20)
) w(min_kg, max_kg, fee, ord);

-- Cargo surcharges: appliances flat, electronics percentage.
insert into public.pricing_cargo_surcharges (
  pricing_plan_version_id, cargo_type_id, currency_code, surcharge_type, surcharge_value
)
select v.id, c.cargo_type_id, 'TZS', c.surcharge_type, c.surcharge_value
from (values
  ('32000000-0000-4000-8000-000000000001'::uuid),
  ('32000000-0000-4000-8000-000000000002'::uuid),
  ('32000000-0000-4000-8000-000000000003'::uuid),
  ('32000000-0000-4000-8000-000000000004'::uuid),
  ('32000000-0000-4000-8000-000000000005'::uuid),
  ('32000000-0000-4000-8000-000000000006'::uuid)
) v(id)
cross join (values
  ('25000000-0000-4000-8000-000000000003'::uuid, 'flat_fee', 5000.0000),
  ('25000000-0000-4000-8000-000000000007'::uuid, 'percentage', 10.0000)
) c(cargo_type_id, surcharge_type, surcharge_value);

-- Refrigeration unit surcharge on the refrigerated plan.
insert into public.pricing_equipment_surcharges (
  pricing_plan_version_id, equipment_id, currency_code, surcharge_type, surcharge_value
) values (
  '32000000-0000-4000-8000-000000000005',
  '23000000-0000-4000-8000-000000000006',
  'TZS', 'flat_fee', 15000.0000
);

-- Time multipliers for every v1 plan. Weekend stacks so it may overlap the
-- night window; the non-stacking peak/night windows never overlap.
insert into public.pricing_time_multipliers (
  pricing_plan_version_id, name, days_of_week, start_time, end_time,
  timezone, multiplier, applies_to, priority, stacks
)
select v.id, t.name, t.days, t.starts, t.ends, 'Africa/Dar_es_Salaam',
       t.multiplier, 'subtotal', t.priority, t.stacks
from (values
  ('32000000-0000-4000-8000-000000000001'::uuid),
  ('32000000-0000-4000-8000-000000000002'::uuid),
  ('32000000-0000-4000-8000-000000000003'::uuid),
  ('32000000-0000-4000-8000-000000000004'::uuid),
  ('32000000-0000-4000-8000-000000000005'::uuid),
  ('32000000-0000-4000-8000-000000000006'::uuid)
) v(id)
cross join (values
  ('Peak Morning',      '{1,2,3,4,5}'::smallint[], '07:00'::time, '09:00'::time, 1.3000, 30, false),
  ('Peak Evening',      '{1,2,3,4,5}'::smallint[], '17:00'::time, '19:00'::time, 1.4000, 30, false),
  ('Night Rate',        '{0,1,2,3,4,5,6}'::smallint[], '22:00'::time, '05:00'::time, 1.2500, 20, false),
  ('Weekend Surcharge', '{0,6}'::smallint[], '00:00'::time, '23:59:59'::time, 1.2000, 10, true)
) t(name, days, starts, ends, multiplier, priority, stacks);

-- ---------------------------------------------------------------------------
-- 5. Van version 2: draft-copy v1, raise base fare by 5%, publish.
--    publish_pricing_plan_version() closes v1 and links it to v2.
-- ---------------------------------------------------------------------------
do $$
declare
  v_v2 uuid;
  v_plan uuid := '31000000-0000-4000-8000-000000000001';
begin
  v_v2 := public.draft_pricing_plan_version(v_plan);

  update public.pricing_plan_base_rates
     set base_fare = round(base_fare * 1.05, 2)
   where pricing_plan_version_id = v_v2;

  update public.pricing_plan_versions
     set effective_from = '2026-07-01 00:00:00+03',
         notes = 'Van v2: 5% base-fare increase, copied from v1.'
   where id = v_v2;

  perform public.publish_pricing_plan_version(v_v2);

  -- Wire the Phase 1 Central zone override to the currently active van version
  -- and record the resolution.
  update public.zone_pricing_overrides
     set pricing_plan_id = v_v2,
         multiplier = 1.15,
         reason = 'Central zone evening peak surcharge (van v2)',
         effective_from = now(),
         effective_to = now() + interval '30 days'
   where id = '0c000000-0000-4000-8000-000000000001';

  insert into public.zone_pricing_override_resolution (
    zone_pricing_override_id, pricing_plan_version_id, resolved_by
  ) values (
    '0c000000-0000-4000-8000-000000000001', v_v2, 'a0000000-0000-4000-8000-000000000001'
  )
  on conflict do nothing;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Promo codes.
-- ---------------------------------------------------------------------------
insert into public.promo_codes (
  id, country_id, code, name, description, discount_type, discount_value,
  max_discount_amount, min_purchase_amount, currency_code, valid_from, valid_to,
  total_redemption_limit, per_user_redemption_limit, new_users_only,
  applicable_vehicle_type_ids, applicable_city_ids, applicable_cargo_type_ids,
  is_active, created_by
) values
  ('37000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'WELCOME10', 'Welcome 10%', '10% off the first booking, capped at TZS 5,000.', 'capped_percentage', 10.0000, 5000.00, 0.00, 'TZS', '2026-01-01 00:00:00+03', '2026-12-31 23:59:59+03', 1000, 1, true, '{}', '{}', '{}', true, 'a0000000-0000-4000-8000-000000000001'),
  ('37000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'DAR50', 'Dar 5,000 off', 'Flat TZS 5,000 off orders above TZS 30,000.', 'flat_amount', 5000.0000, null, 30000.00, 'TZS', '2026-01-01 00:00:00+03', '2026-12-31 23:59:59+03', 500, 2, false, '{}', '{}', '{}', true, 'a0000000-0000-4000-8000-000000000001'),
  ('37000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'MOVEWEEK', 'Move week 15%', '15% off moving jobs for seven days, capped at TZS 10,000.', 'capped_percentage', 15.0000, 10000.00, 0.00, 'TZS', now(), now() + interval '7 days', 200, 1, false, '{}', '{}', '{}', true, 'a0000000-0000-4000-8000-000000000001'),
  ('37000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'FREELOAD', 'Medium truck 8,000 off', 'Flat TZS 8,000 off medium-truck jobs.', 'flat_amount', 8000.0000, null, 0.00, 'TZS', '2026-01-01 00:00:00+03', '2026-12-31 23:59:59+03', 300, 1, false, '{22000000-0000-4000-8000-000000000003}', '{}', '{}', true, 'a0000000-0000-4000-8000-000000000001'),
  ('37000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'EXPIRED2025', 'Expired 2025 promo', 'Expired code used to test rejection paths.', 'flat_amount', 1000.0000, null, 0.00, 'TZS', '2025-01-01 00:00:00+03', '2025-12-31 23:59:59+03', 100, 1, false, '{}', '{}', '{}', true, 'a0000000-0000-4000-8000-000000000001');

insert into public.promo_code_eligibility_rules (
  id, promo_code_id, rule_type, rule_value, description
) values
  ('38000000-0000-4000-8000-000000000001', '37000000-0000-4000-8000-000000000001', 'first_job', '{}'::jsonb, 'Welcome code is for a customer''s first job.'),
  ('38000000-0000-4000-8000-000000000002', '37000000-0000-4000-8000-000000000002', 'min_jobs_completed', '{"min_jobs":3}'::jsonb, 'DAR50 requires at least three completed jobs.'),
  ('38000000-0000-4000-8000-000000000003', '37000000-0000-4000-8000-000000000003', 'specific_day_of_week', '{"day_of_week":6}'::jsonb, 'Move week runs on Saturdays.');

-- ---------------------------------------------------------------------------
-- 7. Audit trail for every seeded publish (7 published versions).
-- ---------------------------------------------------------------------------
insert into private.audit_log (
  actor_id, actor_role, action, entity_type, entity_id, old_value, new_value, created_at
)
select
  'a0000000-0000-4000-8000-000000000001',
  'admin',
  'pricing_changed',
  'pricing_plan_versions',
  v.id,
  null,
  jsonb_build_object(
    'pricing_plan_id', v.pricing_plan_id,
    'version_number', v.version_number,
    'published_at', v.published_at,
    'regulated_tariff_id', v.regulated_tariff_id
  ),
  now()
from public.pricing_plan_versions v
join public.pricing_plans p on p.id = v.pricing_plan_id
where p.code like 'dar-%'
  and v.published_at is not null;

commit;
