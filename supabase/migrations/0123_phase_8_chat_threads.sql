-- ============================================================================
-- SafeShift — Phase 8 / Migration 0123
-- Client-created chat threads for job evidence/attachments.
--
-- Phase 6 models one chat thread per job, but only the service layer could
-- create it. The mobile apps now need to attach photos and messages directly,
-- so this function lets either job participant create the thread idempotently.
-- ============================================================================

create or replace function public.ensure_job_chat_thread(p_job_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_thread_id uuid;
  v_status public.job_status;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select j.status into v_status
  from public.jobs j
  where j.id = p_job_id
    and (j.customer_id = v_actor or j.driver_id = v_actor);

  if not found then
    raise exception 'job % not found for this participant', p_job_id
      using errcode = '42501';
  end if;

  if v_status in ('cancelled', 'disputed') then
    raise exception 'chat is unavailable for a % job', v_status
      using errcode = '23514';
  end if;

  insert into public.chat_threads (job_id, status)
  values (p_job_id, case when v_status in ('completed', 'delivered')
                         then 'read_only' else 'active' end)
  on conflict (job_id) do update
    set updated_at = now()
  returning id into v_thread_id;

  return v_thread_id;
end;
$$;

comment on function public.ensure_job_chat_thread(uuid) is
  'Idempotently creates the one chat thread for a job when called by its customer or assigned driver.';

revoke all on function public.ensure_job_chat_thread(uuid) from public;
revoke all on function public.ensure_job_chat_thread(uuid) from anon;
grant execute on function public.ensure_job_chat_thread(uuid) to authenticated, service_role;
