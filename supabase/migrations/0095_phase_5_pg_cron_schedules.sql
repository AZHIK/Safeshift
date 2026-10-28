-- ============================================================================
-- SafeShift — Phase 5 / Migration 0095
-- pg_cron maintenance schedules.
--
-- pg_cron is created by Phase 1 migration 0001. Production Supabase projects
-- need the pg_cron feature enabled (Pro plan for multi-schedule workloads).
-- ============================================================================

do $$
declare
  v_job record;
begin
  for v_job in
    select jobname from cron.job where jobname like 'safeshift_%'
  loop
    perform cron.unschedule(v_job.jobname);
  end loop;

  perform cron.schedule(
    'safeshift_expire_offers',
    '30 seconds',
    'SELECT public.expire_stale_offers()'
  );

  perform cron.schedule(
    'safeshift_quote_cleanup',
    '0 3 * * *',
    'SELECT public.quote_cleanup()'
  );

  perform cron.schedule(
    'safeshift_acceptance_stats',
    '0 2 * * *',
    'SELECT public.recompute_all_driver_acceptance_stats()'
  );

  perform cron.schedule(
    'safeshift_wallet_verify',
    '0 4 * * *',
    'SELECT public.wallet_balance_verify()'
  );
end $$;

comment on extension pg_cron is
  'SafeShift schedules: expire offers every 30s, quote cleanup 03:00, acceptance stats 02:00, wallet verification 04:00.';
