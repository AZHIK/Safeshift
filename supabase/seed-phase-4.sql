-- ============================================================================
-- PHASE 4 SEED — run after seed.sql, seed-phase-2.sql and seed-phase-3.sql.
-- Local/service-role execution only.
--
-- Demonstrates the operational core:
--   2 cancellation policies, 5 rating categories, 1 dispatch rule
--   3 quote requests (2 accepted, 1 abandoned), 2 persisted quotes
--   3 jobs (completed, in transit, cancelled) with stops/items/evidence
--   matching attempts, offers, acceptance stats, 4 ratings, 1 open dispute
--   with 3 messages, 1 recurring template and 3 scheduled occurrences
--
-- Quote 2 intentionally backs both the in-transit job and the cancelled job;
-- the Phase 4 schema deliberately does not force one job per quote, matching
-- the required seed shape.
-- ============================================================================

set search_path = public, extensions;

begin;

-- ---------------------------------------------------------------------------
-- 1. Cancellation policies (country-scoped, one per cancelling role).
-- ---------------------------------------------------------------------------
insert into public.cancellation_policies (
  id, country_id, name, description, applies_to_role,
  free_cancellation_window_minutes, fee_type, fee_value, currency_code,
  fee_tiers, is_active, created_at, updated_at
) values
  (
    '4a000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    'Tanzania customer cancellation',
    'Customers cancel free up to 10 minutes before pickup, then pay 20% of the quote.',
    'customer', 10, 'percentage_of_quote', 20.0000, 'TZS', null, true,
    now() - interval '30 days', now() - interval '30 days'
  ),
  (
    '4a000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    'Tanzania driver cancellation',
    'Drivers cancel free up to 5 minutes before pickup, then pay a TZS 5,000 fee.',
    'driver', 5, 'flat', 5000.0000, 'TZS', null, true,
    now() - interval '30 days', now() - interval '30 days'
  );

-- ---------------------------------------------------------------------------
-- 2. Rating categories. applies_to_role is the rater role.
-- ---------------------------------------------------------------------------
insert into public.rating_categories (
  id, code, name, description, applies_to_role, display_order, is_active, created_at, updated_at
) values
  ('4c000000-0000-4000-8000-000000000001', 'overall', 'Overall experience',
   'Overall satisfaction with the trip.', 'customer', 10, true, now() - interval '30 days', now() - interval '30 days'),
  ('4c000000-0000-4000-8000-000000000002', 'care_handling', 'Care and handling',
   'How carefully the cargo was handled.', 'customer', 20, true, now() - interval '30 days', now() - interval '30 days'),
  ('4c000000-0000-4000-8000-000000000003', 'vehicle_condition', 'Vehicle condition',
   'Cleanliness and roadworthiness of the vehicle.', 'customer', 30, true, now() - interval '30 days', now() - interval '30 days'),
  ('4c000000-0000-4000-8000-000000000004', 'communication', 'Communication',
   'How clearly the customer communicated before and during the trip.', 'driver', 10, true, now() - interval '30 days', now() - interval '30 days'),
  ('4c000000-0000-4000-8000-000000000005', 'punctuality', 'Punctuality',
   'Whether the customer and cargo were ready on time.', 'driver', 20, true, now() - interval '30 days', now() - interval '30 days');

-- ---------------------------------------------------------------------------
-- 3. Dispatch rule for Dar es Salaam.
-- ---------------------------------------------------------------------------
insert into public.dispatch_rules (
  id, country_id, city_id, vehicle_type_id, max_search_radius_km,
  offer_timeout_seconds, max_concurrent_offers, reassign_after_seconds,
  minimum_acceptance_rate, min_driver_rating, is_active, created_at, updated_at
) values (
  '4d000000-0000-4000-8000-000000000001',
  '33333333-0000-4000-8000-000000000001',
  '55555555-0000-4000-8000-000000000001',
  null, 8.00, 30, 2, 60, 0.6500, 4.20, true,
  now() - interval '30 days', now() - interval '30 days'
);

