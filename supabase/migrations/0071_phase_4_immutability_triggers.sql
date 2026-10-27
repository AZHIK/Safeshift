-- ============================================================================
-- SafeShift — Phase 4 / Migration 0071
-- Immutability, job creation guards, partition protection and updated_at.
--
-- The immutable tables are append-only for every role. The one deliberate
-- exception is job_offers: the dispatch SECURITY DEFINER helpers may move a
-- pending offer to a terminal response exactly once, and may change only
-- responded_at, response and decline_reason. Identity/offer terms never change.
--
-- The guard checks current_user (not session_user) so trusted SECURITY DEFINER
-- helpers owned by postgres pass while a client connected through PostgREST
-- remains `authenticated`.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Generic append-only guard
-- ----------------------------------------------------------------------------
create or replace function private.enforce_phase4_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
  v_new_offer jsonb;
  v_old_offer jsonb;
begin
  if tg_op = 'DELETE' then
    raise exception '% is append-only; rows cannot be deleted', tg_table_name
      using errcode = '42501';
  end if;

  if tg_table_name = 'job_offers' then
    if not v_service then
      raise exception 'job_offers can only be updated by the dispatch service'
        using errcode = '42501';
    end if;

    v_new_offer := to_jsonb(new) - array['responded_at', 'response', 'decline_reason'];
    v_old_offer := to_jsonb(old) - array['responded_at', 'response', 'decline_reason'];

    if v_new_offer is distinct from v_old_offer then
      raise exception 'job_offers identity and terms are immutable'
        using errcode = '42501';
    end if;

    if old.response <> 'pending' or new.response = 'pending' then
      raise exception 'job_offers response can only move once from pending to a terminal state'
        using errcode = '23514';
    end if;

    return new;
  end if;

  raise exception '% is append-only; updates are not allowed', tg_table_name
    using errcode = '42501';
end;
$$;

comment on function private.enforce_phase4_immutability() is
  'Blocks UPDATE/DELETE on Phase 4 append-only tables. job_offers permits one service-only pending -> terminal response transition limited to response fields.';

revoke all on function private.enforce_phase4_immutability() from public;
revoke all on function private.enforce_phase4_immutability() from anon;
revoke all on function private.enforce_phase4_immutability() from authenticated;

create trigger trg_quotes_immutable
  before update or delete on public.quotes
  for each row execute function private.enforce_phase4_immutability();

create trigger trg_job_status_history_immutable
  before update or delete on public.job_status_history
  for each row execute function private.enforce_phase4_immutability();

create trigger trg_job_events_immutable
  before update or delete on public.job_events
  for each row execute function private.enforce_phase4_immutability();

create trigger trg_job_offers_immutable
  before update or delete on public.job_offers
  for each row execute function private.enforce_phase4_immutability();

create trigger trg_dispute_resolutions_immutable
  before update or delete on public.dispute_resolutions
  for each row execute function private.enforce_phase4_immutability();

comment on trigger trg_job_events_immutable on public.job_events is
  'job_events.created_at is the partition key and must never change; the append-only guard also blocks deletes.';

-- ----------------------------------------------------------------------------
-- 2. Driver location partition-key protection
-- ----------------------------------------------------------------------------
create or replace function private.protect_driver_location_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.location is distinct from old.location then
    raise exception 'driver_locations.location is immutable'
      using errcode = '42501';
  end if;

  if new.recorded_at is distinct from old.recorded_at then
    raise exception 'driver_locations.recorded_at is the partition key and is immutable'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

comment on function private.protect_driver_location_fields() is
  'Protects the driver_locations geographic point and partition key even for trusted writers; telemetry corrections must be inserted as new pings.';

revoke all on function private.protect_driver_location_fields() from public;
revoke all on function private.protect_driver_location_fields() from anon;
revoke all on function private.protect_driver_location_fields() from authenticated;

create trigger trg_driver_locations_protect_fields
  before update on public.driver_locations
  for each row execute function private.protect_driver_location_fields();

create or replace function private.sync_driver_current_location()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.drivers
     set current_location = new.location,
         location_updated_at = new.recorded_at
   where id = new.driver_id;

  return null;
end;
$$;

comment on function private.sync_driver_current_location() is
  'Keeps the denormalised drivers.current_location/location_updated_at columns in step with the newest GPS ping.';

revoke all on function private.sync_driver_current_location() from public;
revoke all on function private.sync_driver_current_location() from anon;
revoke all on function private.sync_driver_current_location() from authenticated;

create trigger trg_driver_locations_sync_current
  after insert on public.driver_locations
  for each row execute function private.sync_driver_current_location();

-- ----------------------------------------------------------------------------
-- 3. Job creation must agree with its quote
-- ----------------------------------------------------------------------------
create or replace function private.prepare_job_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quote   public.quotes%rowtype;
  v_request public.quote_requests%rowtype;
  v_service boolean := private.is_service_context();
