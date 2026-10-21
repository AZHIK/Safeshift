-- ============================================================================
-- SafeShift — Phase 2 / Migration 0024
-- Cargo combination/certification restrictions and packaging choices.
-- ============================================================================

create table public.cargo_restrictions (
  id uuid primary key default gen_random_uuid(),
  cargo_type_id uuid not null references public.cargo_types (id) on delete cascade,
  restriction_type text not null,
  restricted_with_cargo_type_id uuid references public.cargo_types (id) on delete cascade,
  restriction_details jsonb not null default '{}'::jsonb,
  description text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cargo_restrictions_type_check check (restriction_type in ('cannot_combine', 'requires_certificate', 'requires_special_vehicle', 'age_restricted', 'prohibited_route', 'time_restricted')),
  constraint cargo_restrictions_details_object_check check (jsonb_typeof(restriction_details) = 'object'),
  constraint cargo_restrictions_pair_check check (restricted_with_cargo_type_id is null or restricted_with_cargo_type_id <> cargo_type_id)
);

create table public.cargo_packaging_options (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  additional_fee_tzs numeric(12,2) not null default 0,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cargo_packaging_options_fee_check check (additional_fee_tzs >= 0)
);

create trigger trg_cargo_restrictions_updated_at before update on public.cargo_restrictions
  for each row execute function public.set_updated_at();
create trigger trg_cargo_packaging_options_updated_at before update on public.cargo_packaging_options
  for each row execute function public.set_updated_at();

