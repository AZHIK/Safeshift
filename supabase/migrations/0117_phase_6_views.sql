-- ============================================================================
-- 0117 — Phase 6: operational views
-- ============================================================================
-- All views use security_invoker so the caller's RLS policies apply. They are
-- convenience projections, not security boundaries.
-- ============================================================================

create or replace view public.notification_summary
with (security_invoker = true)
as
select
  profile_id,
  count(*) filter (where created_at >= current_date)::bigint as notification_count_today,
  count(*) filter (where created_at >= now() - interval '7 days')::bigint as notification_count_week,
  count(*) filter (where read_at is null and status <> 'failed')::bigint as unread_count,
  max(created_at) as last_notification_at
from public.notification_log
group by profile_id;

comment on view public.notification_summary is
  'Per-profile notification counts. RLS on notification_log limits rows to the caller.';

create or replace view public.chat_unread_summary
with (security_invoker = true)
as
select
  r.profile_id,
  t.id as thread_id,
  t.job_id,
  count(m.id) filter (
    where m.id > coalesce(r.last_read_message_id, 0)
      and not m.is_deleted
  )::bigint as unread_count,
  max(m.created_at) as last_message_at
from public.chat_read_receipts r
join public.chat_threads t on t.id = r.thread_id
left join public.chat_messages m on m.thread_id = t.id
group by r.profile_id, t.id, t.job_id, r.last_read_message_id;

comment on view public.chat_unread_summary is
  'Unread chat counts based on each participant read receipt.';

create or replace view public.incident_summary
with (security_invoker = true)
as
select
  i.id,
  i.job_id,
  i.incident_type,
  i.severity,
  i.status,
  reporter.full_name as reported_by_name,
  assignee.full_name as assigned_to_name,
  round(extract(epoch from (now() - i.created_at)) / 3600.0, 2)::numeric(10,2) as age_hours
from public.incidents i
left join public.profiles reporter on reporter.id = i.reported_by
left join public.profiles assignee on assignee.id = i.assigned_to;

comment on view public.incident_summary is
  'Incident queue projection with reporter/assignee names and age.';

create or replace view public.support_ticket_summary
with (security_invoker = true)
as
select
  t.ticket_number,
  t.subject,
  t.status,
  t.priority,
  opener.full_name as opened_by_name,
  assignee.full_name as assigned_to_name,
  round(extract(epoch from (now() - t.created_at)) / 3600.0, 2)::numeric(10,2) as age_hours,
  (t.sla_due_at is not null
   and t.sla_due_at < now()
   and t.status not in ('resolved', 'closed')) as sla_breached
from public.support_tickets t
left join public.profiles opener on opener.id = t.opened_by
left join public.profiles assignee on assignee.id = t.assigned_to;

comment on view public.support_ticket_summary is
  'Support queue projection with SLA breach status.';

create or replace view public.active_demand_zones
with (security_invoker = true)
as
with latest as (
  select distinct on (service_zone_id)
    service_zone_id,
    snapshot_at,
    active_job_requests,
    active_drivers,
    pending_offers,
    avg_wait_seconds
  from public.demand_snapshots
  order by service_zone_id, snapshot_at desc
)
select
  l.service_zone_id,
  z.name as zone_name,
  least(
    100,
    round(
      (l.active_job_requests::numeric / greatest(l.active_drivers, 1)) * 25,
      2
    )
  )::numeric(6,2) as current_demand_score,
  l.active_drivers as current_supply,
  l.avg_wait_seconds
from latest l
join public.service_zones z on z.id = l.service_zone_id;

comment on view public.active_demand_zones is
  'Latest five-minute demand snapshot per active zone.';

create or replace view public.operational_dashboard
with (security_invoker = true)
as
select
  current_date as metric_date,
  coalesce((
    select sum(dm.jobs_created)
      from public.daily_metrics dm
     where dm.metric_date = current_date
  ), 0)::bigint as jobs_today,
  coalesce((
    select sum(dm.jobs_completed)
      from public.daily_metrics dm
     where dm.metric_date = current_date
  ), 0)::bigint as completed_today,
  (
    select count(*)
      from public.incidents i
     where i.status in ('open', 'investigating')
  )::bigint as active_incidents,
  (
    select count(*)
      from public.support_tickets t
     where t.status in ('open', 'in_progress', 'waiting_customer')
  )::bigint as open_tickets,
  coalesce((
    select sum(cus.unread_count)
      from public.chat_unread_summary cus
  ), 0)::bigint as unread_chats;

comment on view public.operational_dashboard is
  'Single-row operational snapshot. RLS on the underlying tables limits what each caller sees.';

grant select on public.notification_summary to authenticated;
grant select on public.chat_unread_summary to authenticated;
grant select on public.incident_summary to authenticated;
grant select on public.support_ticket_summary to authenticated;
grant select on public.active_demand_zones to authenticated;
grant select on public.operational_dashboard to authenticated;
