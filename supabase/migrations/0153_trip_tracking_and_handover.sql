-- A driver with a pending offer cannot yet read the jobs row through RLS.
-- Reuse the authenticated offer inbox to authorize only its booked parcel photos.
create policy live_offer_parcel_photos on storage.objects for select to authenticated
using (bucket_id = 'job-evidence' and exists (
  select 1 from public.driver_pending_offers() o
  where o.job_id::text = (storage.foldername(name))[1] and name = any(o.cargo_photo_paths)
));

-- Keep busy drivers excluded at both new milestones.

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

-- Only reveal live GPS while this driver is handling this move.

create or replace function public.customer_job(p_job_id uuid)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_lat double precision,
  destination_lng double precision,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  scheduled_at timestamptz,
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  cancellation_fee numeric,
  dispatch_attempts smallint,
  last_dispatched_at timestamptz,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  driver_verified boolean,
  driver_lat double precision,
  driver_lng double precision,
  driver_location_updated_at timestamptz,
  driver_location_fresh boolean,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  cargo_weight_kg numeric,
  declared_value_tzs numeric,
  cargo_photo_paths text[],
  payment_method public.payment_method
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    j.id,
    j.status,
    qr.pickup_address,
    qr.destination_address,
    extensions.ST_Y(qr.pickup_location::extensions.geometry),
    extensions.ST_X(qr.pickup_location::extensions.geometry),
    extensions.ST_Y(qr.destination_location::extensions.geometry),
    extensions.ST_X(qr.destination_location::extensions.geometry),
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.scheduled_at,
    j.accepted_at,
    j.completed_at,
    j.cancelled_at,
    jc.reason,
    j.cancellation_fee,
    j.dispatch_attempts,
    j.last_dispatched_at,
    j.driver_id,
    coalesce(dp.full_name, dp.display_name),
    dp.phone,
    d.rating,
    d.verification_status = 'verified',
    case when j.status not between 'accepted' and 'arrived_destination' or d.current_location is null then null
         else extensions.ST_Y(d.current_location::extensions.geometry) end,
    case when j.status not between 'accepted' and 'arrived_destination' or d.current_location is null then null
         else extensions.ST_X(d.current_location::extensions.geometry) end,
    case when j.status between 'accepted' and 'arrived_destination' then d.location_updated_at end,
    j.status between 'accepted' and 'arrived_destination' and d.location_updated_at > now() - interval '5 minutes',
    vt.name,
    vt.id,
    vt.icon_url,
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    qr.cargo_weight_kg,
    qr.declared_value_tzs,
    qr.cargo_photo_paths,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  left join lateral (
    select c.reason
    from public.job_cancellations c
    where c.job_id = j.id
    order by c.created_at desc
    limit 1
  ) jc on true
  where j.id = p_job_id
    and (
      j.customer_id = auth.uid()
      or j.driver_id = auth.uid()
      or public.has_permission('view_all_jobs')
    );
$$;

create or replace function public.job_issue_delivery_otp(p_job_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_code  text;
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or (v_actor is not null and v_actor = v_job.customer_id)) then
    raise exception 'only the job customer may issue a delivery code'
      using errcode = '42501';
  end if;

  if v_job.status not in ('accepted', 'heading_to_pickup', 'arrived', 'cargo_verified', 'loading', 'in_transit', 'arrived_destination') then
    raise exception 'job % cannot issue a delivery code in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');

  insert into public.job_delivery_codes (
    job_id, code_hash, issued_by, issued_at, expires_at, attempts, verified_at
  ) values (
    p_job_id,
    extensions.crypt(v_code, extensions.gen_salt('bf')),
    v_actor,
    now(),
    now() + interval '24 hours',
    0,
    null
  )
  on conflict (job_id) do update
    set code_hash = excluded.code_hash,
        issued_by = excluded.issued_by,
        issued_at = excluded.issued_at,
        expires_at = excluded.expires_at,
        attempts = 0,
        verified_at = null;

  return v_code;
end;
$$;

