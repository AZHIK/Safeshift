-- ============================================================================
-- SafeShift — Phase 3 / Migration 0043
-- Distance, weight and volume tiering.
--
-- Distance tiers replace per_km_rate for the slice they cover. Weight and
-- volume tiers add a flat fee or a multiplier when cargo crosses a threshold.
-- Each tier table carries its own currency because flat fees are money.
--
-- Overlap prevention triggers are installed in migration 0047.
-- ============================================================================

create table public.pricing_distance_tiers (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  currency_code           char(3) not null references public.currencies (code) on update cascade on delete restrict,
  min_km                  numeric(8,2) not null,
  max_km                  numeric(8,2),
  per_km_rate             numeric(14,2) not null,
  display_order           integer not null default 0,
  created_at              timestamptz not null default now(),

  constraint pricing_distance_tiers_min_check check (min_km >= 0),
  constraint pricing_distance_tiers_max_check check (max_km is null or max_km > min_km),
  constraint pricing_distance_tiers_rate_check check (per_km_rate >= 0),
  constraint pricing_distance_tiers_order_check check (display_order >= 0)
);

comment on table public.pricing_distance_tiers is
  'Optional distance slices that override per_km_rate. Gaps fall back to pricing_plan_base_rates.per_km_rate.';

create table public.pricing_weight_tiers (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  currency_code           char(3) not null references public.currencies (code) on update cascade on delete restrict,
  min_kg                  numeric(10,2) not null,
  max_kg                  numeric(10,2),
  surcharge_type          text not null,
  surcharge_value         numeric(14,4) not null,
  display_order           integer not null default 0,
  created_at              timestamptz not null default now(),

  constraint pricing_weight_tiers_min_check check (min_kg >= 0),
  constraint pricing_weight_tiers_max_check check (max_kg is null or max_kg > min_kg),
  constraint pricing_weight_tiers_type_check
    check (surcharge_type in ('flat_fee', 'multiplier')),
  constraint pricing_weight_tiers_value_check check (surcharge_value >= 0),
  constraint pricing_weight_tiers_order_check check (display_order >= 0)
);

comment on table public.pricing_weight_tiers is
  'Weight-band surcharges. flat_fee adds an amount; multiplier scales the base+time+distance component.';

create table public.pricing_volume_tiers (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  currency_code           char(3) not null references public.currencies (code) on update cascade on delete restrict,
  min_m3                  numeric(8,2) not null,
  max_m3                  numeric(8,2),
  surcharge_type          text not null,
  surcharge_value         numeric(14,4) not null,
  display_order           integer not null default 0,
  created_at              timestamptz not null default now(),

  constraint pricing_volume_tiers_min_check check (min_m3 >= 0),
  constraint pricing_volume_tiers_max_check check (max_m3 is null or max_m3 > min_m3),
  constraint pricing_volume_tiers_type_check
    check (surcharge_type in ('flat_fee', 'multiplier')),
  constraint pricing_volume_tiers_value_check check (surcharge_value >= 0),
  constraint pricing_volume_tiers_order_check check (display_order >= 0)
);

comment on table public.pricing_volume_tiers is
  'Volume-band surcharges. Applied the same way as weight tiers, using cubic metres.';
