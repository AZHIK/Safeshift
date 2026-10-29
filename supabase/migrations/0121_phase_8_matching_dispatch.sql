-- ============================================================================
-- SafeShift — Phase 8 / Migration 0121
-- Dispatch fan-out for the customer app + realtime offer publication.
--
-- match_dispatch() is the single call the customer app makes after creating a
-- job. It selects eligible nearby drivers (verified driver + verified vehicle
-- matching the quoted vehicle type), creates time-bounded job_offers, and
-- returns the created offers. The existing offer/accept/decline helpers remain
-- the only way a driver responds.
-- ============================================================================

create or replace function public.match_dispatch(
  p_job_id uuid,
  p_radius_km numeric default 10,
  p_limit integer default 5,
  p_timeout_seconds integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor            uuid := auth.uid();
  v_job              public.jobs%rowtype;
  v_vehicle_type_id  uuid;
  v_pickup           extensions.geography;
  v_driver           record;
  v_sequence         integer;
  v_offers           jsonb := '[]'::jsonb;
  v_offer_id         uuid;
  v_radius_m         numeric;
  v_timeout          integer := greatest(5, least(coalesce(p_timeout_seconds, 30), 300));
  v_limit            integer := greatest(1, least(coalesce(p_limit, 5), 20));
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or v_actor = v_job.customer_id
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to dispatch job %', p_job_id
      using errcode = '42501';
  end if;

  if v_job.driver_id is not null
     or v_job.status not in ('requested', 'quoted', 'matched')
  then
    return jsonb_build_object(
      'job_id', p_job_id,
      'offers', '[]'::jsonb,
      'count', 0,
      'reason', 'job is no longer dispatchable'
    );
  end if;

  select qr.vehicle_type_id, qr.pickup_location
    into v_vehicle_type_id, v_pickup
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  if v_pickup is null or v_vehicle_type_id is null then
    raise exception 'job % has no pickup or vehicle type', p_job_id
      using errcode = '23514';
  end if;

  if p_radius_km is null or p_radius_km <= 0 then
    raise exception 'radius_km must be > 0' using errcode = '22023';
  end if;
  v_radius_m := p_radius_km * 1000;

  for v_driver in
    select
      d.id,
      round((extensions.ST_Distance(d.current_location, v_pickup) / 1000.0)::numeric, 2) as distance_km,
      greatest(
        1,
        ceil(
          extensions.ST_Distance(d.current_location, v_pickup) / 1000.0 / 20.0 * 60.0
        )::integer
      ) as eta_minutes
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
    where d.verification_status = 'verified'
      and d.is_available
      and d.current_location is not null
      and v.is_active
      and v.verification_status = 'verified'
      and v.vehicle_type_id = v_vehicle_type_id
      and extensions.ST_DWithin(d.current_location, v_pickup, v_radius_m)
      and not exists (
        select 1 from public.job_offers o
        where o.job_id = p_job_id
          and o.driver_id = d.id
          and o.response = 'pending'
          and o.expires_at > now()
      )
    order by
      extensions.ST_Distance(d.current_location, v_pickup),
      d.rating desc,
      d.id
    limit v_limit
  loop
    select coalesce(max(o.offer_sequence), 0) + 1
      into v_sequence
    from public.job_offers o
    where o.job_id = p_job_id;

    insert into public.job_offers (
      job_id, driver_id, offer_sequence, offered_at, expires_at,
      distance_to_pickup_km, eta_minutes, payout_estimate, currency_code
    ) values (
      p_job_id, v_driver.id, v_sequence, clock_timestamp(),
      clock_timestamp() + make_interval(secs => v_timeout),
      v_driver.distance_km, v_driver.eta_minutes, null,
      v_job.final_currency_code
    )
    returning id into v_offer_id;

    v_offers := v_offers || jsonb_build_object(
      'offer_id', v_offer_id,
      'driver_id', v_driver.id,
      'distance_km', v_driver.distance_km,
      'eta_minutes', v_driver.eta_minutes,
      'expires_at', clock_timestamp() + make_interval(secs => v_timeout)
    );
  end loop;

  return jsonb_build_object(
    'job_id', p_job_id,
    'offers', v_offers,
    'count', jsonb_array_length(v_offers)
  );
end;
$$;

comment on function public.match_dispatch(uuid, numeric, integer, integer) is
  'Phase 8 dispatch entry point. Selects eligible nearby verified drivers and creates time-bounded offers for a customer-owned job.';

revoke all on function public.match_dispatch(uuid, numeric, integer, integer) from public;
revoke all on function public.match_dispatch(uuid, numeric, integer, integer) from anon;
grant execute on function public.match_dispatch(uuid, numeric, integer, integer) to authenticated, service_role;

-- Realtime: drivers need new/updated offers pushed without polling.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'job_offers'
  ) then
    alter publication supabase_realtime add table public.job_offers;
  end if;
end $$;

comment on publication supabase_realtime is
  'Phase 6 publication extended in Phase 8 with job_offers for driver push/realtime.';
