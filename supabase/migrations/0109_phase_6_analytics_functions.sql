-- ============================================================================
-- 0109 — Phase 6: analytics, demand, and retention functions
-- ============================================================================
-- All analytics functions are SECURITY DEFINER and write only the batch tables.
-- They are callable by the service layer and by staff with manage_analytics.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Daily metrics
-- ----------------------------------------------------------------------------
create or replace function public.compute_daily_metrics(p_target_date date default current_date - 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (private.is_service_context() or public.has_permission('manage_analytics')) then
    raise exception 'insufficient privileges to compute daily metrics'
      using errcode = '42501';
  end if;

  with city_base as (
    select ci.id as city_id,
           ci.country_id,
           cur.code as currency_code
      from public.cities ci
      join public.countries co on co.id = ci.country_id
      join public.currencies cur on cur.id = co.default_currency_id
     where ci.is_active
  ),
  job_stats as (
    select j.city_id,
           count(*) filter (where j.created_at::date = p_target_date)::integer as jobs_created,
           count(*) filter (where j.status = 'completed' and j.completed_at::date = p_target_date)::integer as jobs_completed,
           count(*) filter (where j.status = 'cancelled' and j.cancelled_at::date = p_target_date)::integer as jobs_cancelled,
           coalesce(sum(j.final_amount) filter (where j.status = 'completed' and j.completed_at::date = p_target_date), 0)::numeric(14,2) as gross_booking_value,
           count(distinct j.customer_id) filter (
             where j.created_at::date = p_target_date
                or j.completed_at::date = p_target_date
                or j.cancelled_at::date = p_target_date
           )::integer as active_customers,
           count(distinct j.driver_id) filter (
             where j.created_at::date = p_target_date
                or j.completed_at::date = p_target_date
                or j.cancelled_at::date = p_target_date
           )::integer as active_drivers,
           avg(extract(epoch from (j.completed_at - j.started_at)) / 60.0) filter (
             where j.status = 'completed'
               and j.completed_at::date = p_target_date
               and j.started_at is not null
           )::numeric(8,2) as avg_completion_minutes
      from public.jobs j
     where j.created_at::date = p_target_date
        or j.completed_at::date = p_target_date
        or j.cancelled_at::date = p_target_date
     group by j.city_id
  ),
  rating_stats as (
    select j.city_id, avg(r.score)::numeric(3,2) as avg_rating
      from public.ratings r
      join public.jobs j on j.id = r.job_id
     where j.status = 'completed'
       and j.completed_at::date = p_target_date
       and r.rated_role = 'driver'
     group by j.city_id
  ),
  commission_stats as (
    select j.city_id, coalesce(sum(cl.commission_amount), 0)::numeric(14,2) as net_revenue
      from public.commission_ledger cl
      join public.jobs j on j.id = cl.job_id
     where j.status = 'completed'
       and j.completed_at::date = p_target_date
     group by j.city_id
  ),
  new_customer_stats as (
    select j.city_id, count(distinct j.customer_id)::integer as new_customers
      from public.jobs j
     where j.created_at::date = p_target_date
       and not exists (
         select 1
           from public.jobs prior
          where prior.customer_id = j.customer_id
            and prior.created_at < j.created_at
       )
     group by j.city_id
  ),
  new_driver_stats as (
    select d.home_city_id as city_id, count(*)::integer as new_drivers
      from public.drivers d
     where d.created_at::date = p_target_date
       and d.home_city_id is not null
     group by d.home_city_id
  ),
  acceptance_stats as (
    select d.home_city_id as city_id,
           avg(das.acceptance_rate)::numeric(5,4) as avg_acceptance_rate
      from public.driver_acceptance_stats das
      join public.drivers d on d.id = das.driver_id
     where d.home_city_id is not null
     group by d.home_city_id
  )
  insert into public.daily_metrics (
    metric_date, country_id, city_id,
    jobs_created, jobs_completed, jobs_cancelled,
    gross_booking_value, net_revenue, currency_code,
    active_customers, active_drivers, new_customers, new_drivers,
    avg_acceptance_rate, avg_completion_minutes, avg_cancellation_rate,
    avg_rating, computed_at
  )
  select p_target_date,
         cb.country_id,
         cb.city_id,
         coalesce(js.jobs_created, 0),
         coalesce(js.jobs_completed, 0),
         coalesce(js.jobs_cancelled, 0),
         coalesce(js.gross_booking_value, 0),
         coalesce(cs.net_revenue, 0),
         cb.currency_code,
         coalesce(js.active_customers, 0),
         coalesce(js.active_drivers, 0),
         coalesce(ncs.new_customers, 0),
         coalesce(nds.new_drivers, 0),
         acs.avg_acceptance_rate,
         js.avg_completion_minutes,
         case when coalesce(js.jobs_created, 0) > 0
              then (js.jobs_cancelled::numeric / js.jobs_created)::numeric(5,4)
              else 0::numeric(5,4) end,
         rs.avg_rating,
         now()
    from city_base cb
    left join job_stats js on js.city_id = cb.city_id
    left join rating_stats rs on rs.city_id = cb.city_id
    left join commission_stats cs on cs.city_id = cb.city_id
    left join new_customer_stats ncs on ncs.city_id = cb.city_id
    left join new_driver_stats nds on nds.city_id = cb.city_id
    left join acceptance_stats acs on acs.city_id = cb.city_id
  on conflict on constraint daily_metrics_scope_key do update
    set jobs_created = excluded.jobs_created,
        jobs_completed = excluded.jobs_completed,
        jobs_cancelled = excluded.jobs_cancelled,
        gross_booking_value = excluded.gross_booking_value,
        net_revenue = excluded.net_revenue,
        currency_code = excluded.currency_code,
        active_customers = excluded.active_customers,
        active_drivers = excluded.active_drivers,
        new_customers = excluded.new_customers,
        new_drivers = excluded.new_drivers,
        avg_acceptance_rate = excluded.avg_acceptance_rate,
        avg_completion_minutes = excluded.avg_completion_minutes,
        avg_cancellation_rate = excluded.avg_cancellation_rate,
        avg_rating = excluded.avg_rating,
        computed_at = excluded.computed_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Zone metrics
-- ----------------------------------------------------------------------------
create or replace function public.compute_zone_metrics(p_target_date date default current_date - 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (private.is_service_context() or public.has_permission('manage_analytics')) then
    raise exception 'insufficient privileges to compute zone metrics'
      using errcode = '42501';
  end if;

  with zone_base as (
    select z.id as service_zone_id, z.city_id, z.boundary
      from public.service_zones z
     where z.is_active
  ),
  job_zone as (
    select z.service_zone_id,
           count(j.id) filter (where j.created_at::date = p_target_date)::integer as jobs_requested,
           count(j.id) filter (where j.status = 'completed' and j.completed_at::date = p_target_date)::integer as jobs_fulfilled,
           avg(jo.eta_minutes) filter (where j.created_at::date = p_target_date)::numeric(8,2) as avg_eta_minutes,
           avg(q.surge_multiplier) filter (where j.created_at::date = p_target_date)::numeric(6,4) as surge_multiplier_avg,
           count(distinct j.driver_id) filter (
             where j.created_at::date = p_target_date
                or j.completed_at::date = p_target_date
           )::integer as active_drivers
      from zone_base z
      left join public.jobs j on j.city_id = z.city_id
      left join public.quotes q on q.id = j.quote_id
      left join public.quote_requests qr on qr.id = q.quote_request_id
      left join public.job_offers jo on jo.job_id = j.id and jo.response = 'accepted'
     where j.id is null
        or extensions.st_within(qr.pickup_location::extensions.geometry, z.boundary::extensions.geometry)
     group by z.service_zone_id
  ),
  supply_zone as (
    select z.service_zone_id,
           (count(dl.id) * 5)::bigint as supply_available_minutes
      from zone_base z
      left join public.driver_locations dl
        on dl.recorded_at::date = p_target_date
       and extensions.st_within(dl.location::extensions.geometry, z.boundary::extensions.geometry)
     group by z.service_zone_id
  )
  insert into public.zone_metrics (
    metric_date, service_zone_id, demand_score, supply_available_minutes,
    avg_eta_minutes, surge_multiplier_avg, jobs_requested, jobs_fulfilled, computed_at
  )
  select p_target_date,
         z.service_zone_id,
         least(
           100,
           coalesce(
             (jz.jobs_requested::numeric / greatest(coalesce(jz.active_drivers, 0), 1)) * 25,
             0
           )
         )::numeric(6,2),
         coalesce(sz.supply_available_minutes, 0),
         jz.avg_eta_minutes,
         jz.surge_multiplier_avg,
         coalesce(jz.jobs_requested, 0),
         coalesce(jz.jobs_fulfilled, 0),
         now()
    from zone_base z
    left join job_zone jz on jz.service_zone_id = z.service_zone_id
    left join supply_zone sz on sz.service_zone_id = z.service_zone_id
  on conflict on constraint zone_metrics_scope_key do update
    set demand_score = excluded.demand_score,
        supply_available_minutes = excluded.supply_available_minutes,
        avg_eta_minutes = excluded.avg_eta_minutes,
        surge_multiplier_avg = excluded.surge_multiplier_avg,
        jobs_requested = excluded.jobs_requested,
        jobs_fulfilled = excluded.jobs_fulfilled,
        computed_at = excluded.computed_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Driver metrics
-- ----------------------------------------------------------------------------
create or replace function public.compute_driver_metrics(p_target_date date default current_date - 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (private.is_service_context() or public.has_permission('manage_analytics')) then
    raise exception 'insufficient privileges to compute driver metrics'
      using errcode = '42501';
  end if;

  with driver_base as (
    select d.id as driver_id,
           cur.code as currency_code
      from public.drivers d
      join public.countries co on co.id = d.country_id
      join public.currencies cur on cur.id = co.default_currency_id
  ),
  trip_stats as (
    select j.driver_id,
           count(*) filter (where j.status = 'completed' and j.completed_at::date = p_target_date)::integer as trips_completed,
           avg(j.actual_distance_km) filter (
             where j.status = 'completed' and j.completed_at::date = p_target_date
           )::numeric(8,2) as avg_distance_km,
           avg(case
                 when j.scheduled_at is not null and j.completed_at <= j.scheduled_at + interval '15 minutes'
                 then 1.0 else 0.0
               end) filter (
                 where j.status = 'completed'
                   and j.completed_at::date = p_target_date
                   and j.scheduled_at is not null
               )::numeric(5,4) as on_time_rate
      from public.jobs j
     where j.driver_id is not null
       and (j.created_at::date = p_target_date
            or j.completed_at::date = p_target_date)
     group by j.driver_id
  ),
  location_stats as (
    select dl.driver_id,
           least(24, (count(*) * 5.0 / 60.0))::numeric(6,2) as hours_online
      from public.driver_locations dl
     where dl.recorded_at::date = p_target_date
     group by dl.driver_id
  ),
  earning_stats as (
    select cl.driver_id,
           coalesce(sum(cl.driver_gross_earning), 0)::numeric(14,2) as earnings_gross,
           coalesce(sum(cl.driver_net_earning), 0)::numeric(14,2) as earnings_net
      from public.commission_ledger cl
     where cl.calculated_at::date = p_target_date
     group by cl.driver_id
  ),
  rating_stats as (
    select r.rated_profile_id as driver_id,
           avg(r.score)::numeric(3,2) as avg_rating
      from public.ratings r
     where r.rated_role = 'driver'
       and r.created_at::date = p_target_date
     group by r.rated_profile_id
  )
  insert into public.driver_metrics (
    metric_date, driver_id, trips_completed, hours_online,
    earnings_gross, earnings_net, currency_code,
    acceptance_rate, on_time_rate, avg_rating, avg_distance_km, computed_at
  )
  select p_target_date,
         db.driver_id,
         coalesce(ts.trips_completed, 0),
         ls.hours_online,
         coalesce(es.earnings_gross, 0),
         coalesce(es.earnings_net, 0),
         db.currency_code,
         das.acceptance_rate,
         ts.on_time_rate,
         rs.avg_rating,
         ts.avg_distance_km,
         now()
    from driver_base db
    left join trip_stats ts on ts.driver_id = db.driver_id
    left join location_stats ls on ls.driver_id = db.driver_id
    left join earning_stats es on es.driver_id = db.driver_id
    left join public.driver_acceptance_stats das on das.driver_id = db.driver_id
    left join rating_stats rs on rs.driver_id = db.driver_id
  on conflict on constraint driver_metrics_scope_key do update
    set trips_completed = excluded.trips_completed,
        hours_online = excluded.hours_online,
        earnings_gross = excluded.earnings_gross,
        earnings_net = excluded.earnings_net,
        currency_code = excluded.currency_code,
        acceptance_rate = excluded.acceptance_rate,
        on_time_rate = excluded.on_time_rate,
        avg_rating = excluded.avg_rating,
        avg_distance_km = excluded.avg_distance_km,
        computed_at = excluded.computed_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Customer metrics
-- ----------------------------------------------------------------------------
create or replace function public.compute_customer_metrics(p_target_date date default current_date - 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (private.is_service_context() or public.has_permission('manage_analytics')) then
    raise exception 'insufficient privileges to compute customer metrics'
      using errcode = '42501';
  end if;

  with customer_base as (
    select p.id as customer_id,
           cur.code as currency_code
      from public.profiles p
      join public.countries co on co.id = p.default_country_id
      join public.currencies cur on cur.id = co.default_currency_id
     where p.primary_role = 'customer'
  ),
  job_stats as (
    select j.customer_id,
           count(*) filter (where j.created_at::date = p_target_date)::integer as jobs_created,
           count(*) filter (where j.status = 'completed' and j.completed_at::date = p_target_date)::integer as jobs_completed
      from public.jobs j
     where j.created_at::date = p_target_date
        or j.completed_at::date = p_target_date
     group by j.customer_id
  ),
  spend_stats as (
    select pay.customer_id,
           coalesce(sum(pay.amount), 0)::numeric(14,2) as total_spent
      from public.payments pay
     where pay.payment_type = 'charge'
       and pay.provider_status = 'succeeded'
       and pay.completed_at::date = p_target_date
     group by pay.customer_id
  ),
  rating_stats as (
    select r.rater_profile_id as customer_id,
           avg(r.score)::numeric(3,2) as avg_rating_given
      from public.ratings r
     where r.rater_profile_id in (select customer_id from customer_base)
       and r.created_at::date = p_target_date
     group by r.rater_profile_id
  ),
  activity_stats as (
    select j.customer_id,
           greatest(
             max(j.created_at),
             max(j.completed_at),
             max(j.cancelled_at)
           ) as last_job_activity
      from public.jobs j
     where j.created_at::date = p_target_date
        or j.completed_at::date = p_target_date
        or j.cancelled_at::date = p_target_date
     group by j.customer_id
  )
  insert into public.customer_metrics (
    metric_date, customer_id, jobs_created, jobs_completed,
    total_spent, currency_code, avg_rating_given, last_active_at, computed_at
  )
  select p_target_date,
         cb.customer_id,
         coalesce(js.jobs_created, 0),
         coalesce(js.jobs_completed, 0),
         coalesce(ss.total_spent, 0),
         cb.currency_code,
         rs.avg_rating_given,
         greatest(p.last_login_at, asx.last_job_activity),
         now()
    from customer_base cb
    join public.profiles p on p.id = cb.customer_id
    left join job_stats js on js.customer_id = cb.customer_id
    left join spend_stats ss on ss.customer_id = cb.customer_id
    left join rating_stats rs on rs.customer_id = cb.customer_id
    left join activity_stats asx on asx.customer_id = cb.customer_id
  on conflict on constraint customer_metrics_scope_key do update
    set jobs_created = excluded.jobs_created,
        jobs_completed = excluded.jobs_completed,
        total_spent = excluded.total_spent,
        currency_code = excluded.currency_code,
        avg_rating_given = excluded.avg_rating_given,
        last_active_at = excluded.last_active_at,
        computed_at = excluded.computed_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Demand snapshot (five-minute bucket)
-- ----------------------------------------------------------------------------
create or replace function public.capture_demand_snapshot()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bucket timestamptz := to_timestamp(floor(extract(epoch from now()) / 300) * 300);
  v_count integer;
begin
  if not (private.is_service_context() or public.has_permission('manage_analytics')) then
    raise exception 'insufficient privileges to capture demand snapshot'
      using errcode = '42501';
  end if;

  with zone_base as (
    select z.id as service_zone_id, z.city_id, z.boundary
      from public.service_zones z
     where z.is_active
  ),
  demand as (
    select z.service_zone_id,
           count(j.id)::integer as active_job_requests,
           avg(extract(epoch from (now() - j.created_at)))::numeric(8,2) as avg_wait_seconds
      from zone_base z
      left join public.jobs j on j.city_id = z.city_id
      left join public.quotes q on q.id = j.quote_id
      left join public.quote_requests qr on qr.id = q.quote_request_id
     where j.status in ('requested', 'quoted', 'matched', 'accepted', 'heading_to_pickup', 'arrived', 'loading', 'in_transit')
       and extensions.st_within(qr.pickup_location::extensions.geometry, z.boundary::extensions.geometry)
     group by z.service_zone_id
  ),
  supply as (
    select z.service_zone_id,
           count(d.id)::integer as active_drivers
      from zone_base z
      left join public.drivers d
        on d.is_available
       and d.current_location is not null
       and extensions.st_within(d.current_location::extensions.geometry, z.boundary::extensions.geometry)
     group by z.service_zone_id
  ),
  offers as (
    select z.service_zone_id,
           count(jo.id)::integer as pending_offers
      from zone_base z
      left join public.jobs j on j.city_id = z.city_id
      left join public.quotes q on q.id = j.quote_id
      left join public.quote_requests qr on qr.id = q.quote_request_id
      left join public.job_offers jo
        on jo.job_id = j.id
       and jo.response = 'pending'
       and jo.expires_at > now()
     where extensions.st_within(qr.pickup_location::extensions.geometry, z.boundary::extensions.geometry)
     group by z.service_zone_id
  )
  insert into public.demand_snapshots (
    snapshot_at, service_zone_id, active_job_requests,
    active_drivers, pending_offers, avg_wait_seconds, computed_at
  )
  select v_bucket,
         z.service_zone_id,
         coalesce(d.active_job_requests, 0),
         coalesce(s.active_drivers, 0),
         coalesce(o.pending_offers, 0),
         d.avg_wait_seconds,
         now()
    from zone_base z
    left join demand d on d.service_zone_id = z.service_zone_id
    left join supply s on s.service_zone_id = z.service_zone_id
    left join offers o on o.service_zone_id = z.service_zone_id
  on conflict on constraint demand_snapshots_scope_key do update
    set active_job_requests = excluded.active_job_requests,
        active_drivers = excluded.active_drivers,
        pending_offers = excluded.pending_offers,
        avg_wait_seconds = excluded.avg_wait_seconds,
        computed_at = excluded.computed_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Chat archive lifecycle
-- ----------------------------------------------------------------------------
create or replace function public.archive_stale_chat_threads()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (private.is_service_context() or public.has_permission('manage_retention')) then
    raise exception 'insufficient privileges to archive chat threads'
      using errcode = '42501';
  end if;

  update public.chat_threads t
     set status = 'read_only',
         updated_at = now()
    from public.jobs j
   where t.job_id = j.id
     and t.status = 'active'
     and j.status in ('completed', 'cancelled')
     and coalesce(j.completed_at, j.cancelled_at) >= now() - interval '30 days';

  update public.chat_threads t
     set status = 'archived',
         archived_at = coalesce(t.archived_at, now()),
         updated_at = now()
    from public.jobs j
   where t.job_id = j.id
     and t.status <> 'archived'
     and j.status in ('completed', 'cancelled')
     and coalesce(j.completed_at, j.cancelled_at) < now() - interval '30 days';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Retention runner
-- ----------------------------------------------------------------------------
create or replace function public.apply_retention_policies()
returns table(table_name text, rows_deleted bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_schema text;
  v_table text;
  v_key text;
  v_partitioned boolean;
  v_drop_only boolean;
  v_cutoff timestamptz;
  v_rows bigint;
  v_part_rows bigint;
  v_deleted bigint;
  v_part record;
  v_suffix text;
  v_month date;
begin
  if not (private.is_service_context() or public.has_permission('manage_retention')) then
    raise exception 'insufficient privileges to apply retention policies'
      using errcode = '42501';
  end if;

  perform public.archive_stale_chat_threads();

  for r in
    select * from public.retention_policies where is_active order by table_name
  loop
    v_rows := 0;
    v_schema := null;
    v_table := null;
    v_key := null;
    v_partitioned := false;
    v_drop_only := false;

    case r.table_name
      when 'driver_locations' then
        v_schema := 'public'; v_table := 'driver_locations'; v_key := 'recorded_at';
        v_partitioned := true; v_drop_only := false;
      when 'job_events' then
        v_schema := 'public'; v_table := 'job_events'; v_key := 'created_at';
        v_partitioned := true; v_drop_only := true;
      when 'audit_log' then
        v_schema := 'private'; v_table := 'audit_log'; v_key := 'created_at';
        v_partitioned := true; v_drop_only := true;
      when 'chat_messages' then
        v_schema := 'public'; v_table := 'chat_messages'; v_key := 'created_at';
        v_partitioned := true; v_drop_only := false;
      when 'notification_log' then
        v_schema := 'public'; v_table := 'notification_log'; v_key := 'created_at';
        v_partitioned := true; v_drop_only := false;
      when 'data_access_log' then
        v_schema := 'public'; v_table := 'data_access_log'; v_key := 'created_at';
        v_partitioned := true; v_drop_only := false;
      when 'demand_snapshots' then
        v_schema := 'public'; v_table := 'demand_snapshots'; v_key := 'snapshot_at';
        v_partitioned := true; v_drop_only := false;
      else
        null;
    end case;

    if v_table is null or r.action <> 'delete' or r.table_name = 'daily_metrics' then
      table_name := r.table_name;
      rows_deleted := 0;
      return next;
      continue;
    end if;

    if to_regclass(format('%I.%I', v_schema, v_table)) is null then
      table_name := r.table_name;
      rows_deleted := 0;
      return next;
      continue;
    end if;

    v_cutoff := now() - r.retention_period;

    if v_partitioned then
      for v_part in
        select c.relname
          from pg_inherits i
          join pg_class p on p.oid = i.inhparent
          join pg_namespace pn on pn.oid = p.relnamespace
          join pg_class c on c.oid = i.inhrelid
         where pn.nspname = v_schema
           and p.relname = v_table
           and c.relname ~ ('^' || v_table || '_[0-9]{4}_[0-9]{2}$')
      loop
        v_suffix := substring(v_part.relname from '([0-9]{4}_[0-9]{2})$');
        v_month := to_date(v_suffix, 'YYYY_MM');
        if (v_month + interval '1 month') <= v_cutoff then
          execute format('select count(*) from %I.%I', v_schema, v_part.relname)
            into v_part_rows;
          execute format('drop table %I.%I', v_schema, v_part.relname);
          v_rows := v_rows + v_part_rows;
        end if;
      end loop;
    end if;

    if not v_drop_only then
      execute format('delete from %I.%I where %I < $1', v_schema, v_table, v_key)
        using v_cutoff;
      get diagnostics v_deleted = row_count;
      v_rows := v_rows + v_deleted;
    end if;

    update public.retention_policies
       set last_run_at = now(),
           last_run_rows_affected = v_rows
     where id = r.id;

    table_name := r.table_name;
    rows_deleted := v_rows;
    return next;
  end loop;

  return;
end;
$$;

comment on function public.apply_retention_policies() is
  'Drops old monthly partitions where possible, then deletes leftover rows for non-append-only tables. Append-only tables are partition-drop only.';

revoke all on function public.compute_daily_metrics(date) from public;
revoke all on function public.compute_zone_metrics(date) from public;
revoke all on function public.compute_driver_metrics(date) from public;
revoke all on function public.compute_customer_metrics(date) from public;
revoke all on function public.capture_demand_snapshot() from public;
revoke all on function public.apply_retention_policies() from public;
revoke all on function public.archive_stale_chat_threads() from public;
grant execute on function public.compute_daily_metrics(date) to authenticated, service_role;
grant execute on function public.compute_zone_metrics(date) to authenticated, service_role;
grant execute on function public.compute_driver_metrics(date) to authenticated, service_role;
grant execute on function public.compute_customer_metrics(date) to authenticated, service_role;
grant execute on function public.capture_demand_snapshot() to authenticated, service_role;
grant execute on function public.apply_retention_policies() to authenticated, service_role;
grant execute on function public.archive_stale_chat_threads() to authenticated, service_role;
