-- ============================================================================
-- SafeShift — Phase 3 / Migration 0039
-- Pricing plan identity. A plan is the stable, human-facing identity; the
-- numbers live in immutable versions (migration 0040).
--
-- A plan is scoped to one country + city and to one vehicle type. The optional
-- service_zone_id narrows it to a zone; NULL means the whole city. A plan is
-- never deleted once quoted, and its identity columns are stable for life.
-- ============================================================================

create table public.pricing_plans (
  id              uuid primary key default gen_random_uuid(),
  country_id      uuid not null references public.countries (id) on delete restrict,
  city_id         uuid not null references public.cities (id) on delete restrict,
  service_zone_id uuid references public.service_zones (id) on delete restrict,
  vehicle_type_id uuid not null references public.vehicle_types (id) on delete restrict,
  code            text not null,
  name            text not null,
  description     text,
  display_order   integer not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint pricing_plans_scope_code_key
    unique nulls not distinct (country_id, city_id, service_zone_id, vehicle_type_id, code),
  constraint pricing_plans_code_format_check
    check (code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint pricing_plans_display_order_check check (display_order >= 0)
);

comment on table public.pricing_plans is
  'Stable pricing plan identity: city/zone/vehicle-type scope plus code and name. Rates live in pricing_plan_versions.';

comment on column public.pricing_plans.service_zone_id is
  'NULL = the plan applies to the whole city. A zone-specific plan takes precedence over a city-wide plan in active_pricing_plan_for().';

-- A SQL CHECK cannot compare across tables, so scope coherence is enforced by
-- a trigger: city must belong to country, zone must belong to city, and a
-- country-scoped vehicle type must match the plan country.
create or replace function public.validate_pricing_plan_scope()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_city_country   uuid;
  v_zone_city      uuid;
  v_vehicle_country uuid;
begin
  select c.country_id into v_city_country
  from public.cities c
  where c.id = new.city_id;

  if v_city_country is null then
    raise exception 'city % does not exist', new.city_id using errcode = '23503';
  end if;

  if v_city_country <> new.country_id then
    raise exception 'pricing_plans country_id (%) does not match city country_id (%) for city %',
      new.country_id, v_city_country, new.city_id
      using errcode = '23514';
  end if;

  if new.service_zone_id is not null then
    select sz.city_id into v_zone_city
    from public.service_zones sz
    where sz.id = new.service_zone_id;

    if v_zone_city is null then
      raise exception 'service zone % does not exist', new.service_zone_id using errcode = '23503';
    end if;

    if v_zone_city <> new.city_id then
      raise exception 'pricing_plans service_zone_id (%) belongs to city %, not %',
        new.service_zone_id, v_zone_city, new.city_id
        using errcode = '23514';
    end if;
  end if;

  select vt.country_id into v_vehicle_country
  from public.vehicle_types vt
  where vt.id = new.vehicle_type_id;

  if not found then
    raise exception 'vehicle type % does not exist', new.vehicle_type_id using errcode = '23503';
  end if;

  if v_vehicle_country is not null and v_vehicle_country <> new.country_id then
    raise exception 'pricing_plans vehicle_type_id (%) belongs to country %, not %',
      new.vehicle_type_id, v_vehicle_country, new.country_id
      using errcode = '23514';
  end if;

  return new;
end;
$$;

comment on function public.validate_pricing_plan_scope() is
  'Validates that a pricing plan city, zone and vehicle type all belong to the plan country.';

create trigger trg_pricing_plans_validate_scope
  before insert or update of country_id, city_id, service_zone_id, vehicle_type_id
  on public.pricing_plans
  for each row execute function public.validate_pricing_plan_scope();

create trigger trg_pricing_plans_updated_at
  before update on public.pricing_plans
  for each row execute function public.set_updated_at();
