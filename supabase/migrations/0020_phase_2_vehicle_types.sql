-- ============================================================================
-- SafeShift — Phase 2 / Migration 0020
-- Dynamic vehicle types, replacing a fixed vehicle-type enum.
-- ============================================================================

create table public.vehicle_types (
  id uuid primary key default gen_random_uuid(),
  country_id uuid references public.countries (id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  icon_url text,
  capacity_kg_min numeric(10,2) not null,
  capacity_kg_max numeric(10,2) not null,
  capacity_m3_min numeric(10,2),
  capacity_m3_max numeric(10,2),
  max_dimensions_cm jsonb,
  number_of_wheels smallint,
  requires_special_licence boolean not null default false,
  requires_equipment text[],
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_types_scope_code_key unique nulls not distinct (country_id, code),
  constraint vehicle_types_capacity_kg_check check (capacity_kg_min > 0 and capacity_kg_max >= capacity_kg_min),
  constraint vehicle_types_capacity_m3_check check (capacity_m3_min is null or capacity_m3_min > 0),
  constraint vehicle_types_capacity_m3_range_check check (capacity_m3_max is null or capacity_m3_min is null or capacity_m3_max >= capacity_m3_min),
  constraint vehicle_types_wheels_check check (number_of_wheels is null or number_of_wheels > 0),
  constraint vehicle_types_dimensions_object_check check (max_dimensions_cm is null or jsonb_typeof(max_dimensions_cm) = 'object')
);

alter table public.vehicle_models
  add constraint vehicle_models_vehicle_type_id_fkey
  foreign key (vehicle_type_id) references public.vehicle_types (id) on delete set null;

create trigger trg_vehicle_types_updated_at before update on public.vehicle_types
  for each row execute function public.set_updated_at();

