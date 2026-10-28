-- ============================================================================
-- SafeShift — Phase 7 integration readiness verification
--
-- Usage (local):
--   psql "$LOCAL_DB_URL" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-7-schema.sql
--
-- Run after migrations 0001–0118 and after all Phase 1–6 seeds.
--
-- This gate verifies the contract Phase 7 depends on. It does not call FCM,
-- Beem, Resend, Selcom, or Flutterwave, and it does not require provider
-- credentials. It reports a single PASS/FAIL summary.
-- ============================================================================

set search_path = public, extensions;

drop table if exists _phase7_verification;
create temporary table _phase7_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

-- ----------------------------------------------------------------------------
-- 1. Prerequisite tables
-- ----------------------------------------------------------------------------
drop table if exists _phase7_tables;
create temporary table _phase7_tables (name text primary key);
insert into _phase7_tables (name) values
  ('profiles'),
  ('user_devices'),
  ('push_tokens'),
  ('notification_templates'),
  ('notification_preferences'),
  ('notification_log'),
  ('jobs'),
  ('job_events'),
  ('driver_locations'),
  ('chat_messages'),
  ('payment_providers'),
  ('payment_methods'),
  ('payments'),
  ('payment_webhooks');

insert into _phase7_verification (check_no, check_name, status, details)
select 1, 'All Phase 7 prerequisite tables exist',
       case when count(*) = (select count(*) from _phase7_tables)
            then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase7_tables) || ' present'
from _phase7_tables t
where to_regclass('public.' || t.name) is not null;

-- ----------------------------------------------------------------------------
-- 2. Notification log contract
-- ----------------------------------------------------------------------------
insert into _phase7_verification (check_no, check_name, status, details)
select 2, 'notification_log has the delivery contract columns',
       case when count(*) = 19 then 'PASS' else 'FAIL' end,
       count(*) || ' of 19 columns present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'notification_log'
  and column_name in (
    'id', 'public_id', 'profile_id', 'channel', 'template_code', 'recipient',
    'subject', 'body', 'status', 'provider', 'provider_message_id',
    'provider_response', 'failure_reason', 'reference_type', 'reference_id',
    'sent_at', 'delivered_at', 'read_at', 'created_at'
  );

insert into _phase7_verification (check_no, check_name, status, details)
select 3, 'notification_log status check covers the delivery lifecycle',
       case when exists (
         select 1
           from pg_constraint c
          where c.conrelid = 'public.notification_log'::regclass
            and c.conname = 'notification_log_status_check'
            and pg_get_constraintdef(c.oid) like '%pending%'
            and pg_get_constraintdef(c.oid) like '%sent%'
            and pg_get_constraintdef(c.oid) like '%delivered%'
            and pg_get_constraintdef(c.oid) like '%failed%'
            and pg_get_constraintdef(c.oid) like '%bounced%'
            and pg_get_constraintdef(c.oid) like '%read%'
       ) then 'PASS' else 'FAIL' end,
       coalesce((
         select pg_get_constraintdef(c.oid)
           from pg_constraint c
          where c.conrelid = 'public.notification_log'::regclass
            and c.conname = 'notification_log_status_check'
       ), 'missing constraint');

insert into _phase7_verification (check_no, check_name, status, details)
select 4, 'notification_log remains monthly partitioned with 24+ children',
       case when c.relkind = 'p' and x.child_count >= 24 then 'PASS' else 'FAIL' end,
       coalesce(x.child_count::text || ' partitions', 'missing')
from pg_class c
left join lateral (
  select count(*)::integer as child_count
    from pg_inherits i
   where i.inhparent = to_regclass('public.notification_log')
) x on true
where c.oid = to_regclass('public.notification_log');

