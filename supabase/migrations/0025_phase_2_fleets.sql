-- ============================================================================
-- SafeShift — Phase 2 / Migration 0025
-- Fleet entities. Membership and vehicle relationships follow in 0028.
-- ============================================================================

create table public.fleets (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries (id),
  primary_city_id uuid references public.cities (id) on delete set null,
  name text not null,
  trading_name text,
  registration_number text,
  tax_id text,
  contact_email text,
  contact_phone text,
  billing_address_id uuid references public.addresses (id) on delete set null,
  owner_profile_id uuid references public.profiles (id) on delete set null,
  commission_rate_override numeric(5,2),
  is_active boolean not null default true,
  verified_at timestamptz,
  verified_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fleets_commission_rate_check check (commission_rate_override is null or commission_rate_override between 0 and 100)
);

create trigger trg_fleets_updated_at before update on public.fleets
  for each row execute function public.set_updated_at();