-- ---------------------------------------------------------------------------
-- 4. Quote requests: two converted, one abandoned.
-- ---------------------------------------------------------------------------
insert into public.quote_requests (
  id, country_id, city_id, customer_id,
  pickup_location, pickup_address, destination_location, destination_address,
  vehicle_type_id, cargo_type_id, cargo_weight_kg, cargo_volume_m3,
  scheduled_at, stop_count, waiting_minutes, requested_at, session_id, metadata,
  created_at, updated_at
) values
  (
    '4b000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo Market, Msimbazi Street',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani City Mall, Sam Nujoma Road',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    300.00, 2.00, now() - interval '3 days', 2, 0,
    now() - interval '3 days 5 minutes', 'seed-session-q1',
    '{"source":"seed-phase-4","outcome":"accepted"}'::jsonb,
    now() - interval '3 days 5 minutes', now() - interval '3 days 5 minutes'
  ),
  (
    '4b000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000002',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2800 -6.8200)'),
    'Ilala, Uhuru Street',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2300 -6.7200)'),
    'Mbezi Beach, Bagamoyo Road',
    '22000000-0000-4000-8000-000000000003',
    '25000000-0000-4000-8000-000000000002',
    3500.00, 20.00, now() - interval '2 hours', 2, 0,
    now() - interval '2 hours 5 minutes', 'seed-session-q2',
    '{"source":"seed-phase-4","outcome":"accepted"}'::jsonb,
    now() - interval '2 hours 5 minutes', now() - interval '2 hours 5 minutes'
  ),
  (
    '4b000000-0000-4000-8000-000000000003',
    '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000003',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2100 -6.8300)'),
    'Tabata, Mandela Road',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2210 -6.7730)'),
    'Ubungo, Morogoro Road',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    100.00, 1.00, now() + interval '1 day', 2, 0,
    now() - interval '30 minutes', 'seed-session-q3',
    '{"source":"seed-phase-4","outcome":"abandoned"}'::jsonb,
    now() - interval '30 minutes', now() - interval '30 minutes'
  );

-- ---------------------------------------------------------------------------
-- 5. Persisted quotes. Values come from the Phase 3 preview engine so the
--    snapshot, line items and totals stay internally consistent.
-- ---------------------------------------------------------------------------
do $$
declare
  v_van_version  uuid;
  v_mt_version   uuid;
  v_q1           jsonb;
  v_q2           jsonb;
  v_req1         timestamptz := now() - interval '3 days';
  v_req2         timestamptz := now() - interval '2 hours';
  v_zone         uuid := '66666666-0000-4000-8000-000000000001';
