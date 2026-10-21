-- ============================================================================
-- SafeShift — Phase 3 / Migration 0045
-- Time-based and zone-based multipliers, plus override resolution records.
--
-- Time windows may cross midnight (22:00 -> 05:00 is stored with
-- end_time < start_time). The seed uses this for the night multiplier.
-- Overlap prevention for non-stacking windows is installed in migration 0047.
-- ============================================================================

create table public.pricing_time_multipliers (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  name                    text not null,
  days_of_week            smallint[] not null,
  start_time              time not null,
  end_time                time not null,
  timezone                text not null default 'Africa/Dar_es_Salaam',
  multiplier              numeric(6,4) not null,
  applies_to              text not null default 'subtotal',
  priority                integer not null default 0,
  stacks                  boolean not null default false,
  created_at              timestamptz not null default now(),

  constraint pricing_time_multipliers_days_check
    check (array_length(days_of_week, 1) between 1 and 7),
  constraint pricing_time_multipliers_days_range_check
    check (days_of_week <@ array[0,1,2,3,4,5,6]::smallint[]),
  constraint pricing_time_multipliers_time_check check (end_time <> start_time),
  constraint pricing_time_multipliers_multiplier_check
    check (multiplier >= 1.0 and multiplier <= 5.0),
  constraint pricing_time_multipliers_applies_to_check
    check (applies_to in ('subtotal', 'base_fare', 'distance', 'time'))
);

comment on table public.pricing_time_multipliers is
  'Peak/night/weekend multipliers. days_of_week uses PostgreSQL DOW (0=Sunday). A window whose end_time is before start_time crosses midnight.';

comment on column public.pricing_time_multipliers.stacks is
  'When false, only the highest-priority matching window applies. When true, this window multiplies on top of the selected non-stacking window.';

create table public.pricing_zone_multipliers (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  service_zone_id         uuid not null references public.service_zones (id) on delete restrict,
  multiplier              numeric(6,4) not null,
  reason                  text,
  created_at              timestamptz not null default now(),

  constraint pricing_zone_multipliers_version_zone_key
    unique (pricing_plan_version_id, service_zone_id),
  constraint pricing_zone_multipliers_multiplier_check
    check (multiplier >= 1.0 and multiplier <= 5.0)
);

comment on table public.pricing_zone_multipliers is
  'Zone-level surge-like modifier for a specific pricing version.';

create table public.zone_pricing_override_resolution (
  id                      uuid primary key default gen_random_uuid(),
  zone_pricing_override_id uuid not null references public.zone_pricing_overrides (id) on delete cascade,
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  resolved_at             timestamptz not null default now(),
  resolved_by             uuid references public.profiles (id) on delete set null,
  created_at              timestamptz not null default now(),

  constraint zone_pricing_override_resolution_key
    unique (zone_pricing_override_id, pricing_plan_version_id)
);

comment on table public.zone_pricing_override_resolution is
  'Audit record of which pricing plan version a Phase 1 zone override resolved to and when.';
