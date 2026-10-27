-- ============================================================================
-- SafeShift — Phase 4 / Migration 0074
-- Operational helper functions: assignment, status transitions, cancellation,
-- matching, offers and rating aggregation.
--
-- All helpers are SECURITY DEFINER with an empty search_path. Each validates
-- the caller and writes the immutable history/events records that clients
-- cannot write directly.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Driver assignment
-- ----------------------------------------------------------------------------
create or replace function public.job_assign_driver(
  p_job_id uuid,
  p_driver_id uuid,
  p_vehicle_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor        uuid := auth.uid();
  v_job          public.jobs%rowtype;
  v_driver       public.drivers%rowtype;
  v_vehicle      public.vehicles%rowtype;
  v_vehicle_id   uuid;
  v_old_status   public.job_status;
  v_vehicle_type uuid;
  v_actor_for_log uuid;
begin
  if p_job_id is null or p_driver_id is null then
    raise exception 'job and driver are required' using errcode = '22004';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_actor = p_driver_id)
  ) then
    raise exception 'not authorised to assign this job' using errcode = '42501';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_job.status not in ('requested', 'quoted', 'matched') then
    raise exception 'job % is not assignable in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  select d.* into v_driver
  from public.drivers d
  join public.profiles p on p.id = d.id
  where d.id = p_driver_id
    and p.is_active
    and d.verification_status = 'verified';

  if not found then
    raise exception 'driver % is not active and verified', p_driver_id
      using errcode = 'P0002';
  end if;

  select qr.vehicle_type_id into v_vehicle_type
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  v_vehicle_id := coalesce(p_vehicle_id, v_driver.current_vehicle_id);

  if v_vehicle_id is null then
    raise exception 'driver % has no vehicle', p_driver_id using errcode = '23514';
  end if;

  select * into v_vehicle
  from public.vehicles
  where id = v_vehicle_id;

  if not found then
    raise exception 'vehicle % not found', v_vehicle_id using errcode = 'P0002';
  end if;

  if not v_vehicle.is_active or v_vehicle.verification_status <> 'verified' then
    raise exception 'vehicle % is not active and verified', v_vehicle_id
      using errcode = '23514';
  end if;

  if v_vehicle.vehicle_type_id <> v_vehicle_type then
    raise exception 'vehicle % does not match the quoted vehicle type', v_vehicle_id
      using errcode = '23514';
  end if;

  if v_vehicle.primary_driver_id is distinct from p_driver_id
     and not exists (
       select 1 from public.vehicle_assignments va
       where va.vehicle_id = v_vehicle.id
         and va.driver_id = p_driver_id
         and va.is_active
         and va.unassigned_at is null
     )
  then
    raise exception 'vehicle % is not assigned to driver %', v_vehicle_id, p_driver_id
      using errcode = '23514';
  end if;

  v_old_status := v_job.status;
  v_actor_for_log := coalesce(v_actor, p_driver_id);

  update public.jobs
     set driver_id = p_driver_id,
         vehicle_id = v_vehicle_id,
         status = 'accepted',
         accepted_at = coalesce(accepted_at, now())
   where id = p_job_id;

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, v_old_status, 'accepted', v_actor_for_log, 'Driver assigned to job'
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id,
    'driver_assigned',
    v_actor_for_log,
    jsonb_build_object(
      'driver_id', p_driver_id,
      'vehicle_id', v_vehicle_id,
      'from_status', v_old_status,
      'to_status', 'accepted'
    )
  );

  perform private.refresh_driver_acceptance_stats(p_driver_id);
end;
$$;

comment on function public.job_assign_driver(uuid, uuid, uuid) is
  'Assigns a verified driver/vehicle to a requested/matched job, moves it to accepted, and writes immutable history/events. Admins with assign_drivers or the driver themselves may call it.';

