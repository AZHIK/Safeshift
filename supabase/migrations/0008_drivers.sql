-- ============================================================================
-- SafeShift — Phase 1 / Migration 0008
-- Drivers and driver operational data.
--
-- drivers.current_vehicle_id and drivers.current_fleet_id have NO foreign keys
-- yet: they target public.vehicles and public.fleets, created in Phase 2.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.drivers
-- ----------------------------------------------------------------------------
create table public.drivers (
  id                     uuid primary key references public.profiles (id) on delete cascade,
  country_id             uuid not null references public.countries (id),
  home_city_id           uuid references public.cities (id),
  licence_number         text,
  licence_expiry         date,
  licence_country_id     uuid references public.countries (id),
  verification_status    public.driver_verification_status not null default 'pending',
  risk_tier              public.driver_risk_tier not null default 'standard',
  rating                 numeric(3, 2) not null default 0,
  total_trips            integer not null default 0,
  total_earnings         numeric(14, 2) not null default 0,
  is_available           boolean not null default false,
  current_location       extensions.geography(point, 4326),
  location_updated_at    timestamptz,
  -- FK will be added in Phase 2 (targets public.vehicles).
  current_vehicle_id     uuid,
  -- FK will be added in Phase 2 (targets public.fleets).
  current_fleet_id       uuid,
  verified_at            timestamptz,
  verified_by            uuid references public.profiles (id) on delete set null,
  re_verification_due_at timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint drivers_rating_check check (rating between 0 and 5),
  constraint drivers_total_trips_check check (total_trips >= 0),
  constraint drivers_total_earnings_check check (total_earnings >= 0)
);

comment on table public.drivers is
  'Driver-specific state: verification, risk tier, reputation, live location and fleet/vehicle assignment.';

comment on column public.drivers.current_vehicle_id is
  'FK will be added in Phase 2 (references public.vehicles.id).';

comment on column public.drivers.current_fleet_id is
  'FK will be added in Phase 2 (references public.fleets.id).';

-- ----------------------------------------------------------------------------
-- public.driver_status_history
-- ----------------------------------------------------------------------------
create table public.driver_status_history (
  id            bigint generated always as identity primary key,
  driver_id     uuid not null references public.drivers (id) on delete cascade,
  field_changed text not null,
  old_value     text,
  new_value     text,
  changed_by    uuid references public.profiles (id) on delete set null,
  reason        text,
  created_at    timestamptz not null default now()
);

comment on table public.driver_status_history is
  'Append-only trail of driver trust/availability transitions (verification_status, risk_tier, is_available).';

-- Automatically record transitions of the fields that matter for trust and
-- dispatch. Runs as SECURITY DEFINER so it can write even though clients have
-- no INSERT policy on the history table.
create or replace function public.log_driver_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();
  if v_actor is not null
     and not exists (select 1 from public.profiles p where p.id = v_actor)
  then
    v_actor := null;
  end if;

  if new.verification_status is distinct from old.verification_status then
    insert into public.driver_status_history (driver_id, field_changed, old_value, new_value, changed_by)
    values (new.id, 'verification_status', old.verification_status::text, new.verification_status::text, v_actor);
  end if;

  if new.risk_tier is distinct from old.risk_tier then
    insert into public.driver_status_history (driver_id, field_changed, old_value, new_value, changed_by)
    values (new.id, 'risk_tier', old.risk_tier::text, new.risk_tier::text, v_actor);
  end if;

  if new.is_available is distinct from old.is_available then
    insert into public.driver_status_history (driver_id, field_changed, old_value, new_value, changed_by)
    values (new.id, 'is_available', old.is_available::text, new.is_available::text, v_actor);
  end if;

  return new;
end;
$$;

create trigger trg_drivers_status_history
  after update on public.drivers
  for each row execute function public.log_driver_status_change();

comment on function public.log_driver_status_change() is
  'Writes a driver_status_history row for each protected field transition on drivers.';

-- ----------------------------------------------------------------------------
-- public.driver_operating_zones
-- ----------------------------------------------------------------------------
create table public.driver_operating_zones (
  id              uuid primary key default gen_random_uuid(),
  driver_id       uuid not null references public.drivers (id) on delete cascade,
  service_zone_id uuid not null references public.service_zones (id) on delete cascade,
  is_primary      boolean not null default false,
  created_at      timestamptz not null default now(),

  constraint driver_operating_zones_driver_zone_key unique (driver_id, service_zone_id)
);

comment on table public.driver_operating_zones is
  'Zones a driver accepts jobs in. is_primary marks the home operating zone.';

-- Only one primary zone per driver.
create unique index if not exists driver_operating_zones_one_primary_idx
  on public.driver_operating_zones (driver_id)
  where is_primary;

-- ----------------------------------------------------------------------------
-- public.driver_service_hours
-- ----------------------------------------------------------------------------
create table public.driver_service_hours (
  id          uuid primary key default gen_random_uuid(),
  driver_id   uuid not null references public.drivers (id) on delete cascade,
  day_of_week smallint not null,
  start_time  time not null,
  end_time    time not null,
  timezone    text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),

  constraint driver_service_hours_driver_day_key unique (driver_id, day_of_week),
  constraint driver_service_hours_day_check check (day_of_week between 0 and 6),
  constraint driver_service_hours_window_check check (end_time > start_time)
);

comment on table public.driver_service_hours is
  'Declared availability windows per weekday (0 = Sunday). One window per weekday per driver.';
