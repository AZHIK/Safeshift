-- ============================================================================
-- SafeShift — Phase 1 / Migration 0011
-- Localization content, currency conversion and feature flags.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.exchange_rates
-- ----------------------------------------------------------------------------
create table public.exchange_rates (
  id                uuid primary key default gen_random_uuid(),
  from_currency_id  uuid not null references public.currencies (id),
  to_currency_id    uuid not null references public.currencies (id),
  rate              numeric(14, 6) not null,
  source            text not null,
  effective_from    timestamptz not null,
  effective_to      timestamptz,
  created_at        timestamptz not null default now(),

  constraint exchange_rates_rate_check check (rate > 0),
  constraint exchange_rates_distinct_currencies_check check (from_currency_id <> to_currency_id),
  constraint exchange_rates_effective_window_check
    check (effective_to is null or effective_to > effective_from)
);

comment on table public.exchange_rates is
  'Time-windowed FX rates. source records provenance (central bank, manual, provider).';

-- ----------------------------------------------------------------------------
-- public.localization_strings
-- ----------------------------------------------------------------------------
create table public.localization_strings (
  id          uuid primary key default gen_random_uuid(),
  language_id uuid not null references public.languages (id) on delete cascade,
  namespace   text not null,
  key         text not null,
  value       text not null,
  context     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint localization_strings_language_namespace_key unique (language_id, namespace, key)
);

comment on table public.localization_strings is
  'Translatable strings for app, SMS, email and error surfaces. namespace groups related keys.';

comment on column public.localization_strings.context is
  'Translator guidance (tone, variables, character budget).';

-- ----------------------------------------------------------------------------
-- public.feature_flags
-- ----------------------------------------------------------------------------
create table public.feature_flags (
  id                 uuid primary key default gen_random_uuid(),
  flag_key           text not null,
  country_id         uuid references public.countries (id) on delete cascade,
  city_id            uuid references public.cities (id) on delete cascade,
  profile_id         uuid references public.profiles (id) on delete cascade,
  is_enabled         boolean not null default false,
  rollout_percentage smallint not null default 0,
  description        text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  -- NULLS NOT DISTINCT keeps a single global row per flag (NULL country/city/profile).
  constraint feature_flags_scope_key
    unique nulls not distinct (flag_key, country_id, city_id, profile_id),
  constraint feature_flags_rollout_range check (rollout_percentage between 0 and 100),
  constraint feature_flags_scope_check check (
    (city_id is null or country_id is not null)
    and (profile_id is null or country_id is not null)
  )
);

comment on table public.feature_flags is
  'Scoped rollout flags: global, per country, per city or per beta profile. Most specific scope wins at evaluation time.';
