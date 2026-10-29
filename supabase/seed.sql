-- ============================================================================
-- SafeShift — Phase 1 seed data
-- SEED DATA — LOCAL DEVELOPMENT ONLY.
--
-- Never run this against staging or production. It creates fictional users,
-- fictional phone numbers, fictional licence numbers and development
-- passwords. Every value here is throwaway fixture data.
--
-- IMPORTANT — auth.users:
--   A public.profiles row is created automatically by the auth trigger
--   (public.handle_new_user) when a row is inserted into auth.users. For real
--   accounts, create auth.users through the Supabase Auth Admin API or by
--   sign-up, never with raw SQL. This seed inserts auth.users rows directly
--   because it is a disposable local database. Password sign-in additionally
--   requires matching auth.identities rows; the seed attempts to create them
--   and reports a notice if the local GoTrue version rejects them.
-- ============================================================================

set search_path = public, extensions;

begin;

-- ----------------------------------------------------------------------------
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
-- 8. Auth users
--    (profiles rows are created by the auth trigger public.handle_new_user)
-- ----------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  phone, phone_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  -- Admins
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'superadmin@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255700000001', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Asha Mwinyi","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'ops.national@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255700000002', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Baraka Mushi","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
   'ops.dar@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255700000003', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Neema Salum","country_code":"TZ"}'::jsonb, now(), now()),
  -- Customers
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'customer1@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255711000001', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Juma Ally","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'customer2@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255711000002', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Fatuma Hassan","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
   'customer3@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255711000003', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Peter Mwakalinga","country_code":"TZ"}'::jsonb, now(), now()),
  -- Drivers
  ('00000000-0000-0000-0000-000000000000', 'd0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'driver1@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255712000001', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Joseph Mwakyusa","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'd0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'driver2@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255712000002', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Grace Mushi","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'd0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
   'driver3@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255712000003', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Hamisi Juma","country_code":"TZ"}'::jsonb, now(), now()),
  -- Business members
  ('00000000-0000-0000-0000-000000000000', 'e0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'business.owner@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255713000001', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Saida Abdallah","country_code":"TZ"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'e0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'business.booker@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255713000002', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Emmanuel Kessy","country_code":"TZ"}'::jsonb, now(), now()),
  -- Fleet owner
  ('00000000-0000-0000-0000-000000000000', 'f0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'fleet.owner@safeshift.local', extensions.crypt('SafeshiftDev!2026', extensions.gen_salt('bf')), now(), '+255714000001', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Mariam Mtei","country_code":"TZ"}'::jsonb, now(), now());

-- GoTrue's password grant scans these columns into strings. Recent GoTrue
-- versions reject NULL, even though older seeds omitted them.
update auth.users
   set confirmation_token = coalesce(confirmation_token, ''),
       recovery_token = coalesce(recovery_token, ''),
       email_change_token_new = coalesce(email_change_token_new, ''),
       email_change_token_current = coalesce(email_change_token_current, ''),
       phone_change_token = coalesce(phone_change_token, ''),
       email_change = coalesce(email_change, ''),
       phone_change = coalesce(phone_change, ''),
       reauthentication_token = coalesce(reauthentication_token, '')
 where email like '%@safeshift.local';

-- Password sign-in support (best effort; local GoTrue versions differ).
do $$
begin
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select
    u.id::text,
    u.id,
    jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
    'email',
    now(), now(), now()
  from auth.users u
  where u.email like '%@safeshift.local'
  on conflict do nothing;
exception when others then
  raise notice 'Skipping auth.identities seed (%): password sign-in may be unavailable locally.', sqlerrm;
end $$;

-- ----------------------------------------------------------------------------
-- 9. Promote profiles created by the auth trigger
-- ----------------------------------------------------------------------------
update public.profiles
   set primary_role = 'admin',
       phone_verified = true,
       email_verified = true,
       terms_accepted_at = now(),
       privacy_accepted_at = now()
 where id in (
   'a0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000003'
 );

update public.profiles
   set phone_verified = true,
       email_verified = true,
       terms_accepted_at = now(),
       privacy_accepted_at = now()
 where id in (
   'c0000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000002',
   'c0000000-0000-4000-8000-000000000003'
 );

update public.profiles
   set marketing_opt_in = true
 where id = 'c0000000-0000-4000-8000-000000000001';

update public.profiles
   set primary_role = 'driver',
       phone_verified = true,
       email_verified = true,
       terms_accepted_at = now(),
       privacy_accepted_at = now()
 where id in (
   'd0000000-0000-4000-8000-000000000001',
   'd0000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-000000000003'
 );

update public.profiles
   set primary_role = 'business',
       phone_verified = true,
       email_verified = true,
       terms_accepted_at = now(),
       privacy_accepted_at = now()
 where id in (
   'e0000000-0000-4000-8000-000000000001',
   'e0000000-0000-4000-8000-000000000002'
 );

update public.profiles
   set primary_role = 'fleet_owner',
       phone_verified = true,
       email_verified = true,
       terms_accepted_at = now(),
       privacy_accepted_at = now()
 where id = 'f0000000-0000-4000-8000-000000000001';

-- ----------------------------------------------------------------------------
-- 10. Addresses (8 realistic Dar es Salaam locations)
-- ----------------------------------------------------------------------------
insert into public.addresses (
  id, country_id, city_id, neighborhood_id, line_1, line_2, landmark, location, metadata, created_by
) values
  ('88888888-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000001',
   'Kariakoo Market, Msimbazi Street', null, 'Main market entrance, opposite the clock tower',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), '{"building":"Kariakoo Market","gate":"main"}'::jsonb, 'c0000000-0000-4000-8000-000000000001'),
  ('88888888-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000005',
   'Mlimani City Mall, Sam Nujoma Road', null, 'Mall main parking entrance',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), '{"building":"Mlimani City","floor":"ground"}'::jsonb, 'c0000000-0000-4000-8000-000000000001'),
  ('88888888-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000006',
   'Mbezi Beach, Bagamoyo Road', null, 'Near Mbezi Beach roundabout',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2300 -6.7200)'), '{"gate":"white metal gate"}'::jsonb, 'c0000000-0000-4000-8000-000000000001'),
  ('88888888-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000008',
   'Temeke Municipal Council, Nyerere Road', null, 'Council offices, main reception',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8600)'), '{"building":"Temeke Council"}'::jsonb, 'c0000000-0000-4000-8000-000000000001'),
  ('88888888-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000007',
   'Kinondoni Municipal, Ali Hassan Mwinyi Road', null, 'Opposite Kinondoni district offices',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2600 -6.7800)'), '{"floor":"2nd floor"}'::jsonb, 'c0000000-0000-4000-8000-000000000001'),
  ('88888888-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000002',
   'Ilala, Uhuru Street', null, 'Ilala district offices',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2800 -6.8200)'), '{}'::jsonb, 'c0000000-0000-4000-8000-000000000002'),
  ('88888888-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000003',
   'Tabata, Mandela Road', null, 'Tabata Relini bus stop',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2100 -6.8300)'), '{}'::jsonb, 'c0000000-0000-4000-8000-000000000002'),
  ('88888888-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', '77777777-0000-4000-8000-000000000004',
   'Ubungo, Morogoro Road', null, 'Ubungo bus terminal, north gate',
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2210 -6.7730)'), '{}'::jsonb, 'c0000000-0000-4000-8000-000000000003');