create or replace function public.job_advance_status(
  p_job_id uuid,
  p_new_status public.job_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor     uuid := auth.uid();
  v_job       public.jobs%rowtype;
  v_allowed   public.job_status[];
  v_event     text;
  v_start     timestamptz;
  v_actual    integer;
begin
  if p_job_id is null or p_new_status is null then
    raise exception 'job and new status are required' using errcode = '22004';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_job.driver_id is not null and v_actor = v_job.driver_id)
    or (v_actor is not null and v_actor = v_job.customer_id and p_new_status = 'delivered'
        and v_job.status = 'arrived_destination')
  ) then
    raise exception 'only the assigned driver or an operations admin may advance job %', p_job_id
      using errcode = '42501';
  end if;

  if p_new_status = 'delivered' and v_actor = v_job.driver_id
     and v_actor is distinct from v_job.customer_id
     and not private.is_service_context()
     and not public.has_permission('assign_drivers')
     and not exists (select 1 from public.job_delivery_codes where job_id = p_job_id and verified_at is not null)
  then
    raise exception 'verify the delivery code first' using errcode = '23514';
  end if;

  if p_new_status = v_job.status then
    raise exception 'job % is already in status %', p_job_id, p_new_status
      using errcode = '23514';
  end if;

  if p_new_status = 'cancelled' then
    perform public.job_cancel(
      p_job_id,
      coalesce(v_actor, v_job.customer_id),
      coalesce(p_reason, 'Cancelled via status transition')
    );
    return;
  end if;

  v_allowed := case v_job.status
    when 'requested'         then array['matched']::public.job_status[]
    when 'quoted'            then array['matched']::public.job_status[]
    when 'matched'           then array['accepted']::public.job_status[]
    when 'accepted'          then array['heading_to_pickup']::public.job_status[]
    when 'heading_to_pickup' then array['arrived']::public.job_status[]
    when 'arrived'           then array['cargo_verified']::public.job_status[]
    when 'cargo_verified'    then array['loading']::public.job_status[]
    when 'loading'           then array['in_transit']::public.job_status[]
    when 'in_transit'        then array['arrived_destination', 'disputed']::public.job_status[]
    when 'arrived_destination' then array['delivered', 'disputed']::public.job_status[]
    when 'delivered'         then array['completed', 'disputed']::public.job_status[]
    when 'completed'         then array['disputed']::public.job_status[]
    else array[]::public.job_status[]
  end;

  if not (p_new_status = any(v_allowed)) then
    raise exception 'illegal job transition: % -> %', v_job.status, p_new_status
      using errcode = '23514';
  end if;

  if p_new_status = 'accepted' and v_job.driver_id is null then
    raise exception 'job % has no driver; use job_assign_driver()', p_job_id
      using errcode = '23514';
  end if;

  v_start := coalesce(v_job.started_at, now());
  v_actual := greatest(
    0,
    round(extract(epoch from (now() - v_start)) / 60.0)::integer
  );

  update public.jobs
     set status = p_new_status,
         started_at = case
           when p_new_status in ('heading_to_pickup', 'in_transit')
             then coalesce(started_at, now())
           else started_at
         end,
         completed_at = case
           when p_new_status = 'completed' then now()
           else completed_at
         end,
         actual_duration_min = case
           when p_new_status = 'completed' then v_actual
           else actual_duration_min
         end
   where id = p_job_id;

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, v_job.status, p_new_status, v_actor, p_reason
  );

  v_event := case p_new_status
    when 'matched'      then 'note'
    when 'accepted'     then 'driver_assigned'
    when 'arrived'      then 'driver_arrived'
    when 'cargo_verified' then 'cargo_verified'
    when 'loading'      then 'pickup_completed'
    when 'in_transit'   then 'in_transit'
    when 'arrived_destination' then 'arrived_destination'
    when 'delivered'    then 'delivered'
    when 'completed'    then 'completed'
    when 'disputed'     then 'note'
    else 'note'
  end;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id,
    v_event,
    v_actor,
    jsonb_build_object(
      'from_status', v_job.status,
      'to_status', p_new_status,
      'reason', p_reason,
      'actual_duration_min', case when p_new_status = 'completed' then v_actual else null end
    )
  );
end;
$$;

create or replace function public.job_confirm_delivery(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job public.jobs%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;
  if v_job.customer_id <> auth.uid() then
    raise exception 'only the customer may confirm delivery' using errcode = '42501';
  end if;

  if v_job.status = 'arrived_destination' then
    perform public.job_advance_status(
      p_job_id,
      'delivered',
      'Confirmed by customer'
    );
  elsif v_job.status not in ('delivered', 'completed') then
    raise exception 'job % is not ready for delivery confirmation', p_job_id
      using errcode = '23514';
  end if;
end;
$$;

create or replace function public.job_verify_delivery_otp(
  p_job_id uuid,
  p_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_code  public.job_delivery_codes%rowtype;
begin
  if p_code is null or p_code !~ '^[0-9]{6}$' then
    return false;
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or (v_actor is not null and v_actor = v_job.driver_id)) then
    raise exception 'only the assigned driver may verify the delivery code'
      using errcode = '42501';
  end if;

  if v_job.status in ('delivered', 'completed') then
    return true;
  end if;
  if v_job.status <> 'arrived_destination' then
    raise exception 'mark arrival at the destination before confirming delivery' using errcode = '23514';
  end if;

  select * into v_code
  from public.job_delivery_codes
  where job_id = p_job_id
  for update;

  if not found then
    raise exception 'no delivery code has been issued for this job'
      using errcode = 'P0002';
  end if;
  if v_code.expires_at <= now() then
    raise exception 'the delivery code has expired' using errcode = '22023';
  end if;
  if v_code.attempts >= 5 then
    raise exception 'too many delivery code attempts' using errcode = '22023';
  end if;

  if extensions.crypt(p_code, v_code.code_hash) = v_code.code_hash then
    update public.job_delivery_codes
       set verified_at = now()
     where job_id = p_job_id;

    perform public.job_advance_status(
      p_job_id,
      'delivered'::public.job_status,
      'Delivery OTP verified'
    );
    return true;
  end if;

  update public.job_delivery_codes
     set attempts = attempts + 1
   where job_id = p_job_id;
  return false;
end;
$$;
