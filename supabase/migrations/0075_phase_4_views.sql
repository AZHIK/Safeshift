-- ============================================================================
-- SafeShift — Phase 4 / Migration 0075
-- Operational read models. Every view uses security_invoker so the caller's
-- RLS policies on the underlying tables remain in force.
-- ============================================================================

create or replace view public.job_summary
with (security_invoker = true)
as
select
  j.id as job_id,
  j.quote_id,
  cp.full_name as customer_name,
  dp.full_name as driver_name,
  j.status,
  coalesce(pickup.address, qr.pickup_address) as pickup_address,
  coalesce(dropoff.address, qr.destination_address) as destination_address,
  j.scheduled_at,
  j.final_amount,
  coalesce(j.final_currency_code, q.currency_code) as currency_code,
  (select count(*)::integer from public.ratings r where r.job_id = j.id) as rating_count
from public.jobs j
join public.quotes q on q.id = j.quote_id
join public.quote_requests qr on qr.id = q.quote_request_id
join public.profiles cp on cp.id = j.customer_id
left join public.profiles dp on dp.id = j.driver_id
left join lateral (
  select s.address
  from public.job_stops s
  where s.job_id = j.id
    and s.stop_type = 'pickup'
  order by s.stop_sequence
  limit 1
) pickup on true
left join lateral (
  select s.address
  from public.job_stops s
  where s.job_id = j.id
    and s.stop_type = 'dropoff'
  order by s.stop_sequence desc
  limit 1
) dropoff on true;

comment on view public.job_summary is
  'Participant/staff job list with customer and driver names, resolved pickup/drop-off addresses, final amount and rating count.';

create or replace view public.active_jobs_by_driver
with (security_invoker = true)
as
select
  j.driver_id,
  j.id as job_id,
  j.status,
  j.scheduled_at,
  coalesce(pickup.address, qr.pickup_address) as pickup_address,
  round(
    (
      extensions.ST_Distance(
        dl.location,
        coalesce(pickup.location, qr.pickup_location)
      ) / 1000.0
    )::numeric,
    2
  ) as distance_to_pickup_km
from public.jobs j
join public.quotes q on q.id = j.quote_id
join public.quote_requests qr on qr.id = q.quote_request_id
left join lateral (
  select s.address, s.location
  from public.job_stops s
  where s.job_id = j.id
    and s.stop_type = 'pickup'
  order by s.stop_sequence
  limit 1
) pickup on true
left join lateral (
  select dl.location
  from public.driver_locations dl
  where dl.driver_id = j.driver_id
  order by dl.recorded_at desc
  limit 1
) dl on true
where j.driver_id is not null
  and j.status not in ('completed', 'cancelled', 'disputed');

comment on view public.active_jobs_by_driver is
  'Non-terminal jobs for each assigned driver with the driver current location distance to the pickup stop.';

create or replace view public.driver_dashboard_summary
with (security_invoker = true)
as
select
  d.id as driver_id,
  count(*) filter (
    where j.status = 'completed'
      and j.completed_at >= date_trunc('day', now())
  )::integer as today_trips,
  coalesce(sum(j.final_amount) filter (
    where j.status = 'completed'
      and j.completed_at >= date_trunc('day', now())
  ), 0)::numeric(14,2) as today_earnings,
  count(*) filter (
    where j.status = 'completed'
      and j.completed_at >= date_trunc('week', now())
  )::integer as week_trips,
  coalesce(sum(j.final_amount) filter (
    where j.status = 'completed'
      and j.completed_at >= date_trunc('week', now())
  ), 0)::numeric(14,2) as week_earnings,
  (
    select count(*)::integer
    from public.job_offers o
    where o.driver_id = d.id
      and o.response = 'pending'
      and o.expires_at > now()
  ) as active_offer_count,
  s.acceptance_rate as acceptance_rate_30d,
  (
    select round(avg(r.score)::numeric, 2)
    from public.ratings r
    where r.rated_profile_id = d.id
      and r.rated_role = 'driver'
      and r.created_at >= now() - interval '30 days'
  ) as rating_30d
from public.drivers d
left join public.jobs j on j.driver_id = d.id
left join public.driver_acceptance_stats s on s.driver_id = d.id
group by d.id, s.acceptance_rate;

comment on view public.driver_dashboard_summary is
  'Per-driver today/week completed trips and gross earnings, open offer count, 30-day acceptance rate and 30-day rating.';

create or replace view public.quote_summary
with (security_invoker = true)
as
select
  q.id as quote_id,
  q.quote_request_id,
  p.full_name as customer_name,
  vt.name as vehicle_type_name,
  q.total,
  q.currency_code,
  q.expires_at,
  q.created_at
from public.quotes q
join public.quote_requests qr on qr.id = q.quote_request_id
join public.profiles p on p.id = qr.customer_id
join public.vehicle_types vt on vt.id = qr.vehicle_type_id;

comment on view public.quote_summary is
  'Quote list with customer, vehicle type, final total and validity window. Underlying quote RLS decides visibility.';

create or replace view public.dispute_summary
with (security_invoker = true)
as
select
  d.id as dispute_id,
  d.job_id,
  d.dispute_type,
  d.status,
  d.priority,
  rp.full_name as raised_by_name,
  coalesce(res.full_name, 'Unassigned') as assigned_to_name,
  d.sla_due_at,
  round(extract(epoch from (now() - d.created_at)) / 3600.0, 1) as age_hours
from public.disputes d
join public.profiles rp on rp.id = d.raised_by
left join public.profiles res on res.id = d.resolved_by;

comment on view public.dispute_summary is
  'Dispute queue with raiser name, SLA deadline and age. assigned_to_name is derived from disputes.resolved_by because the Phase 4 schema has no separate assignee column.';

create or replace view public.matching_performance
with (security_invoker = true)
as
select
  started_at::date as date,
  count(*)::integer as total_attempts,
  round(
    count(*) filter (where match_successful)::numeric / nullif(count(*), 0),
    4
  ) as success_rate,
  round(
    avg(attempt_number) filter (where match_successful),
    2
  ) as avg_attempts_to_match,
  round(
    avg(extract(epoch from (ended_at - started_at))) filter (
      where match_successful and ended_at is not null
    ),
    2
  ) as avg_seconds_to_match
from public.matching_attempts
group by started_at::date;

comment on view public.matching_performance is
  'Daily dispatch efficiency: attempt volume, success rate, attempts per successful match and seconds to match.';

revoke all on
  public.job_summary,
  public.active_jobs_by_driver,
  public.driver_dashboard_summary,
  public.quote_summary,
  public.dispute_summary,
  public.matching_performance
from anon, authenticated;

grant select on
  public.job_summary,
  public.active_jobs_by_driver,
  public.driver_dashboard_summary,
  public.quote_summary,
  public.dispute_summary,
  public.matching_performance
to authenticated;
