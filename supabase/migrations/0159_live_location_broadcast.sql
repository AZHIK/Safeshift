-- Live driver location over Realtime Broadcast.
--
-- During a trip the driver app broadcasts its position every few seconds on
-- the private channel `job-location:<job id>`. Broadcast messages are not
-- written to the database, so live tracking no longer costs a row insert, a
-- drivers update and a PII audit row per GPS fix. driver_locations still
-- receives a point every 30 seconds for history, dispatch and disputes.
--
-- Private channels are authorised by RLS on realtime.messages:
--   * send (insert): only the job's assigned driver;
--   * listen (select): the job's customer and assigned driver;
--   * only while the job is between accepted and arrived_destination.

create or replace function public.job_location_topic_allowed(
  p_topic text,
  p_send boolean
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor  uuid := auth.uid();
  v_job_id uuid;
begin
  if v_actor is null
     or p_topic is null
     or p_topic !~ '^job-location:[0-9a-fA-F-]{36}$'
  then
    return false;
  end if;

  v_job_id := substr(p_topic, length('job-location:') + 1)::uuid;

  return exists (
    select 1
    from public.jobs j
    where j.id = v_job_id
      and j.status between 'accepted' and 'arrived_destination'
      and (
        j.driver_id = v_actor
        or (not p_send and j.customer_id = v_actor)
      )
  );
end;
$$;

comment on function public.job_location_topic_allowed(text, boolean) is
  'Realtime authorisation for job-location:<job id> channels: the assigned driver may send; the customer and driver may listen, while the job is live.';

revoke all on function public.job_location_topic_allowed(text, boolean) from public, anon;
grant execute on function public.job_location_topic_allowed(text, boolean) to authenticated;

drop policy if exists job_location_broadcast_listen on realtime.messages;
create policy job_location_broadcast_listen
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and public.job_location_topic_allowed((select realtime.topic()), false)
  );

drop policy if exists job_location_broadcast_send on realtime.messages;
create policy job_location_broadcast_send
  on realtime.messages
  for insert
  to authenticated
  with check (
    realtime.messages.extension = 'broadcast'
    and public.job_location_topic_allowed((select realtime.topic()), true)
  );