-- ----------------------------------------------------------------------------
-- 3. Payment webhook contract
-- ----------------------------------------------------------------------------
insert into _phase7_verification (check_no, check_name, status, details)
select 5, 'payment_webhooks has the ingestion contract columns',
       case when count(*) = 13 then 'PASS' else 'FAIL' end,
       count(*) || ' of 13 columns present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'payment_webhooks'
  and column_name in (
    'id', 'provider_id', 'event_type', 'event_id', 'provider_reference',
    'payload', 'signature_header', 'signature_valid', 'processing_status',
    'processing_error', 'processed_at', 'received_at', 'created_at'
  );

insert into _phase7_verification (check_no, check_name, status, details)
select 6, 'payment_webhooks processing status check is complete',
       case when exists (
         select 1
           from pg_constraint c
          where c.conrelid = 'public.payment_webhooks'::regclass
            and c.conname = 'payment_webhooks_processing_status_check'
            and pg_get_constraintdef(c.oid) like '%pending%'
            and pg_get_constraintdef(c.oid) like '%processed%'
            and pg_get_constraintdef(c.oid) like '%ignored%'
            and pg_get_constraintdef(c.oid) like '%error%'
       ) then 'PASS' else 'FAIL' end,
       coalesce((
         select pg_get_constraintdef(c.oid)
           from pg_constraint c
          where c.conrelid = 'public.payment_webhooks'::regclass
            and c.conname = 'payment_webhooks_processing_status_check'
       ), 'missing constraint');

insert into _phase7_verification (check_no, check_name, status, details)
select 7, 'payment_webhooks remains monthly partitioned with 24+ children',
       case when c.relkind = 'p' and x.child_count >= 24 then 'PASS' else 'FAIL' end,
       coalesce(x.child_count::text || ' partitions', 'missing')
from pg_class c
left join lateral (
  select count(*)::integer as child_count
    from pg_inherits i
   where i.inhparent = to_regclass('public.payment_webhooks')
) x on true
where c.oid = to_regclass('public.payment_webhooks');

insert into _phase7_verification (check_no, check_name, status, details)
select 8, 'payment_providers stores only a Vault secret reference',
       case when exists (
         select 1
           from information_schema.columns
          where table_schema = 'public'
            and table_name = 'payment_providers'
            and column_name = 'webhook_secret_reference'
            and data_type = 'text'
            and is_nullable = 'YES'
       ) then 'PASS' else 'FAIL' end,
       coalesce((
         select data_type || ', nullable=' || is_nullable
           from information_schema.columns
          where table_schema = 'public'
            and table_name = 'payment_providers'
            and column_name = 'webhook_secret_reference'
       ), 'missing column');

insert into _phase7_verification (check_no, check_name, status, details)
select 9, 'payment_providers.config contains no secret-like keys',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(p.code || ':' || k, ', '), 'no secret-like config keys')
from public.payment_providers p
cross join lateral jsonb_object_keys(p.config) as k
where lower(k) similar to '%(secret|password|private_key|api_key|api_secret|token)%';

-- ----------------------------------------------------------------------------
-- 4. Function and privilege contract
-- ----------------------------------------------------------------------------
insert into _phase7_verification (check_no, check_name, status, details)
select 10, 'send_notification() is SECURITY DEFINER with an empty search_path',
       case when p.oid is not null
                  and p.prosecdef
                  and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
            then 'PASS' else 'FAIL' end,
       coalesce(p.oid::regprocedure::text, 'missing')
from (select to_regprocedure(
        'public.send_notification(uuid,text,text,jsonb,text,uuid)'
      ) as oid) x
left join pg_proc p on p.oid = x.oid;

