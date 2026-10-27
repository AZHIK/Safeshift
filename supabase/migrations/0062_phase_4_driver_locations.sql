-- ============================================================================
-- SafeShift — Phase 4 / Migration 0062
-- Driver GPS time series, partitioned monthly.
--
-- The current location also remains denormalised on public.drivers for cheap
-- dispatch joins. A trigger in migration 0071 keeps that column fresh.
--
-- Retention: 90 days. The pg_cron expression is documented below but not
-- scheduled by the migration; scheduler ownership belongs to Phase 5/6 ops.
-- ============================================================================

create table public.driver_locations (
  id              bigint generated always as identity,
  driver_id       uuid not null references public.drivers (id) on delete cascade,
  job_id          uuid references public.jobs (id) on delete set null,
  location        geography(point, 4326) not null,
  heading_degrees smallint,
  speed_kmh       numeric(5,2),
  accuracy_m      numeric(6,2),
  recorded_at     timestamptz not null default now(),
  created_at      timestamptz not null default now(),

  primary key (id, recorded_at),
  constraint driver_locations_heading_check
    check (heading_degrees is null or heading_degrees between 0 and 359),
  constraint driver_locations_speed_check
    check (speed_kmh is null or speed_kmh >= 0),
  constraint driver_locations_accuracy_check
    check (accuracy_m is null or accuracy_m >= 0)
) partition by range (recorded_at);

comment on table public.driver_locations is
  'High-volume driver location pings, partitioned monthly. Keep 90 days; e.g. cron.schedule(''purge-driver-locations'', ''0 3 * * *'', $$delete from public.driver_locations where recorded_at < now() - interval ''''90 days''''$$).';

comment on column public.driver_locations.job_id is
  'Set while the ping belongs to an active job; retained after job completion for reconciliation.';

create table if not exists public.driver_locations_default
  partition of public.driver_locations default;

create or replace function private.ensure_driver_location_partitions(p_months_ahead integer default 6)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base  date := date_trunc('month', now())::date;
  v_i     integer;
  v_name  text;
  v_count integer := 0;
begin
  if p_months_ahead is null or p_months_ahead < 1 then
    raise exception 'p_months_ahead must be >= 1';
  end if;

  for v_i in 0..(p_months_ahead - 1) loop
    v_name := 'driver_locations_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.driver_locations for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

comment on function private.ensure_driver_location_partitions(integer) is
  'Creates missing monthly driver_locations partitions up to p_months_ahead months from the current month. Pair with a 90-day retention job.';

revoke all on function private.ensure_driver_location_partitions(integer) from public;
revoke all on function private.ensure_driver_location_partitions(integer) from anon;
revoke all on function private.ensure_driver_location_partitions(integer) from authenticated;
grant execute on function private.ensure_driver_location_partitions(integer) to service_role;

do $$
declare
  v_base date := date_trunc('month', now())::date;
  v_i    integer;
  v_name text;
begin
  for v_i in 0..5 loop
    v_name := 'driver_locations_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.driver_locations for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
    end if;
  end loop;
end $$;
