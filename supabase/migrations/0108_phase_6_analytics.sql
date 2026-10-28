-- ============================================================================
-- 0108 — Phase 6: analytics and monitoring tables
-- ============================================================================
-- All analytics are batch-computed nightly (and every five minutes for demand
-- snapshots). No real-time aggregation is performed by the application.
-- ============================================================================

create table public.daily_metrics (
  id bigint generated always as identity primary key,
  metric_date date not null,
  country_id uuid not null references public.countries(id) on delete cascade,
  city_id uuid references public.cities(id) on delete cascade,
  jobs_created integer not null default 0,
  jobs_completed integer not null default 0,
  jobs_cancelled integer not null default 0,
  gross_booking_value numeric(14,2) not null default 0,
  net_revenue numeric(14,2) not null default 0,
  currency_code char(3) not null references public.currencies(code),
  active_customers integer not null default 0,
  active_drivers integer not null default 0,
  new_customers integer not null default 0,
  new_drivers integer not null default 0,
  avg_acceptance_rate numeric(5,4),
  avg_completion_minutes numeric(8,2),
  avg_cancellation_rate numeric(5,4),
  avg_rating numeric(3,2),
  computed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint daily_metrics_counts_check
    check (jobs_created >= 0 and jobs_completed >= 0 and jobs_cancelled >= 0
       and active_customers >= 0 and active_drivers >= 0
       and new_customers >= 0 and new_drivers >= 0),
  constraint daily_metrics_money_check
    check (gross_booking_value >= 0 and net_revenue >= 0),
  constraint daily_metrics_acceptance_check
    check (avg_acceptance_rate is null or (avg_acceptance_rate >= 0 and avg_acceptance_rate <= 1)),
  constraint daily_metrics_cancellation_check
    check (avg_cancellation_rate is null or (avg_cancellation_rate >= 0 and avg_cancellation_rate <= 1)),
  constraint daily_metrics_completion_check
    check (avg_completion_minutes is null or avg_completion_minutes >= 0),
  constraint daily_metrics_rating_check
    check (avg_rating is null or (avg_rating >= 0 and avg_rating <= 5)),
  constraint daily_metrics_scope_key
    unique nulls not distinct (metric_date, country_id, city_id)
);

create table public.zone_metrics (
  id bigint generated always as identity primary key,
  metric_date date not null,
  service_zone_id uuid not null references public.service_zones(id) on delete cascade,
  demand_score numeric(6,2),
  supply_available_minutes bigint,
  avg_eta_minutes numeric(8,2),
  surge_multiplier_avg numeric(6,4),
  jobs_requested integer not null default 0,
  jobs_fulfilled integer not null default 0,
  computed_at timestamptz not null default now(),
  constraint zone_metrics_demand_check
    check (demand_score is null or (demand_score >= 0 and demand_score <= 100)),
  constraint zone_metrics_supply_check
    check (supply_available_minutes is null or supply_available_minutes >= 0),
  constraint zone_metrics_eta_check
    check (avg_eta_minutes is null or avg_eta_minutes >= 0),
  constraint zone_metrics_surge_check
    check (surge_multiplier_avg is null or surge_multiplier_avg > 0),
  constraint zone_metrics_jobs_check
    check (jobs_requested >= 0 and jobs_fulfilled >= 0),
  constraint zone_metrics_scope_key unique (metric_date, service_zone_id)
);

create table public.driver_metrics (
  id bigint generated always as identity primary key,
  metric_date date not null,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  trips_completed integer not null default 0,
  hours_online numeric(6,2),
  earnings_gross numeric(14,2) not null default 0,
  earnings_net numeric(14,2) not null default 0,
  currency_code char(3) not null references public.currencies(code),
  acceptance_rate numeric(5,4),
  on_time_rate numeric(5,4),
  avg_rating numeric(3,2),
  avg_distance_km numeric(8,2),
  computed_at timestamptz not null default now(),
  constraint driver_metrics_counts_check
    check (trips_completed >= 0),
  constraint driver_metrics_hours_check
    check (hours_online is null or (hours_online >= 0 and hours_online <= 24)),
  constraint driver_metrics_money_check
    check (earnings_gross >= 0 and earnings_net >= 0),
  constraint driver_metrics_acceptance_check
    check (acceptance_rate is null or (acceptance_rate >= 0 and acceptance_rate <= 1)),
  constraint driver_metrics_on_time_check
    check (on_time_rate is null or (on_time_rate >= 0 and on_time_rate <= 1)),
  constraint driver_metrics_rating_check
    check (avg_rating is null or (avg_rating >= 0 and avg_rating <= 5)),
  constraint driver_metrics_distance_check
    check (avg_distance_km is null or avg_distance_km >= 0),
  constraint driver_metrics_scope_key unique (metric_date, driver_id)
);

create table public.customer_metrics (
  id bigint generated always as identity primary key,
  metric_date date not null,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  jobs_created integer not null default 0,
  jobs_completed integer not null default 0,
  total_spent numeric(14,2) not null default 0,
  currency_code char(3) not null references public.currencies(code),
  avg_rating_given numeric(3,2),
  last_active_at timestamptz,
  computed_at timestamptz not null default now(),
  constraint customer_metrics_counts_check
    check (jobs_created >= 0 and jobs_completed >= 0),
  constraint customer_metrics_money_check
    check (total_spent >= 0),
  constraint customer_metrics_rating_check
    check (avg_rating_given is null or (avg_rating_given >= 0 and avg_rating_given <= 5)),
  constraint customer_metrics_scope_key unique (metric_date, customer_id)
);

create table public.demand_snapshots (
  id bigint generated always as identity,
  snapshot_at timestamptz not null,
  service_zone_id uuid not null references public.service_zones(id) on delete cascade,
  active_job_requests integer not null default 0,
  active_drivers integer not null default 0,
  pending_offers integer not null default 0,
  avg_wait_seconds numeric(8,2),
  computed_at timestamptz not null default now(),
  primary key (id, snapshot_at),
  constraint demand_snapshots_bucket_check
    check (date_trunc('minute', snapshot_at) = snapshot_at
           and extract(second from snapshot_at) = 0
           and extract(minute from snapshot_at)::integer % 5 = 0),
  constraint demand_snapshots_counts_check
    check (active_job_requests >= 0 and active_drivers >= 0 and pending_offers >= 0),
  constraint demand_snapshots_wait_check
    check (avg_wait_seconds is null or avg_wait_seconds >= 0),
  constraint demand_snapshots_scope_key unique (snapshot_at, service_zone_id)
) partition by range (snapshot_at);

create table public.demand_snapshots_default
  partition of public.demand_snapshots default;
revoke all on table public.demand_snapshots_default from anon, authenticated;

select private.ensure_monthly_partitions('public', 'demand_snapshots', 'snapshot_at', 3);