begin
  if new.quote_id is null then
    raise exception 'jobs.quote_id is required' using errcode = '23502';
  end if;

  select * into v_quote
  from public.quotes
  where id = new.quote_id;

  if not found then
    raise exception 'quote % not found', new.quote_id using errcode = 'P0002';
  end if;

  select * into v_request
  from public.quote_requests
  where id = v_quote.quote_request_id;

  if not found then
    raise exception 'quote request for quote % not found', new.quote_id using errcode = 'P0002';
  end if;

  if new.customer_id is null then
    new.customer_id := v_request.customer_id;
  end if;

  if new.customer_id <> v_request.customer_id then
    raise exception 'job customer does not match the quote customer'
      using errcode = '23514';
  end if;

  if new.city_id is null then
    new.city_id := v_request.city_id;
  end if;

  if new.city_id <> v_request.city_id then
    raise exception 'job city does not match the quote city'
      using errcode = '23514';
  end if;

  new.distance_km := v_quote.distance_km;
  new.final_amount := v_quote.total;
  new.final_currency_code := v_quote.currency_code;
  new.scheduled_at := coalesce(new.scheduled_at, v_request.scheduled_at, now());

  -- A promo is redeemed when the priced quote becomes a job. The ledger is
  -- append-only and client-inaccessible; service/seed inserts still pass
  -- through this SECURITY DEFINER trigger.
  if v_quote.promo_code_id is not null
     and not exists (
       select 1 from public.promo_redemptions pr where pr.job_id = new.id
     )
  then
    insert into public.promo_redemptions (
      promo_code_id, profile_id, job_id, discount_amount, currency_code,
      redeemed_at, created_at
    ) values (
      v_quote.promo_code_id, v_request.customer_id, new.id,
      v_quote.promo_discount, v_quote.currency_code, now(), now()
    );
  end if;

  if not v_service then
    if v_quote.expires_at <= now() then
      raise exception 'quote % has expired', v_quote.id using errcode = '22023';
    end if;

    if exists (select 1 from public.jobs j where j.quote_id = new.quote_id) then
      raise exception 'quote % has already been used to create a job', v_quote.id
        using errcode = '23505';
    end if;

    -- A client may only create the untouched initial state. Every later change
    -- goes through job_advance_status(), job_assign_driver() or job_cancel().
    new.status := 'requested';
    new.driver_id := null;
    new.vehicle_id := null;
    new.accepted_at := null;
    new.started_at := null;
    new.completed_at := null;
    new.cancelled_at := null;
    new.payment_status := 'pending';
    new.payment_method := null;
    new.cancellation_policy_applied := null;
    new.cancellation_fee := 0;
    new.actual_duration_min := null;
    new.actual_distance_km := null;
  end if;

  return new;
end;
$$;

comment on function private.prepare_job_insert() is
  'Derives customer/city/distance/amount from the persisted quote and prevents clients from creating a job in a non-initial state.';

revoke all on function private.prepare_job_insert() from public;
revoke all on function private.prepare_job_insert() from anon;
revoke all on function private.prepare_job_insert() from authenticated;

create trigger trg_jobs_prepare_insert
  before insert on public.jobs
  for each row execute function private.prepare_job_insert();

-- ----------------------------------------------------------------------------
-- 4. Cross-table child validation
-- ----------------------------------------------------------------------------
create or replace function private.validate_job_child()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_stop_id    uuid := nullif(to_jsonb(new) ->> 'stop_id', '')::uuid;
  v_job_id     uuid := nullif(to_jsonb(new) ->> 'job_id', '')::uuid;
  v_message_id uuid := nullif(to_jsonb(new) ->> 'message_id', '')::uuid;
  v_dispute_id uuid := nullif(to_jsonb(new) ->> 'dispute_id', '')::uuid;
begin
  if tg_table_name = 'job_evidence' and v_stop_id is not null then
    if not exists (
      select 1 from public.job_stops s
      where s.id = v_stop_id
        and s.job_id = v_job_id
    ) then
      raise exception 'evidence stop does not belong to the job'
        using errcode = '23514';
    end if;
  end if;

  if tg_table_name = 'dispute_attachments' and v_message_id is not null then
    if not exists (
      select 1 from public.dispute_messages m
      where m.id = v_message_id
        and m.dispute_id = v_dispute_id
    ) then
      raise exception 'attachment message does not belong to the dispute'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

comment on function private.validate_job_child() is
  'Ensures job_evidence.stop_id and dispute_attachments.message_id reference rows in the same parent aggregate.';

revoke all on function private.validate_job_child() from public;
revoke all on function private.validate_job_child() from anon;
revoke all on function private.validate_job_child() from authenticated;

create trigger trg_job_evidence_validate_stop
  before insert or update on public.job_evidence
  for each row execute function private.validate_job_child();

create trigger trg_dispute_attachments_validate_message
  before insert or update on public.dispute_attachments
  for each row execute function private.validate_job_child();

