-- Courier ordering fixes.
--
-- 1. One dispatch core. match_dispatch keeps its signature and authorisation,
--    and delegates to private.match_dispatch_core so server-side triggers
--    (a fully declined round) can start the next round without a caller role.
-- 2. A driver is offered one job at a time. Drivers holding a live offer for
--    another job are skipped, so they cannot accept two moves at once.
-- 3. Accept/decline take the job lock before the offer lock, the same order
--    as match_dispatch and job_cancel. Two drivers accepting the same job at
--    the same moment no longer deadlock; the loser gets a clear message.
-- 4. accept refuses a driver who is already on a move, and closes that
--    driver's other pending offers once the job is theirs.
-- 5. When every driver in a round declines, the next round starts at once
--    instead of waiting for the worker.
-- 6. job_request_dispatch is the customer app's entry point: the server
--    owns the escalating radius, the minimum gap between rounds and the
--    attempt cap, so the app cannot shrink the radius or burn attempts.

-- ----------------------------------------------------------------------------
-- Shared radius schedule (matches dispatch_tick)
-- ----------------------------------------------------------------------------
create or replace function private.dispatch_radius_km(p_attempts integer)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case coalesce(p_attempts, 0)
    when 0 then 5
    when 1 then 10
    when 2 then 15
    when 3 then 20
    else 25
  end::numeric;
$$;