begin
  v_van_version := public.active_pricing_plan_version(
    '31000000-0000-4000-8000-000000000001', now()
  );
  v_mt_version := public.active_pricing_plan_version(
    '31000000-0000-4000-8000-000000000003', now()
  );

  v_q1 := public.quote_preview(
    v_van_version, 8.5, 25, 300, 2,
    '25000000-0000-4000-8000-000000000001',
    '{}'::uuid[], v_zone, v_req1
  );

  v_q2 := public.quote_preview(
    v_mt_version, 12.0, 40, 3500, 20,
    '25000000-0000-4000-8000-000000000002',
    '{}'::uuid[], v_zone, v_req2
  );

  insert into public.quotes (
    id, quote_request_id, pricing_plan_version_id, currency_code,
    base_fare, distance_charge, time_charge, weight_surcharge, volume_surcharge,
    cargo_surcharge, equipment_surcharge, waiting_charge, multi_stop_charge,
    zone_multiplier, time_multiplier, surge_multiplier, promo_code_id,
    promo_discount, subtotal, vat, total, is_capped, regulated_max_fare,
    pricing_breakdown_snapshot, distance_km, estimated_duration_min,
    expires_at, created_at
  ) values (
    '4e000000-0000-4000-8000-000000000001',
    '4b000000-0000-4000-8000-000000000001',
    v_van_version, 'TZS',
    (v_q1 ->> 'base_fare')::numeric,
    (v_q1 ->> 'distance_charge')::numeric,
    (v_q1 ->> 'time_charge')::numeric,
    (v_q1 ->> 'weight_surcharge')::numeric,
    (v_q1 ->> 'volume_surcharge')::numeric,
    (v_q1 ->> 'cargo_surcharge')::numeric,
    (v_q1 ->> 'equipment_surcharge')::numeric,
    (v_q1 ->> 'waiting_charge')::numeric,
    (v_q1 ->> 'multi_stop_charge')::numeric,
    (v_q1 ->> 'zone_multiplier')::numeric,
    (v_q1 ->> 'time_multiplier')::numeric,
    1.0000, null, 0,
    (v_q1 ->> 'subtotal')::numeric,
    (v_q1 ->> 'vat')::numeric,
    (v_q1 ->> 'total')::numeric,
    (v_q1 ->> 'is_capped')::boolean,
    nullif(v_q1 ->> 'regulated_max_fare', 'null')::numeric,
    jsonb_build_object(
      'quote_id', '4e000000-0000-4000-8000-000000000001',
      'quote_request_id', '4b000000-0000-4000-8000-000000000001',
      'source', 'seed-phase-4',
      'inputs', jsonb_build_object(
        'customer_id', 'c0000000-0000-4000-8000-000000000001',
        'pickup_address', 'Kariakoo Market, Msimbazi Street',
        'destination_address', 'Mlimani City Mall, Sam Nujoma Road',
        'vehicle_type_id', '22000000-0000-4000-8000-000000000001',
        'cargo_type_id', '25000000-0000-4000-8000-000000000001',
        'scheduled_at', v_req1, 'stop_count', 2, 'waiting_minutes', 0
      ),
      'plan', jsonb_build_object(
        'pricing_plan_version_id', v_van_version,
        'pricing_plan_id', '31000000-0000-4000-8000-000000000001',
        'currency_code', 'TZS'
      ),
      'surge', jsonb_build_object('multiplier', 1.0000),
      'promo', jsonb_build_object(
        'promo_code_id', null, 'discount_amount', 0, 'applied', false
      ),
      'calculation', v_q1,
      'final', jsonb_build_object(
        'currency_code', 'TZS',
        'subtotal', (v_q1 ->> 'subtotal')::numeric,
        'promo_discount', 0,
        'vat', (v_q1 ->> 'vat')::numeric,
        'total', (v_q1 ->> 'total')::numeric,
        'is_capped', (v_q1 ->> 'is_capped')::boolean,
        'regulated_max_fare', nullif(v_q1 ->> 'regulated_max_fare', 'null')::numeric
      )
    ),
    8.5, 25, v_req1 + interval '15 minutes', v_req1
  );

  insert into public.quotes (
    id, quote_request_id, pricing_plan_version_id, currency_code,
    base_fare, distance_charge, time_charge, weight_surcharge, volume_surcharge,
    cargo_surcharge, equipment_surcharge, waiting_charge, multi_stop_charge,
    zone_multiplier, time_multiplier, surge_multiplier, promo_code_id,
    promo_discount, subtotal, vat, total, is_capped, regulated_max_fare,
    pricing_breakdown_snapshot, distance_km, estimated_duration_min,
    expires_at, created_at
  ) values (
    '4e000000-0000-4000-8000-000000000002',
    '4b000000-0000-4000-8000-000000000002',
    v_mt_version, 'TZS',
    (v_q2 ->> 'base_fare')::numeric,
    (v_q2 ->> 'distance_charge')::numeric,
    (v_q2 ->> 'time_charge')::numeric,
    (v_q2 ->> 'weight_surcharge')::numeric,
    (v_q2 ->> 'volume_surcharge')::numeric,
    (v_q2 ->> 'cargo_surcharge')::numeric,
    (v_q2 ->> 'equipment_surcharge')::numeric,
    (v_q2 ->> 'waiting_charge')::numeric,
    (v_q2 ->> 'multi_stop_charge')::numeric,
    (v_q2 ->> 'zone_multiplier')::numeric,
    (v_q2 ->> 'time_multiplier')::numeric,
    1.0000, null, 0,
    (v_q2 ->> 'subtotal')::numeric,
    (v_q2 ->> 'vat')::numeric,
    (v_q2 ->> 'total')::numeric,
    (v_q2 ->> 'is_capped')::boolean,
    nullif(v_q2 ->> 'regulated_max_fare', 'null')::numeric,
    jsonb_build_object(
      'quote_id', '4e000000-0000-4000-8000-000000000002',
      'quote_request_id', '4b000000-0000-4000-8000-000000000002',
      'source', 'seed-phase-4',
      'inputs', jsonb_build_object(
        'customer_id', 'c0000000-0000-4000-8000-000000000002',
        'pickup_address', 'Ilala, Uhuru Street',
        'destination_address', 'Mbezi Beach, Bagamoyo Road',
        'vehicle_type_id', '22000000-0000-4000-8000-000000000003',
        'cargo_type_id', '25000000-0000-4000-8000-000000000002',
        'scheduled_at', v_req2, 'stop_count', 2, 'waiting_minutes', 0
      ),
      'plan', jsonb_build_object(
        'pricing_plan_version_id', v_mt_version,
        'pricing_plan_id', '31000000-0000-4000-8000-000000000003',
        'currency_code', 'TZS'
      ),
      'surge', jsonb_build_object('multiplier', 1.0000),
      'promo', jsonb_build_object(
        'promo_code_id', null, 'discount_amount', 0, 'applied', false
      ),
      'calculation', v_q2,
      'final', jsonb_build_object(
        'currency_code', 'TZS',
        'subtotal', (v_q2 ->> 'subtotal')::numeric,
        'promo_discount', 0,
        'vat', (v_q2 ->> 'vat')::numeric,
        'total', (v_q2 ->> 'total')::numeric,
        'is_capped', (v_q2 ->> 'is_capped')::boolean,
        'regulated_max_fare', nullif(v_q2 ->> 'regulated_max_fare', 'null')::numeric
      )
    ),
    12.0, 40, v_req2 + interval '15 minutes', v_req2
  );
end $$;

