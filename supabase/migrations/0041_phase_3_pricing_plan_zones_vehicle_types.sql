-- ============================================================================
-- SafeShift — Phase 3 / Migration 0041
-- Version-level service-zone and vehicle-type applicability.
--
-- The plan carries a primary zone and vehicle type. These tables let one
-- version extend to additional zones (e.g. a city-wide zone list) or share a
-- single rate card across several vehicle types (medium + large truck).
-- ============================================================================

create table public.pricing_plan_zones (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  service_zone_id         uuid not null references public.service_zones (id) on delete restrict,
  is_primary              boolean not null default false,
  created_at              timestamptz not null default now(),

  constraint pricing_plan_zones_version_zone_key
    unique (pricing_plan_version_id, service_zone_id)
);

comment on table public.pricing_plan_zones is
  'Additional service zones a pricing version applies to. is_primary marks the plan''s home zone for display and override resolution.';

create table public.pricing_plan_vehicle_types (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  vehicle_type_id         uuid not null references public.vehicle_types (id) on delete restrict,
  created_at              timestamptz not null default now(),

  constraint pricing_plan_vehicle_types_version_type_key
    unique (pricing_plan_version_id, vehicle_type_id)
);

comment on table public.pricing_plan_vehicle_types is
  'Additional vehicle types a pricing version applies to, allowing shared rate cards.';
