-- ============================================================================
-- SafeShift — example country seed
--
-- SEED DATA — LOCAL DEVELOPMENT ONLY.
-- Never run against staging or production. It adds a country that does not
-- operate any real business.
--
-- Adds one complete, deliberately inactive example country (Nigeria) with the
-- currency, language, region, city, service zone and neighborhoods it needs.
-- A country row on its own is inert: the multi-country model is
-- country -> region -> city -> service zone, so the example only becomes
-- usable once the whole chain exists.
--
-- This file is idempotent. Every insert is guarded by a conflict clause or an
-- existence check, so it can be applied to an already-seeded database without
-- a full `supabase db reset`:
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed-example-country.sql
--
-- References are resolved by code (not by hardcoded id) so the file works
-- whether or not ./seed.sql has already run.
--
-- Activation is a data change, never a code change:
--
--   update public.countries set is_active = true, launched_at = now()
--    where iso_code = 'NG';
--
--   update public.cities set is_active = true, launched_at = now()
--    where country_id = (select id from public.countries where iso_code = 'NG');
-- ============================================================================

set search_path = public, extensions;

begin;

-- ----------------------------------------------------------------------------
-- 1. Currency
--
-- Inactive like the other non-pilot currencies. The platform never hardcodes
-- a currency; countries.default_currency_id points at this row.
-- ----------------------------------------------------------------------------
insert into public.currencies (id, code, name, symbol, decimal_places, is_active)
values ('9c000000-0000-4000-8000-000000000001', 'NGN', 'Nigerian Naira', '₦', 2, false)
on conflict (code) do nothing;

-- ----------------------------------------------------------------------------
-- 2. Language
--
-- English, so the example country reuses the strings that already exist.
-- Inserted defensively: if ./seed.sql has run, this row is a no-op.
-- ----------------------------------------------------------------------------
insert into public.languages (id, code, name, native_name, is_active)
values ('9c000000-0000-4000-8000-000000000002', 'en', 'English', 'English', true)
on conflict (code) do nothing;

-- ----------------------------------------------------------------------------
-- 3. Country
--
-- is_active = false, launched_at = null: the country is provisioned but not
-- live. Exactly one country (Tanzania) is active in the local seed, and the
-- Phase 1 verification gate checks for that.
--
-- tax_registration_required = false because no real data is collected in this
-- market yet. Set it to true before any real launch.
-- ----------------------------------------------------------------------------
insert into public.countries (
  id, iso_code, name, default_currency_id, default_timezone, default_language_id,
  regulatory_framework, tax_registration_required, is_active, launched_at, config
)
values (
  '9c000000-0000-4000-8000-000000000003', 'NG', 'Nigeria',
  (select id from public.currencies where code = 'NGN'),
  'Africa/Lagos',
  (select id from public.languages where code = 'en'),
  'FRSC', false, false, null,
  '{"mobile_money_providers": ["palm_pay"], "pdpc_registration_required": false, "example_country": true}'::jsonb
)
on conflict (iso_code) do nothing;

-- ----------------------------------------------------------------------------
-- 4. Region
--
-- First-level administrative division. Inactive for the same reason as the
-- country.
-- ----------------------------------------------------------------------------
insert into public.regions (id, country_id, name, code, is_active)
select '9c000000-0000-4000-8000-000000000004'::uuid, c.id, 'Lagos State', 'LAG', false
from public.countries c
where c.iso_code = 'NG'
on conflict (country_id, name) do nothing;

-- ----------------------------------------------------------------------------
-- 5. City
--
-- The trigger public.sync_city_country() validates that cities.country_id
-- matches the parent region's country, so an inconsistent city cannot be
-- created. The boundary is a simple example polygon around Lagos.
-- ----------------------------------------------------------------------------
insert into public.cities (
  id, region_id, country_id, name, timezone, latitude, longitude,
  boundary, is_active, launched_at, config
)
select '9c000000-0000-4000-8000-000000000005'::uuid,
       r.id,
       r.country_id,
       'Lagos',
       'Africa/Lagos',
       6.5244000,
       3.3792000,
       extensions.ST_GeogFromText('SRID=4326;POLYGON((3.2000 6.4000, 3.6000 6.4000, 3.6000 6.6500, 3.2000 6.6500, 3.2000 6.4000))'),
       false,
       null,
       '{"pilot": false, "currency": "NGN"}'::jsonb
from public.regions r
join public.countries c on c.id = r.country_id
where c.iso_code = 'NG'
  and r.name = 'Lagos State'
on conflict (region_id, name) do nothing;

-- ----------------------------------------------------------------------------
-- 6. Service zone
--
-- boundary and centroid are required: matching and pricing read them
-- in-database via PostGIS distance queries.
-- ----------------------------------------------------------------------------
insert into public.service_zones (
  id, city_id, name, zone_type, boundary, centroid, is_active, metadata
)
select '9c000000-0000-4000-8000-000000000006'::uuid,
       ci.id,
       'Lagos Central',
       'operating_area',
       extensions.ST_GeogFromText('SRID=4326;POLYGON((3.3000 6.4500, 3.4500 6.4500, 3.4500 6.5600, 3.3000 6.5600, 3.3000 6.4500))'),
       extensions.ST_GeogFromText('SRID=4326;POINT(3.3750 6.5050)'),
       false,
       '{"description": "Example operating zone over Lagos Island and Victoria Island"}'::jsonb
from public.cities ci
join public.countries c on c.id = ci.country_id
where c.iso_code = 'NG'
  and ci.name = 'Lagos'
on conflict (city_id, name) do nothing;

-- ----------------------------------------------------------------------------
-- 7. Neighborhoods
--
-- Human-recognisable areas used for pickup hints and analytics.
-- ----------------------------------------------------------------------------
insert into public.neighborhoods (
  id, city_id, service_zone_id, name, centroid, boundary, is_active
)
select v.id, ci.id, z.id, v.name, v.centroid, v.boundary, false
from (
  values
    (
      '9c000000-0000-4000-8000-000000000007'::uuid,
      'Victoria Island',
      extensions.ST_GeogFromText('SRID=4326;POINT(3.4219 6.4281)'),
      extensions.ST_GeogFromText('SRID=4326;POLYGON((3.3800 6.4000, 3.4600 6.4000, 3.4600 6.4600, 3.3800 6.4600, 3.3800 6.4000))')
    ),
    (
      '9c000000-0000-4000-8000-000000000008'::uuid,
      'Lagos Island',
      extensions.ST_GeogFromText('SRID=4326;POINT(3.4244 6.4330)'),
      extensions.ST_GeogFromText('SRID=4326;POLYGON((3.3900 6.4400, 3.4600 6.4400, 3.4600 6.4900, 3.3900 6.4900, 3.3900 6.4400))')
    )
) as v(id, name, centroid, boundary)
join public.cities ci
  on ci.name = 'Lagos'
 and ci.country_id = (select id from public.countries where iso_code = 'NG')
join public.service_zones z
  on z.city_id = ci.id
 and z.name = 'Lagos Central'
on conflict (city_id, name) do nothing;

-- ----------------------------------------------------------------------------
-- 8. Summary
-- ----------------------------------------------------------------------------
select c.iso_code,
       c.name,
       c.is_active,
       c.default_currency_id is not null as has_currency,
       r.name as region,
       ci.name as city,
       ci.is_active as city_active,
       (select count(*) from public.neighborhoods n where n.city_id = ci.id) as neighborhoods
from public.countries c
left join public.regions r on r.country_id = c.id
left join public.cities ci on ci.region_id = r.id
where c.iso_code = 'NG';

commit;
