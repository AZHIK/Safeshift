-- ============================================================================
-- SafeShift — Phase 5 / Migration 0083
-- Commission rules, resolved by specificity and priority.
--
-- Scope cascade: driver > fleet > vehicle_type > city > country > platform
-- default (every scope column NULL). Higher priority wins inside a scope.
-- ============================================================================

create table public.commission_rules (
  id                uuid primary key default gen_random_uuid(),
  country_id        uuid references public.countries (id) on delete cascade,
  city_id           uuid references public.cities (id) on delete cascade,
  vehicle_type_id   uuid references public.vehicle_types (id) on delete cascade,
  fleet_id          uuid references public.fleets (id) on delete cascade,
  driver_id         uuid references public.drivers (id) on delete cascade,
  commission_type   text not null,
  commission_value  numeric(14,4) not null,
  min_commission    numeric(14,2) not null default 0,
  max_commission    numeric(14,2),
  priority          integer not null default 0,
  effective_from    timestamptz not null,
  effective_to      timestamptz,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint commission_rules_type_check
    check (commission_type in ('percentage', 'flat_fee')),
  constraint commission_rules_value_check check (commission_value >= 0),
  constraint commission_rules_percentage_check
    check (commission_type <> 'percentage' or commission_value <= 100),
  constraint commission_rules_min_check check (min_commission >= 0),
  constraint commission_rules_max_check
    check (max_commission is null or max_commission >= min_commission),
  constraint commission_rules_window_check
    check (effective_to is null or effective_to > effective_from)
);

comment on table public.commission_rules is
  'Commission scopes. driver_id wins over fleet_id, then vehicle_type_id, city_id, country_id and the global default.';

comment on column public.commission_rules.commission_value is
  'Percentage points for percentage rules, or a flat amount for flat_fee rules. NUMERIC(14,4) keeps both representations exact.';

create trigger trg_commission_rules_updated_at
  before update on public.commission_rules
  for each row execute function public.set_updated_at();
