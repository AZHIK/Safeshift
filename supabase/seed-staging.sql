-- ============================================================================
-- SafeShift — staging configuration seed
--
-- Configuration data only. This file deliberately contains no auth users,
-- demo customers/drivers, jobs, payments, documents, chat messages, metrics,
-- or other fixture rows. Create UAT accounts through the Supabase Auth Admin
-- API and let the app's ensure_my_profile() RPC bootstrap their profiles.
--
-- Apply with:
--   supabase db push
--   psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed-staging.sql
--
-- The local demo seed files (seed*.sql) must never run against staging.
-- ============================================================================

set search_path = public, extensions;

begin;


-- 1. Currencies
-- ----------------------------------------------------------------------------
insert into public.currencies (id, code, name, symbol, decimal_places, is_active) values
  ('11111111-0000-4000-8000-000000000001', 'TZS', 'Tanzanian Shilling', 'TSh', 2, true),
  ('11111111-0000-4000-8000-000000000002', 'KES', 'Kenyan Shilling',    'KSh', 2, false),
  ('11111111-0000-4000-8000-000000000003', 'UGX', 'Ugandan Shilling',   'USh', 0, false),
  ('11111111-0000-4000-8000-000000000004', 'USD', 'United States Dollar', '$', 2, true);

-- ----------------------------------------------------------------------------
-- 2. Languages
-- ----------------------------------------------------------------------------
insert into public.languages (id, code, name, native_name, is_active) values
  ('22222222-0000-4000-8000-000000000001', 'en', 'English', 'English', true),
  ('22222222-0000-4000-8000-000000000002', 'sw', 'Swahili', 'Kiswahili', true);

-- ----------------------------------------------------------------------------
-- 3. Countries (multi-country foundation: 1 active, 2 inactive)
-- ----------------------------------------------------------------------------
insert into public.countries (
  id, iso_code, name, default_currency_id, default_timezone, default_language_id,
  regulatory_framework, tax_registration_required, is_active, launched_at, config
) values
  (
    '33333333-0000-4000-8000-000000000001', 'TZ', 'Tanzania',
    '11111111-0000-4000-8000-000000000001', 'Africa/Dar_es_Salaam',
    '22222222-0000-4000-8000-000000000002', 'LATRA', true, true, now(),
    '{"mobile_money_providers": ["mpesa", "tigo_pesa", "airtel_money", "halopesa"], "pdpc_registration_required": true}'::jsonb
  ),
  (
    '33333333-0000-4000-8000-000000000002', 'KE', 'Kenya',
    '11111111-0000-4000-8000-000000000002', 'Africa/Nairobi',
    '22222222-0000-4000-8000-000000000001', 'NTSA', true, false, null,
    '{"mobile_money_providers": ["mpesa"]}'::jsonb
  ),
  (
    '33333333-0000-4000-8000-000000000003', 'UG', 'Uganda',
    '11111111-0000-4000-8000-000000000003', 'Africa/Kampala',
    '22222222-0000-4000-8000-000000000001', 'UNRA', true, false, null,
    '{"mobile_money_providers": ["mtn_momo", "airtel_money"]}'::jsonb
  );

-- ----------------------------------------------------------------------------
-- 4. Regions
-- ----------------------------------------------------------------------------
insert into public.regions (id, country_id, name, code, is_active) values
  ('44444444-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'Dar es Salaam Region', 'DSM', true),
  ('44444444-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'Arusha Region',        'ARU', true);

-- ----------------------------------------------------------------------------
-- 5. Cities (Dar es Salaam active, Arusha inactive)
-- ----------------------------------------------------------------------------
insert into public.cities (
  id, region_id, country_id, name, timezone, latitude, longitude, boundary, is_active, launched_at, config
) values
  (
    '55555555-0000-4000-8000-000000000001',
    '44444444-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    'Dar es Salaam', 'Africa/Dar_es_Salaam', -6.7924000, 39.2083000,
    extensions.ST_GeogFromText('SRID=4326;POLYGON((39.1500 -6.9500, 39.3500 -6.9500, 39.3500 -6.6500, 39.1500 -6.6500, 39.1500 -6.9500))'),
    true, now(),
    '{"pilot": true, "currency": "TZS"}'::jsonb
  ),
  (
    '55555555-0000-4000-8000-000000000002',
    '44444444-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    'Arusha', 'Africa/Dar_es_Salaam', -3.3869000, 36.6830000,
    extensions.ST_GeogFromText('SRID=4326;POLYGON((36.5500 -3.5000, 36.8000 -3.5000, 36.8000 -3.2500, 36.5500 -3.2500, 36.5500 -3.5000))'),
    false, null,
    '{"pilot": false, "currency": "TZS"}'::jsonb
  );

-- ----------------------------------------------------------------------------
-- 6. Service zones — three real-ish polygons covering Dar es Salaam
-- ----------------------------------------------------------------------------
insert into public.service_zones (id, city_id, name, zone_type, boundary, centroid, is_active, metadata) values
  (
    '66666666-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001', 'Central', 'operating_area',
    extensions.ST_GeogFromText('SRID=4326;POLYGON((39.2400 -6.8600, 39.3100 -6.8600, 39.3100 -6.7800, 39.2400 -6.7800, 39.2400 -6.8600))'),
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2750 -6.8200)'),
    true, '{"description": "Kariakoo, Ilala, Tabata and the CBD corridor"}'::jsonb
  ),
  (
    '66666666-0000-4000-8000-000000000002',
    '55555555-0000-4000-8000-000000000001', 'North', 'operating_area',
    extensions.ST_GeogFromText('SRID=4326;POLYGON((39.1500 -6.8000, 39.3200 -6.8000, 39.3200 -6.6500, 39.1500 -6.6500, 39.1500 -6.8000))'),
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2350 -6.7250)'),
    true, '{"description": "Kinondoni, Ubungo, Mbezi Beach, Mlimani City"}'::jsonb
  ),
  (
    '66666666-0000-4000-8000-000000000003',
    '55555555-0000-4000-8000-000000000001', 'South', 'operating_area',
    extensions.ST_GeogFromText('SRID=4326;POLYGON((39.2000 -6.9500, 39.3400 -6.9500, 39.3400 -6.8400, 39.2000 -6.8400, 39.2000 -6.9500))'),
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8950)'),
    true, '{"description": "Temeke and the southern industrial corridor"}'::jsonb
  );

