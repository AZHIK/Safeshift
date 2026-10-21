-- ============================================================================
-- SafeShift — Phase 3 / Migration 0044
-- Cargo-type and equipment surcharges on a pricing plan version.
--
-- Surcharge semantics:
--   flat_fee    -> add surcharge_value (money)
--   multiplier  -> scale the running fare by surcharge_value
--   percentage  -> add surcharge_value percent of the running fare (cargo only)
-- ============================================================================

create table public.pricing_cargo_surcharges (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  cargo_type_id           uuid not null references public.cargo_types (id) on delete restrict,
  currency_code           char(3) not null references public.currencies (code) on update cascade on delete restrict,
  surcharge_type          text not null,
  surcharge_value         numeric(14,4) not null,
  created_at              timestamptz not null default now(),

  constraint pricing_cargo_surcharges_version_cargo_key
    unique (pricing_plan_version_id, cargo_type_id),
  constraint pricing_cargo_surcharges_type_check
    check (surcharge_type in ('flat_fee', 'multiplier', 'percentage')),
  constraint pricing_cargo_surcharges_value_check check (surcharge_value >= 0)
);

comment on table public.pricing_cargo_surcharges is
  'Per-cargo-type additions to a fare. percentage values are percentage points (10.0000 = 10%).';

create table public.pricing_equipment_surcharges (
  id                      uuid primary key default gen_random_uuid(),
  pricing_plan_version_id uuid not null references public.pricing_plan_versions (id) on delete restrict,
  equipment_id            uuid not null references public.vehicle_equipment_catalog (id) on delete restrict,
  currency_code           char(3) not null references public.currencies (code) on update cascade on delete restrict,
  surcharge_type          text not null,
  surcharge_value         numeric(14,4) not null,
  created_at              timestamptz not null default now(),

  constraint pricing_equipment_surcharges_version_equipment_key
    unique (pricing_plan_version_id, equipment_id),
  constraint pricing_equipment_surcharges_type_check
    check (surcharge_type in ('flat_fee', 'multiplier')),
  constraint pricing_equipment_surcharges_value_check check (surcharge_value >= 0)
);

comment on table public.pricing_equipment_surcharges is
  'Surcharges for required equipment (refrigeration unit, tail lift, ...) on a pricing plan version.';
