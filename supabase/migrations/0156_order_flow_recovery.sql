-- Order flow recovery: what happens when a matched move goes wrong before
-- the cargo is loaded.
--
-- 1. job_driver_release: the assigned driver hands a job back. The move is
--    not cancelled; it returns to `requested` and is re-dispatched at once,
--    without the releasing driver.
-- 2. order watchdog (run from dispatch_tick): releases drivers who accepted
--    but never started, stopped sharing location, or never reached pickup.
-- 3. job_pickup_wait: the free waiting window once the driver has arrived.
-- 4. job_report_customer_no_show / job_report_cargo_mismatch: the driver
--    ends a move the customer cannot go ahead with. Both are recorded as a
--    customer cancellation through the existing job_cancel, so the existing
--    customer cancellation policy decides any fee. No money logic changes.
-- 5. job_cancellation_preview: read-only preview of what job_cancel would
--    charge the customer right now, so the app can show it before confirming.
-- 6. driver_job_outcome: tells a driver why a job left their screen.

-- ----------------------------------------------------------------------------
-- Event types
-- ----------------------------------------------------------------------------
alter table public.job_events
  drop constraint if exists job_events_type_check;

alter table public.job_events
  add constraint job_events_type_check check (
    event_type in (
      'created',
      'driver_assigned',
      'driver_arrived',
      'cargo_verified',
      'pickup_completed',
      'in_transit',
      'arrived_destination',
      'delivered',
      'completed',
      'cancelled',
      'route_deviation',
      'prolonged_stop',
      'sos',
      'chat_message',
      'call_made',
      'note',
      'driver_released',
      'customer_no_show',
      'cargo_mismatch'
    )
  );

-- ----------------------------------------------------------------------------
-- Settings
-- ----------------------------------------------------------------------------
create or replace function private.pickup_free_wait_minutes()
returns integer
language sql
immutable
set search_path = ''
as $$ select 10 $$;

revoke all on function private.pickup_free_wait_minutes() from public, anon, authenticated;

