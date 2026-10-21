-- ============================================================================
-- SafeShift — Phase 3 / Migration 0042
-- Core rate card: exactly one base-rate row per pricing plan version.
--
-- All money is NUMERIC(14,2) with an explicit currency. Percentages and
-- multipliers are NUMERIC(6,4). No FLOAT/DOUBLE anywhere in Phase 3.
-- ============================================================================

create table public.pricing_plan_base_rates (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  currency_code           char(3) not null references public.currencies (code) on update cascade on delete restrict,
  base_fare               numeric(14,2) not null,
  per_km_rate             numeric(14,2) not null,
  per_min_rate            numeric(14,2) not null,
  minimum_charge          numeric(14,2) not null default 0,
  loading_fee             numeric(14,2) not null default 0,
  unloading_fee           numeric(14,2) not null default 0,
  waiting_per_min_rate    numeric(14,2) not null default 0,
  waiting_free_minutes    integer not null default 5,
  multi_stop_fee          numeric(14,2) not null default 0,
  vat_rate                numeric(6,4) not null default 0.1800,
  created_at              timestamptz not null default now(),

  constraint pricing_plan_base_rates_version_key
    unique (pricing_plan_version_id),
  constraint pricing_plan_base_rates_base_fare_check check (base_fare >= 0),
  constraint pricing_plan_base_rates_per_km_check check (per_km_rate >= 0),
  constraint pricing_plan_base_rates_per_min_check check (per_min_rate >= 0),
  constraint pricing_plan_base_rates_minimum_check check (minimum_charge >= 0),
  constraint pricing_plan_base_rates_loading_check check (loading_fee >= 0),
  constraint pricing_plan_base_rates_unloading_check check (unloading_fee >= 0),
  constraint pricing_plan_base_rates_waiting_check check (waiting_per_min_rate >= 0),
  constraint pricing_plan_base_rates_waiting_free_check check (waiting_free_minutes >= 0),
  constraint pricing_plan_base_rates_multi_stop_check check (multi_stop_fee >= 0),
  constraint pricing_plan_base_rates_vat_check check (vat_rate >= 0 and vat_rate <= 1)
);

comment on table public.pricing_plan_base_rates is
  'The core rate numbers for one pricing plan version. Exactly one row per version.';

comment on column public.pricing_plan_base_rates.waiting_free_minutes is
  'Minutes of on-site waiting included before waiting_per_min_rate applies.';

comment on column public.pricing_plan_base_rates.vat_rate is
  'Fraction, not percent: 0.1800 = 18% VAT.';
