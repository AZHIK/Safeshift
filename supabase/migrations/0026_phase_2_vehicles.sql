-- ============================================================================
-- SafeShift — Phase 2 / Migration 0026
-- Individual vehicles and their ownership/verification state.
-- ============================================================================

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries (id),
  home_city_id uuid references public.cities (id) on delete set null,
  primary_driver_id uuid references public.profiles (id) on delete set null,
  owner_type text not null,
  -- Owner references are RESTRICT, not SET NULL: the owner-shape CHECK below
  -- would otherwise be violated the moment one of these rows was deleted.
  -- Deactivate/reassign a vehicle before removing its legal owner.
  owner_profile_id uuid references public.profiles (id) on delete restrict,
  owner_business_account_id uuid references public.business_accounts (id) on delete restrict,
  owner_fleet_id uuid references public.fleets (id) on delete restrict,
  vehicle_type_id uuid not null references public.vehicle_types (id),
  make_id uuid references public.vehicle_makes (id) on delete set null,
  model_id uuid references public.vehicle_models (id) on delete set null,
  year smallint,
  registration_number text not null,
  registration_country_id uuid not null references public.countries (id),
  chassis_number text,
  engine_number text,
  color text,
  capacity_kg numeric(10,2) not null,
  capacity_m3 numeric(10,2),
  dimensions_cm jsonb,
  photo_urls text[] not null default '{}',
  verification_status public.driver_verification_status not null default 'pending',
  verified_at timestamptz,
  verified_by uuid references public.profiles (id) on delete set null,
  rejection_reason text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicles_registration_key unique (registration_country_id, registration_number),
  constraint vehicles_owner_type_check check (owner_type in ('individual', 'fleet', 'business', 'safeshift')),
  constraint vehicles_owner_shape_check check (
    (owner_type = 'individual' and owner_profile_id is not null and owner_business_account_id is null and owner_fleet_id is null)
    or (owner_type = 'fleet' and owner_profile_id is null and owner_business_account_id is null and owner_fleet_id is not null)
    or (owner_type = 'business' and owner_profile_id is null and owner_business_account_id is not null and owner_fleet_id is null)
    or (owner_type = 'safeshift' and owner_profile_id is null and owner_business_account_id is null and owner_fleet_id is null)
  ),
  constraint vehicles_year_check check (year is null or year between 1900 and 2100),
  constraint vehicles_capacity_kg_check check (capacity_kg > 0),
  constraint vehicles_capacity_m3_check check (capacity_m3 is null or capacity_m3 > 0),
  constraint vehicles_dimensions_object_check check (dimensions_cm is null or jsonb_typeof(dimensions_cm) = 'object')
);

create trigger trg_vehicles_updated_at before update on public.vehicles
  for each row execute function public.set_updated_at();