revoke all on function public.job_assign_driver(uuid, uuid, uuid) from public;
revoke all on function public.job_assign_driver(uuid, uuid, uuid) from anon;
grant execute on function public.job_assign_driver(uuid, uuid, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Cancellation
-- ----------------------------------------------------------------------------
create or replace function public.job_cancel(
  p_job_id uuid,
  p_cancelled_by uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor          uuid := auth.uid();
  v_job            public.jobs%rowtype;
  v_quote          public.quotes%rowtype;
  v_policy         public.cancellation_policies%rowtype;
  v_policy_found   boolean := false;
  v_policy_name    text;
  v_role           public.user_role;
  v_country_id     uuid;
  v_minutes_before integer;
  v_fee            numeric(14,2) := 0;
  v_refund         numeric(14,2) := 0;
  v_currency       char(3);
  v_refund_status  text;
  v_tier           record;
begin
  if p_job_id is null or p_cancelled_by is null then
    raise exception 'job and cancelling profile are required' using errcode = '22004';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a cancellation reason is required' using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or (v_actor is not null and p_cancelled_by = v_actor)
    or public.has_permission('assign_drivers')
  ) then
    raise exception 'not authorised to cancel this job' using errcode = '42501';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_job.status in ('completed', 'cancelled', 'disputed') then
    raise exception 'job % cannot be cancelled in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  if p_cancelled_by = v_job.customer_id then
    v_role := 'customer';
  elsif p_cancelled_by = v_job.driver_id then
    v_role := 'driver';
  elsif private.is_service_context() or public.has_permission('assign_drivers') then
    v_role := 'admin';
  else
    raise exception 'profile % is not a party to job %', p_cancelled_by, p_job_id
      using errcode = '42501';
  end if;

  select * into v_quote
  from public.quotes
  where id = v_job.quote_id;

  select c.country_id into v_country_id
  from public.cities c
  where c.id = v_job.city_id;

  v_minutes_before := floor(
    extract(epoch from (coalesce(v_job.scheduled_at, now()) - now())) / 60.0
  )::integer;

  if v_role in ('customer', 'driver') then
    select * into v_policy
    from public.cancellation_policies cp
    where cp.country_id = v_country_id
      and cp.applies_to_role = v_role
      and cp.is_active
    order by cp.created_at desc, cp.id
    limit 1;

    v_policy_found := found;
  end if;

  if v_policy_found then
    v_policy_name := v_policy.name;

    if v_minutes_before < v_policy.free_cancellation_window_minutes then
      if v_policy.fee_type = 'flat' then
        v_fee := v_policy.fee_value;
      elsif v_policy.fee_type = 'percentage_of_quote' then
        v_fee := round(
          coalesce(v_job.final_amount, v_quote.total, 0) * v_policy.fee_value / 100.0,
          2
        );
      elsif v_policy.fee_type = 'tiered' then
        select (tier ->> 'fee')::numeric into v_fee
        from jsonb_array_elements(v_policy.fee_tiers) tier
        where (tier ->> 'minutes_before_pickup')::numeric <= v_minutes_before
        order by (tier ->> 'minutes_before_pickup')::numeric desc
        limit 1;

        if not found then
          v_fee := 0;
        end if;
      end if;
    end if;
  end if;

  v_fee := round(
    least(
      greatest(coalesce(v_fee, 0), 0),
      coalesce(v_job.final_amount, v_quote.total, 0)
    ),
    2
  );

  v_currency := coalesce(v_job.final_currency_code, v_quote.currency_code);

  if v_job.payment_status in ('paid', 'partially_refunded') then
    v_refund := round(
      greatest(coalesce(v_job.final_amount, v_quote.total, 0) - v_fee, 0),
      2
    );
    v_refund_status := 'pending';
  else
    v_refund := 0;
    v_refund_status := 'not_applicable';
  end if;

  update public.jobs
     set status = 'cancelled',
         cancelled_at = now(),
         cancellation_policy_applied = v_policy_name,
         cancellation_fee = v_fee
   where id = p_job_id;

  insert into public.job_cancellations (
    job_id, cancelled_by, canceller_role, reason, cancellation_policy_id,
    fee_applied, refund_amount, currency_code, refund_status, notes
  ) values (
    p_job_id, p_cancelled_by, v_role, p_reason,
    case when v_policy_found then v_policy.id else null end,
    v_fee, v_refund, v_currency, v_refund_status, p_reason
  );

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, v_job.status, 'cancelled', p_cancelled_by, p_reason
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id,
    'cancelled',
    p_cancelled_by,
    jsonb_build_object(
      'canceller_role', v_role,
      'policy_id', case when v_policy_found then v_policy.id else null end,
      'fee_applied', v_fee,
      'refund_amount', v_refund,
      'refund_status', v_refund_status,
      'currency_code', v_currency,
      'reason', p_reason
    )
  );
end;
$$;

