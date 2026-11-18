-- ============================================================================
-- SafeShift — Phase 11 / Migration 0136
-- The currencies and languages the country catalogue refers to.
--
-- The catalogue of countries the platform supports lives in
-- apps/admin-console/lib/configuration/countries.json. Every entry names the
-- currency and the language of its market, and the console fills those in
-- when the operator picks a country.
--
-- The country row stores the currency and the language as foreign keys, so
-- the rows they point at have to exist. They live in this migration rather
-- than only in the development seed, for the same reason the permission
-- catalogue rows live in migration 0035: a deployment applies migrations
-- without seed data and must still be operable.
--
-- The ids are the ones the seed files use, so a seeded database and a
-- migrated database agree.
-- ============================================================================

insert into public.currencies (id, code, name, symbol, decimal_places, is_active) values
  ('11111111-0000-4000-8000-000000000001', 'TZS', 'Tanzanian Shilling', 'TSh', 2, true),
  ('11111111-0000-4000-8000-000000000002', 'KES', 'Kenyan Shilling',    'KSh', 2, true),
  ('11111111-0000-4000-8000-000000000003', 'UGX', 'Ugandan Shilling',   'USh', 0, true)
on conflict (code) do update
  set name = excluded.name,
      symbol = excluded.symbol,
      decimal_places = excluded.decimal_places,
      is_active = true;

insert into public.languages (id, code, name, native_name, is_active) values
  ('22222222-0000-4000-8000-000000000001', 'en', 'English', 'English', true),
  ('22222222-0000-4000-8000-000000000002', 'sw', 'Swahili', 'Kiswahili', true)
on conflict (code) do update
  set name = excluded.name,
      native_name = excluded.native_name,
      is_active = true;

-- The country rows the catalogue describes. They start inactive: a market
-- goes live when an operator activates it, not because the catalogue lists it.
insert into public.countries (
  id, iso_code, name, default_currency_id, default_timezone, default_language_id,
  regulatory_framework, tax_registration_required, phone_code, is_active, launched_at
) values
  ('33333333-0000-4000-8000-000000000001', 'TZ', 'Tanzania',
   '11111111-0000-4000-8000-000000000001', 'Africa/Dar_es_Salaam',
   '22222222-0000-4000-8000-000000000002', 'LATRA', true, '+255', false, null),
  ('33333333-0000-4000-8000-000000000002', 'KE', 'Kenya',
   '11111111-0000-4000-8000-000000000002', 'Africa/Nairobi',
   '22222222-0000-4000-8000-000000000001', 'NTSA', true, '+254', false, null),
  ('33333333-0000-4000-8000-000000000003', 'UG', 'Uganda',
   '11111111-0000-4000-8000-000000000003', 'Africa/Kampala',
   '22222222-0000-4000-8000-000000000001', 'UNRA', true, '+256', false, null)
on conflict (iso_code) do update
  set name = excluded.name,
      default_currency_id = excluded.default_currency_id,
      default_timezone = excluded.default_timezone,
      default_language_id = excluded.default_language_id,
      regulatory_framework = excluded.regulatory_framework,
      tax_registration_required = excluded.tax_registration_required,
      phone_code = excluded.phone_code;
