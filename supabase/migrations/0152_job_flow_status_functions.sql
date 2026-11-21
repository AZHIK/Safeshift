-- State machine, notifications and driver-facing job reads for the extended
-- courier flow (cargo verification and arrival at destination).

-- ----------------------------------------------------------------------------
-- 1. Legal transitions and lifecycle events
-- ----------------------------------------------------------------------------
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
  ) then
    raise exception 'only the assigned driver or an operations admin may advance job %', p_job_id
      using errcode = '42501';
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

comment on function public.job_advance_status(uuid, public.job_status, text) is
  'Enforces the legal job state machine, writes append-only history/events, and records completion duration. Cancellation delegates to job_cancel().';

revoke all on function public.job_advance_status(uuid, public.job_status, text) from public, anon;
grant execute on function public.job_advance_status(uuid, public.job_status, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Customer delivery confirmation
-- ----------------------------------------------------------------------------
-- The customer confirms the goods have arrived. The driver can also reach
-- 'delivered' by verifying the delivery OTP; both paths are idempotent.
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

  if v_job.status in ('in_transit', 'arrived_destination') then
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

comment on function public.job_confirm_delivery(uuid) is
  'Customer-side confirmation that the goods arrived; moves an in-transit job to delivered.';

revoke all on function public.job_confirm_delivery(uuid) from public, anon;
grant execute on function public.job_confirm_delivery(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2b. Driver OTP verification also works from arrived_destination
-- ----------------------------------------------------------------------------
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

  if not (private.is_service_context() or v_actor = v_job.driver_id) then
    raise exception 'only the assigned driver may verify the delivery code'
      using errcode = '42501';
  end if;

  select * into v_code
  from public.job_delivery_codes
  where job_id = p_job_id
  for update;

  if not found then
    raise exception 'no delivery code has been issued for this job'
      using errcode = 'P0002';
  end if;
  if v_code.verified_at is not null then
    return true;
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

    if v_job.status in ('in_transit', 'arrived_destination') then
      perform public.job_advance_status(
        p_job_id,
        'delivered'::public.job_status,
        'Delivery OTP verified'
      );
    end if;
    return true;
  end if;

  update public.job_delivery_codes
     set attempts = attempts + 1
   where job_id = p_job_id;
  return false;
end;
$$;

revoke all on function public.job_verify_delivery_otp(uuid, text) from public, anon;
grant execute on function public.job_verify_delivery_otp(uuid, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Push notifications for the two new steps
-- ----------------------------------------------------------------------------
create or replace function private.notify_job_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_name text;
  v_title       text;
  v_body        text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status
     and new.driver_id is not distinct from old.driver_id
  then
    return new;
  end if;

  select coalesce(p.full_name, p.display_name)
    into v_driver_name
  from public.profiles p
  where p.id = new.driver_id;

  if new.driver_id is not null
     and (tg_op = 'INSERT' or new.driver_id is distinct from old.driver_id)
  then
    perform private.invoke_push_send(
      new.customer_id,
      'Driver on the way',
      format(
        '%s accepted your move and is heading to the pickup point.',
        coalesce(v_driver_name, 'Your driver')
      ),
      jsonb_build_object('type', 'job_status', 'job_id', new.id::text, 'status', new.status::text),
      'safeshift://tracking/' || new.id::text
    );
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    v_title := null;
    v_body := null;

    case new.status
      when 'heading_to_pickup' then
        v_title := 'Driver on the way';
        v_body := format('%s is heading to the pickup point.', coalesce(v_driver_name, 'Your driver'));
      when 'arrived' then
        v_title := 'Driver has arrived';
        v_body := 'Your driver is at the pickup point.';
      when 'cargo_verified' then
        v_title := 'Cargo verified';
        v_body := 'Your driver has checked the cargo against the booking.';
      when 'loading' then
        v_title := 'Loading started';
        v_body := 'Your goods are being loaded.';
      when 'in_transit' then
        v_title := 'Your move is on the way';
        v_body := 'Your goods are on the road now.';
      when 'arrived_destination' then
        v_title := 'Driver has arrived';
        v_body := 'Your driver is at the destination.';
      when 'delivered' then
        v_title := 'Delivered';
        v_body := 'Your goods have arrived. Please confirm and complete payment.';
      when 'completed' then
        v_title := 'Move complete';
        v_body := 'Thanks for using SafeShift.';
      when 'cancelled' then
        v_title := 'Move cancelled';
        v_body := 'This move was cancelled.';
      else
        v_title := null;
    end case;

    if v_title is not null then
      perform private.invoke_push_send(
        new.customer_id,
        v_title,
        v_body,
        jsonb_build_object('type', 'job_status', 'job_id', new.id::text, 'status', new.status::text),
        'safeshift://tracking/' || new.id::text
      );
    end if;

    if new.status = 'cancelled' and new.driver_id is not null then
      perform private.invoke_push_send(
        new.driver_id,
        'Move cancelled',
        'The customer cancelled this move. You are free for new requests.',
        jsonb_build_object('type', 'job_status', 'job_id', new.id::text, 'status', new.status::text),
        'safeshift://home'
      );
    end if;
  end if;

  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- 4. Driver job reads: include the geography the map needs
-- ----------------------------------------------------------------------------
drop function if exists public.driver_pending_offers();
create function public.driver_pending_offers()
returns table (
  offer_id uuid,
  job_id uuid,
  offered_at timestamptz,
  expires_at timestamptz,
  offer_ttl_seconds integer,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_lat double precision,
  destination_lng double precision,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  scheduled_at timestamptz,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  cargo_weight_kg numeric,
  declared_value_tzs numeric,
  cargo_photo_paths text[],
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  customer_name text,
  customer_phone text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.id,
    o.job_id,
    o.offered_at,
    o.expires_at,
    greatest(0, floor(extract(epoch from (o.expires_at - now())))::integer),
    o.distance_to_pickup_km,
    o.eta_minutes,
    qr.pickup_address,
    qr.destination_address,
    extensions.ST_Y(qr.pickup_location::extensions.geometry),
    extensions.ST_X(qr.pickup_location::extensions.geometry),
    extensions.ST_Y(qr.destination_location::extensions.geometry),
    extensions.ST_X(qr.destination_location::extensions.geometry),
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    qr.scheduled_at,
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    qr.cargo_weight_kg,
    qr.declared_value_tzs,
    qr.cargo_photo_paths,
    vt.name,
    vt.id,
    vt.icon_url,
    coalesce(cp.full_name, cp.display_name),
    cp.phone
  from public.job_offers o
  join public.jobs j on j.id = o.job_id
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where o.driver_id = auth.uid()
    and o.response = 'pending'
    and o.expires_at > now()
    and j.status in ('requested', 'quoted', 'matched')
  order by o.offered_at;
$$;

revoke all on function public.driver_pending_offers() from public, anon;
grant execute on function public.driver_pending_offers() to authenticated, service_role;

drop function if exists public.driver_active_job();
create function public.driver_active_job()
returns table (
  offer_id uuid,
  job_id uuid,
  status public.job_status,
  expires_at timestamptz,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_lat double precision,
  destination_lng double precision,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  scheduled_at timestamptz,
  accepted_at timestamptz,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  cargo_weight_kg numeric,
  declared_value_tzs numeric,
  cargo_photo_paths text[],
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  customer_name text,
  customer_phone text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    null::uuid,
    j.id,
    j.status,
    null::timestamptz,
    null::numeric,
    null::integer,
    qr.pickup_address,
    qr.destination_address,
    extensions.ST_Y(qr.pickup_location::extensions.geometry),
    extensions.ST_X(qr.pickup_location::extensions.geometry),
    extensions.ST_Y(qr.destination_location::extensions.geometry),
    extensions.ST_X(qr.destination_location::extensions.geometry),
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    qr.scheduled_at,
    j.accepted_at,
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    qr.cargo_weight_kg,
    qr.declared_value_tzs,
    qr.cargo_photo_paths,
    vt.name,
    vt.id,
    vt.icon_url,
    coalesce(cp.full_name, cp.display_name),
    cp.phone
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.driver_id = auth.uid()
    and j.status in (
      'accepted', 'heading_to_pickup', 'arrived', 'cargo_verified', 'loading',
      'in_transit', 'arrived_destination', 'delivered'
    )
  order by j.accepted_at desc nulls last
  limit 1;
$$;

revoke all on function public.driver_active_job() from public, anon;
grant execute on function public.driver_active_job() to authenticated, service_role;
