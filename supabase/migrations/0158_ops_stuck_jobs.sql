-- Operations view of moves that are not progressing.
--
-- Each live job is measured against a time limit for its current stage.
-- Anything over the limit, or with a driver whose GPS has gone quiet, is
-- returned with a plain-language issue and the action operations can take
-- (re-dispatch, release the driver, or cancel), using the existing
-- job_request_dispatch, job_driver_release and job_cancel functions.

create or replace function public.admin_stuck_jobs(p_limit integer default 100)
returns table (
  job_id               uuid,
  status               public.job_status,
  issue                text,
  minutes_in_status    integer,
  created_at           timestamptz,
  customer_id          uuid,
  customer_name        text,
  driver_id            uuid,
  driver_name          text,
  driver_gps_minutes   integer,
  dispatch_attempts    integer,
  suggested_action     text
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
    or public.has_permission('assign_drivers')
  ) then
    raise exception 'not authorised to view operations queues' using errcode = '42501';
  end if;

  return query
  with live as (
    select
      j.*,
      coalesce((
        select max(h.created_at) from public.job_status_history h
        where h.job_id = j.id and h.to_status = j.status
      ), j.accepted_at, j.created_at) as status_since,
      d.location_updated_at
    from public.jobs j
    left join public.drivers d on d.id = j.driver_id
    where j.status not in ('completed', 'cancelled', 'disputed')
  ),
  measured as (
    select
      l.*,
      floor(extract(epoch from (now() - l.status_since)) / 60)::integer as mins,
      case when l.driver_id is null or l.location_updated_at is null then null
           else floor(extract(epoch from (now() - l.location_updated_at)) / 60)::integer
      end as gps_mins
    from live l
  ),
  flagged as (
    select
      m.*,
      case
        when m.driver_id is null and m.status in ('requested', 'quoted', 'matched')
             and coalesce(m.scheduled_at, m.created_at) <= now()
             and m.mins >= 10
          then 'Still searching for a driver'
        when m.status in ('accepted', 'heading_to_pickup') and m.mins >= 45
          then 'Driver has not reached the pickup'
        when m.status = 'arrived' and m.mins >= 30
          then 'Driver waiting at pickup for a long time'
        when m.status in ('cargo_verified', 'loading') and m.mins >= 60
          then 'Loading is taking unusually long'
        when m.status = 'in_transit'
             and m.mins >= greatest(120, ceil(coalesce(m.distance_km, 0) * 6))::integer
          then 'Trip is taking much longer than expected'
        when m.status = 'arrived_destination' and m.mins >= 60
          then 'Handover at the destination has not finished'
        when m.status = 'delivered' and m.mins >= 24 * 60
          then 'Delivered but never completed'
        when m.driver_id is not null
             and m.status in ('heading_to_pickup', 'arrived', 'cargo_verified',
                              'loading', 'in_transit', 'arrived_destination')
             and coalesce(m.gps_mins, 999) >= 15
          then 'Driver GPS has gone quiet'
        else null
      end as issue
    from measured m
  )
  select
    f.id,
    f.status,
    f.issue,
    f.mins,
    f.created_at,
    f.customer_id,
    coalesce(cp.full_name, cp.display_name),
    f.driver_id,
    coalesce(dp.full_name, dp.display_name),
    f.gps_mins,
    f.dispatch_attempts::integer,
    case
      when f.driver_id is null then 'redispatch'
      when f.status in ('accepted', 'heading_to_pickup', 'arrived') then 'release'
      else 'contact'
    end
  from flagged f
  left join public.profiles cp on cp.id = f.customer_id
  left join public.profiles dp on dp.id = f.driver_id
  where f.issue is not null
  order by f.mins desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$$;

comment on function public.admin_stuck_jobs(integer) is
  'Live jobs over the time limit for their stage, or with a silent driver GPS, with the suggested operations action.';

revoke all on function public.admin_stuck_jobs(integer) from public, anon;
grant execute on function public.admin_stuck_jobs(integer) to authenticated, service_role;
