-- ============================================================================
-- SafeShift — Phase 2 / Migration 0021
-- Global catalogue of vehicle equipment.
-- ============================================================================

create table public.vehicle_equipment_catalog (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  icon_url text,
  category text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_vehicle_equipment_catalog_updated_at before update on public.vehicle_equipment_catalog
  for each row execute function public.set_updated_at();

