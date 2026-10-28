-- ============================================================================
-- 0116 — Phase 6: pg_cron schedules
-- ============================================================================
-- All Phase 6 maintenance is batch-only. The six schedules below are prefixed
-- safeshift_ so they are easy to identify alongside the Phase 4/5 jobs.
-- ============================================================================

do $$
declare
  j record;
begin
  for j in
    select jobid
      from cron.job
     where jobname in (
       'safeshift_compute_daily_metrics',
       'safeshift_compute_zone_metrics',
       'safeshift_compute_driver_metrics',
       'safeshift_compute_customer_metrics',
       'safeshift_capture_demand',
       'safeshift_retention'
     )
  loop
    perform cron.unschedule(j.jobid);
  end loop;
end;
$$;

select cron.schedule(
  'safeshift_compute_daily_metrics',
  '15 1 * * *',
  $$select public.compute_daily_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_compute_zone_metrics',
  '20 1 * * *',
  $$select public.compute_zone_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_compute_driver_metrics',
  '25 1 * * *',
  $$select public.compute_driver_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_compute_customer_metrics',
  '30 1 * * *',
  $$select public.compute_customer_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_capture_demand',
  '*/5 * * * *',
  $$select public.capture_demand_snapshot();$$
);

select cron.schedule(
  'safeshift_retention',
  '0 5 * * *',
  $$select public.apply_retention_policies();$$
);