-- ----------------------------------------------------------------------------
-- 5. Rolling driver acceptance statistics
-- ----------------------------------------------------------------------------
create or replace function private.refresh_driver_acceptance_stats(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window_start timestamptz := now() - interval '30 days';
  v_window_end   timestamptz := now();
  v_received     integer;
  v_accepted     integer;
  v_declined     integer;
  v_expired      integer;
  v_rate         numeric(5,4);
  v_avg          numeric(8,2);
begin
  if p_driver_id is null then
    return;
  end if;

  select
    count(*)::integer,
    count(*) filter (where response = 'accepted')::integer,
    count(*) filter (where response = 'declined')::integer,
    count(*) filter (where response = 'expired')::integer,
    (
      avg(greatest(0, extract(epoch from (responded_at - offered_at))))
      filter (where responded_at is not null)
    )::numeric(8,2)
  into v_received, v_accepted, v_declined, v_expired, v_avg
  from public.job_offers
  where driver_id = p_driver_id
    and offered_at >= v_window_start
    and offered_at < v_window_end;

  if v_received > 0 then
    v_rate := round(v_accepted::numeric / v_received::numeric, 4);
  else
    v_rate := null;
  end if;

  insert into public.driver_acceptance_stats (
    driver_id, window_start, window_end, offers_received, offers_accepted,
    offers_declined, offers_expired, acceptance_rate, avg_response_seconds, updated_at
  ) values (
    p_driver_id, v_window_start, v_window_end, v_received, v_accepted,
    v_declined, v_expired, v_rate, v_avg, now()
  )
  on conflict (driver_id) do update
    set window_start = excluded.window_start,
        window_end = excluded.window_end,
        offers_received = excluded.offers_received,
        offers_accepted = excluded.offers_accepted,
        offers_declined = excluded.offers_declined,
        offers_expired = excluded.offers_expired,
        acceptance_rate = excluded.acceptance_rate,
        avg_response_seconds = excluded.avg_response_seconds,
        updated_at = now();
end;
$$;

comment on function private.refresh_driver_acceptance_stats(uuid) is
  'Recomputes the rolling 30-day offer statistics for one driver from job_offers.';

revoke all on function private.refresh_driver_acceptance_stats(uuid) from public;
revoke all on function private.refresh_driver_acceptance_stats(uuid) from anon;
revoke all on function private.refresh_driver_acceptance_stats(uuid) from authenticated;

create or replace function private.sync_driver_acceptance_stats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.refresh_driver_acceptance_stats(
    case when tg_op = 'DELETE' then old.driver_id else new.driver_id end
  );
  return null;
end;
$$;

comment on function private.sync_driver_acceptance_stats() is
  'AFTER trigger on job_offers that keeps driver_acceptance_stats current.';

revoke all on function private.sync_driver_acceptance_stats() from public;
revoke all on function private.sync_driver_acceptance_stats() from anon;
revoke all on function private.sync_driver_acceptance_stats() from authenticated;

create trigger trg_job_offers_sync_acceptance_stats
  after insert or update of response on public.job_offers
  for each row execute function private.sync_driver_acceptance_stats();

-- ----------------------------------------------------------------------------
-- 6. updated_at maintenance
-- ----------------------------------------------------------------------------
create trigger trg_cancellation_policies_updated_at
  before update on public.cancellation_policies
  for each row execute function public.set_updated_at();

create trigger trg_quote_requests_updated_at
  before update on public.quote_requests
  for each row execute function public.set_updated_at();

create trigger trg_surge_multipliers_updated_at
  before update on public.surge_multipliers
  for each row execute function public.set_updated_at();

create trigger trg_jobs_updated_at
  before update on public.jobs
  for each row execute function public.set_updated_at();

create trigger trg_job_stops_updated_at
  before update on public.job_stops
  for each row execute function public.set_updated_at();

create trigger trg_job_items_updated_at
  before update on public.job_items
  for each row execute function public.set_updated_at();

create trigger trg_dispatch_rules_updated_at
  before update on public.dispatch_rules
  for each row execute function public.set_updated_at();

create trigger trg_rating_categories_updated_at
  before update on public.rating_categories
  for each row execute function public.set_updated_at();

create trigger trg_rating_reports_updated_at
  before update on public.rating_reports
  for each row execute function public.set_updated_at();

create trigger trg_disputes_updated_at
  before update on public.disputes
  for each row execute function public.set_updated_at();

create trigger trg_recurring_job_templates_updated_at
  before update on public.recurring_job_templates
  for each row execute function public.set_updated_at();

create trigger trg_scheduled_jobs_updated_at
  before update on public.scheduled_jobs
  for each row execute function public.set_updated_at();

create trigger trg_driver_acceptance_stats_updated_at
  before update on public.driver_acceptance_stats
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 7. Audit trails on mutable operational roots
-- Reuses the Phase 1 private.audit_trigger(); append-only tables and
-- high-volume telemetry/offer rows are intentionally not audited row-by-row.
-- ----------------------------------------------------------------------------
do $$
declare
  v_table text;
  v_tables text[] := array[
    'public.jobs',
    'public.cancellation_policies',
    'public.surge_multipliers',
    'public.dispatch_rules',
    'public.rating_categories',
    'public.rating_reports',
    'public.disputes',
    'public.recurring_job_templates',
    'public.scheduled_jobs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists %I on %s',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
    execute format(
      'create trigger %I after insert or update or delete on %s for each row execute function private.audit_trigger()',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
  end loop;
end $$;
