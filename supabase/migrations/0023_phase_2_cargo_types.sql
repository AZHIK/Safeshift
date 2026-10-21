-- ============================================================================
-- SafeShift — Phase 2 / Migration 0023
-- Dynamic, country-aware cargo types.
-- ============================================================================

create table public.cargo_types (
  id uuid primary key default gen_random_uuid(),
  country_id uuid references public.countries (id) on delete cascade,
  category_id uuid references public.cargo_categories (id) on delete set null,
  code text not null,
  name text not null,
  description text,
  icon_url text,
  requires_special_handling boolean not null default false,
  requires_declared_value boolean not null default false,
  requires_insurance boolean not null default false,
  allowed_vehicle_type_codes text[] not null default '{}',
  prohibited_vehicle_type_codes text[] not null default '{}',
  max_value_tzs numeric(14,2),
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cargo_types_scope_code_key unique nulls not distinct (country_id, code),
  constraint cargo_types_max_value_check check (max_value_tzs is null or max_value_tzs >= 0)
);

create trigger trg_cargo_types_updated_at before update on public.cargo_types
  for each row execute function public.set_updated_at();

