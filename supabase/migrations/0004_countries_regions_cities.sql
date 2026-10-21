-- ============================================================================
-- SafeShift — Phase 1 / Migration 0004
-- Geography: countries -> regions -> cities.
--
-- Multi-country rule: no country, currency, timezone or regulatory framework
-- is hardcoded in schema, functions or triggers. Everything is looked up from
-- these tables.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.countries
-- ----------------------------------------------------------------------------
create table public.countries (
  id                       uuid primary key default gen_random_uuid(),
  iso_code                 char(2) not null unique,
  name                     text not null,
  default_currency_id      uuid,
  default_timezone         text not null,
  default_language_id      uuid,
  regulatory_framework     text,
  tax_registration_required boolean not null default false,
  is_active                boolean not null default false,
  launched_at              timestamptz,
  config                   jsonb not null default '{}'::jsonb,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  constraint countries_iso_code_format check (btrim(iso_code) ~ '^[A-Z]{2}$'),

  -- Deferrable because countries is the first table that needs currencies and
  -- languages, and seed data may be inserted in any order inside a transaction.
  constraint countries_default_currency_fkey
    foreign key (default_currency_id) references public.currencies (id)
    deferrable initially deferred,
  constraint countries_default_language_fkey
    foreign key (default_language_id) references public.languages (id)
    deferrable initially deferred
);

comment on table public.countries is
  'Countries the platform operates in. Activating a country is a data change, not a code change.';

comment on column public.countries.regulatory_framework is
  'Transport regulator for this country (e.g. a national land transport authority). Stored as data, never hardcoded in functions.';

comment on column public.countries.config is
  'Country-level configuration: payment providers, KYC rules, document requirements, feature defaults.';

-- ----------------------------------------------------------------------------
-- public.regions
-- ----------------------------------------------------------------------------
create table public.regions (
  id         uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries (id) on delete cascade,
  name       text not null,
  code       text,
  is_active  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint regions_country_name_key unique (country_id, name)
);

comment on table public.regions is
  'First-level administrative divisions (region/state/province) within a country.';

-- ----------------------------------------------------------------------------
-- public.cities
-- ----------------------------------------------------------------------------
create table public.cities (
  id          uuid primary key default gen_random_uuid(),
  region_id   uuid not null references public.regions (id) on delete cascade,
  country_id  uuid not null references public.countries (id) on delete cascade,
  name        text not null,
  timezone    text not null,
  latitude    numeric(10, 7),
  longitude   numeric(10, 7),
  boundary    extensions.geography(polygon, 4326),
  is_active   boolean not null default false,
  launched_at timestamptz,
  config      jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint cities_region_name_key unique (region_id, name),
  constraint cities_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint cities_longitude_range check (longitude is null or longitude between -180 and 180)
);

comment on table public.cities is
  'Operating cities. country_id is denormalised for query performance and kept in sync by trigger with the parent region.';

comment on column public.cities.config is
  'City-level rules: service radius, dispatch settings, local operating hours, payment provider overrides.';

-- Keep cities.country_id consistent with regions.country_id. This prevents a
-- city from ever pointing at a country different from its region.
create or replace function public.sync_city_country()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_region_country uuid;
begin
  select r.country_id
    into v_region_country
    from public.regions r
   where r.id = new.region_id;

  if v_region_country is null then
    raise exception 'region % does not exist', new.region_id
      using errcode = '23503';
  end if;

  if new.country_id is null then
    new.country_id := v_region_country;
  elsif new.country_id <> v_region_country then
    raise exception 'cities.country_id (%) must match regions.country_id (%) for region %',
      new.country_id, v_region_country, new.region_id
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger trg_cities_sync_country
  before insert or update of region_id, country_id on public.cities
  for each row execute function public.sync_city_country();

comment on function public.sync_city_country() is
  'Validates and backfills cities.country_id from the parent region.';