-- ---------------------------------------------------------------------------
-- 6. Jobs. final_amount/final_currency/distance are derived by the insert
--    trigger from the quote; statuses are service-context seed states.
-- ---------------------------------------------------------------------------
insert into public.jobs (
  id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
  scheduled_at, accepted_at, started_at, completed_at, cancelled_at,
  payment_status, payment_method, cancellation_policy_applied, cancellation_fee,
  distance_km, actual_duration_min, actual_distance_km, notes, created_at, updated_at
) values
  (
    '4f000000-0000-4000-8000-000000000001',
    '4e000000-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    '28000000-0000-4000-8000-000000000001',
    'completed',
    now() - interval '3 days',
    now() - interval '3 days' + interval '5 minutes',
    now() - interval '3 days' + interval '10 minutes',
    now() - interval '3 days' + interval '55 minutes',
    null,
    'paid', 'mpesa', null, 0,
    8.5, 45, 9.1,
    'Delivered and signed for at Mlimani City.',
    now() - interval '3 days 5 minutes', now() - interval '3 days' + interval '55 minutes'
  ),
  (
    '4f000000-0000-4000-8000-000000000002',
    '4e000000-0000-4000-8000-000000000002',
    '55555555-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000003',
    '28000000-0000-4000-8000-000000000003',
    'in_transit',
    now() - interval '2 hours',
    now() - interval '2 hours' + interval '5 minutes',
    now() - interval '2 hours' + interval '10 minutes',
    null, null,
    'paid', 'cash', null, 0,
    12.0, null, null,
    'Medium-truck move to Mbezi Beach; driver en route.',
    now() - interval '2 hours 5 minutes', now() - interval '2 hours' + interval '10 minutes'
  ),
  (
    '4f000000-0000-4000-8000-000000000003',
    '4e000000-0000-4000-8000-000000000002',
    '55555555-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000002',
    null, null, 'cancelled',
    now() + interval '5 minutes',
    null, null, null,
    now() - interval '10 minutes',
    'pending', null, 'Tanzania customer cancellation',
    (select round(total * 0.20, 2) from public.quotes where id = '4e000000-0000-4000-8000-000000000002'),
    12.0, null, null,
    'Customer cancelled before dispatch.',
    now() - interval '30 minutes', now() - interval '10 minutes'
  );

-- ---------------------------------------------------------------------------
-- 7. Stops and cargo manifest.
-- ---------------------------------------------------------------------------
insert into public.job_stops (
  id, job_id, stop_sequence, stop_type, location, address,
  contact_name, contact_phone, notes, arrived_at, completed_at, created_at, updated_at
) values
  ('5a000000-0000-4000-8000-000000000001', '4f000000-0000-4000-8000-000000000001', 1, 'pickup',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), 'Kariakoo Market, Msimbazi Street',
   'Juma Ally', '+255711000001', 'Load at the main market entrance.',
   now() - interval '3 days' + interval '20 minutes', now() - interval '3 days' + interval '25 minutes',
   now() - interval '3 days 5 minutes', now() - interval '3 days' + interval '25 minutes'),
  ('5a000000-0000-4000-8000-000000000002', '4f000000-0000-4000-8000-000000000001', 2, 'dropoff',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), 'Mlimani City Mall, Sam Nujoma Road',
   'Juma Ally', '+255711000001', 'Deliver to the mall main parking entrance.',
   now() - interval '3 days' + interval '45 minutes', now() - interval '3 days' + interval '50 minutes',
   now() - interval '3 days 5 minutes', now() - interval '3 days' + interval '50 minutes'),
  ('5a000000-0000-4000-8000-000000000003', '4f000000-0000-4000-8000-000000000002', 1, 'pickup',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2800 -6.8200)'), 'Ilala, Uhuru Street',
   'Fatuma Hassan', '+255711000002', 'Call on arrival; narrow street.',
   now() - interval '2 hours' + interval '15 minutes', now() - interval '2 hours' + interval '20 minutes',
   now() - interval '2 hours 5 minutes', now() - interval '2 hours' + interval '20 minutes'),
  ('5a000000-0000-4000-8000-000000000004', '4f000000-0000-4000-8000-000000000002', 2, 'dropoff',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2300 -6.7200)'), 'Mbezi Beach, Bagamoyo Road',
   'Fatuma Hassan', '+255711000002', 'White metal gate near the roundabout.',
   null, null,
   now() - interval '2 hours 5 minutes', now() - interval '2 hours 5 minutes'),
  ('5a000000-0000-4000-8000-000000000005', '4f000000-0000-4000-8000-000000000003', 1, 'pickup',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2800 -6.8200)'), 'Ilala, Uhuru Street',
   'Fatuma Hassan', '+255711000002', 'Cancelled before dispatch.',
   null, null,
   now() - interval '30 minutes', now() - interval '10 minutes'),
  ('5a000000-0000-4000-8000-000000000006', '4f000000-0000-4000-8000-000000000003', 2, 'dropoff',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2300 -6.7200)'), 'Mbezi Beach, Bagamoyo Road',
   'Fatuma Hassan', '+255711000002', 'Cancelled before dispatch.',
   null, null,
   now() - interval '30 minutes', now() - interval '10 minutes');