-- ----------------------------------------------------------------------------
-- 11. Customers
-- ----------------------------------------------------------------------------
insert into public.customers (id, default_address_id, total_jobs, total_spent, rating, is_flagged, created_at, updated_at) values
  ('c0000000-0000-4000-8000-000000000001', '88888888-0000-4000-8000-000000000001', 12, 450000.00, 4.85, false, now(), now()),
  ('c0000000-0000-4000-8000-000000000002', '88888888-0000-4000-8000-000000000006',  4, 120000.00, 4.50, false, now(), now()),
  ('c0000000-0000-4000-8000-000000000003', '88888888-0000-4000-8000-000000000008',  0,      0.00, 5.00, false, now(), now());

-- 12. Saved addresses
insert into public.saved_addresses (id, profile_id, address_id, label, is_default) values
  ('99999999-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '88888888-0000-4000-8000-000000000001', 'Home',     true),
  ('99999999-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '88888888-0000-4000-8000-000000000002', 'Work',     false),
  ('99999999-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000002', '88888888-0000-4000-8000-000000000006', 'Home',     true),
  ('99999999-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000003', '88888888-0000-4000-8000-000000000008', 'Warehouse', true);

-- ----------------------------------------------------------------------------
-- 13. Admin roles
-- ----------------------------------------------------------------------------
insert into public.admin_roles (id, profile_id, role_name, country_id, city_id, is_active, granted_by) values
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'super_admin', null, null, true, null),
  ('a1000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002', 'operations_admin', '33333333-0000-4000-8000-000000000001', null, true, 'a0000000-0000-4000-8000-000000000001'),
  ('a1000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000003', 'operations_admin', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', true, 'a0000000-0000-4000-8000-000000000001');

-- ----------------------------------------------------------------------------
-- 14. Drivers
-- ----------------------------------------------------------------------------
insert into public.drivers (
  id, country_id, home_city_id, licence_number, licence_expiry, licence_country_id,
  verification_status, risk_tier, rating, total_trips, total_earnings, is_available,
  current_location, location_updated_at, verified_at, verified_by, re_verification_due_at,
  -- FK will be added in Phase 2 (references public.fleets.id).
  current_fleet_id
) values
  ('d0000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001',
   'TZ-DL-100001', '2028-12-31', '33333333-0000-4000-8000-000000000001',
   'verified', 'standard', 4.90, 320, 12500000.00, true,
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2750 -6.8150)'), now(), now(), 'a0000000-0000-4000-8000-000000000001', now() + interval '12 months', null),
  ('d0000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001',
   'TZ-DL-100002', '2027-06-30', '33333333-0000-4000-8000-000000000001',
   'pending', 'standard', 0.00, 0, 0.00, false,
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2210 -6.7730)'), now(), null, null, null, null),
  ('d0000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001',
   'TZ-DL-100003', '2026-11-30', '33333333-0000-4000-8000-000000000001',
   're_verification_due', 'enhanced', 4.60, 150, 6200000.00, false,
   extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8600)'), now(), now() - interval '11 months', 'a0000000-0000-4000-8000-000000000001', now(), null);

-- Demonstrate the status-history + audit pipeline: driver 2 is verified after
-- being created as pending.
update public.drivers
   set verification_status = 'verified',
       verified_at = now(),
       verified_by = 'a0000000-0000-4000-8000-000000000001',
       re_verification_due_at = now() + interval '12 months'
 where id = 'd0000000-0000-4000-8000-000000000002';

-- 15. Driver operating zones
insert into public.driver_operating_zones (id, driver_id, service_zone_id, is_primary) values
  ('a2000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001', true),
  ('a2000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000002', false),
  ('a2000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000002', '66666666-0000-4000-8000-000000000002', true),
  ('a2000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000003', '66666666-0000-4000-8000-000000000003', true);

-- 16. Driver service hours (Monday–Friday, 07:00–19:00)
insert into public.driver_service_hours (driver_id, day_of_week, start_time, end_time, timezone, is_active)
select d.id, g.day, time '07:00', time '19:00', 'Africa/Dar_es_Salaam', true
from (
  values
    ('d0000000-0000-4000-8000-000000000001'::uuid),
    ('d0000000-0000-4000-8000-000000000002'::uuid),
    ('d0000000-0000-4000-8000-000000000003'::uuid)
) as d(id)
cross join generate_series(1, 5) as g(day);

-- ----------------------------------------------------------------------------
-- 17. Business account + members
-- ----------------------------------------------------------------------------
insert into public.business_accounts (
  id, country_id, city_id, legal_name, trading_name, registration_number, tax_id,
  industry, contact_email, contact_phone, billing_address_id,
  credit_limit, current_balance, payment_terms_days, is_active, verified_at
) values (
  'b0000000-0000-4000-8000-000000000001',
  '33333333-0000-4000-8000-000000000001',
  '55555555-0000-4000-8000-000000000001',
  'Kilimanjaro Fresh Produce Limited', 'Kilimanjaro Fresh',
  'BRELA-123456', 'TIN-100-200-300', 'Food & Beverage Distribution',
  'accounts@kilimanjarofresh.example', '+255222000100',
  '88888888-0000-4000-8000-000000000002',
  5000000.00, 1250000.00, 30, true, now()
);

insert into public.business_members (id, business_account_id, profile_id, role, invited_at, accepted_at) values
  ('b2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 'owner',  now() - interval '30 days', now() - interval '29 days'),
  ('b2000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000002', 'booker', now() - interval '20 days', now() - interval '19 days');

-- ----------------------------------------------------------------------------
-- 18. Fleet owner
-- ----------------------------------------------------------------------------
-- A fleet_owner profile cannot reference a fleet yet: public.fleets is created
-- in Phase 2. Placeholder fleet id used by Phase 2 seed/migration:
--   0f1e2d3c-4b5a-4968-8776-655443322110
-- No fleet_id column exists on profiles; the fleet relationship will live on
-- public.fleets.owner_profile_id (Phase 2).

-- ----------------------------------------------------------------------------
-- 19. Referral
-- ----------------------------------------------------------------------------
insert into public.user_referrals (
  id, referrer_profile_id, referred_profile_id, referral_code, status, reward_granted, reward_amount
) values (
  '0a000000-0000-4000-8000-000000000001',
  'c0000000-0000-4000-8000-000000000001', null, 'JUMA2026', 'pending', false, 10000.00
);

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
-- 25. Consent records (PDPC compliance foundation) — 3 for customer 1
-- ----------------------------------------------------------------------------
insert into public.consent_records (
  id, profile_id, consent_type, consent_version, granted, ip_address, user_agent, granted_at, revoked_at
) values
  ('0d000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'terms_of_service', '2026-10-v1', true,
   '41.59.100.10'::inet, 'SafeShift/1.0 (local seed)', now() - interval '30 days', null),
  ('0d000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 'privacy_policy', '2026-10-v1', true,
   '41.59.100.10'::inet, 'SafeShift/1.0 (local seed)', now() - interval '30 days', null),
  ('0d000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', 'marketing_sms', '2026-10-v1', false,
   '41.59.100.10'::inet, 'SafeShift/1.0 (local seed)', null, now() - interval '5 days');

-- ----------------------------------------------------------------------------
-- 26. Admin action log (demonstrates the admin audit trail)
-- ----------------------------------------------------------------------------
insert into public.admin_actions_log (
  admin_profile_id, admin_role, permission_used, action, entity_type, entity_id,
  old_value, new_value, ip_address, user_agent
) values (
  'a0000000-0000-4000-8000-000000000001', 'super_admin', 'verify_driver', 'approved_driver', 'driver',
  'd0000000-0000-4000-8000-000000000001',
  '{"verification_status": "pending"}'::jsonb,
  '{"verification_status": "verified"}'::jsonb,
  '41.59.100.10'::inet, 'SafeShift Admin Console (local seed)'
);

commit;

-- ============================================================================
-- Seed complete.
-- Trigger-generated rows now exist in private.audit_log for the inserts and
-- updates above (the generic audit trigger is attached in migration 0014), and
-- in public.driver_status_history for the driver verification transition.
-- ============================================================================
