-- ============================================================================
-- SafeShift — Phase 1 / Migration 0005
-- Service zones, neighborhoods, addresses and zone pricing overrides.
--
-- zone_pricing_overrides.pricing_plan_id has NO foreign key yet: it targets
-- public.pricing_plans, which is created in Phase 3. The FK is added in Phase 3.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.service_zones
-- ----------------------------------------------------------------------------
create table public.service_zones (
  id         uuid primary key default gen_random_uuid(),
  city_id    uuid not null references public.cities (id) on delete cascade,
  name       text not null,
  zone_type  text not null,
  boundary   extensions.geography(polygon, 4326) not null,
  centroid   extensions.geography(point, 4326) not null,
  is_active  boolean not null default true,
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint service_zones_city_name_key unique (city_id, name),
  constraint service_zones_zone_type_check check (
    zone_type in (
      'operating_area',
      'pricing_zone',
      'surge_zone',
      'restricted_zone',
      'priority_zone'
    )
  )
);

comment on table public.service_zones is
  'Geographic operating/pricing zones inside a city. Geometry is PostGIS geography so distance queries run in-database.';

comment on column public.service_zones.metadata is
  'Zone-specific configuration: surge caps, priority weighting, restriction reasons, LATRA tariff references.';

-- ----------------------------------------------------------------------------
-- public.neighborhoods
-- ----------------------------------------------------------------------------
create table public.neighborhoods (
  id              uuid primary key default gen_random_uuid(),
  city_id         uuid not null references public.cities (id) on delete cascade,
  service_zone_id uuid references public.service_zones (id) on delete set null,
  name            text not null,
  centroid        extensions.geography(point, 4326),
  boundary        extensions.geography(polygon, 4326),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint neighborhoods_city_name_key unique (city_id, name)
);

comment on table public.neighborhoods is
  'Human-recognisable areas (Kariakoo, Ubungo, ...) used for pickup hints, matching and analytics.';

-- ----------------------------------------------------------------------------
-- public.addresses
-- ----------------------------------------------------------------------------
-- created_by references public.profiles, which is created in migration 0006.
-- The column is created here and the FK is added in 0006.
create table public.addresses (
  id              uuid primary key default gen_random_uuid(),
  country_id      uuid not null references public.countries (id),
  city_id         uuid references public.cities (id),
  neighborhood_id uuid references public.neighborhoods (id),
  line_1          text not null,
  line_2          text,
  landmark        text,
  location        extensions.geography(point, 4326) not null,
  metadata        jsonb not null default '{}'::jsonb,
  created_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.addresses is
  'Reusable addresses. landmark is first-class because formal street addressing is uncommon in the pilot market.';

comment on column public.addresses.metadata is
  'Structured address hints: building name, floor, gate colour, access notes.';

comment on column public.addresses.created_by is
  'FK to public.profiles(id) added in migration 0006 (profiles is created after addresses).';

-- Keep address -> city -> country and address -> neighborhood -> city coherent.
create or replace function public.validate_address_hierarchy()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_city_country uuid;
  v_neighborhood_city uuid;
begin
  if new.city_id is not null then
    select c.country_id into v_city_country
      from public.cities c where c.id = new.city_id;

    if v_city_country is null then
      raise exception 'city % does not exist', new.city_id using errcode = '23503';
    end if;
    if v_city_country <> new.country_id then
      raise exception 'address country_id (%) does not match city country_id (%)',
        new.country_id, v_city_country using errcode = '23514';
    end if;
  end if;

  if new.neighborhood_id is not null then
    select n.city_id into v_neighborhood_city
      from public.neighborhoods n where n.id = new.neighborhood_id;

    if v_neighborhood_city is null then
      raise exception 'neighborhood % does not exist', new.neighborhood_id using errcode = '23503';
    end if;
    if new.city_id is distinct from v_neighborhood_city then
      raise exception 'address city_id (%) does not match neighborhood city_id (%)',
        new.city_id, v_neighborhood_city using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_addresses_validate_hierarchy
  before insert or update on public.addresses
  for each row execute function public.validate_address_hierarchy();

comment on function public.validate_address_hierarchy() is
  'Ensures country/city/neighborhood references on addresses form a coherent hierarchy.';

-- ----------------------------------------------------------------------------
-- public.zone_pricing_overrides
-- ----------------------------------------------------------------------------
create table public.zone_pricing_overrides (
  id              uuid primary key default gen_random_uuid(),
  service_zone_id uuid not null references public.service_zones (id) on delete cascade,
  -- FK will be added in Phase 3 (targets public.pricing_plans).
  pricing_plan_id uuid,
  multiplier      numeric(4, 2) not null,
  reason          text,
  effective_from  timestamptz not null,
  effective_to    timestamptz,
  created_at      timestamptz not null default now(),

  constraint zone_pricing_overrides_multiplier_check
    check (multiplier > 0 and multiplier <= 5),
  constraint zone_pricing_overrides_effective_window_check
    check (effective_to is null or effective_to > effective_from)
);

comment on table public.zone_pricing_overrides is
  'Zone-level price multipliers (surge, congestion, priority). Consumed by the Phase 3 pricing engine.';

comment on column public.zone_pricing_overrides.pricing_plan_id is
  'FK will be added in Phase 3 (references public.pricing_plans.id).';