insert into public.job_items (
  id, job_id, description, quantity, weight_kg, volume_m3,
  declared_value, currency_code, is_fragile, requires_special_handling,
  photo_urls, created_at, updated_at
) values
  ('5b000000-0000-4000-8000-000000000001', '4f000000-0000-4000-8000-000000000001',
   'Three-seater sofa', 1, 120.00, 1.80, 450000.00, 'TZS', false, true,
   '{job-items/4f000000-0000-4000-8000-000000000001/sofa.jpg}',
   now() - interval '3 days 5 minutes', now() - interval '3 days 5 minutes'),
  ('5b000000-0000-4000-8000-000000000002', '4f000000-0000-4000-8000-000000000001',
   'Packed household boxes', 12, 160.00, 0.15, 120000.00, 'TZS', false, false,
   '{}',
   now() - interval '3 days 5 minutes', now() - interval '3 days 5 minutes'),
  ('5b000000-0000-4000-8000-000000000003', '4f000000-0000-4000-8000-000000000001',
   'Refrigerator', 1, 80.00, 0.70, 900000.00, 'TZS', true, true,
   '{job-items/4f000000-0000-4000-8000-000000000001/fridge.jpg}',
   now() - interval '3 days 5 minutes', now() - interval '3 days 5 minutes');

insert into public.job_evidence (
  id, job_id, stop_id, evidence_type, storage_path, file_mime_type,
  file_size_bytes, metadata, created_by, created_at
) values
  ('5c000000-0000-4000-8000-000000000001', '4f000000-0000-4000-8000-000000000001',
   '5a000000-0000-4000-8000-000000000001', 'pickup_photo',
   'jobs/4f000000-0000-4000-8000-000000000001/pickup.jpg', 'image/jpeg', 184320,
   '{"camera":"driver-app","captured_at":"pickup"}'::jsonb,
   'd0000000-0000-4000-8000-000000000001', now() - interval '3 days' + interval '22 minutes'),
  ('5c000000-0000-4000-8000-000000000002', '4f000000-0000-4000-8000-000000000001',
   '5a000000-0000-4000-8000-000000000002', 'delivery_photo',
   'jobs/4f000000-0000-4000-8000-000000000001/delivery.jpg', 'image/jpeg', 201400,
   '{"camera":"driver-app","captured_at":"delivery"}'::jsonb,
   'd0000000-0000-4000-8000-000000000001', now() - interval '3 days' + interval '52 minutes'),
  ('5c000000-0000-4000-8000-000000000003', '4f000000-0000-4000-8000-000000000001',
   null, 'otp',
   'jobs/4f000000-0000-4000-8000-000000000001/otp.txt', 'text/plain', 64,
   '{"verified":true,"method":"delivery_otp"}'::jsonb,
   'd0000000-0000-4000-8000-000000000001', now() - interval '3 days' + interval '53 minutes'),
  ('5c000000-0000-4000-8000-000000000004', '4f000000-0000-4000-8000-000000000002',
   '5a000000-0000-4000-8000-000000000003', 'pickup_photo',
   'jobs/4f000000-0000-4000-8000-000000000002/pickup.jpg', 'image/jpeg', 176500,
   '{"camera":"driver-app","captured_at":"pickup"}'::jsonb,
   'd0000000-0000-4000-8000-000000000003', now() - interval '2 hours' + interval '18 minutes');

-- ---------------------------------------------------------------------------
-- 8. Append-only status history.
-- ---------------------------------------------------------------------------
insert into public.job_status_history (
  job_id, from_status, to_status, changed_by, reason, created_at
) values
  ('4f000000-0000-4000-8000-000000000001', 'requested', 'matched', 'a0000000-0000-4000-8000-000000000002', 'Dispatch matched Joseph Mwakyusa.', now() - interval '3 days' + interval '1 minute'),
  ('4f000000-0000-4000-8000-000000000001', 'matched', 'accepted', 'd0000000-0000-4000-8000-000000000001', 'Driver accepted the job.', now() - interval '3 days' + interval '5 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'accepted', 'heading_to_pickup', 'd0000000-0000-4000-8000-000000000001', 'Driver left for pickup.', now() - interval '3 days' + interval '10 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'heading_to_pickup', 'arrived', 'd0000000-0000-4000-8000-000000000001', 'Driver arrived at Kariakoo.', now() - interval '3 days' + interval '20 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'arrived', 'loading', 'd0000000-0000-4000-8000-000000000001', 'Loading started.', now() - interval '3 days' + interval '25 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'loading', 'in_transit', 'd0000000-0000-4000-8000-000000000001', 'Loaded and departed.', now() - interval '3 days' + interval '35 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'in_transit', 'delivered', 'd0000000-0000-4000-8000-000000000001', 'Delivered at Mlimani City.', now() - interval '3 days' + interval '50 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'delivered', 'completed', 'd0000000-0000-4000-8000-000000000001', 'Delivery OTP verified.', now() - interval '3 days' + interval '55 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'requested', 'matched', 'a0000000-0000-4000-8000-000000000002', 'Dispatch matched Hamisi Juma.', now() - interval '2 hours' + interval '2 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'matched', 'accepted', 'd0000000-0000-4000-8000-000000000003', 'Driver accepted the job.', now() - interval '2 hours' + interval '5 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'accepted', 'heading_to_pickup', 'd0000000-0000-4000-8000-000000000003', 'Driver left for pickup.', now() - interval '2 hours' + interval '10 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'heading_to_pickup', 'arrived', 'd0000000-0000-4000-8000-000000000003', 'Driver arrived at Ilala.', now() - interval '2 hours' + interval '15 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'arrived', 'loading', 'd0000000-0000-4000-8000-000000000003', 'Loading started.', now() - interval '2 hours' + interval '20 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'loading', 'in_transit', 'd0000000-0000-4000-8000-000000000003', 'Loaded and departed for Mbezi.', now() - interval '2 hours' + interval '30 minutes'),
  ('4f000000-0000-4000-8000-000000000003', 'requested', 'matched', 'a0000000-0000-4000-8000-000000000002', 'Dispatch matched the cancelled job.', now() - interval '29 minutes'),
  ('4f000000-0000-4000-8000-000000000003', 'matched', 'cancelled', 'c0000000-0000-4000-8000-000000000002', 'Customer cancelled before dispatch.', now() - interval '10 minutes');