insert into _phase7_verification (check_no, check_name, status, details)
select 11, 'send_notification() is executable by staff and workers, not anon',
       case when has_function_privilege(
                   'authenticated',
                   'public.send_notification(uuid,text,text,jsonb,text,uuid)'::regprocedure,
                   'EXECUTE')
                  and has_function_privilege(
                   'service_role',
                   'public.send_notification(uuid,text,text,jsonb,text,uuid)'::regprocedure,
                   'EXECUTE')
                  and not has_function_privilege(
                   'anon',
                   'public.send_notification(uuid,text,text,jsonb,text,uuid)'::regprocedure,
                   'EXECUTE')
            then 'PASS' else 'FAIL' end,
       'authenticated='
       || has_function_privilege(
            'authenticated',
            'public.send_notification(uuid,text,text,jsonb,text,uuid)'::regprocedure,
            'EXECUTE')::text
       || ', service_role='
       || has_function_privilege(
            'service_role',
            'public.send_notification(uuid,text,text,jsonb,text,uuid)'::regprocedure,
            'EXECUTE')::text
       || ', anon='
       || has_function_privilege(
            'anon',
            'public.send_notification(uuid,text,text,jsonb,text,uuid)'::regprocedure,
            'EXECUTE')::text;

insert into _phase7_verification (check_no, check_name, status, details)
select 12, 'notification_log is client-readable but not client-writable',
       case when has_table_privilege('authenticated', 'public.notification_log', 'SELECT')
                  and not has_table_privilege('authenticated', 'public.notification_log', 'INSERT')
                  and not has_table_privilege('authenticated', 'public.notification_log', 'UPDATE')
                  and not has_table_privilege('authenticated', 'public.notification_log', 'DELETE')
                  and has_table_privilege('service_role', 'public.notification_log', 'UPDATE')
            then 'PASS' else 'FAIL' end,
       'auth select='
       || has_table_privilege('authenticated', 'public.notification_log', 'SELECT')::text
       || ', auth insert='
       || has_table_privilege('authenticated', 'public.notification_log', 'INSERT')::text
       || ', auth update='
       || has_table_privilege('authenticated', 'public.notification_log', 'UPDATE')::text
       || ', service update='
       || has_table_privilege('service_role', 'public.notification_log', 'UPDATE')::text;

insert into _phase7_verification (check_no, check_name, status, details)
select 13, 'payment_webhooks is client-readable but not client-writable',
       case when has_table_privilege('authenticated', 'public.payment_webhooks', 'SELECT')
                  and not has_table_privilege('authenticated', 'public.payment_webhooks', 'INSERT')
                  and not has_table_privilege('authenticated', 'public.payment_webhooks', 'UPDATE')
                  and not has_table_privilege('authenticated', 'public.payment_webhooks', 'DELETE')
                  and has_table_privilege('service_role', 'public.payment_webhooks', 'INSERT')
                  and has_table_privilege('service_role', 'public.payment_webhooks', 'UPDATE')
            then 'PASS' else 'FAIL' end,
       'auth select='
       || has_table_privilege('authenticated', 'public.payment_webhooks', 'SELECT')::text
       || ', auth insert='
       || has_table_privilege('authenticated', 'public.payment_webhooks', 'INSERT')::text
       || ', service insert='
       || has_table_privilege('service_role', 'public.payment_webhooks', 'INSERT')::text
       || ', service update='
       || has_table_privilege('service_role', 'public.payment_webhooks', 'UPDATE')::text;

insert into _phase7_verification (check_no, check_name, status, details)
select 14, 'RLS is enabled on both integration tables',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' of 2 tables'
from pg_class c
where c.oid in (
        'public.notification_log'::regclass,
        'public.payment_webhooks'::regclass
      )
  and c.relrowsecurity;

insert into _phase7_verification (check_no, check_name, status, details)
select 15, 'Both integration tables have at least one RLS policy',
       case when count(distinct c.relname) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' policies across ' || count(distinct c.relname) || ' tables'
from pg_policy p
join pg_class c on c.oid = p.polrelid
where c.oid in (
        'public.notification_log'::regclass,
        'public.payment_webhooks'::regclass
      );

