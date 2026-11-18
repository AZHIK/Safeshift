-- ============================================================================
-- SafeShift — Phase 11 / Migration 0135
-- The dialling code of a country.
--
-- The catalogue of countries the platform supports lives in
-- apps/admin-console/lib/configuration/countries.json. It carries the
-- currency, the language and the phone code of every country, and the
-- console fills those in when the operator picks a country.
--
-- The phone code has to live in the database as well, because the apps
-- format phone numbers from it. It is stored per country rather than
-- derived from the ISO code, because the dialling code is not a function of
-- the ISO code (the United States and Canada share +1, and several
-- territories share the code of the country they belong to).
-- ============================================================================

alter table public.countries
  add column if not exists phone_code text;

comment on column public.countries.phone_code is
  'The dialling code of the country, e.g. +255. Filled in from the country catalogue.';

-- The catalogue always carries one, so a country that has been created
-- without one is an operator mistake rather than a state to allow.
alter table public.countries
  add constraint countries_phone_code_format
  check (phone_code is null or phone_code ~ '^\+[0-9]{1,4}$');

-- The catalogue rows that already exist in a seeded database keep working:
-- their phone code is backfilled from the catalogue the console reads.
update public.countries c
   set phone_code = catalogue.phone_code
  from (
    select 'TZ'::text as iso_code, '+255'::text as phone_code
    union all select 'KE', '+254'
    union all select 'UG', '+256'
  ) as catalogue
 where c.iso_code = catalogue.iso_code
   and (c.phone_code is null or c.phone_code <> catalogue.phone_code);