-- ----------------------------------------------------------------------------
-- 7. Neighborhoods
-- ----------------------------------------------------------------------------
insert into public.neighborhoods (id, city_id, service_zone_id, name, centroid, boundary, is_active) values
  ('77777777-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001', 'Kariakoo',    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), null, true),
  ('77777777-0000-4000-8000-000000000002', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001', 'Ilala',       extensions.ST_GeogFromText('SRID=4326;POINT(39.2800 -6.8200)'), null, true),
  ('77777777-0000-4000-8000-000000000003', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001', 'Tabata',      extensions.ST_GeogFromText('SRID=4326;POINT(39.2100 -6.8300)'), null, true),
  ('77777777-0000-4000-8000-000000000004', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000002', 'Ubungo',      extensions.ST_GeogFromText('SRID=4326;POINT(39.2210 -6.7730)'), null, true),
  ('77777777-0000-4000-8000-000000000005', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000002', 'Mlimani City', extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), null, true),
  ('77777777-0000-4000-8000-000000000006', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000002', 'Mbezi Beach', extensions.ST_GeogFromText('SRID=4326;POINT(39.2300 -6.7200)'), null, true),
  ('77777777-0000-4000-8000-000000000007', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000002', 'Kinondoni',   extensions.ST_GeogFromText('SRID=4326;POINT(39.2600 -6.7800)'), null, true),
  ('77777777-0000-4000-8000-000000000008', '55555555-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000003', 'Temeke',      extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8600)'), null, true);

-- ----------------------------------------------------------------------------

-- 20. Feature flags
-- ----------------------------------------------------------------------------
insert into public.feature_flags (id, flag_key, country_id, city_id, profile_id, is_enabled, rollout_percentage, description) values
  ('0b000000-0000-4000-8000-000000000001', 'mobile_money_checkout', '33333333-0000-4000-8000-000000000001', null, null, true, 100, 'Enable mobile-money checkout for the pilot country.'),
  ('0b000000-0000-4000-8000-000000000002', 'business_portal_beta',   null, null, null, false, 10, 'Gradual rollout of the business portal.');

-- ----------------------------------------------------------------------------
-- 21. Localization strings
-- ----------------------------------------------------------------------------
insert into public.localization_strings (language_id, namespace, key, value, context) values
  ((select id from public.languages where code = 'en'), 'app',    'name',            'SafeShift', 'Product name — do not translate.'),
  ((select id from public.languages where code = 'en'), 'app',    'tagline',         'Move anything, safely.', 'Marketing tagline, max ~40 chars.'),
  ((select id from public.languages where code = 'en'), 'errors', 'network',         'Network unavailable. Please try again.', 'Shown when a request fails due to connectivity.'),
  ((select id from public.languages where code = 'en'), 'errors', 'generic',         'Something went wrong. Please try again.', 'Fallback error message.'),
  ((select id from public.languages where code = 'en'), 'errors', 'location_permission', 'Location permission is required to book a trip.', 'Shown when location permission is denied.'),
  ((select id from public.languages where code = 'sw'), 'app',    'name',            'SafeShift', 'Product name — do not translate.'),
  ((select id from public.languages where code = 'sw'), 'app',    'tagline',         'Safirisha chochote kwa usalama.', 'Marketing tagline, max ~40 chars.'),
  ((select id from public.languages where code = 'sw'), 'errors', 'network',         'Mtandao haupatikani. Tafadhali jaribu tena.', 'Shown when a request fails due to connectivity.'),
  ((select id from public.languages where code = 'sw'), 'errors', 'generic',         'Hitilafu imetokea. Tafadhali jaribu tena.', 'Fallback error message.'),
  ((select id from public.languages where code = 'sw'), 'errors', 'location_permission', 'Ruhusa ya mahali inahitajika kuweka safari.', 'Shown when location permission is denied.');

-- ----------------------------------------------------------------------------
-- 22. Permission catalogue and role mappings
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('verify_driver',             'Approve a driver after document and identity verification', 'trust_safety'),
  ('reject_driver',             'Reject a driver verification',                              'trust_safety'),
  ('suspend_driver',            'Suspend a driver account',                                  'trust_safety'),
  ('view_all_drivers',          'View all driver records',                                   'operations'),
  ('view_driver_documents',     'View driver licence and compliance documents',               'trust_safety'),
  ('view_all_customers',        'View all customer records',                                 'support'),
  ('manage_customers',          'Modify customer account fields and flags',                   'support'),
  ('view_all_users',            'View all profile records',                                  'support'),
  ('suspend_user',              'Deactivate a user account',                                 'trust_safety'),
  ('reactivate_user',           'Reactivate a suspended user account',                       'trust_safety'),
  ('view_sessions',             'View user session audit records',                           'support'),
  ('view_business_accounts',    'View business account records',                             'support'),
  ('manage_business_accounts',  'Modify business account credit and verification fields',    'finance'),
  ('adjust_pricing',            'Create or modify pricing overrides',                        'pricing'),
  ('manage_zones',              'Create or modify service zones',                            'operations'),
  ('manage_currency',           'Manage currencies and exchange rates',                      'finance'),
  ('manage_localization',       'Manage localization strings',                               'platform'),
  ('manage_features',           'Manage feature flags',                                      'platform'),
  ('view_audit',                'Read the audit log and admin action log',                   'compliance'),
  ('view_financial_reports',    'View financial reporting data',                             'finance'),
  ('process_payout',            'Initiate or approve driver payouts',                        'finance'),
  ('manage_promotions',         'Manage promotions and referral rewards',                    'operations'),
  ('manage_fleets',             'Manage fleet owner accounts',                               'operations'),
  ('manage_disputes',           'Manage job disputes and resolutions',                       'support'),
  ('manage_admins',             'Grant or revoke admin roles',                               'platform'),
  ('view_consent',              'View consent records',                                      'compliance'),
  ('view_all_addresses',        'View all address records',                                  'operations');

-- super_admin gets everything. Phase 2 migrations may already have seeded
-- grants for permissions added after Phase 1; keep this seed re-runnable.
insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', permission_key from public.admin_permissions_catalog
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  -- operations_admin
  ('operations_admin', 'view_all_drivers'),
  ('operations_admin', 'view_all_customers'),
  ('operations_admin', 'view_all_users'),
  ('operations_admin', 'view_all_addresses'),
  ('operations_admin', 'view_sessions'),
  ('operations_admin', 'manage_zones'),
  ('operations_admin', 'adjust_pricing'),
  ('operations_admin', 'manage_fleets'),
  ('operations_admin', 'manage_disputes'),
  ('operations_admin', 'manage_promotions'),
  ('operations_admin', 'manage_customers'),
  ('operations_admin', 'suspend_user'),
  ('operations_admin', 'reactivate_user'),
  ('operations_admin', 'view_business_accounts'),
  -- verification_admin
  ('verification_admin', 'verify_driver'),
  ('verification_admin', 'reject_driver'),
  ('verification_admin', 'suspend_driver'),
  ('verification_admin', 'view_all_drivers'),
  ('verification_admin', 'view_driver_documents'),
  ('verification_admin', 'view_all_users'),
  -- support_agent
  ('support_agent', 'view_all_drivers'),
  ('support_agent', 'view_all_customers'),
  ('support_agent', 'view_all_users'),
  ('support_agent', 'view_all_addresses'),
  ('support_agent', 'view_sessions'),
  ('support_agent', 'view_consent'),
  ('support_agent', 'view_business_accounts'),
  ('support_agent', 'manage_disputes'),
  ('support_agent', 'manage_customers'),
  -- finance_admin
  ('finance_admin', 'view_financial_reports'),
  ('finance_admin', 'process_payout'),
  ('finance_admin', 'manage_currency'),
  ('finance_admin', 'view_business_accounts'),
  ('finance_admin', 'manage_business_accounts'),
  ('finance_admin', 'view_all_customers'),
  -- analyst
  ('analyst', 'view_financial_reports'),
  ('analyst', 'view_all_drivers'),
  ('analyst', 'view_all_customers'),
  ('analyst', 'view_all_users'),
  ('analyst', 'view_audit'),
  ('analyst', 'view_business_accounts'),
  ('analyst', 'view_consent')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 23. Exchange rate (demonstrates the FX foundation)
-- ----------------------------------------------------------------------------
insert into public.exchange_rates (from_currency_id, to_currency_id, rate, source, effective_from) values
  ('11111111-0000-4000-8000-000000000004', '11111111-0000-4000-8000-000000000001', 2650.000000, 'manual', now());

-- ----------------------------------------------------------------------------
-- 24. Zone pricing override (demonstrates Phase 3 hand-off; no FK yet)
-- ----------------------------------------------------------------------------
insert into public.zone_pricing_overrides (
  id, service_zone_id, pricing_plan_id, multiplier, reason, effective_from, effective_to
) values (
  '0c000000-0000-4000-8000-000000000001',
  '66666666-0000-4000-8000-000000000001', null, 1.15,
  'Evening peak surcharge (demonstration row)', now(), now() + interval '30 days'
);

-- ----------------------------------------------------------------------------

-- 1. Permission catalogue additions used by Phase 2 RLS and operations.
-- ---------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('verify_vehicle', 'Approve or reject vehicle and vehicle-document verification', 'trust_safety'),
  ('manage_document_types', 'Manage country document catalogues and checklists', 'trust_safety'),
  ('manage_vehicle_catalog', 'Manage vehicle types, makes, models and equipment', 'operations'),
  ('manage_cargo_catalog', 'Manage cargo categories, types and restrictions', 'operations'),
  ('view_all_vehicles', 'View all vehicle records', 'operations'),
  ('view_all_fleets', 'View all fleet records', 'operations'),
  ('assign_vehicles', 'Assign drivers to vehicles', 'operations'),
  ('view_fleet_reports', 'View generated fleet reports', 'operations'),
  ('view_reminders', 'View scheduled document-expiry reminders', 'trust_safety')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', permission_key
from public.admin_permissions_catalog
where permission_key in ('verify_vehicle', 'manage_document_types', 'manage_vehicle_catalog', 'manage_cargo_catalog', 'view_all_vehicles', 'view_all_fleets', 'assign_vehicles', 'view_fleet_reports', 'view_reminders')
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('verification_admin', 'verify_vehicle'),
  ('verification_admin', 'view_reminders'),
  ('verification_admin', 'view_all_vehicles'),
  ('verification_admin', 'manage_document_types'),
  ('operations_admin', 'manage_vehicle_catalog'),
  ('operations_admin', 'manage_cargo_catalog'),
  ('operations_admin', 'view_all_vehicles'),
  ('operations_admin', 'view_all_fleets'),
  ('operations_admin', 'assign_vehicles'),
  ('operations_admin', 'view_fleet_reports')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Documents and vehicle reference data.
-- ---------------------------------------------------------------------------
insert into public.document_types (id, country_id, code, name, description, applies_to, is_required, has_expiry, validity_days) values
  ('20000000-0000-4000-8000-000000000001', null, 'driving_licence', 'Driving licence', 'Valid transport driving licence.', 'driver', true, true, 3650),
  ('20000000-0000-4000-8000-000000000002', null, 'national_id', 'National ID', 'Government-issued national identity document.', 'driver', true, true, 3650),
  ('20000000-0000-4000-8000-000000000003', null, 'police_clearance', 'Police clearance', 'Police clearance certificate.', 'driver', false, true, 365),
  ('20000000-0000-4000-8000-000000000004', null, 'vehicle_registration', 'Vehicle registration', 'Vehicle registration certificate.', 'vehicle', true, true, 365),
  ('20000000-0000-4000-8000-000000000005', null, 'insurance_certificate', 'Insurance certificate', 'Current vehicle insurance cover.', 'vehicle', true, true, 365),
  ('20000000-0000-4000-8000-000000000006', null, 'vehicle_inspection', 'Vehicle inspection', 'Roadworthiness inspection certificate.', 'vehicle', true, true, 180),
  ('20000000-0000-4000-8000-000000000007', null, 'business_licence', 'Business licence', 'Registered business licence.', 'business', true, true, 365),
  ('20000000-0000-4000-8000-000000000008', null, 'tin_certificate', 'TIN certificate', 'Taxpayer identification certificate.', 'business', true, false, null),
  ('20000000-0000-4000-8000-000000000009', null, 'road_service_licence', 'Road service licence', 'Commercial road service licence.', 'vehicle', true, true, 365),
  ('20000000-0000-4000-8000-000000000010', '33333333-0000-4000-8000-000000000001', 'latra_permit', 'LATRA permit', 'Tanzania LATRA operating permit.', 'vehicle', false, true, 365);

insert into public.vehicle_makes (id, name, country_of_origin) values
  ('21000000-0000-4000-8000-000000000001', 'Toyota', 'Japan'),
  ('21000000-0000-4000-8000-000000000002', 'Isuzu', 'Japan'),
  ('21000000-0000-4000-8000-000000000003', 'Mitsubishi', 'Japan'),
  ('21000000-0000-4000-8000-000000000004', 'Hino', 'Japan'),
  ('21000000-0000-4000-8000-000000000005', 'Fuso', 'Japan'),
  ('21000000-0000-4000-8000-000000000006', 'Mercedes-Benz', 'Germany'),
  ('21000000-0000-4000-8000-000000000007', 'Nissan', 'Japan'),
  ('21000000-0000-4000-8000-000000000008', 'Suzuki', 'Japan');

insert into public.vehicle_types (id, country_id, code, name, capacity_kg_min, capacity_kg_max, capacity_m3_min, capacity_m3_max, requires_special_licence, requires_equipment, display_order) values
  ('22000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'small_van', 'Small van', 500, 1500, 3, 12, false, '{}', 10),
  ('22000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'pickup', 'Pickup', 1000, 2000, 4, 15, false, '{straps}', 20),
  ('22000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'medium_truck', 'Medium truck', 3000, 7000, 15, 35, false, '{straps,load_bars}', 30),
  ('22000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'large_truck', 'Large truck', 10000, 30000, 40, 80, false, '{straps,load_bars}', 40),
  ('22000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'refrigerated_truck', 'Refrigerated truck', 3000, 10000, 15, 45, true, '{refrigeration_unit,straps}', 50),
  ('22000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', 'flatbed', 'Flatbed', 5000, 20000, 20, 60, true, '{straps}', 60);

insert into public.vehicle_models (make_id, name, vehicle_type_id, year_start) values
  ('21000000-0000-4000-8000-000000000001', 'Hiace', '22000000-0000-4000-8000-000000000001', 1990),
  ('21000000-0000-4000-8000-000000000001', 'Dyna', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000001', 'Hilux', '22000000-0000-4000-8000-000000000002', 1990),
  ('21000000-0000-4000-8000-000000000002', 'Elf', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000002', 'NQR', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000002', 'D-Max', '22000000-0000-4000-8000-000000000002', 2000),
  ('21000000-0000-4000-8000-000000000003', 'Canter', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000003', 'Fuso Fighter', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000003', 'L200', '22000000-0000-4000-8000-000000000002', 1990),
  ('21000000-0000-4000-8000-000000000004', '300 Series', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000004', '500 Series', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000005', 'Canter FE', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000005', 'Fighter', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000006', 'Sprinter', '22000000-0000-4000-8000-000000000001', 1995),
  ('21000000-0000-4000-8000-000000000006', 'Atego', '22000000-0000-4000-8000-000000000003', 1998),
  ('21000000-0000-4000-8000-000000000006', 'Actros', '22000000-0000-4000-8000-000000000004', 1996),
  ('21000000-0000-4000-8000-000000000007', 'NV200', '22000000-0000-4000-8000-000000000001', 2009),
  ('21000000-0000-4000-8000-000000000007', 'Navara', '22000000-0000-4000-8000-000000000002', 1997),
  ('21000000-0000-4000-8000-000000000008', 'Carry', '22000000-0000-4000-8000-000000000001', 1990),
  ('21000000-0000-4000-8000-000000000008', 'Super Carry', '22000000-0000-4000-8000-000000000001', 1990);

insert into public.vehicle_equipment_catalog (id, code, name, category) values
  ('23000000-0000-4000-8000-000000000001', 'straps', 'Tie-down straps', 'safety'),
  ('23000000-0000-4000-8000-000000000002', 'blankets', 'Moving blankets', 'protection'),
  ('23000000-0000-4000-8000-000000000003', 'dolly', 'Hand dolly', 'handling'),
  ('23000000-0000-4000-8000-000000000004', 'ramp', 'Loading ramp', 'handling'),
  ('23000000-0000-4000-8000-000000000005', 'load_bars', 'Load bars', 'safety'),
  ('23000000-0000-4000-8000-000000000006', 'refrigeration_unit', 'Refrigeration unit', 'specialty'),
  ('23000000-0000-4000-8000-000000000007', 'tail_lift', 'Tail lift', 'handling'),
  ('23000000-0000-4000-8000-000000000008', 'gloves', 'Protective gloves', 'safety');

-- ---------------------------------------------------------------------------
-- 3. Cargo catalogue.
-- ---------------------------------------------------------------------------
insert into public.cargo_categories (id, code, name, display_order) values
  ('24000000-0000-4000-8000-000000000001', 'household', 'Household', 10),
  ('24000000-0000-4000-8000-000000000002', 'commercial', 'Commercial', 20),
  ('24000000-0000-4000-8000-000000000003', 'industrial', 'Industrial', 30);

insert into public.cargo_types (id, country_id, category_id, code, name, requires_special_handling, requires_declared_value, requires_insurance, allowed_vehicle_type_codes, max_value_tzs, display_order) values
  ('25000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001', 'household_goods', 'Household goods', false, false, false, '{}', null, 10),
  ('25000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001', 'furniture', 'Furniture', false, false, false, '{small_van,pickup,medium_truck,large_truck}', null, 20),
  ('25000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001', 'appliances', 'Appliances', false, true, false, '{small_van,pickup,medium_truck,large_truck}', null, 30),
  ('25000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'building_materials', 'Building materials', false, false, false, '{medium_truck,large_truck,flatbed}', null, 40),
  ('25000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'fresh_produce', 'Fresh produce', true, false, true, '{refrigerated_truck}', null, 50),
  ('25000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'refrigerated_goods', 'Refrigerated goods', true, false, false, '{refrigerated_truck}', null, 60),
  ('25000000-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'electronics', 'Electronics', false, true, true, '{small_van,pickup,medium_truck}', null, 70),
  ('25000000-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000003', 'machinery', 'Machinery', true, true, true, '{flatbed,large_truck}', null, 80),
  ('25000000-0000-4000-8000-000000000009', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'livestock', 'Livestock', true, false, true, '{}', null, 90),
  ('25000000-0000-4000-8000-000000000010', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000003', 'hazardous_materials', 'Hazardous materials', true, true, true, '{flatbed,large_truck}', 5000000, 100);

insert into public.cargo_packaging_options (id, code, name, additional_fee_tzs, display_order) values
  ('26000000-0000-4000-8000-000000000001', 'boxed', 'Boxed', 0, 10),
  ('26000000-0000-4000-8000-000000000002', 'wrapped', 'Wrapped', 5000, 20),
  ('26000000-0000-4000-8000-000000000003', 'loose', 'Loose', 0, 30),
  ('26000000-0000-4000-8000-000000000004', 'palletized', 'Palletized', 10000, 40),
  ('26000000-0000-4000-8000-000000000005', 'containerized', 'Containerized', 25000, 50),
  ('26000000-0000-4000-8000-000000000006', 'bulk', 'Bulk', 15000, 60);

insert into public.cargo_restrictions (cargo_type_id, restriction_type, restricted_with_cargo_type_id, restriction_details, description) values
  ('25000000-0000-4000-8000-000000000010', 'cannot_combine', '25000000-0000-4000-8000-000000000005', '{}', 'Hazardous materials cannot be carried with fresh produce.'),
  ('25000000-0000-4000-8000-000000000010', 'requires_certificate', null, '{"certificate":"hazmat"}', 'Hazardous materials require a hazardous-goods certificate.'),
  ('25000000-0000-4000-8000-000000000009', 'requires_certificate', null, '{"certificate":"veterinary"}', 'Livestock requires a valid veterinary movement certificate.'),
  ('25000000-0000-4000-8000-000000000006', 'requires_special_vehicle', null, '{"vehicle_type":"refrigerated_truck"}', 'Refrigerated goods require a refrigerated vehicle.'),
  ('25000000-0000-4000-8000-000000000008', 'time_restricted', null, '{"hours":"22:00-05:00"}', 'Heavy machinery movements are restricted to approved night windows.');

-- ---------------------------------------------------------------------------

-- 4. Tanzania verification rules, fleet, vehicles and assignments.
-- ---------------------------------------------------------------------------
insert into public.verification_checklist_templates (id, country_id, request_type, required_document_codes, optional_document_codes, description) values
  ('27000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'driver_verification', '{driving_licence,national_id}', '{police_clearance}', 'Tanzania driver verification.'),
  ('27000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'vehicle_verification', '{vehicle_registration,insurance_certificate,vehicle_inspection}', '{latra_permit}', 'Tanzania vehicle verification.'),
  ('27000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'business_verification', '{business_licence,tin_certificate}', '{}', 'Tanzania business verification.');

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
  ('32000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), null, null, 'Initial Dar es Salaam small-van version.'),
  ('32000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000002', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), null, null, 'Initial Dar es Salaam pickup version.'),
  ('32000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000003', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), null, null, 'Initial Dar es Salaam medium-truck version.'),
  ('32000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000004', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), null, null, 'Initial Dar es Salaam large-truck version.'),
  ('32000000-0000-4000-8000-000000000005', '31000000-0000-4000-8000-000000000005', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), null, '30000000-0000-4000-8000-000000000001', 'Initial refrigerated version, regulated by LATRA.'),
  ('32000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', 1, 'TZS', '2026-01-01 00:00:00+03', null, now(), null, '30000000-0000-4000-8000-000000000001', 'Initial flatbed version, regulated by LATRA.');

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

-- 1. Payment providers (per country).
-- ---------------------------------------------------------------------------
insert into public.payment_providers (
  id, country_id, code, name, provider_type, webhook_secret_reference,
  supports_refunds, supports_partial_refunds, supports_payouts, config, is_active
) values
  (
    '5b000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    'selcom', 'Selcom', 'mobile_money_aggregator',
    'selcom_webhook_secret', true, true, true,
    '{"settlement":"T+1","methods":["mpesa","tigopesa","airtelmoney","halopesa"]}'::jsonb,
    true
  ),
  (
    '5b000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    'flutterwave', 'Flutterwave', 'card_processor',
    'flutterwave_webhook_secret', true, true, false,
    '{"settlement":"T+2","methods":["card"]}'::jsonb,
    true
  );

-- ---------------------------------------------------------------------------

-- 3. Tax rates: 18% VAT on customer charges, 5% withholding on payouts.
-- ---------------------------------------------------------------------------
insert into public.tax_rates (
  id, country_id, tax_type, name, rate, applies_to,
  effective_from, is_active, notes
) values
  (
    '5d000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    'vat', 'Tanzania VAT', 0.1800, 'customer_charge',
    now() - interval '30 days', true,
    'VAT on the gross customer fare, already included in persisted quote totals.'
  ),
  (
    '5d000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    'withholding', 'Withholding on Transport Services', 0.0500, 'driver_payout',
    now() - interval '30 days', true,
    'Withholding tax applied to the driver net earning and recorded separately.'
  );

-- ---------------------------------------------------------------------------
-- 4. Commission rules.
-- ---------------------------------------------------------------------------
insert into public.commission_rules (
  id, country_id, city_id, vehicle_type_id, fleet_id, driver_id,
  commission_type, commission_value, min_commission, max_commission,
  priority, effective_from, is_active
) values
  (
    '5e000000-0000-4000-8000-000000000001',
    null, null, null, null, null,
    'percentage', 12.0000, 0, null, 0,
    now() - interval '30 days', true
  ),
  (
    '5e000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    '22000000-0000-4000-8000-000000000003',
    null, null,
    'percentage', 10.0000, 0, null, 10,
    now() - interval '30 days', true
  );

-- 2. Notification templates (18 = 12 push + 3 SMS + 3 email)
-- ----------------------------------------------------------------------------
insert into public.notification_templates (
  id, country_id, language_id, code, channel, title_template,
  body_template, variables, deep_link_template, is_active
) values
  -- Push — Swahili
  ('7c000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'job_offer', 'push', 'Kazi mpya karibu nawe', 'Kazi mpya ya {vehicle_type} iko karibu. ETA {eta_minutes} dakika. Gharama: {fare}.', array['vehicle_type','eta_minutes','fare'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'trip_started', 'push', 'Safari imeanza', 'Safari yako na dereva {driver_name} imeanza. Fuatilia moja kwa moja.', array['driver_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'trip_completed', 'push', 'Safari imekamilika', 'Mizigo yako imefika. Asante kwa kutumia SafeShift, {customer_name}.', array['customer_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'payment_received', 'push', 'Malipo yamepokelewa', 'Malipo ya {amount} {currency} kwa kazi {job_id} yamepokelewa.', array['amount','currency','job_id'], 'safeshift://payment/{payment_id}', true),
  ('7c000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'document_expiry', 'push', 'Hati inakaribia kuisha', 'Hati yako ya {document_name} inaisha tarehe {expiry_date}. Tafadhali sasisha.', array['document_name','expiry_date'], 'safeshift://profile/documents', true),
  ('7c000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'emergency_alert', 'push', 'Tahadhari ya usalama', 'Tukio la usalama limeripotiwa kwenye kazi {job_id}. Timu yetu inafuatilia.', array['job_id'], 'safeshift://incident/{incident_id}', true),
  -- Push — English
  ('7c000000-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'job_offer', 'push', 'New job nearby', 'A new {vehicle_type} job is nearby. ETA {eta_minutes} minutes. Payout: {fare}.', array['vehicle_type','eta_minutes','fare'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'trip_started', 'push', 'Trip started', 'Your trip with {driver_name} has started. Track it live.', array['driver_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000009', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'trip_completed', 'push', 'Trip completed', 'Your cargo has arrived. Thank you for using SafeShift, {customer_name}.', array['customer_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000010', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'payment_received', 'push', 'Payment received', 'Payment of {amount} {currency} for job {job_id} has been received.', array['amount','currency','job_id'], 'safeshift://payment/{payment_id}', true),
  ('7c000000-0000-4000-8000-000000000011', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'document_expiry', 'push', 'Document expiring', 'Your {document_name} expires on {expiry_date}. Please update it.', array['document_name','expiry_date'], 'safeshift://profile/documents', true),
  ('7c000000-0000-4000-8000-000000000012', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'emergency_alert', 'push', 'Safety alert', 'A safety incident was reported on job {job_id}. Our team is responding.', array['job_id'], 'safeshift://incident/{incident_id}', true),
  -- SMS — Swahili
  ('7c000000-0000-4000-8000-000000000013', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'job_offer', 'sms', null, 'SafeShift: Kazi mpya karibu. ETA {eta_minutes} dakika. Fungua app kukubali.', array['eta_minutes','job_id'], null, true),
  ('7c000000-0000-4000-8000-000000000014', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'trip_started', 'sms', null, 'SafeShift: Safari ya {job_id} imeanza. Fuatilia kwenye app.', array['job_id'], null, true),
  ('7c000000-0000-4000-8000-000000000015', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'payment_received', 'sms', null, 'SafeShift: Malipo ya {amount} {currency} yamepokelewa. Asante.', array['amount','currency'], null, true),
  -- Email — English
  ('7c000000-0000-4000-8000-000000000016', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'trip_completed', 'email', 'Your SafeShift trip is complete', 'Hello {customer_name}, your cargo for job {job_id} has arrived. Thank you for choosing SafeShift.', array['customer_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000017', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'payment_received', 'email', 'Payment receipt', 'We received {amount} {currency} for job {job_id}. Your receipt is available in the app.', array['amount','currency','job_id'], 'safeshift://payment/{payment_id}', true),
  ('7c000000-0000-4000-8000-000000000018', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'document_expiry', 'email', 'Action required: document expiring', 'Your {document_name} expires on {expiry_date}. Please upload a replacement.', array['document_name','expiry_date'], 'safeshift://profile/documents', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------

insert into public.prohibited_items (
  id, country_id, category, name, description, legal_reference, severity, is_active
) values
  ('8b000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'weapons', 'Firearms and ammunition', 'Firearms, ammunition, and military-grade weapons.', 'Tanzania Firearms and Ammunition Control Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'drugs', 'Narcotics and controlled substances', 'Illegal narcotics and controlled pharmaceutical substances.', 'Tanzania Drugs and Prevention of Illicit Traffic in Drugs Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'hazardous_materials', 'Explosives and hazardous chemicals', 'Explosives, flammable gases, and toxic industrial chemicals.', 'Tanzania Occupational Safety and Health Act', 'requires_licence', true),
  ('8b000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'live_animals', 'Live animals', 'Live animals require a licensed livestock carrier and veterinary permit.', 'Tanzania Animal Diseases Act', 'requires_licence', true),
  ('8b000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'cash', 'Large cash consignments', 'Cash above the regulatory threshold requires a licensed cash-in-transit provider.', 'Bank of Tanzania cash handling rules', 'requires_licence', true),
  ('8b000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', 'illegal_goods', 'Wildlife products', 'Protected wildlife products and trophies are prohibited.', 'Tanzania Wildlife Conservation Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', 'illegal_goods', 'Ivory and elephant products', 'Raw or worked ivory and other elephant products are prohibited.', 'CITES and Tanzania Wildlife Conservation Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', 'illegal_goods', 'Counterfeit goods', 'Counterfeit branded goods and unlicensed replicas.', 'Tanzania Fair Competition Act', 'prohibited', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------

insert into public.support_categories (
  id, country_id, code, name, description, display_order, is_active
) values
  ('8c000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'account_access', 'Account access', 'Login, OTP, and account recovery issues.', 10, true),
  ('8c000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'payment_issue', 'Payment issue', 'Payments, refunds, and wallet problems.', 20, true),
  ('8c000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'app_bug', 'App bug', 'Crashes, display defects, and broken flows.', 30, true),
  ('8c000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'driver_behavior', 'Driver behaviour', 'Service quality and conduct concerns.', 40, true),
  ('8c000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'feature_request', 'Feature request', 'Product ideas and new capability requests.', 50, true)
on conflict (id) do nothing;

-- 10. Retention policies
-- ----------------------------------------------------------------------------
insert into public.retention_policies (
  id, table_name, retention_period, action, is_active, notes
) values
  ('8e000000-0000-4000-8000-000000000001', 'driver_locations', interval '90 days', 'delete', true, 'Drop monthly partitions, then delete default-partition leftovers.'),
  ('8e000000-0000-4000-8000-000000000002', 'job_events', interval '5 years', 'delete', true, 'Partition-drop only because job_events is append-only.'),
  ('8e000000-0000-4000-8000-000000000003', 'audit_log', interval '7 years', 'delete', true, 'Private audit partitions; partition-drop only.'),
  ('8e000000-0000-4000-8000-000000000004', 'chat_messages', interval '2 years', 'delete', true, 'Post-completion retention approximated by message created_at; archived threads are never hard-deleted by chat UI.'),
  ('8e000000-0000-4000-8000-000000000005', 'notification_log', interval '24 months', 'delete', true, 'PDPC-aligned notification retention.'),
  ('8e000000-0000-4000-8000-000000000006', 'data_access_log', interval '7 years', 'delete', true, 'Seven-year PDPC accountability period.'),
  ('8e000000-0000-4000-8000-000000000007', 'demand_snapshots', interval '90 days', 'delete', true, 'Five-minute demand buckets outside 90 days are removed.'),
  ('8e000000-0000-4000-8000-000000000008', 'daily_metrics', interval '100 years', 'archive', true, 'Indefinite retention; archive action is a no-op in Phase 6.')
on conflict (table_name) do nothing;

-- ----------------------------------------------------------------------------

commit;