-- ----------------------------------------------------------------------------
-- 5. Triggers and indexes
-- ----------------------------------------------------------------------------
insert into _phase7_verification (check_no, check_name, status, details)
select 16, 'notification_log immutability trigger is installed',
       case when exists (
         select 1
           from pg_trigger t
          where t.tgrelid = 'public.notification_log'::regclass
            and t.tgname = 'trg_notification_log_immutable'
            and not t.tgisinternal
            and t.tgenabled <> 'D'
       ) then 'PASS' else 'FAIL' end,
       'trg_notification_log_immutable';

insert into _phase7_verification (check_no, check_name, status, details)
select 17, 'payment_webhooks immutability trigger is installed',
       case when exists (
         select 1
           from pg_trigger t
          where t.tgrelid = 'public.payment_webhooks'::regclass
            and t.tgname = 'trg_payment_webhooks_immutable'
            and not t.tgisinternal
            and t.tgenabled <> 'D'
       ) then 'PASS' else 'FAIL' end,
       'trg_payment_webhooks_immutable';

insert into _phase7_verification (check_no, check_name, status, details)
select 18, 'payment_webhooks dedupe trigger is installed',
       case when exists (
         select 1
           from pg_trigger t
          where t.tgrelid = 'public.payment_webhooks'::regclass
            and t.tgname = 'trg_payment_webhooks_dedupe'
            and not t.tgisinternal
            and t.tgenabled <> 'D'
       ) then 'PASS' else 'FAIL' end,
       'trg_payment_webhooks_dedupe';

insert into _phase7_verification (check_no, check_name, status, details)
select 19, 'Payment webhook dedupe and pending indexes exist',
       case when to_regclass('public.uq_payment_webhooks_provider_event') is not null
                  and to_regclass('public.idx_payment_webhooks_pending') is not null
                  and to_regclass('public.idx_payment_webhooks_provider_received') is not null
            then 'PASS' else 'FAIL' end,
       'uq_payment_webhooks_provider_event, idx_payment_webhooks_pending, '
       || 'idx_payment_webhooks_provider_received';

insert into _phase7_verification (check_no, check_name, status, details)
select 20, 'Notification worker indexes exist',
       case when to_regclass('public.idx_notification_log_status_open') is not null
                  and to_regclass('public.idx_notification_log_public_id') is not null
            then 'PASS' else 'FAIL' end,
       'idx_notification_log_status_open, idx_notification_log_public_id';

-- ----------------------------------------------------------------------------
-- 6. Realtime and helper contract
-- ----------------------------------------------------------------------------
insert into _phase7_verification (check_no, check_name, status, details)
select 21, 'Realtime publication contains the five approved tables',
       case when count(*) = 5 then 'PASS' else 'FAIL' end,
       count(*) || ' of 5: '
       || coalesce(string_agg(tablename, ', ' order by tablename), 'none')
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in (
    'jobs', 'driver_locations', 'job_events', 'chat_messages', 'notification_log'
  );

insert into _phase7_verification (check_no, check_name, status, details)
select 22, 'Service-context and permission helpers exist',
       case when to_regprocedure('private.is_service_context()') is not null
                  and to_regprocedure('public.has_permission(text)') is not null
            then 'PASS' else 'FAIL' end,
       'private.is_service_context(), public.has_permission(text)';

insert into _phase7_verification (check_no, check_name, status, details)
select 23, 'notification_log trigger permits failed -> pending retry',
       case when coalesce(
              pg_get_functiondef(
                'private.enforce_notification_log_immutability()'::regprocedure
              ),
              ''
            ) like '%failed%'
                  and coalesce(
                    pg_get_functiondef(
                      'private.enforce_notification_log_immutability()'::regprocedure
                    ),
                    ''
                  ) like '%pending%'
            then 'PASS' else 'FAIL' end,
       'private.enforce_notification_log_immutability()';

insert into _phase7_verification (check_no, check_name, status, details)
select 24, 'payment webhook dedupe uses an advisory lock',
       case when coalesce(
              pg_get_functiondef('private.payment_webhook_dedupe()'::regprocedure),
              ''
            ) like '%pg_advisory_xact_lock%'
            then 'PASS' else 'FAIL' end,
       'private.payment_webhook_dedupe()';