revoke all on function private.dispatch_radius_km(integer) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1-2. Dispatch core (no authorisation; callers must authorise)
-- ----------------------------------------------------------------------------
create or replace function private.match_dispatch_core(
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
  v_job              public.jobs%rowtype;
  v_vehicle_type_id  uuid;
  v_pickup           extensions.geography;
  v_scheduled_at     timestamptz;
  v_driver           record;
  v_sequence         integer;
  v_offers           jsonb := '[]'::jsonb;
  v_offer_id         uuid;
  v_radius_m         numeric;
  v_timeout          integer := greatest(5, least(coalesce(p_timeout_seconds, 30), 300));
  v_limit            integer := greatest(1, least(coalesce(p_limit, 5), 20));
  v_verified         integer := 0;
  v_located          integer := 0;
  v_vehicled         integer := 0;
  v_typed            integer := 0;
  v_in_radius        integer := 0;
  v_busy             integer := 0;
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
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

  select qr.vehicle_type_id, qr.pickup_location, qr.scheduled_at
    into v_vehicle_type_id, v_pickup, v_scheduled_at
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  if v_pickup is null or v_vehicle_type_id is null then
    raise exception 'job % has no pickup or vehicle type', p_job_id
      using errcode = '23514';
  end if;

  -- Scheduled moves are not offered hours in advance. The dispatch worker
  -- starts the search 45 minutes before the requested time.
  if v_scheduled_at is not null
     and v_scheduled_at > now() + interval '45 minutes'
  then
    return jsonb_build_object(
      'job_id', p_job_id,
      'offers', '[]'::jsonb,
      'count', 0,
      'reason', 'job is scheduled for later',
      'scheduled_at', v_scheduled_at
    );
  end if;

  -- The customer app retries dispatch as a fallback for a missing pg_cron.
  -- A job that already has a live offer must never fan out to more drivers,
  -- and the retry must not consume a dispatch attempt.
  if exists (
    select 1 from public.job_offers o
    where o.job_id = p_job_id
      and o.response = 'pending'
      and o.expires_at > now()
  ) then
    return jsonb_build_object(
      'job_id', p_job_id,
      'offers', '[]'::jsonb,
      'count', 0,
      'reason', 'waiting for a driver to respond'
    );
  end if;

  if p_radius_km is null or p_radius_km <= 0 then
    raise exception 'radius_km must be > 0' using errcode = '22023';
  end if;
  v_radius_m := p_radius_km * 1000;

  -- Count the drivers surviving each filter, in the same order the selection
  -- below applies them. Used only to explain an empty result.
  select count(*) into v_verified
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
   where d.verification_status = 'verified'
     and d.is_available;

  select count(*) into v_located
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes';

  select count(*) into v_vehicled
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified';

  select count(*) into v_typed
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and v.vehicle_type_id = v_vehicle_type_id;

  select count(*) into v_busy
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and v.vehicle_type_id = v_vehicle_type_id
     and not exists (
       select 1 from public.jobs aj
       where aj.driver_id = d.id
         and aj.status between 'accepted' and 'delivered'
     )
     and not exists (
       select 1 from public.job_offers po
       where po.driver_id = d.id
         and po.job_id <> p_job_id
         and po.response = 'pending'
         and po.expires_at > now()
     );

  select count(*) into v_in_radius
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and v.vehicle_type_id = v_vehicle_type_id
     and not exists (
       select 1 from public.jobs aj
       where aj.driver_id = d.id
         and aj.status between 'accepted' and 'delivered'
     )
     and not exists (
       select 1 from public.job_offers po
       where po.driver_id = d.id
         and po.job_id <> p_job_id
         and po.response = 'pending'
         and po.expires_at > now()
     )
     and extensions.ST_DWithin(d.current_location, v_pickup, v_radius_m);

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
      and d.location_updated_at > now() - interval '10 minutes'
      and v.is_active
      and v.verification_status = 'verified'
      and v.vehicle_type_id = v_vehicle_type_id
      and not exists (
        select 1 from public.jobs aj
        where aj.driver_id = d.id
          and aj.status between 'accepted' and 'delivered'
      )
      and not exists (
        select 1 from public.job_offers po
        where po.driver_id = d.id
          and po.job_id <> p_job_id
          and po.response = 'pending'
          and po.expires_at > now()
      )
      and extensions.ST_DWithin(d.current_location, v_pickup, v_radius_m)
      and not exists (
        select 1 from public.job_offers o
        where o.job_id = p_job_id
          and o.driver_id = d.id
          and (
            o.response in ('pending', 'declined')
            or (o.response = 'expired' and o.responded_at > now() - interval '5 minutes')
          )
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

  update public.jobs
     set dispatch_attempts = dispatch_attempts + 1,
         last_dispatched_at = now()
   where id = p_job_id;

  return jsonb_build_object(
    'job_id', p_job_id,
    'offers', v_offers,
    'count', jsonb_array_length(v_offers),
    'reason', case
      when jsonb_array_length(v_offers) > 0 then null
      when v_verified = 0 then 'no verified drivers are available right now'
      when v_located = 0 then 'drivers are online but have not shared a recent location'
      when v_vehicled = 0 then 'drivers have no verified vehicle attached'
      when v_typed = 0 then 'no online driver has a vehicle of the requested class'
      when v_busy = 0 then 'every matching driver is already on a job'
      when v_in_radius = 0 then 'no matching driver is within the search radius'
      else 'no matching driver is free right now'
    end,
    'diagnostics', jsonb_build_object(
      'verified_and_available', v_verified,
      'with_fresh_location', v_located,
      'with_verified_vehicle', v_vehicled,
      'with_requested_vehicle_type', v_typed,
      'free_for_a_new_job', v_busy,
      'within_radius', v_in_radius,
      'attempts', v_job.dispatch_attempts + 1
    )
  );
end;
$$;
revoke all on function private.match_dispatch_core(uuid, numeric, integer, integer)
  from public, anon, authenticated;

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
  v_customer uuid;
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;

  select customer_id into v_customer from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or auth.uid() = v_customer
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to dispatch job %', p_job_id
      using errcode = '42501';
  end if;

  return private.match_dispatch_core(
    p_job_id, p_radius_km, p_limit, p_timeout_seconds
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. Customer-facing dispatch request
-- ----------------------------------------------------------------------------
create or replace function public.job_request_dispatch(p_job_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
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
    or auth.uid() = v_job.customer_id
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to dispatch job %', p_job_id
      using errcode = '42501';
  end if;

  if v_job.driver_id is null
     and v_job.status in ('requested', 'quoted', 'matched')
  then
    -- Rapid "try again" taps must not burn the search: a round already ran
    -- moments ago, so report that and let the current one play out.
    if v_job.last_dispatched_at is not null
       and v_job.last_dispatched_at > now() - interval '15 seconds'
       and not exists (
         select 1 from public.job_offers o
         where o.job_id = p_job_id
           and o.response = 'pending'
           and o.expires_at > now()
       )
    then
      return jsonb_build_object(
        'job_id', p_job_id,
        'offers', '[]'::jsonb,
        'count', 0,
        'reason', 'a search round just ran',
        'attempts', v_job.dispatch_attempts
      );
    end if;

    -- Same cap as dispatch_tick, so a missing pg_cron cannot leave a move
    -- searching forever. Nobody accepted it, so job_cancel waives any fee.
    if v_job.dispatch_attempts >= 6
       and not exists (
         select 1 from public.job_offers o
         where o.job_id = p_job_id
           and o.response = 'pending'
           and o.expires_at > now()
       )
    then
      perform public.job_cancel(
        p_job_id,
        v_job.customer_id,
        'No driver was available for this move'
      );
      return jsonb_build_object(
        'job_id', p_job_id,
        'offers', '[]'::jsonb,
        'count', 0,
        'reason', 'no driver was available for this move',
        'attempts', v_job.dispatch_attempts
      );
    end if;
  end if;

  return private.match_dispatch_core(
    p_job_id,
    private.dispatch_radius_km(v_job.dispatch_attempts),
    5,
    45
  );
end;
$$;

comment on function public.job_request_dispatch(uuid) is
  'Customer entry point for dispatch. The server chooses the escalating radius, rate-limits rounds and retires the job after six attempts.';

revoke all on function public.job_request_dispatch(uuid) from public, anon;
grant execute on function public.job_request_dispatch(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3-4. Accept: job lock first, clear outcomes, no double booking
-- ----------------------------------------------------------------------------
create or replace function public.accept_job_offer(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_job_id  uuid;
  v_offer   public.job_offers%rowtype;
  v_job     public.jobs%rowtype;
  v_vehicle uuid;
begin
  select job_id into v_job_id from public.job_offers where id = p_offer_id;
  if not found then
    raise exception 'offer % not found', p_offer_id using errcode = 'P0002';
  end if;

  -- Lock order: job, then offers (same as match_dispatch and job_cancel).
  select * into v_job from public.jobs where id = v_job_id for update;
  select * into v_offer from public.job_offers where id = p_offer_id for update;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_actor = v_offer.driver_id)
  ) then
    raise exception 'only the offered driver may accept offer %', p_offer_id
      using errcode = '42501';
  end if;

  if v_offer.response = 'auto_reassigned'
     or (v_job.driver_id is not null and v_job.driver_id <> v_offer.driver_id)
  then
    raise exception 'this job has already been taken by another driver'
      using errcode = '23514';
  end if;

  if v_job.status = 'cancelled' then
    raise exception 'the customer cancelled this job' using errcode = '23514';
  end if;

  if v_offer.response <> 'pending' then
    raise exception 'this offer is no longer available (%)', v_offer.response
      using errcode = '23514';
  end if;

  if v_offer.expires_at <= now() then
    raise exception 'this offer has expired' using errcode = '22023';
  end if;

  if v_job.status not in ('requested', 'quoted', 'matched') then
    raise exception 'this job is no longer available' using errcode = '23514';
  end if;

  if exists (
    select 1 from public.jobs aj
    where aj.driver_id = v_offer.driver_id
      and aj.id <> v_job.id
      and aj.status between 'accepted' and 'delivered'
  ) then
    raise exception 'you already have an active job; finish it before accepting another'
      using errcode = '23514';
  end if;

  update public.job_offers
     set response = 'accepted',
         responded_at = now()
   where id = p_offer_id;

  update public.job_offers
     set response = 'auto_reassigned',
         responded_at = now(),
         decline_reason = 'Auto-reassigned after another driver accepted'
   where job_id = v_job.id
     and id <> p_offer_id
     and response = 'pending';

  select current_vehicle_id into v_vehicle
  from public.drivers
  where id = v_offer.driver_id;

  perform public.job_assign_driver(v_job.id, v_offer.driver_id, v_vehicle);

  -- Offers for other jobs that slipped through before this fix (or a race)
  -- must not stay open for a driver who is now busy.
  update public.job_offers
     set response = 'auto_reassigned',
         responded_at = now(),
         decline_reason = 'Driver accepted another job'
   where driver_id = v_offer.driver_id
     and job_id <> v_job.id
     and response = 'pending';
end;
$$;

-- ----------------------------------------------------------------------------
-- 3, 5. Decline: job lock first; a fully declined round re-dispatches at once
-- ----------------------------------------------------------------------------
create or replace function public.decline_job_offer(
  p_offer_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor  uuid := auth.uid();
  v_job_id uuid;
  v_offer  public.job_offers%rowtype;
  v_job    public.jobs%rowtype;
begin
  select job_id into v_job_id from public.job_offers where id = p_offer_id;
  if not found then
    raise exception 'offer % not found', p_offer_id using errcode = 'P0002';
  end if;

  select * into v_job from public.jobs where id = v_job_id for update;
  select * into v_offer from public.job_offers where id = p_offer_id for update;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_actor = v_offer.driver_id)
  ) then
    raise exception 'only the offered driver may decline offer %', p_offer_id
      using errcode = '42501';
  end if;

  -- Declining something already gone is a no-op for the driver.
  if v_offer.response <> 'pending' or v_offer.expires_at <= now() then
    return;
  end if;

  update public.job_offers
     set response = 'declined',
         responded_at = now(),
         decline_reason = coalesce(nullif(btrim(p_reason), ''), 'Declined by driver')
   where id = p_offer_id;

  if v_job.driver_id is null
     and v_job.status in ('requested', 'quoted', 'matched')
     and v_job.dispatch_attempts < 6
     and not exists (
       select 1 from public.job_offers o
       where o.job_id = v_job.id
         and o.response = 'pending'
         and o.expires_at > now()
     )
  then
    begin
      perform private.match_dispatch_core(
        v_job.id,
        private.dispatch_radius_km(v_job.dispatch_attempts),
        5,
        45
      );
    exception when others then
      -- The decline itself must always succeed; the worker retries.
      null;
    end;
  end if;
end;
$$;
