-- ============================================================================
-- SafeShift — Phase 2 / Migration 0027
-- Installed equipment per vehicle.
-- ============================================================================

create table public.vehicle_equipment (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  equipment_id uuid not null references public.vehicle_equipment_catalog (id) on delete cascade,
  quantity smallint not null default 1,
  condition text,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_equipment_vehicle_equipment_key unique (vehicle_id, equipment_id),
  constraint vehicle_equipment_quantity_check check (quantity > 0),
  constraint vehicle_equipment_condition_check check (condition is null or condition in ('good', 'fair', 'needs_replacement'))
);

create trigger trg_vehicle_equipment_updated_at before update on public.vehicle_equipment
  for each row execute function public.set_updated_at();

