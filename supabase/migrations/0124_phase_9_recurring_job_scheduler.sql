-- ============================================================================
-- SafeShift — Phase 9 / Migration 0124
-- Recurring job materialisation.
--
-- Phase 4 modelled recurring_job_templates and scheduled_jobs but left
-- occurrence generation to an operator. Phase 9 turns verified business
-- templates into concrete scheduled_jobs rows for the next 24 hours.
--
-- Supported RRULE subset (deliberately conservative):
--   FREQ=DAILY
--   FREQ=WEEKLY[;BYDAY=MO,WE,FR]
--   FREQ=MONTHLY
--
-- The function is idempotent because scheduled_jobs has
-- UNIQUE(template_id, scheduled_for).
-- ============================================================================

create or replace function public.generate_recurring_scheduled_jobs(
  p_horizon_hours integer default 24
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := now();
  v_horizon timestamptz := now() + make_interval(hours => greatest(1, least(coalesce(p_horizon_hours, 24), 168)));
  v_template record;
  v_freq text;
  v_byday text;
  v_days integer[];
  v_day integer;
  v_local_date date;
  v_local_now date;
  v_local_end date;
  v_candidate timestamptz;
  v_created_dow integer;
  v_created_dom integer;
  v_inserted integer := 0;
begin
  for v_template in
    select t.id,
           t.recurrence_rule,
           t.time_of_day,
           t.timezone,
           t.created_at
      from public.recurring_job_templates t
      join public.business_accounts b on b.id = t.business_account_id
     where t.is_active
       and b.is_active
       and b.verified_at is not null
  loop
    v_freq := upper(coalesce(substring(v_template.recurrence_rule from 'FREQ=([^;]+)'), ''));
    v_byday := upper(coalesce(substring(v_template.recurrence_rule from 'BYDAY=([^;]+)'), ''));
    v_days := array[]::integer[];

    if v_byday <> '' then
      foreach v_byday in array string_to_array(v_byday, ',') loop
        v_days := v_days || case btrim(v_byday)
          when 'MO' then 1 when 'TU' then 2 when 'WE' then 3 when 'TH' then 4
          when 'FR' then 5 when 'SA' then 6 when 'SU' then 7
          else null end;
      end loop;
    end if;

    v_local_now := (v_now at time zone v_template.timezone)::date;
    v_local_end := (v_horizon at time zone v_template.timezone)::date;
    v_created_dow := extract(isodow from (v_template.created_at at time zone v_template.timezone))::integer;
    v_created_dom := extract(day from (v_template.created_at at time zone v_template.timezone))::integer;

    for v_day in 0..greatest(0, (v_local_end - v_local_now)) loop
      v_local_date := v_local_now + v_day;

      if v_freq = 'DAILY'
         or (v_freq = 'WEEKLY' and (
              (cardinality(v_days) = 0 and extract(isodow from v_local_date)::integer = v_created_dow)
              or extract(isodow from v_local_date)::integer = any(v_days)
            ))
         or (v_freq = 'MONTHLY' and extract(day from v_local_date)::integer = v_created_dom)
      then
        v_candidate := (v_local_date + v_template.time_of_day) at time zone v_template.timezone;

        if v_candidate >= v_now and v_candidate <= v_horizon then
          insert into public.scheduled_jobs (
            template_id,
            scheduled_for,
            status,
            generated_at
          )
          values (
            v_template.id,
            v_candidate,
            'pending',
            now()
          )
          on conflict (template_id, scheduled_for) do nothing;

          if found then
            v_inserted := v_inserted + 1;
          end if;
        end if;
      end if;
    end loop;
  end loop;

  return v_inserted;
end;
$$;

comment on function public.generate_recurring_scheduled_jobs(integer) is
  'Materialises verified recurring_job_templates into scheduled_jobs for the next p_horizon_hours. Idempotent and safe to run hourly.';

revoke all on function public.generate_recurring_scheduled_jobs(integer) from public;
revoke all on function public.generate_recurring_scheduled_jobs(integer) from anon;
revoke all on function public.generate_recurring_scheduled_jobs(integer) from authenticated;
grant execute on function public.generate_recurring_scheduled_jobs(integer) to service_role;

-- pg_cron is part of the local Supabase stack and Phase 6 already uses it.
-- Guard the schedule so the migration remains portable to environments where
-- the extension is unavailable (the function can still be invoked manually).
do $$
declare
  v_job record;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for v_job in
      select jobid from cron.job where jobname = 'safeshift_generate_scheduled_jobs'
    loop
      perform cron.unschedule(v_job.jobid);
    end loop;

    perform cron.schedule(
      'safeshift_generate_scheduled_jobs',
      '17 * * * *',
      $cron$select public.generate_recurring_scheduled_jobs(24);$cron$
    );
  end if;
end $$;
