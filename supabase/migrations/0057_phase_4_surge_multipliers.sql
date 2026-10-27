-- ============================================================================
-- SafeShift — Phase 4 / Migration 0057
-- Time-series demand surge (Decision F).
--
-- Surge is operational data, not part of an immutable pricing version. A quote
-- applies both the version's zone/time multipliers and the highest matching
-- active surge multiplier. Surge rows are short-lived and may be deleted.
-- ============================================================================

create table public.surge_multipliers (
  id                  uuid primary key default gen_random_uuid(),
  city_id             uuid not null references public.cities (id) on delete cascade,
  service_zone_id     uuid references public.service_zones (id) on delete cascade,
  vehicle_type_id     uuid references public.vehicle_types (id) on delete cascade,
  multiplier          numeric(6,4) not null,
  reason              text,
  starts_at           timestamptz not null,
  ends_at             timestamptz not null,
  created_by          uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint surge_multipliers_value_check
    check (multiplier >= 1.0 and multiplier <= 5.0),
  constraint surge_multipliers_window_check
    check (ends_at > starts_at)
);

comment on table public.surge_multipliers is
  'Time-bounded demand surge. NULL service_zone_id means the whole city; NULL vehicle_type_id means every vehicle type. Overlaps for the same scope are rejected by trigger.';

comment on column public.surge_multipliers.multiplier is
  'Applied multiplicatively after the immutable plan version multipliers. The quote engine chooses the highest matching active row.';

comment on column public.surge_multipliers.reason is
  'Human-readable operational reason, e.g. rain, port congestion, event dispersal.';