comment on function public.job_cancel(uuid, uuid, text) is
  'Cancels a job, resolves the country/role cancellation policy, records the fee and Phase 5 refund placeholder, and writes immutable history/events.';

revoke all on function public.job_cancel(uuid, uuid, text) from public;
revoke all on function public.job_cancel(uuid, uuid, text) from anon;
grant execute on function public.job_cancel(uuid, uuid, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Status transitions
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
    when 'arrived'           then array['loading']::public.job_status[]
    when 'loading'           then array['in_transit']::public.job_status[]
    when 'in_transit'        then array['delivered', 'disputed']::public.job_status[]
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
    when 'loading'      then 'pickup_completed'
    when 'in_transit'   then 'in_transit'
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

revoke all on function public.job_advance_status(uuid, public.job_status, text) from public;
revoke all on function public.job_advance_status(uuid, public.job_status, text) from anon;
grant execute on function public.job_advance_status(uuid, public.job_status, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Dispatch rule cascade and nearby-driver search
-- ----------------------------------------------------------------------------
create or replace function public.dispatch_rule_for(
  p_city_id uuid,
  p_vehicle_type_id uuid
)
returns public.dispatch_rules
language sql
stable
security definer
set search_path = ''
as $$
  select dr.*
  from public.dispatch_rules dr
  join public.cities c on c.id = p_city_id
  where dr.is_active
    and (dr.country_id is null or dr.country_id = c.country_id)
    and (dr.city_id is null or dr.city_id = p_city_id)
    and (dr.vehicle_type_id is null or dr.vehicle_type_id = p_vehicle_type_id)
  order by
    (dr.vehicle_type_id is not null) desc,
    (dr.city_id is not null) desc,
    (dr.country_id is not null) desc,
    dr.updated_at desc,
    dr.id
  limit 1;
$$;

comment on function public.dispatch_rule_for(uuid, uuid) is
  'Resolves the most specific active dispatch rule: vehicle+city, city, country, then global. Returns NULL when no rule applies.';

revoke all on function public.dispatch_rule_for(uuid, uuid) from public;
revoke all on function public.dispatch_rule_for(uuid, uuid) from anon;
grant execute on function public.dispatch_rule_for(uuid, uuid) to authenticated, service_role;

create or replace function public.find_nearby_drivers(
  p_pickup_location extensions.geography,
  p_vehicle_type_id uuid,
  p_radius_km numeric default 10,
  p_limit integer default 20
)
returns table (
  driver_id uuid,
  distance_km numeric,
  rating numeric,
  acceptance_rate numeric,
  eta_minutes integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (
    private.is_service_context()
    or public.has_permission('view_all_jobs')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to search drivers' using errcode = '42501';
  end if;

  if p_pickup_location is null or p_vehicle_type_id is null then
    raise exception 'pickup location and vehicle type are required' using errcode = '22004';
  end if;

  if p_radius_km is null or p_radius_km <= 0 then
    raise exception 'radius_km must be > 0' using errcode = '22023';
  end if;

  if p_limit is null or p_limit <= 0 then
    raise exception 'limit must be > 0' using errcode = '22023';
  end if;

  return query
  select
    d.id,
    round((extensions.ST_Distance(d.current_location, p_pickup_location) / 1000.0)::numeric, 2),
    d.rating,
    coalesce(s.acceptance_rate, 0.5000),
    greatest(
      1,
      ceil(
        extensions.ST_Distance(d.current_location, p_pickup_location) / 1000.0 / 20.0 * 60.0
      )::integer
    )
  from public.drivers d
  join public.profiles p on p.id = d.id and p.is_active
  join public.vehicles v on v.id = d.current_vehicle_id
  left join public.driver_acceptance_stats s on s.driver_id = d.id
  where d.verification_status = 'verified'
    and d.is_available
    and d.current_location is not null
    and v.is_active
    and v.verification_status = 'verified'
    and v.vehicle_type_id = p_vehicle_type_id
    and extensions.ST_DWithin(
      d.current_location,
      p_pickup_location,
      (p_radius_km * 1000)::double precision
    )
  order by 2, 3 desc, 1
  limit p_limit;
end;
$$;

comment on function public.find_nearby_drivers(extensions.geography, uuid, numeric, integer) is
  'Returns verified, available drivers with the matching vehicle type inside the radius, ordered by distance then rating, with ETA and rolling acceptance rate.';

revoke all on function public.find_nearby_drivers(extensions.geography, uuid, numeric, integer) from public;
revoke all on function public.find_nearby_drivers(extensions.geography, uuid, numeric, integer) from anon;
grant execute on function public.find_nearby_drivers(extensions.geography, uuid, numeric, integer) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Offers
-- ----------------------------------------------------------------------------
create or replace function public.offer_job_to_driver(
  p_job_id uuid,
  p_driver_id uuid,
  p_offer_timeout_seconds integer default 30
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job              public.jobs%rowtype;
  v_driver           public.drivers%rowtype;
  v_vehicle_type_id  uuid;
  v_pickup           extensions.geography;
  v_offer_id         uuid;
  v_existing         uuid;
  v_sequence         integer;
  v_timeout          integer := coalesce(p_offer_timeout_seconds, 30);
  v_offered_at       timestamptz := clock_timestamp();
  v_distance_km      numeric(8,2);
  v_eta              integer;
  v_pickup_distance  numeric;
begin
  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to offer jobs' using errcode = '42501';
  end if;

  if p_job_id is null or p_driver_id is null then
    raise exception 'job and driver are required' using errcode = '22004';
  end if;

  if v_timeout < 5 then
    raise exception 'offer timeout must be at least 5 seconds' using errcode = '22023';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_job.status not in ('requested', 'quoted', 'matched') then
    raise exception 'job % cannot receive offers in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  select d.* into v_driver
  from public.drivers d
  join public.profiles p on p.id = d.id
  where d.id = p_driver_id
    and p.is_active
    and d.verification_status = 'verified'
    and d.current_vehicle_id is not null;

  if not found then
    raise exception 'driver % is not eligible for offers', p_driver_id
      using errcode = 'P0002';
  end if;

  select qr.vehicle_type_id, qr.pickup_location
    into v_vehicle_type_id, v_pickup
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  if not exists (
    select 1 from public.vehicles v
    where v.id = v_driver.current_vehicle_id
      and v.is_active
      and v.verification_status = 'verified'
      and v.vehicle_type_id = v_vehicle_type_id
  ) then
    raise exception 'driver % does not have a matching verified vehicle', p_driver_id
      using errcode = '23514';
  end if;

  select o.id into v_existing
  from public.job_offers o
  where o.job_id = p_job_id
    and o.driver_id = p_driver_id
    and o.response = 'pending'
    and o.expires_at > now()
  order by o.offered_at desc
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  select coalesce(max(o.offer_sequence), 0) + 1 into v_sequence
  from public.job_offers o
  where o.job_id = p_job_id;

  if v_driver.current_location is not null and v_pickup is not null then
    v_pickup_distance := extensions.ST_Distance(v_driver.current_location, v_pickup);
    v_distance_km := round((v_pickup_distance / 1000.0)::numeric, 2);
    v_eta := greatest(1, ceil(v_pickup_distance / 1000.0 / 20.0 * 60.0)::integer);
  end if;

  insert into public.job_offers (
    job_id, driver_id, offer_sequence, offered_at, expires_at,
    distance_to_pickup_km, eta_minutes, payout_estimate, currency_code
  ) values (
    p_job_id, p_driver_id, v_sequence, v_offered_at,
    v_offered_at + make_interval(secs => v_timeout),
    v_distance_km, v_eta, null, v_job.final_currency_code
  )
  returning id into v_offer_id;

  -- Push/SMS delivery is owned by Phase 6. The offer row is the source of truth.
  return v_offer_id;
end;
$$;

comment on function public.offer_job_to_driver(uuid, uuid, integer) is
  'Creates a time-bounded job offer for an eligible driver. Duplicate pending offers return the existing offer id. Notification delivery is Phase 6.';

revoke all on function public.offer_job_to_driver(uuid, uuid, integer) from public;
revoke all on function public.offer_job_to_driver(uuid, uuid, integer) from anon;
grant execute on function public.offer_job_to_driver(uuid, uuid, integer) to authenticated, service_role;

create or replace function public.accept_job_offer(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_offer   public.job_offers%rowtype;
  v_job     public.jobs%rowtype;
  v_vehicle uuid;
begin
  select * into v_offer
  from public.job_offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'offer % not found', p_offer_id using errcode = 'P0002';
  end if;

  if v_offer.response <> 'pending' then
    raise exception 'offer % is already %', p_offer_id, v_offer.response
      using errcode = '23514';
  end if;

  if v_offer.expires_at <= now() then
    raise exception 'offer % has expired', p_offer_id using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_actor = v_offer.driver_id)
  ) then
    raise exception 'only the offered driver may accept offer %', p_offer_id
      using errcode = '42501';
  end if;

  select * into v_job
  from public.jobs
  where id = v_offer.job_id
  for update;

  if not found then
    raise exception 'job % not found', v_offer.job_id using errcode = 'P0002';
  end if;

  if v_job.status not in ('requested', 'quoted', 'matched') then
    raise exception 'job % cannot be accepted in status %', v_offer.job_id, v_job.status
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
   where job_id = v_offer.job_id
     and id <> p_offer_id
     and response = 'pending';

  select current_vehicle_id into v_vehicle
  from public.drivers
  where id = v_offer.driver_id;

  perform public.job_assign_driver(v_offer.job_id, v_offer.driver_id, v_vehicle);
end;
$$;

comment on function public.accept_job_offer(uuid) is
  'Driver accepts a pending offer; moves it to accepted, auto-reassigns competing pending offers and delegates assignment to job_assign_driver().';

revoke all on function public.accept_job_offer(uuid) from public;
revoke all on function public.accept_job_offer(uuid) from anon;
grant execute on function public.accept_job_offer(uuid) to authenticated, service_role;

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
  v_actor uuid := auth.uid();
  v_offer public.job_offers%rowtype;
begin
  select * into v_offer
  from public.job_offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'offer % not found', p_offer_id using errcode = 'P0002';
  end if;

  if v_offer.response <> 'pending' then
    raise exception 'offer % is already %', p_offer_id, v_offer.response
      using errcode = '23514';
  end if;

  if v_offer.expires_at <= now() then
    raise exception 'offer % has expired', p_offer_id using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_actor = v_offer.driver_id)
  ) then
    raise exception 'only the offered driver may decline offer %', p_offer_id
      using errcode = '42501';
  end if;

  update public.job_offers
     set response = 'declined',
         responded_at = now(),
         decline_reason = coalesce(nullif(btrim(p_reason), ''), 'Declined by driver')
   where id = p_offer_id;
end;
$$;

comment on function public.decline_job_offer(uuid, text) is
  'Marks a pending offer declined. The trigger refreshes the driver rolling acceptance statistics.';

revoke all on function public.decline_job_offer(uuid, text) from public;
revoke all on function public.decline_job_offer(uuid, text) from anon;
grant execute on function public.decline_job_offer(uuid, text) to authenticated, service_role;

create or replace function public.expire_stale_offers()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to expire offers' using errcode = '42501';
  end if;

  update public.job_offers
     set response = 'expired',
         responded_at = now(),
         decline_reason = 'Offer expired before a response'
   where response = 'pending'
     and expires_at <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.expire_stale_offers() is
  'Marks every pending offer past its deadline as expired. Intended for a Phase 5 pg_cron schedule.';

revoke all on function public.expire_stale_offers() from public;
revoke all on function public.expire_stale_offers() from anon;
grant execute on function public.expire_stale_offers() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Rating aggregation
-- ----------------------------------------------------------------------------
create or replace function public.recompute_driver_rating(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_rating  numeric(3,2);
begin
  if not (
    private.is_service_context()
    or public.has_permission('manage_ratings')
    or (v_actor is not null and v_actor = p_driver_id)
  ) then
    raise exception 'not authorised to recompute this driver rating' using errcode = '42501';
  end if;

  if not exists (select 1 from public.drivers d where d.id = p_driver_id) then
    raise exception 'driver % not found', p_driver_id using errcode = 'P0002';
  end if;

  select round(avg(r.score)::numeric, 2) into v_rating
  from public.ratings r
  where r.rated_profile_id = p_driver_id
    and r.rated_role = 'driver'
    and r.created_at >= now() - interval '90 days';

  update public.drivers
     set rating = coalesce(v_rating, 0)
   where id = p_driver_id;
end;
$$;

comment on function public.recompute_driver_rating(uuid) is
  'Recomputes drivers.rating from driver-directed ratings in the last 90 days. Customer ratings are unaffected.';

revoke all on function public.recompute_driver_rating(uuid) from public;
revoke all on function public.recompute_driver_rating(uuid) from anon;
grant execute on function public.recompute_driver_rating(uuid) to authenticated, service_role;
