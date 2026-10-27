-- ============================================================================
-- SafeShift — Phase 4 / Migration 0056
-- Persisted quotes: the immutable record of what the customer was shown.
--
-- Decision A: a quote stores both the exact pricing_plan_version_id and a JSONB
-- snapshot of the complete calculation. The version reference is the source of
-- truth; the snapshot is for audit, support and explainability.
--
-- Decision B: the regulated cap is a maximum total including VAT, matching
-- Phase 3. Decision C: at most one promo code per quote.
-- ============================================================================

create table public.quotes (
  id                         uuid primary key default gen_random_uuid(),
  quote_request_id           uuid not null references public.quote_requests (id) on delete restrict,
  pricing_plan_version_id    uuid not null references public.pricing_plan_versions (id) on delete restrict,
  currency_code              char(3) not null references public.currencies (code) on update cascade on delete restrict,
  base_fare                  numeric(14,2) not null,
  distance_charge            numeric(14,2) not null,
  time_charge                numeric(14,2) not null,
  weight_surcharge           numeric(14,2) not null default 0,
  volume_surcharge           numeric(14,2) not null default 0,
  cargo_surcharge            numeric(14,2) not null default 0,
  equipment_surcharge        numeric(14,2) not null default 0,
  waiting_charge             numeric(14,2) not null default 0,
  multi_stop_charge          numeric(14,2) not null default 0,
  zone_multiplier            numeric(6,4) not null default 1.0000,
  time_multiplier            numeric(6,4) not null default 1.0000,
  surge_multiplier           numeric(6,4) not null default 1.0000,
  promo_code_id              uuid references public.promo_codes (id) on delete restrict,
  promo_discount             numeric(14,2) not null default 0,
  subtotal                   numeric(14,2) not null,
  vat                        numeric(14,2) not null,
  total                      numeric(14,2) not null,
  is_capped                  boolean not null default false,
  regulated_max_fare         numeric(14,2),
  pricing_breakdown_snapshot jsonb not null,
  distance_km                numeric(8,2) not null,
  estimated_duration_min     integer not null,
  expires_at                 timestamptz not null,
  created_at                 timestamptz not null default now(),

  constraint quotes_base_fare_check check (base_fare >= 0),
  constraint quotes_distance_charge_check check (distance_charge >= 0),
  constraint quotes_time_charge_check check (time_charge >= 0),
  constraint quotes_weight_surcharge_check check (weight_surcharge >= 0),
  constraint quotes_volume_surcharge_check check (volume_surcharge >= 0),
  constraint quotes_cargo_surcharge_check check (cargo_surcharge >= 0),
  constraint quotes_equipment_surcharge_check check (equipment_surcharge >= 0),
  constraint quotes_waiting_charge_check check (waiting_charge >= 0),
  constraint quotes_multi_stop_charge_check check (multi_stop_charge >= 0),
  constraint quotes_zone_multiplier_check check (zone_multiplier > 0),
  constraint quotes_time_multiplier_check check (time_multiplier > 0),
  constraint quotes_surge_multiplier_check check (surge_multiplier >= 1 and surge_multiplier <= 5),
  constraint quotes_promo_discount_check check (promo_discount >= 0),
  constraint quotes_discount_not_above_subtotal_check check (promo_discount <= subtotal),
  constraint quotes_subtotal_check check (subtotal >= 0),
  constraint quotes_vat_check check (vat >= 0),
  constraint quotes_total_check check (total >= 0),
  constraint quotes_regulated_max_check check (regulated_max_fare is null or regulated_max_fare >= 0),
  constraint quotes_capped_has_cap_check check (not is_capped or regulated_max_fare is not null),
  constraint quotes_distance_check check (distance_km >= 0),
  constraint quotes_duration_check check (estimated_duration_min >= 0),
  constraint quotes_expiry_check check (expires_at > created_at),
  constraint quotes_snapshot_object_check check (jsonb_typeof(pricing_breakdown_snapshot) = 'object')
);

comment on table public.quotes is
  'Immutable authoritative quotes. UPDATE and DELETE are blocked for client roles; the version id plus JSONB snapshot make every quote reproducible forever.';

comment on column public.quotes.pricing_breakdown_snapshot is
  'Complete Phase 4 engine snapshot: inputs, plan resolution, rate card, components, multipliers, surge, promo, cap and final totals.';

comment on column public.quotes.subtotal is
  'Net fare after the regulated cap but before promo discount. vat is calculated on (subtotal - promo_discount), so the customer-facing total is subtotal - promo_discount + vat.';

comment on column public.quotes.expires_at is
  'Quote validity deadline. A job must be created from a quote before this timestamp.';