-- When the driver reached the pickup (latest transition into `arrived`).
create or replace function private.job_arrived_at(p_job_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(h.created_at)
  from public.job_status_history h
  where h.job_id = p_job_id
    and h.to_status = 'arrived';
$$;

revoke all on function private.job_arrived_at(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1. Release core (callers authorise and lock nothing; this locks the job)
-- ----------------------------------------------------------------------------
create or replace function private.release_job_driver(
  p_job_id uuid,
  p_reason text,
  p_released_by uuid,
  p_kind text,
  p_driver_stays_available boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job      public.jobs%rowtype;
  v_driver   uuid;
  v_dispatch jsonb;
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  v_driver := v_job.driver_id;
  if v_driver is null then
    raise exception 'this job has no driver to release' using errcode = '23514';
  end if;

  -- Once cargo is verified the goods are the driver's responsibility; a
  -- handover needs operations, not a silent re-dispatch.
  if v_job.status not in ('accepted', 'heading_to_pickup', 'arrived') then
    raise exception 'this job can no longer be released; contact support'
      using errcode = '23514';
  end if;

  update public.jobs
     set driver_id = null,
         vehicle_id = null,
         status = 'requested',
         accepted_at = null,
         started_at = null,
         dispatch_attempts = 0,
         last_dispatched_at = null
   where id = p_job_id;

  -- The released driver must not be offered this job again; match_dispatch
  -- skips drivers who declined it.
  update public.job_offers
     set response = 'declined',
         responded_at = coalesce(responded_at, now()),
         decline_reason = left('Released after accepting: ' || p_reason, 500)
   where job_id = p_job_id
     and driver_id = v_driver
     and response = 'accepted';

  update public.drivers
     set is_available = p_driver_stays_available
   where id = v_driver;

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, v_job.status, 'requested', p_released_by, p_reason
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id,
    'driver_released',
    p_released_by,
    jsonb_build_object(
      'driver_id', v_driver,
      'from_status', v_job.status,
      'kind', p_kind,
      'reason', p_reason
    )
  );

  perform private.invoke_push_send(
    v_job.customer_id,
    'Finding you a new driver',
    'Your driver could not complete the pickup. We are finding another driver now.',
    jsonb_build_object('type', 'job_status', 'job_id', p_job_id::text, 'status', 'requested'),
    'safeshift://tracking/' || p_job_id::text
  );

  if p_kind <> 'driver' then
    perform private.invoke_push_send(
      v_driver,
      'Job reassigned',
      'This job was given to another driver. Reason: ' || p_reason,
      jsonb_build_object('type', 'job_released', 'job_id', p_job_id::text),
      'safeshift://home'
    );
  end if;

  begin
    v_dispatch := private.match_dispatch_core(
      p_job_id, private.dispatch_radius_km(0), 5, 45
    );
  exception when others then
    -- The release stands; the worker or the customer app retries dispatch.
    v_dispatch := jsonb_build_object('count', 0, 'reason', 'dispatch will retry');
  end;

  return v_dispatch;
end;
$$;

revoke all on function private.release_job_driver(uuid, text, uuid, text, boolean)
  from public, anon, authenticated;

create or replace function public.job_driver_release(
  p_job_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor  uuid := auth.uid();
  v_driver uuid;
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a reason is required' using errcode = '22023';
  end if;

  select driver_id into v_driver from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or (v_actor is not null and v_actor = v_driver)
  ) then
    raise exception 'only the assigned driver may release this job'
      using errcode = '42501';
  end if;

  return private.release_job_driver(
    p_job_id, btrim(p_reason), v_actor,
    case when v_actor = v_driver then 'driver' else 'operations' end,
    true
  );
end;
$$;

comment on function public.job_driver_release(uuid, text) is
  'The assigned driver (or operations) hands a job back before cargo verification. The move returns to requested and is re-dispatched without that driver.';

revoke all on function public.job_driver_release(uuid, text) from public, anon;
grant execute on function public.job_driver_release(uuid, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Watchdog
-- ----------------------------------------------------------------------------
create or replace function private.order_watchdog()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job      record;
  v_released integer := 0;
begin
  for v_job in
    select
      j.id,
      j.status,
      j.accepted_at,
      d.location_updated_at,
      coalesce((
        select o.eta_minutes from public.job_offers o
        where o.job_id = j.id and o.driver_id = j.driver_id
          and o.response = 'accepted'
        order by o.offered_at desc limit 1
      ), 15) as eta_minutes
    from public.jobs j
    join public.drivers d on d.id = j.driver_id
    where j.status in ('accepted', 'heading_to_pickup')
      and j.accepted_at is not null
    for update of j skip locked
  loop
    begin
      if v_job.status = 'accepted'
         and v_job.accepted_at < now() - interval '3 minutes'
      then
        perform private.release_job_driver(
          v_job.id, 'Trip not started within 3 minutes of accepting', null,
          'watchdog', false
        );
        v_released := v_released + 1;
      elsif v_job.status = 'heading_to_pickup'
         and v_job.accepted_at < now() - interval '10 minutes'
         and (v_job.location_updated_at is null
              or v_job.location_updated_at < now() - interval '10 minutes')
      then
        perform private.release_job_driver(
          v_job.id, 'Location not shared for 10 minutes', null,
          'watchdog', false
        );
        v_released := v_released + 1;
      elsif v_job.status = 'heading_to_pickup'
         and v_job.accepted_at < now()
           - make_interval(mins => greatest(45, v_job.eta_minutes * 4))
      then
        perform private.release_job_driver(
          v_job.id, 'Pickup not reached in time', null,
          'watchdog', false
        );
        v_released := v_released + 1;
      end if;
    exception when others then
      -- One bad row must not stop the watchdog.
      null;
    end;
  end loop;

  return v_released;
end;
$$;

revoke all on function private.order_watchdog() from public, anon, authenticated;

-- dispatch_tick is already scheduled by pg_cron; run the watchdog from it.
create or replace function public.dispatch_tick(p_max_jobs integer default 25)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job        record;
  v_processed  integer := 0;
  v_max        integer := greatest(1, least(coalesce(p_max_jobs, 25), 200));
begin
  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to run the dispatch worker' using errcode = '42501';
  end if;

  update public.job_offers
     set response = 'expired',
         responded_at = now(),
         decline_reason = 'Offer expired before a response'
   where response = 'pending'
     and expires_at <= now();

  begin
    perform private.order_watchdog();
  exception when others then
    null;
  end;

  for v_job in
    select
      j.id,
      j.customer_id,
      j.dispatch_attempts,
      (
        select count(*) from public.job_offers o
        where o.job_id = j.id
          and o.response = 'pending'
          and o.expires_at > now()
      ) as pending_offers
    from public.jobs j
    join public.quotes q on q.id = j.quote_id
    join public.quote_requests qr on qr.id = q.quote_request_id
    where j.driver_id is null
      and j.status in ('requested', 'quoted', 'matched')
      and j.scheduled_at > now() - interval '2 hours'
      and (j.last_dispatched_at is null
           or j.last_dispatched_at < now() - interval '35 seconds')
      and (qr.scheduled_at is null
           or qr.scheduled_at <= now() + interval '45 minutes')
    order by j.created_at
    limit v_max
    for update of j skip locked
  loop
    if v_job.pending_offers > 0 then
      continue;
    end if;

    if v_job.dispatch_attempts >= 6 then
      begin
        perform public.job_cancel(
          v_job.id,
          v_job.customer_id,
          'No driver was available for this move'
        );
      exception when others then
        null;
      end;
      continue;
    end if;

    begin
      perform private.match_dispatch_core(
        v_job.id, private.dispatch_radius_km(v_job.dispatch_attempts), 5, 45
      );
      v_processed := v_processed + 1;
    exception when others then
      update public.jobs
         set dispatch_attempts = dispatch_attempts + 1,
             last_dispatched_at = now()
       where id = v_job.id;
    end;
  end loop;

  return v_processed;
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. Pickup waiting window
-- ----------------------------------------------------------------------------
create or replace function public.job_pickup_wait(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_job     public.jobs%rowtype;
  v_arrived timestamptz;
  v_free    integer := private.pickup_free_wait_minutes();
begin
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('view_all_jobs')
    or v_actor = v_job.customer_id
    or v_actor = v_job.driver_id
  ) then
    raise exception 'not authorised to view job %', p_job_id using errcode = '42501';
  end if;

  if v_job.status <> 'arrived' then
    return jsonb_build_object('status', v_job.status, 'waiting', false);
  end if;

  v_arrived := coalesce(private.job_arrived_at(p_job_id), now());
  return jsonb_build_object(
    'status', v_job.status,
    'waiting', true,
    'arrived_at', v_arrived,
    'free_wait_minutes', v_free,
    'free_wait_ends_at', v_arrived + make_interval(mins => v_free),
    'no_show_allowed', now() >= v_arrived + make_interval(mins => v_free),
    'server_now', now()
  );
end;
$$;

revoke all on function public.job_pickup_wait(uuid) from public, anon;
grant execute on function public.job_pickup_wait(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Driver-reported pickup failures
-- ----------------------------------------------------------------------------
-- Records the cancellation as the customer's, through the unchanged
-- job_cancel. job_cancel only lets a caller cancel as themselves, so the
-- request runs with the service role for this one call and the previous
-- role is restored immediately, on success and on error.
create or replace function private.cancel_on_behalf_of_customer(
  p_job_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer uuid;
  v_role     text := current_setting('request.jwt.claim.role', true);
begin
  select customer_id into v_customer from public.jobs where id = p_job_id;

  perform set_config('request.jwt.claim.role', 'service_role', true);
  begin
    perform public.job_cancel(p_job_id, v_customer, p_reason);
  exception when others then
    perform set_config('request.jwt.claim.role', coalesce(v_role, ''), true);
    raise;
  end;
  perform set_config('request.jwt.claim.role', coalesce(v_role, ''), true);
end;
$$;

revoke all on function private.cancel_on_behalf_of_customer(uuid, text)
  from public, anon, authenticated;

create or replace function public.job_report_customer_no_show(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_job     public.jobs%rowtype;
  v_arrived timestamptz;
  v_free    integer := private.pickup_free_wait_minutes();
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (v_actor is not null and v_actor = v_job.driver_id) then
    raise exception 'only the assigned driver may report a no-show'
      using errcode = '42501';
  end if;

  if v_job.status <> 'arrived' then
    raise exception 'mark yourself as arrived at the pickup first'
      using errcode = '23514';
  end if;

  v_arrived := private.job_arrived_at(p_job_id);
  if v_arrived is null or now() < v_arrived + make_interval(mins => v_free) then
    raise exception 'wait the full % minutes before reporting a no-show', v_free
      using errcode = '23514';
  end if;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id, 'customer_no_show', v_actor,
    jsonb_build_object(
      'arrived_at', v_arrived,
      'waited_minutes', floor(extract(epoch from (now() - v_arrived)) / 60)
    )
  );

  perform private.cancel_on_behalf_of_customer(
    p_job_id, 'Customer did not show up at the pickup'
  );
end;
$$;

revoke all on function public.job_report_customer_no_show(uuid) from public, anon;
grant execute on function public.job_report_customer_no_show(uuid) to authenticated, service_role;

create or replace function public.job_report_cargo_mismatch(
  p_job_id uuid,
  p_reason text,
  p_photo_paths text[] default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (v_actor is not null and v_actor = v_job.driver_id) then
    raise exception 'only the assigned driver may report a cargo mismatch'
      using errcode = '42501';
  end if;

  if v_job.status not in ('arrived', 'cargo_verified') then
    raise exception 'cargo can only be refused at the pickup, before loading'
      using errcode = '23514';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'describe what does not match' using errcode = '22023';
  end if;

  if cardinality(coalesce(p_photo_paths, '{}')) > 8 then
    raise exception 'at most 8 photos are allowed' using errcode = '22023';
  end if;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id, 'cargo_mismatch', v_actor,
    jsonb_build_object(
      'reason', left(btrim(p_reason), 500),
      'photo_paths', to_jsonb(coalesce(p_photo_paths, '{}'))
    )
  );

  perform private.cancel_on_behalf_of_customer(
    p_job_id,
    left('Cargo did not match the booking: ' || btrim(p_reason), 500)
  );
end;
$$;

revoke all on function public.job_report_cargo_mismatch(uuid, text, text[]) from public, anon;
grant execute on function public.job_report_cargo_mismatch(uuid, text, text[]) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Cancellation preview (read-only mirror of job_cancel's fee rules)
-- ----------------------------------------------------------------------------
-- Keep in step with public.job_cancel. This function never writes.
create or replace function public.job_cancellation_preview(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor          uuid := auth.uid();
  v_job            public.jobs%rowtype;
  v_quote          public.quotes%rowtype;
  v_policy         public.cancellation_policies%rowtype;
  v_policy_found   boolean := false;
  v_country_id     uuid;
  v_minutes_before integer;
  v_fee            numeric(14,2) := 0;
  v_free_until     timestamptz;
begin
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or v_actor = v_job.customer_id) then
    raise exception 'not authorised to view job %', p_job_id using errcode = '42501';
  end if;

  if v_job.status in ('completed', 'cancelled', 'disputed') then
    return jsonb_build_object('cancellable', false, 'status', v_job.status);
  end if;

  if v_job.status in ('loading', 'in_transit', 'arrived_destination', 'delivered') then
    return jsonb_build_object(
      'cancellable', false,
      'status', v_job.status,
      'message', 'Your goods are already with the driver. Contact support to stop this move.'
    );
  end if;

  select * into v_quote from public.quotes where id = v_job.quote_id;

  if v_job.driver_id is not null or v_job.accepted_at is not null then
    select c.country_id into v_country_id from public.cities c where c.id = v_job.city_id;

    select * into v_policy
    from public.cancellation_policies cp
    where cp.country_id = v_country_id
      and cp.applies_to_role = 'customer'
      and cp.is_active
    order by cp.created_at desc, cp.id
    limit 1;
    v_policy_found := found;
  end if;

  v_minutes_before := floor(
    extract(epoch from (coalesce(v_job.scheduled_at, now()) - now())) / 60.0
  )::integer;

  if v_policy_found then
    if v_minutes_before < v_policy.free_cancellation_window_minutes then
      if v_policy.fee_type = 'flat' then
        v_fee := v_policy.fee_value;
      elsif v_policy.fee_type = 'percentage_of_quote' then
        v_fee := round(
          coalesce(v_job.final_amount, v_quote.total, 0) * v_policy.fee_value / 100.0, 2
        );
      elsif v_policy.fee_type = 'tiered' then
        select (tier ->> 'fee')::numeric into v_fee
        from jsonb_array_elements(v_policy.fee_tiers) tier
        where (tier ->> 'minutes_before_pickup')::numeric <= v_minutes_before
        order by (tier ->> 'minutes_before_pickup')::numeric desc
        limit 1;
        if not found then v_fee := 0; end if;
      end if;
    else
      v_free_until := coalesce(v_job.scheduled_at, now())
        - make_interval(mins => v_policy.free_cancellation_window_minutes);
    end if;
  end if;

  v_fee := round(
    least(greatest(coalesce(v_fee, 0), 0), coalesce(v_job.final_amount, v_quote.total, 0)),
    2
  );

  return jsonb_build_object(
    'cancellable', true,
    'status', v_job.status,
    'fee', v_fee,
    'currency_code', coalesce(v_job.final_currency_code, v_quote.currency_code),
    'policy_name', case when v_policy_found then v_policy.name else null end,
    'free_until', v_free_until,
    'driver_assigned', v_job.driver_id is not null
  );
end;
$$;

revoke all on function public.job_cancellation_preview(uuid) from public, anon;
grant execute on function public.job_cancellation_preview(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Why did this job leave the driver's screen?
-- ----------------------------------------------------------------------------
create or replace function public.driver_job_outcome(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor  uuid := auth.uid();
  v_job    public.jobs%rowtype;
  v_reason text;
begin
  if v_actor is null or not exists (
    select 1 from public.job_offers o
    where o.job_id = p_job_id and o.driver_id = v_actor
  ) then
    raise exception 'not authorised to view job %', p_job_id using errcode = '42501';
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_job.driver_id = v_actor and v_job.status <> 'cancelled' then
    return jsonb_build_object('outcome', 'assigned', 'status', v_job.status);
  end if;

  if v_job.status = 'cancelled' and not exists (
    select 1 from public.job_events e
    where e.job_id = p_job_id and e.event_type = 'driver_released'
      and e.details ->> 'driver_id' = v_actor::text
  ) then
    select h.reason into v_reason
    from public.job_status_history h
    where h.job_id = p_job_id and h.to_status = 'cancelled'
    order by h.created_at desc limit 1;
    return jsonb_build_object('outcome', 'cancelled', 'reason', v_reason);
  end if;

  select e.details ->> 'reason' into v_reason
  from public.job_events e
  where e.job_id = p_job_id and e.event_type = 'driver_released'
    and e.details ->> 'driver_id' = v_actor::text
  order by e.created_at desc limit 1;

  if v_reason is not null then
    return jsonb_build_object('outcome', 'released', 'reason', v_reason);
  end if;

  return jsonb_build_object('outcome', 'unassigned');
end;
$$;

revoke all on function public.driver_job_outcome(uuid) from public, anon;
grant execute on function public.driver_job_outcome(uuid) to authenticated, service_role;