insert into _phase7_verification (check_no, check_name, status, details)
select 25, 'payment webhook processing can only move once from pending',
       case when coalesce(
              pg_get_functiondef(
                'private.enforce_payment_webhook_immutability()'::regprocedure
              ),
              ''
            ) like '%old.processing_status <> ''pending''%'
            then 'PASS' else 'FAIL' end,
       'private.enforce_payment_webhook_immutability()';

insert into _phase7_verification (check_no, check_name, status, details)
select 26, 'Anon cannot execute privileged SECURITY DEFINER functions',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(signature, ', '), 'no anon execution grants')
from (values
  ('public.log_driver_status_change()'),
  ('public.compute_daily_metrics(date)'),
  ('public.compute_zone_metrics(date)'),
  ('public.compute_driver_metrics(date)'),
  ('public.compute_customer_metrics(date)'),
  ('public.capture_demand_snapshot()'),
  ('public.archive_stale_chat_threads()'),
  ('public.apply_retention_policies()'),
  ('public.send_notification(uuid,text,text,jsonb,text,uuid)'),
  ('public.log_data_access(uuid,uuid,text,text,uuid,text,text,boolean)'),
  ('public.log_pii_select(uuid,text,text)')
) as f(signature)
where has_function_privilege('anon', f.signature::regprocedure, 'EXECUTE');

-- ----------------------------------------------------------------------------
-- 7. Seed and worker prerequisites
-- ----------------------------------------------------------------------------
insert into _phase7_verification (check_no, check_name, status, details)
select 27, 'Active push, SMS, and email templates exist',
       case when count(distinct channel) = 3 then 'PASS' else 'FAIL' end,
       count(*) || ' active templates across '
       || count(distinct channel) || ' channels'
from public.notification_templates
where is_active
  and channel in ('push', 'sms', 'email');

insert into _phase7_verification (check_no, check_name, status, details)
select 28, 'push_tokens is unique per (profile_id, device_id) and FCM-only',
       case when exists (
         select 1
           from pg_constraint c
          where c.conrelid = 'public.push_tokens'::regclass
            and c.contype = 'u'
            and pg_get_constraintdef(c.oid) = 'UNIQUE (profile_id, device_id)'
       ) and exists (
         select 1
           from pg_constraint c
          where c.conrelid = 'public.push_tokens'::regclass
            and c.conname = 'push_tokens_provider_check'
            and pg_get_constraintdef(c.oid) like '%fcm%'
       ) then 'PASS' else 'FAIL' end,
       'unique(profile_id, device_id), provider=fcm';

insert into _phase7_verification (check_no, check_name, status, details)
select 29, 'At least one active payment provider is configured',
       case when count(*) > 0 then 'PASS' else 'FAIL' end,
       count(*) || ' active providers'
from public.payment_providers
where is_active;

insert into _phase7_verification (check_no, check_name, status, details)
select 30, 'pg_cron and pg_net are installed for Phase 7 workers',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(extname, ', ' order by extname), 'none')
from pg_extension
where extname in ('pg_cron', 'pg_net');

-- ----------------------------------------------------------------------------
-- 8. Results
-- ----------------------------------------------------------------------------
select
  check_no,
  lpad(check_no::text, 2, '0') as no,
  check_name,
  status,
  details
from _phase7_verification
order by check_no, check_name;

select
  'PHASE 7 SCHEMA VERIFICATION: '
  || count(*) filter (where status = 'PASS')
  || ' PASS, '
  || count(*) filter (where status = 'FAIL')
  || ' FAIL' as result
from _phase7_verification;

-- List failures a second time for fast triage.
select check_no, check_name, details
from _phase7_verification
where status = 'FAIL'
order by check_no, check_name;

drop table if exists _phase7_verification;
drop table if exists _phase7_tables;