-- ---------------------------------------------------------------------------
-- 9. Lifecycle events.
-- ---------------------------------------------------------------------------
insert into public.job_events (job_id, event_type, actor_id, details, created_at)
values
  ('4f000000-0000-4000-8000-000000000001', 'created', 'c0000000-0000-4000-8000-000000000001', '{"source":"quote"}'::jsonb, now() - interval '3 days' + interval '30 seconds'),
  ('4f000000-0000-4000-8000-000000000001', 'driver_assigned', 'a0000000-0000-4000-8000-000000000002', '{"driver_id":"d0000000-0000-4000-8000-000000000001"}'::jsonb, now() - interval '3 days' + interval '5 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'driver_arrived', 'd0000000-0000-4000-8000-000000000001', '{"stop_sequence":1}'::jsonb, now() - interval '3 days' + interval '20 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'pickup_completed', 'd0000000-0000-4000-8000-000000000001', '{"stop_sequence":1}'::jsonb, now() - interval '3 days' + interval '25 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'in_transit', 'd0000000-0000-4000-8000-000000000001', '{}'::jsonb, now() - interval '3 days' + interval '35 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'delivered', 'd0000000-0000-4000-8000-000000000001', '{"stop_sequence":2}'::jsonb, now() - interval '3 days' + interval '50 minutes'),
  ('4f000000-0000-4000-8000-000000000001', 'completed', 'd0000000-0000-4000-8000-000000000001', '{"otp_verified":true}'::jsonb, now() - interval '3 days' + interval '55 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'created', 'c0000000-0000-4000-8000-000000000002', '{"source":"quote"}'::jsonb, now() - interval '2 hours' + interval '30 seconds'),
  ('4f000000-0000-4000-8000-000000000002', 'driver_assigned', 'a0000000-0000-4000-8000-000000000002', '{"driver_id":"d0000000-0000-4000-8000-000000000003"}'::jsonb, now() - interval '2 hours' + interval '5 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'driver_arrived', 'd0000000-0000-4000-8000-000000000003', '{"stop_sequence":1}'::jsonb, now() - interval '2 hours' + interval '15 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'pickup_completed', 'd0000000-0000-4000-8000-000000000003', '{"stop_sequence":1}'::jsonb, now() - interval '2 hours' + interval '20 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'in_transit', 'd0000000-0000-4000-8000-000000000003', '{}'::jsonb, now() - interval '2 hours' + interval '30 minutes'),
  ('4f000000-0000-4000-8000-000000000002', 'note', 'd0000000-0000-4000-8000-000000000003', '{"note":"Light traffic on Bagamoyo Road."}'::jsonb, now() - interval '1 hour' + interval '30 minutes'),
  ('4f000000-0000-4000-8000-000000000003', 'created', 'c0000000-0000-4000-8000-000000000002', '{"source":"quote"}'::jsonb, now() - interval '30 minutes'),
  ('4f000000-0000-4000-8000-000000000003', 'cancelled', 'c0000000-0000-4000-8000-000000000002', '{"reason":"Customer cancelled before dispatch."}'::jsonb, now() - interval '10 minutes');

-- ---------------------------------------------------------------------------
-- 10. Cancellation record for the third job.
-- ---------------------------------------------------------------------------
insert into public.job_cancellations (
  id, job_id, cancelled_by, canceller_role, reason, cancellation_policy_id,
  fee_applied, refund_amount, currency_code, refund_status, notes, created_at
) values (
  '5d000000-0000-4000-8000-000000000001',
  '4f000000-0000-4000-8000-000000000003',
  'c0000000-0000-4000-8000-000000000002',
  'customer',
  'Customer cancelled before dispatch.',
  '4a000000-0000-4000-8000-000000000001',
  (select round(total * 0.20, 2) from public.quotes where id = '4e000000-0000-4000-8000-000000000002'),
  0, 'TZS', 'not_applicable',
  'No payment had been captured; refund handled by Phase 5 when applicable.',
  now() - interval '10 minutes'
);

-- ---------------------------------------------------------------------------
-- 11. Driver location pings (current month partitions).
-- ---------------------------------------------------------------------------
insert into public.driver_locations (
  driver_id, job_id, location, heading_degrees, speed_kmh, accuracy_m, recorded_at, created_at
)
select
  v.driver_id,
  null,
  extensions.ST_GeogFromText(v.point_wkt),
  ((v.heading + g * 3) % 360)::smallint,
  (v.speed + g)::numeric(5,2),
  (12.0 + g)::numeric(6,2),
  now() - ((6 - g) * interval '5 minutes'),
  now() - ((6 - g) * interval '5 minutes')
from (values
  ('d0000000-0000-4000-8000-000000000001'::uuid, 'SRID=4326;POINT(39.2750 -6.8150)', 45, 18.0),
  ('d0000000-0000-4000-8000-000000000002'::uuid, 'SRID=4326;POINT(39.2210 -6.7730)', 180, 12.0),
  ('d0000000-0000-4000-8000-000000000003'::uuid, 'SRID=4326;POINT(39.2700 -6.8600)', 270, 22.0)
) as v(driver_id, point_wkt, heading, speed)
cross join generate_series(1, 5) as g;

-- ---------------------------------------------------------------------------
-- 12. Matching attempts, offers and acceptance statistics.
-- ---------------------------------------------------------------------------
insert into public.matching_attempts (
  id, job_id, attempt_number, matched_driver_id, drivers_considered,
  drivers_offered, match_successful, failure_reason, started_at, ended_at,
  metadata, created_at
) values
  ('5e000000-0000-4000-8000-000000000001', '4f000000-0000-4000-8000-000000000001',
   1, 'd0000000-0000-4000-8000-000000000001', 4, 2, true, null,
   now() - interval '3 days' + interval '4 minutes', now() - interval '3 days' + interval '5 minutes',
   '{"strategy":"nearest_first","radius_km":8}'::jsonb, now() - interval '3 days' + interval '4 minutes'),
  ('5e000000-0000-4000-8000-000000000002', '4f000000-0000-4000-8000-000000000002',
   1, 'd0000000-0000-4000-8000-000000000003', 3, 2, true, null,
   now() - interval '2 hours' + interval '4 minutes', now() - interval '2 hours' + interval '5 minutes',
   '{"strategy":"nearest_first","radius_km":8}'::jsonb, now() - interval '2 hours' + interval '4 minutes');

insert into public.job_offers (
  id, job_id, driver_id, offer_sequence, offered_at, expires_at, responded_at,
  response, decline_reason, distance_to_pickup_km, eta_minutes,
  payout_estimate, currency_code, created_at
) values
  ('5f000000-0000-4000-8000-000000000001', '4f000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-000000000003', 1,
   now() - interval '2 hours' + interval '5 minutes',
   now() - interval '2 hours' + interval '5 minutes 30 seconds',
   now() - interval '2 hours' + interval '5 minutes 15 seconds',
   'accepted', null, 1.20, 4, null, 'TZS',
   now() - interval '2 hours' + interval '5 minutes'),
  ('5f000000-0000-4000-8000-000000000002', '4f000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-000000000001', 2,
   now() - interval '2 hours' + interval '4 minutes',
   now() - interval '2 hours' + interval '4 minutes 30 seconds',
   now() - interval '2 hours' + interval '5 minutes 16 seconds',
   'auto_reassigned', 'Auto-reassigned after another driver accepted', 6.80, 22, null, 'TZS',
   now() - interval '2 hours' + interval '4 minutes');

insert into public.driver_acceptance_stats (
  driver_id, window_start, window_end, offers_received, offers_accepted,
  offers_declined, offers_expired, acceptance_rate, avg_response_seconds, updated_at
) values
  ('d0000000-0000-4000-8000-000000000001', now() - interval '30 days', now(), 40, 35, 3, 2, 0.8750, 18.50, now()),
  ('d0000000-0000-4000-8000-000000000002', now() - interval '30 days', now(), 10, 6, 3, 1, 0.6000, 25.00, now()),
  ('d0000000-0000-4000-8000-000000000003', now() - interval '30 days', now(), 30, 25, 4, 1, 0.8333, 21.00, now())
on conflict (driver_id) do update
  set window_start = excluded.window_start,
      window_end = excluded.window_end,
      offers_received = excluded.offers_received,
      offers_accepted = excluded.offers_accepted,
      offers_declined = excluded.offers_declined,
      offers_expired = excluded.offers_expired,
      acceptance_rate = excluded.acceptance_rate,
      avg_response_seconds = excluded.avg_response_seconds,
      updated_at = now();

-- ---------------------------------------------------------------------------
-- 13. Ratings: two from the customer, two from the driver.
-- ---------------------------------------------------------------------------
insert into public.ratings (
  id, job_id, rater_profile_id, rated_profile_id, rated_role,
  rating_category_id, score, comment, is_anonymous, created_at
) values
  ('6a000000-0000-4000-8000-000000000001', '4f000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'driver',
   '4c000000-0000-4000-8000-000000000001', 5, 'Careful driver and on time.', false,
   now() - interval '3 days' + interval '1 hour'),
  ('6a000000-0000-4000-8000-000000000002', '4f000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'driver',
   '4c000000-0000-4000-8000-000000000002', 4, 'Sofa arrived without damage.', false,
   now() - interval '3 days' + interval '1 hour'),
  ('6a000000-0000-4000-8000-000000000003', '4f000000-0000-4000-8000-000000000001',
   'd0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'customer',
   '4c000000-0000-4000-8000-000000000004', 5, 'Clear instructions and ready at pickup.', false,
   now() - interval '3 days' + interval '1 hour'),
  ('6a000000-0000-4000-8000-000000000004', '4f000000-0000-4000-8000-000000000001',
   'd0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'customer',
   '4c000000-0000-4000-8000-000000000005', 4, 'Cargo was ready a few minutes late.', false,
   now() - interval '3 days' + interval '1 hour');

-- ---------------------------------------------------------------------------
-- 14. Open dispute with three messages (including one internal note).
-- ---------------------------------------------------------------------------
insert into public.disputes (
  id, job_id, raised_by, raised_by_role, dispute_type, status, priority,
  summary, requested_resolution, resolved_by, resolved_at, resolution_notes,
  compensation_amount, currency_code, sla_due_at, created_at, updated_at
) values (
  '6b000000-0000-4000-8000-000000000001',
  '4f000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000002',
  'customer', 'damage', 'open', 'high',
  'One box of kitchenware was cracked during loading at Ilala.',
  'Customer requests TZS 80,000 compensation and a damage review.',
  null, null, null, null, null,
  now() + interval '4 hours',
  now() - interval '1 hour', now() - interval '45 minutes'
);

insert into public.dispute_messages (
  id, dispute_id, sender_profile_id, message, is_internal_note, created_at
) values
  ('6c000000-0000-4000-8000-000000000001', '6b000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000002',
   'The box was intact at pickup and cracked by the time it reached Mbezi. Please review the loading photos.',
   false, now() - interval '55 minutes'),
  ('6c000000-0000-4000-8000-000000000002', '6b000000-0000-4000-8000-000000000001',
   'd0000000-0000-4000-8000-000000000003',
   'I have uploaded the pickup photo. The box was already dented before loading.',
   false, now() - interval '50 minutes'),
  ('6c000000-0000-4000-8000-000000000003', '6b000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000003',
   'Internal: compare pickup photo 5c000000-0000-4000-8000-000000000004 and check cargo insurance.',
   true, now() - interval '45 minutes');

-- ---------------------------------------------------------------------------
-- 15. Recurring template and the next three scheduled occurrences.
-- ---------------------------------------------------------------------------
insert into public.recurring_job_templates (
  id, business_account_id, created_by, name, description,
  pickup_address_id, destination_address_id, vehicle_type_id, cargo_type_id,
  default_cargo_weight_kg, default_cargo_volume_m3, recurrence_rule,
  time_of_day, timezone, preferred_driver_id, is_active, created_at, updated_at
) values (
  '6d000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'e0000000-0000-4000-8000-000000000001',
  'Monday fresh-produce run',
  'Weekly refrigerated pickup at Mlimani City for the Temeke distribution point.',
  '88888888-0000-4000-8000-000000000002',
  '88888888-0000-4000-8000-000000000004',
  '22000000-0000-4000-8000-000000000005',
  '25000000-0000-4000-8000-000000000005',
  2500.00, 15.00, 'FREQ=WEEKLY;BYDAY=MO',
  '08:00', 'Africa/Dar_es_Salaam', null, true,
  now() - interval '7 days', now() - interval '7 days'
);

insert into public.scheduled_jobs (
  id, template_id, quote_request_id, job_id, scheduled_for, status,
  generated_at, error_reason, created_at, updated_at
)
select
  v.id,
  '6d000000-0000-4000-8000-000000000001',
  null, null,
  (
    (date_trunc('week', now())::date + 7 + (v.week_offset * 7))
    + time '08:00'
  ) at time zone 'Africa/Dar_es_Salaam',
  'pending', null, null, now(), now()
from (values
  ('6e000000-0000-4000-8000-000000000001'::uuid, 0),
  ('6e000000-0000-4000-8000-000000000002'::uuid, 1),
  ('6e000000-0000-4000-8000-000000000003'::uuid, 2)
) as v(id, week_offset);

commit;
