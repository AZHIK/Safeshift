-- ============================================================================
-- SafeShift — Phase 2 / Migration 0019
-- Vehicle manufacturers and models. vehicle_type_id is added after types exist.
-- ============================================================================

create table public.vehicle_makes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  country_of_origin text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vehicle_models (
  id uuid primary key default gen_random_uuid(),
  make_id uuid not null references public.vehicle_makes (id) on delete cascade,
  name text not null,
  vehicle_type_id uuid,
  year_start smallint,
  year_end smallint,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_models_make_name_key unique (make_id, name),
  constraint vehicle_models_year_range_check check (year_end is null or year_start is null or year_end >= year_start)
);

create trigger trg_vehicle_makes_updated_at before update on public.vehicle_makes
  for each row execute function public.set_updated_at();
create trigger trg_vehicle_models_updated_at before update on public.vehicle_models
  for each row execute function public.set_updated_at();

