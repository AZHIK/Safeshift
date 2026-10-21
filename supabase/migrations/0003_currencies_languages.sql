-- ============================================================================
-- SafeShift — Phase 1 / Migration 0003
-- Localization and currency primitives.
--
-- These tables are created before countries because countries reference a
-- default currency and a default language. The FKs from countries are declared
-- DEFERRABLE INITIALLY DEFERRED in 0004.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.currencies
-- ----------------------------------------------------------------------------
create table public.currencies (
  id             uuid primary key default gen_random_uuid(),
  code           char(3) not null unique,
  name           text not null,
  symbol         text not null,
  decimal_places smallint not null default 2,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint currencies_code_format check (code ~ '^[A-Z]{3}$'),
  constraint currencies_decimal_places_range check (decimal_places between 0 and 4)
);

comment on table public.currencies is
  'ISO-4217 currencies supported by the platform. Money is always stored as NUMERIC with an explicit currency reference.';

-- ----------------------------------------------------------------------------
-- public.languages
-- ----------------------------------------------------------------------------
create table public.languages (
  id          uuid primary key default gen_random_uuid(),
  code        char(5) not null unique,
  name        text not null,
  native_name text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint languages_code_format check (btrim(code) ~ '^[a-z]{2,3}(-[A-Za-z]{2,4})?$')
);

comment on table public.languages is
  'Languages available for app, SMS, email and error localisation.';
