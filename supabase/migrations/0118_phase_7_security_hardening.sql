-- ============================================================================
-- 0118 — Phase 7: Edge Function security hardening
-- ============================================================================
-- Supabase's default privileges grant EXECUTE on new public functions to the
-- anon, authenticated, and service_role roles. The Phase 6 migrations revoked
-- PUBLIC but did not remove the explicit anon grant. Every function below is
-- either a service/owner batch job or an authenticated staff path; anon has no
-- legitimate call path to any of them.
--
-- This migration also enables pg_net so pg_cron can invoke Phase 7 Edge
-- Functions for delivery retries and webhook reconciliation.
-- ============================================================================

create extension if not exists pg_net with schema extensions;

revoke all on function public.log_driver_status_change() from public;
revoke execute on function public.log_driver_status_change() from anon;

revoke execute on function public.compute_daily_metrics(date) from anon;
revoke execute on function public.compute_zone_metrics(date) from anon;
revoke execute on function public.compute_driver_metrics(date) from anon;
revoke execute on function public.compute_customer_metrics(date) from anon;
revoke execute on function public.capture_demand_snapshot() from anon;
revoke execute on function public.archive_stale_chat_threads() from anon;
revoke execute on function public.apply_retention_policies() from anon;

revoke execute on function public.send_notification(uuid, text, text, jsonb, text, uuid) from anon;
revoke execute on function public.log_data_access(uuid, uuid, text, text, uuid, text, text, boolean) from anon;
revoke execute on function public.log_pii_select(uuid, text, text) from anon;

comment on extension pg_net is
  'Phase 7 uses pg_net from pg_cron to invoke authenticated Edge Function workers.';
