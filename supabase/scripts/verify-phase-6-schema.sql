-- ============================================================================
-- SafeShift — Phase 6 schema verification
--
-- Usage (local):
--   psql "$LOCAL_DB_URL" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-6-schema.sql
--
-- Run after migrations 0001–0117 and after seed.sql + seed-phase-2.sql +
-- seed-phase-3.sql + seed-phase-4.sql + seed-phase-5.sql + seed-phase-6.sql.
--
-- The script is read-mostly. Behavioural checks create uniquely named scratch
-- rows and remove them again. It reports a single PASS/FAIL summary.
-- ============================================================================

set search_path = public, extensions;

drop table if exists _phase6_verification;
create temporary table _phase6_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

-- Role simulation helpers. SET LOCAL ROLE persists after the helper returns,
-- so callers must call pg_temp.clear_auth() when finished.
create or replace function pg_temp.as_user(p_profile uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_profile::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', p_profile::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  execute 'set local role anon';
end;
$$;

create or replace function pg_temp.clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
end;
$$;

-- ----------------------------------------------------------------------------
-- 1. Table inventory
-- ----------------------------------------------------------------------------
drop table if exists _phase6_tables;
create temporary table _phase6_tables (name text primary key);
insert into _phase6_tables (name) values
  ('push_tokens'),
  ('notification_templates'),
  ('notification_log'),
  ('notification_preferences'),
  ('chat_threads'),
  ('chat_messages'),
  ('chat_attachments'),
  ('chat_read_receipts'),
  ('emergency_contacts'),
  ('incidents'),
  ('incident_actions'),
  ('blocked_users'),
  ('prohibited_items'),
  ('support_categories'),
  ('support_tickets'),
  ('support_ticket_messages'),
  ('data_access_log'),
  ('retention_policies'),
  ('data_subject_requests'),
  ('daily_metrics'),
  ('zone_metrics'),
  ('driver_metrics'),
  ('customer_metrics'),
  ('demand_snapshots');

insert into _phase6_verification (check_no, check_name, status, details)
select 1, 'All 24 Phase 6 tables exist',
       case when count(*) = 24 then 'PASS' else 'FAIL' end,
       count(*) || ' of 24 present'
from _phase6_tables t
where to_regclass('public.' || t.name) is not null;

insert into _phase6_verification (check_no, check_name, status, details)
select 1, 'push_tokens is one row per (profile_id, device_id) and FCM-only',
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
            and pg_get_constraintdef(c.oid) not like '%apns%'
       ) then 'PASS' else 'FAIL' end,
       coalesce((
         select string_agg(pg_get_constraintdef(c.oid), ', ')
           from pg_constraint c
          where c.conrelid = 'public.push_tokens'::regclass
            and c.contype in ('u','c')
            and c.conname in ('push_tokens_profile_device_key','push_tokens_provider_check')
       ), 'missing constraints');

-- ----------------------------------------------------------------------------
-- 2. RLS and policies
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 2, 'RLS enabled on ' || t.name,
       case when c.relrowsecurity then 'PASS' else 'FAIL' end,
       coalesce(c.relkind::text, 'missing')
from _phase6_tables t
left join pg_class c on c.oid = to_regclass('public.' || t.name)
order by t.name;

insert into _phase6_verification (check_no, check_name, status, details)
select 3, 'At least one policy on ' || t.name,
       case when exists (
         select 1 from pg_policy p where p.polrelid = to_regclass('public.' || t.name)
       ) then 'PASS' else 'FAIL' end,
       (select count(*)::text || ' policies' from pg_policy p
         where p.polrelid = to_regclass('public.' || t.name))
from _phase6_tables t
order by t.name;

insert into _phase6_verification (check_no, check_name, status, details)
select 4, 'Every auth.uid() policy uses (select auth.uid())',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(policyname || ' on ' || tablename, ', '),
                'all auth.uid() references are subqueries')
from (
  select c.relname as tablename,
         p.polname as policyname,
         regexp_replace(coalesce(pg_get_expr(p.polqual, p.polrelid), ''), '\s+', '', 'g') as expr
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in (select name from _phase6_tables)
  union all
  select c.relname,
         p.polname,
         regexp_replace(coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''), '\s+', '', 'g')
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in (select name from _phase6_tables)
) x
where (lower(expr) like '%auth.uid()%' or lower(expr) like '%uid()%')
  and lower(expr) not like '%selectuid()%'
  and lower(expr) not like '%selectauth.uid()%';

insert into _phase6_verification (check_no, check_name, status, details)
select 4, 'Every has_permission() policy uses a scalar subquery',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(policyname || ' on ' || tablename, ', '),
                'all has_permission() references are scalar subqueries')
from (
  select c.relname as tablename,
         p.polname as policyname,
         regexp_replace(coalesce(pg_get_expr(p.polqual, p.polrelid), ''), '\s+', '', 'g') as expr
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in (select name from _phase6_tables)
  union all
  select c.relname,
         p.polname,
         regexp_replace(coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''), '\s+', '', 'g')
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in (select name from _phase6_tables)
) x
where lower(expr) like '%has_permission%'
  and lower(expr) not like '%selecthas_permission%'
  and lower(expr) not like '%selectpublic.has_permission%';

-- ----------------------------------------------------------------------------
-- 3. Partitioned tables
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 5, 'Partition count: ' || t.name,
       case when c.relkind = 'p' and x.child_count = t.expected then 'PASS' else 'FAIL' end,
       coalesce(x.child_count::text, '0') || ' of ' || t.expected
from (values
  ('notification_log', 24),
  ('chat_messages', 12),
  ('data_access_log', 84),
  ('demand_snapshots', 3)
) as t(name, expected)
left join pg_class c on c.oid = to_regclass('public.' || t.name)
left join (
  select p.relname as parent,
         count(*) as child_count
    from pg_inherits i
    join pg_class p on p.oid = i.inhparent
    join pg_namespace pn on pn.oid = p.relnamespace
    join pg_class ch on ch.oid = i.inhrelid
   where pn.nspname = 'public'
     and ch.relname ~ '_20[0-9]{2}_[0-9]{2}$'
   group by p.relname
) x on x.parent = t.name
order by t.name;

insert into _phase6_verification (check_no, check_name, status, details)
select 5, 'Default partition exists: ' || t.name,
       case when to_regclass('public.' || t.name || '_default') is not null
            then 'PASS' else 'FAIL' end,
       coalesce(to_regclass('public.' || t.name || '_default')::text, 'missing')
from (values
  ('notification_log'), ('chat_messages'), ('data_access_log'), ('demand_snapshots')
) as t(name);

insert into _phase6_verification (check_no, check_name, status, details)
select 6, 'Phase 6 partition children have no client privileges',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'no direct client access')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relispartition
  and c.relname ~ '^(notification_log|chat_messages|data_access_log|demand_snapshots)_'
  and (
    has_table_privilege('anon', c.oid, 'SELECT')
    or has_table_privilege('anon', c.oid, 'INSERT')
    or has_table_privilege('anon', c.oid, 'UPDATE')
    or has_table_privilege('anon', c.oid, 'DELETE')
    or has_table_privilege('authenticated', c.oid, 'SELECT')
    or has_table_privilege('authenticated', c.oid, 'INSERT')
    or has_table_privilege('authenticated', c.oid, 'UPDATE')
    or has_table_privilege('authenticated', c.oid, 'DELETE')
  );

-- ----------------------------------------------------------------------------
-- 4. Realtime publication
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 7, 'Realtime publication contains the five Phase 6 tables',
       case when array['chat_messages','driver_locations','job_events','jobs','notification_log']::text[]
                 <@ coalesce(array_agg(tablename::text), array[]::text[])
            then 'PASS' else 'FAIL' end,
       coalesce(string_agg(tablename, ', ' order by tablename), 'none')
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public';

insert into _phase6_verification (check_no, check_name, status, details)
select 7, 'driver_locations Realtime uses the required column subset',
       case when attnames::text[] = array[
              'id','driver_id','job_id','location','heading_degrees','speed_kmh','recorded_at'
            ]::text[] then 'PASS' else 'FAIL' end,
       array_to_string(attnames, ', ')
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename = 'driver_locations';

insert into _phase6_verification (check_no, check_name, status, details)
select 7, 'Realtime publishes partition roots',
       case when bool_and(pubviaroot) then 'PASS' else 'FAIL' end,
       coalesce(string_agg(pubname || '=' || pubviaroot::text, ', '), 'missing')
from pg_publication
where pubname = 'supabase_realtime';

-- ----------------------------------------------------------------------------
-- 5. pg_cron
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 8, 'Six Phase 6 safeshift pg_cron jobs registered',
       case when count(*) = 6 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(jobname, ', ' order by jobname), 'none')
from cron.job
where jobname in (
  'safeshift_compute_daily_metrics',
  'safeshift_compute_zone_metrics',
  'safeshift_compute_driver_metrics',
  'safeshift_compute_customer_metrics',
  'safeshift_capture_demand',
  'safeshift_retention'
);

-- ----------------------------------------------------------------------------
-- 6. Views
-- ----------------------------------------------------------------------------
drop table if exists _phase6_views;
create temporary table _phase6_views (name text primary key);
insert into _phase6_views (name) values
  ('notification_summary'),
  ('chat_unread_summary'),
  ('incident_summary'),
  ('support_ticket_summary'),
  ('active_demand_zones'),
  ('operational_dashboard');

insert into _phase6_verification (check_no, check_name, status, details)
select 9, 'View uses security_invoker: ' || v.name,
       case when c.relkind = 'v'
             and coalesce(array_to_string(c.reloptions, ','), '') like '%security_invoker=true%'
            then 'PASS' else 'FAIL' end,
       coalesce(array_to_string(c.reloptions, ','), 'missing')
from _phase6_views v
left join pg_class c on c.oid = to_regclass('public.' || v.name)
order by v.name;

-- ----------------------------------------------------------------------------
-- 7. Functions
-- ----------------------------------------------------------------------------
drop table if exists _phase6_functions;
create temporary table _phase6_functions (signature text primary key);
insert into _phase6_functions (signature) values
  ('public.compute_daily_metrics(date)'),
  ('public.compute_zone_metrics(date)'),
  ('public.compute_driver_metrics(date)'),
  ('public.compute_customer_metrics(date)'),
  ('public.capture_demand_snapshot()'),
  ('public.send_notification(uuid,text,text,jsonb,text,uuid)'),
  ('public.log_data_access(uuid,uuid,text,text,uuid,text,text,boolean)'),
  ('public.log_pii_select(uuid,text,text)'),
  ('public.apply_retention_policies()'),
  ('public.archive_stale_chat_threads()'),
  ('private.ensure_monthly_partitions(text,text,text,integer)'),
  ('private.validate_chat_reply()'),
  ('private.validate_chat_attachment()'),
  ('private.sync_chat_thread_last_message()'),
  ('private.validate_chat_read_receipt()'),
  ('private.is_job_participant(uuid,uuid)'),
  ('private.can_read_incident(uuid,uuid)'),
  ('private.can_read_support_ticket(uuid,uuid)');

insert into _phase6_verification (check_no, check_name, status, details)
select 10, 'SECURITY DEFINER + empty search_path: ' || f.signature,
       case when p.prosecdef
             and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
            then 'PASS' else 'FAIL' end,
       coalesce(array_to_string(p.proconfig, ','), 'no proconfig')
from _phase6_functions f
left join pg_proc p on p.oid = to_regprocedure(f.signature)
order by f.signature;

insert into _phase6_verification (check_no, check_name, status, details)
select 10, 'send_notification returns UUID',
       case when pg_get_function_result(to_regprocedure('public.send_notification(uuid,text,text,jsonb,text,uuid)')) = 'uuid'
            then 'PASS' else 'FAIL' end,
       coalesce(pg_get_function_result(to_regprocedure('public.send_notification(uuid,text,text,jsonb,text,uuid)')), 'missing');

-- ----------------------------------------------------------------------------
-- 8. Permissions
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 11, 'All 13 Phase 6 permissions installed',
       case when count(*) = 13 then 'PASS' else 'FAIL' end,
       count(*) || ' of 13'
from public.admin_permissions_catalog
where permission_key in (
  'manage_notifications','view_incidents','manage_incidents','manage_prohibited_items',
  'manage_support','view_all_tickets','manage_tickets','view_data_access',
  'view_retention','manage_retention','manage_data_requests','view_analytics','manage_analytics'
);

insert into _phase6_verification (check_no, check_name, status, details)
select 11, 'Phase 6 role permission mappings installed',
       case when count(*) >= 31 then 'PASS' else 'FAIL' end,
       count(*) || ' mappings (expected >= 31)'
from public.admin_role_permissions
where permission_key in (
  'manage_notifications','view_incidents','manage_incidents','manage_prohibited_items',
  'manage_support','view_all_tickets','manage_tickets','view_data_access',
  'view_retention','manage_retention','manage_data_requests','view_analytics','manage_analytics'
);

-- ----------------------------------------------------------------------------
-- 9. TEXT + CHECK status fields and money columns
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 12, 'No Phase 6 enum types were introduced',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(t.typname, ', '), 'TEXT + CHECK only')
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
  and t.typtype = 'e'
  and t.typname ~ '(notification|chat|incident|support|retention|demand|analytics|data_subject|prohibited|blocked|push)';

drop table if exists _phase6_status_columns;
create temporary table _phase6_status_columns (table_name text, column_name text);
insert into _phase6_status_columns values
  ('push_tokens','provider'), ('push_tokens','platform'),
  ('notification_templates','channel'), ('notification_log','channel'),
  ('notification_log','status'), ('notification_preferences','category'),
  ('notification_preferences','channel'), ('chat_threads','status'),
  ('chat_messages','message_type'), ('incidents','incident_type'),
  ('incidents','severity'), ('incidents','status'), ('incident_actions','action_type'),
  ('blocked_users','scope'), ('prohibited_items','category'),
  ('prohibited_items','severity'), ('support_tickets','status'),
  ('support_tickets','priority'), ('data_access_log','access_type'),
  ('retention_policies','action'), ('data_subject_requests','request_type'),
  ('data_subject_requests','status');

insert into _phase6_verification (check_no, check_name, status, details)
select 12, 'Status-like columns use TEXT + CHECK',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.table_name || '.' || c.column_name || '=' || coalesce(col.data_type, 'missing'), ', '),
                'all text')
from _phase6_status_columns c
left join information_schema.columns col
  on col.table_schema = 'public'
 and col.table_name = c.table_name
 and col.column_name = c.column_name
where col.data_type is distinct from 'text';

insert into _phase6_verification (check_no, check_name, status, details)
select 13, 'Money columns are NUMERIC(14,2) with currency_code',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(table_name || '.' || column_name, ', '), 'all money columns correct')
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'daily_metrics' and column_name in ('gross_booking_value','net_revenue'))
    or (table_name = 'driver_metrics' and column_name in ('earnings_gross','earnings_net'))
    or (table_name = 'customer_metrics' and column_name = 'total_spent')
  )
  and not (data_type = 'numeric' and numeric_precision = 14 and numeric_scale = 2);

insert into _phase6_verification (check_no, check_name, status, details)
select 13, 'Analytics money tables have currency_code char(3)',
       case when count(*) = 3 then 'PASS' else 'FAIL' end,
       count(*) || ' of 3'
from information_schema.columns
where table_schema = 'public'
  and table_name in ('daily_metrics','driver_metrics','customer_metrics')
  and column_name = 'currency_code'
  and data_type = 'character'
  and character_maximum_length = 3;

-- ----------------------------------------------------------------------------
-- 10. Seed counts
-- ----------------------------------------------------------------------------
insert into _phase6_verification (check_no, check_name, status, details)
select 14, 'Seed: ' || s.label,
       case when s.label = 'demand snapshots'
                 then case when s.actual >= s.expected then 'PASS' else 'FAIL' end
            else case when s.actual = s.expected then 'PASS' else 'FAIL' end
       end,
       s.actual || ' expected ' || s.expected
       || case when s.label = 'demand snapshots' then ' (minimum; cron may add buckets)' else '' end
from (
  select 'push tokens' as label,
         (select count(*)::int from public.push_tokens where id::text like '7b%') as actual, 2 as expected
  union all select 'notification templates',
         (select count(*)::int from public.notification_templates where id::text like '7c%'), 18
  union all select 'notification preferences',
         (select count(*)::int from public.notification_preferences where id::text like '7d%'), 6
  union all select 'chat threads',
         (select count(*)::int from public.chat_threads where id::text like '7e%'), 2
  union all select 'chat messages',
         (select count(*)::int from public.chat_messages), 8
  union all select 'chat attachments',
         (select count(*)::int from public.chat_attachments where id::text like '9b%'), 2
  union all select 'chat read receipts',
         (select count(*)::int from public.chat_read_receipts), 4
  union all select 'emergency contacts',
         (select count(*)::int from public.emergency_contacts where id::text like '9a%'), 1
  union all select 'incidents',
         (select count(*)::int from public.incidents where id::text like '7f%'), 2
  union all select 'incident actions',
         (select count(*)::int from public.incident_actions), 2
  union all select 'blocked users',
         (select count(*)::int from public.blocked_users where id::text like '8a%'), 1
  union all select 'prohibited items',
         (select count(*)::int from public.prohibited_items where id::text like '8b%'), 8
  union all select 'support categories',
         (select count(*)::int from public.support_categories where id::text like '8c%'), 5
  union all select 'support tickets',
         (select count(*)::int from public.support_tickets where id::text like '8d%'), 2
  union all select 'support ticket messages',
         (select count(*)::int from public.support_ticket_messages), 5
  union all select 'data access seed rows',
         (select count(*)::int from public.data_access_log where purpose = 'phase6_seed'), 5
  union all select 'retention policies',
         (select count(*)::int from public.retention_policies where id::text like '8e%'), 8
  union all select 'data subject requests',
         (select count(*)::int from public.data_subject_requests where id::text like '8f%'), 1
  union all select 'daily metrics',
         (select count(*)::int from public.daily_metrics where country_id = '33333333-0000-4000-8000-000000000001' and city_id = '55555555-0000-4000-8000-000000000001' and metric_date between current_date - 7 and current_date - 1), 7
  union all select 'zone metrics',
         (select count(*)::int from public.zone_metrics where service_zone_id in ('66666666-0000-4000-8000-000000000001','66666666-0000-4000-8000-000000000002','66666666-0000-4000-8000-000000000003') and metric_date between current_date - 7 and current_date - 1), 21
  union all select 'driver metrics',
         (select count(*)::int from public.driver_metrics where driver_id in ('d0000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','d0000000-0000-4000-8000-000000000003') and metric_date between current_date - 7 and current_date - 1), 21
  union all select 'customer metrics',
         (select count(*)::int from public.customer_metrics where customer_id in ('c0000000-0000-4000-8000-000000000001','c0000000-0000-4000-8000-000000000002','c0000000-0000-4000-8000-000000000003') and metric_date between current_date - 7 and current_date - 1), 21
  union all select 'demand snapshots',
         (select count(*)::int from public.demand_snapshots), 432
) s
order by s.label;

-- ----------------------------------------------------------------------------
-- 11. RLS read behaviour
-- ----------------------------------------------------------------------------
do $$
declare
  v_push_own integer;
  v_push_other integer;
  v_pref_own integer;
  v_pref_other integer;
  v_contact_own integer;
  v_contact_other integer;
  v_blocked_own integer;
  v_blocked_other integer;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_push_own from public.push_tokens;
  select count(*) into v_push_other from public.push_tokens
   where profile_id = 'd0000000-0000-4000-8000-000000000001';
  select count(*) into v_pref_own from public.notification_preferences;
  select count(*) into v_pref_other from public.notification_preferences
   where profile_id = 'c0000000-0000-4000-8000-000000000002';
  select count(*) into v_contact_own from public.emergency_contacts;
  select count(*) into v_contact_other from public.emergency_contacts
   where profile_id = 'c0000000-0000-4000-8000-000000000002';
  select count(*) into v_blocked_own from public.blocked_users
   where blocker_profile_id = 'c0000000-0000-4000-8000-000000000001';
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  select count(*) into v_blocked_other from public.blocked_users;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (20, 'RLS: push tokens are own-only',
     case when v_push_own = 1 and v_push_other = 0 then 'PASS' else 'FAIL' end,
     'own=' || v_push_own || ', other=' || v_push_other),
    (21, 'RLS: notification preferences are own-only',
     case when v_pref_own = 6 and v_pref_other = 0 then 'PASS' else 'FAIL' end,
     'own=' || v_pref_own || ', other=' || v_pref_other),
    (22, 'RLS: emergency contacts are own-only',
     case when v_contact_own = 1 and v_contact_other = 0 then 'PASS' else 'FAIL' end,
     'own=' || v_contact_own || ', other=' || v_contact_other),
    (23, 'RLS: blocked users are blocker-only',
     case when v_blocked_own = 0 and v_blocked_other = 1 then 'PASS' else 'FAIL' end,
     'c1=' || v_blocked_own || ', c2=' || v_blocked_other);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (20, 'RLS: own-only communication tables', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_threads_c2 integer;
  v_threads_c3 integer;
  v_messages_c2 integer;
  v_messages_c3 integer;
  v_receipts_c2 integer;
  v_receipts_c3 integer;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  select count(*) into v_threads_c2 from public.chat_threads;
  select count(*) into v_messages_c2 from public.chat_messages;
  select count(*) into v_receipts_c2 from public.chat_read_receipts;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  select count(*) into v_threads_c3 from public.chat_threads;
  select count(*) into v_messages_c3 from public.chat_messages;
  select count(*) into v_receipts_c3 from public.chat_read_receipts;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (25, 'RLS: chat threads and messages are participant-only',
     case when v_threads_c2 = 1 and v_threads_c3 = 0
            and v_messages_c2 = 4 and v_messages_c3 = 0
            and v_receipts_c2 = 1 and v_receipts_c3 = 0
          then 'PASS' else 'FAIL' end,
     'c2 threads=' || v_threads_c2 || ', messages=' || v_messages_c2
       || ', receipts=' || v_receipts_c2
       || '; c3 threads=' || v_threads_c3 || ', messages=' || v_messages_c3
       || ', receipts=' || v_receipts_c3);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (25, 'RLS: chat threads and messages are participant-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_c1 integer;
  v_c2 integer;
  v_c3 integer;
  v_admin integer;
  v_actions_c1 integer;
  v_actions_c3 integer;
  v_actions_admin integer;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_c1 from public.incidents;
  select count(*) into v_actions_c1 from public.incident_actions;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  select count(*) into v_c2 from public.incidents;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  select count(*) into v_c3 from public.incidents;
  select count(*) into v_actions_c3 from public.incident_actions;

  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
  select count(*) into v_admin from public.incidents;
  select count(*) into v_actions_admin from public.incident_actions;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (26, 'RLS: incidents are reporter/participant/staff-only',
     case when v_c1 = 1 and v_c2 = 1 and v_c3 = 0 and v_admin = 2
            and v_actions_c1 = 2 and v_actions_c3 = 0 and v_actions_admin = 2
          then 'PASS' else 'FAIL' end,
     'c1=' || v_c1 || ', c2=' || v_c2 || ', c3=' || v_c3
       || ', admin=' || v_admin
       || '; actions c1=' || v_actions_c1 || ', c3=' || v_actions_c3
       || ', admin=' || v_actions_admin);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (26, 'RLS: incidents are reporter/participant/staff-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_c1 integer;
  v_c2 integer;
  v_c3 integer;
  v_staff integer;
  v_msg_c1 integer;
  v_msg_c3 integer;
  v_msg_staff integer;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_c1 from public.support_tickets;
  select count(*) into v_msg_c1 from public.support_ticket_messages;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  select count(*) into v_c2 from public.support_tickets;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  select count(*) into v_c3 from public.support_tickets;
  select count(*) into v_msg_c3 from public.support_ticket_messages;

  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000003');
  select count(*) into v_staff from public.support_tickets;
  select count(*) into v_msg_staff from public.support_ticket_messages;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (27, 'RLS: support tickets and internal notes are scoped correctly',
     case when v_c1 = 1 and v_c2 = 0 and v_c3 = 1 and v_staff = 2
            and v_msg_c1 = 2 and v_msg_c3 = 2 and v_msg_staff = 5
          then 'PASS' else 'FAIL' end,
     'tickets c1=' || v_c1 || ', c2=' || v_c2 || ', c3=' || v_c3
       || ', staff=' || v_staff
       || '; messages c1=' || v_msg_c1 || ', c3=' || v_msg_c3
       || ', staff=' || v_msg_staff);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (27, 'RLS: support tickets and internal notes are scoped correctly', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_access_admin integer;
  v_access_c1 integer;
  v_access_ops integer;
  v_ret_admin integer;
  v_ret_ops integer;
  v_dsr_c1 integer;
  v_dsr_c2 integer;
  v_dsr_admin integer;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
  select count(*) into v_access_admin from public.data_access_log;
  select count(*) into v_ret_admin from public.retention_policies;
  select count(*) into v_dsr_admin from public.data_subject_requests;

  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000002');
  select count(*) into v_access_ops from public.data_access_log;
  select count(*) into v_ret_ops from public.retention_policies;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_access_c1 from public.data_access_log;
  select count(*) into v_dsr_c1 from public.data_subject_requests;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  select count(*) into v_dsr_c2 from public.data_subject_requests;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (28, 'RLS: compliance logs and retention policies are staff-only',
     case when v_access_admin = 5 and v_access_c1 = 0 and v_access_ops = 0
            and v_ret_admin = 8 and v_ret_ops = 0
            and v_dsr_c1 = 1 and v_dsr_c2 = 0 and v_dsr_admin = 1
          then 'PASS' else 'FAIL' end,
     'access admin/c1/ops=' || v_access_admin || '/' || v_access_c1 || '/' || v_access_ops
       || ', retention admin/ops=' || v_ret_admin || '/' || v_ret_ops
       || ', dsr c1/c2/admin=' || v_dsr_c1 || '/' || v_dsr_c2 || '/' || v_dsr_admin);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (28, 'RLS: compliance logs and retention policies are staff-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_daily_admin integer;
  v_daily_c1 integer;
  v_daily_ops integer;
  v_demand_admin integer;
  v_demand_c1 integer;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
  select count(*) into v_daily_admin from public.daily_metrics;
  select count(*) into v_demand_admin from public.demand_snapshots;

  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000002');
  select count(*) into v_daily_ops from public.daily_metrics;

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_daily_c1 from public.daily_metrics;
  select count(*) into v_demand_c1 from public.demand_snapshots;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (29, 'RLS: analytics tables are view_analytics-only',
     case when v_daily_admin = 7 and v_daily_ops = 7 and v_daily_c1 = 0
            and v_demand_admin >= 432 and v_demand_c1 = 0
          then 'PASS' else 'FAIL' end,
     'daily admin/ops/c1=' || v_daily_admin || '/' || v_daily_ops || '/' || v_daily_c1
       || ', demand admin/c1=' || v_demand_admin || '/' || v_demand_c1);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (29, 'RLS: analytics tables are view_analytics-only', 'FAIL', sqlerrm);
end $$;

insert into _phase6_verification (check_no, check_name, status, details)
select 24, 'Authenticated can read templates, prohibited items, and support categories',
       case when
         has_table_privilege('authenticated', 'public.notification_templates', 'SELECT')
         and has_table_privilege('authenticated', 'public.prohibited_items', 'SELECT')
         and has_table_privilege('authenticated', 'public.support_categories', 'SELECT')
         and not has_table_privilege('anon', 'public.notification_templates', 'SELECT')
         and not has_table_privilege('anon', 'public.prohibited_items', 'SELECT')
         and not has_table_privilege('anon', 'public.support_categories', 'SELECT')
       then 'PASS' else 'FAIL' end,
       'authenticated select granted; anon select denied';

do $$
declare
  v_c1_templates integer;
  v_c1_prohibited integer;
  v_c1_categories integer;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_c1_templates from public.notification_templates;
  select count(*) into v_c1_prohibited from public.prohibited_items;
  select count(*) into v_c1_categories from public.support_categories;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (24, 'RLS: catalogue reads return the seeded rows',
     case when v_c1_templates = 18 and v_c1_prohibited = 8 and v_c1_categories = 5
          then 'PASS' else 'FAIL' end,
     'templates=' || v_c1_templates || ', prohibited=' || v_c1_prohibited
       || ', categories=' || v_c1_categories);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (24, 'RLS: catalogue reads return the seeded rows', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 12. RLS write behaviour and grant boundaries
-- ----------------------------------------------------------------------------
do $$
declare
  v_own boolean := false;
  v_other_blocked boolean := false;
begin
  delete from public.user_devices where id = '7a000000-0000-4000-8000-000000000099';
  insert into public.user_devices (id, profile_id, device_id, device_type)
  values ('7a000000-0000-4000-8000-000000000099',
          'c0000000-0000-4000-8000-000000000001',
          'gate-device-c1', 'android');

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.push_tokens (profile_id, device_id, token, provider, platform)
    values ('c0000000-0000-4000-8000-000000000001',
            '7a000000-0000-4000-8000-000000000099',
            'gate-push-token', 'fcm', 'android');
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.push_tokens (profile_id, device_id, token, provider, platform)
    values ('c0000000-0000-4000-8000-000000000002',
            '7a000000-0000-4000-8000-000000000099',
            'gate-push-other', 'fcm', 'android');
  exception when others then
    v_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.push_tokens where token like 'gate-push-%';
  delete from public.user_devices where id = '7a000000-0000-4000-8000-000000000099';
  insert into _phase6_verification values
    (40, 'RLS: push token writes are own-only',
     case when v_own and v_other_blocked then 'PASS' else 'FAIL' end,
     'own=' || v_own || ', other blocked=' || v_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.push_tokens where token like 'gate-push-%';
  delete from public.user_devices where id = '7a000000-0000-4000-8000-000000000099';
  insert into _phase6_verification values
    (40, 'RLS: push token writes are own-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_own boolean := false;
  v_other_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.notification_preferences (profile_id, category, channel, is_enabled)
    values ('c0000000-0000-4000-8000-000000000001', 'job_updates', 'sms', true);
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.notification_preferences (profile_id, category, channel, is_enabled)
    values ('c0000000-0000-4000-8000-000000000002', 'job_updates', 'sms', true);
  exception when others then
    v_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.notification_preferences
   where profile_id = 'c0000000-0000-4000-8000-000000000001'
     and category = 'job_updates' and channel = 'sms';
  insert into _phase6_verification values
    (41, 'RLS: notification preference writes are own-only',
     case when v_own and v_other_blocked then 'PASS' else 'FAIL' end,
     'own=' || v_own || ', other blocked=' || v_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.notification_preferences
   where profile_id = 'c0000000-0000-4000-8000-000000000001'
     and category = 'job_updates' and channel = 'sms';
  insert into _phase6_verification values
    (41, 'RLS: notification preference writes are own-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_own boolean := false;
  v_other_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.emergency_contacts (profile_id, name, phone)
    values ('c0000000-0000-4000-8000-000000000001', 'Gate Contact', '+255700009999');
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.emergency_contacts (profile_id, name, phone)
    values ('c0000000-0000-4000-8000-000000000002', 'Gate Other', '+255700009998');
  exception when others then
    v_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.emergency_contacts where name like 'Gate %';
  insert into _phase6_verification values
    (42, 'RLS: emergency contact writes are own-only',
     case when v_own and v_other_blocked then 'PASS' else 'FAIL' end,
     'own=' || v_own || ', other blocked=' || v_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.emergency_contacts where name like 'Gate %';
  insert into _phase6_verification values
    (42, 'RLS: emergency contact writes are own-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_own boolean := false;
  v_other_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.blocked_users (blocker_profile_id, blocked_profile_id, scope)
    values ('c0000000-0000-4000-8000-000000000001',
            'd0000000-0000-4000-8000-000000000002', 'global');
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.blocked_users (blocker_profile_id, blocked_profile_id, scope)
    values ('c0000000-0000-4000-8000-000000000002',
            'd0000000-0000-4000-8000-000000000002', 'global');
  exception when others then
    v_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.blocked_users
   where blocker_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and blocked_profile_id = 'd0000000-0000-4000-8000-000000000002';
  insert into _phase6_verification values
    (43, 'RLS: blocked-user writes are blocker-only',
     case when v_own and v_other_blocked then 'PASS' else 'FAIL' end,
     'own=' || v_own || ', other blocked=' || v_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.blocked_users
   where blocker_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and blocked_profile_id = 'd0000000-0000-4000-8000-000000000002';
  insert into _phase6_verification values
    (43, 'RLS: blocked-user writes are blocker-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_own boolean := false;
  v_other_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.support_tickets (
      country_id, ticket_number, opened_by, category_id, subject
    ) values (
      '33333333-0000-4000-8000-000000000001', 'GATE6-000001',
      'c0000000-0000-4000-8000-000000000001',
      '8c000000-0000-4000-8000-000000000001', 'Gate support ticket'
    );
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.support_tickets (
      country_id, ticket_number, opened_by, category_id, subject
    ) values (
      '33333333-0000-4000-8000-000000000001', 'GATE6-000002',
      'c0000000-0000-4000-8000-000000000002',
      '8c000000-0000-4000-8000-000000000001', 'Gate spoofed ticket'
    );
  exception when others then
    v_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.support_tickets where ticket_number like 'GATE6-%';
  insert into _phase6_verification values
    (44, 'RLS: support ticket inserts must be self-opened',
     case when v_own and v_other_blocked then 'PASS' else 'FAIL' end,
     'own=' || v_own || ', other blocked=' || v_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.support_tickets where ticket_number like 'GATE6-%';
  insert into _phase6_verification values
    (44, 'RLS: support ticket inserts must be self-opened', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_own boolean := false;
  v_internal_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.support_ticket_messages (ticket_id, sender_profile_id, message)
    values ('8d000000-0000-4000-8000-000000000001',
            'c0000000-0000-4000-8000-000000000001', 'Gate customer reply');
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.support_ticket_messages (ticket_id, sender_profile_id, message, is_internal_note)
    values ('8d000000-0000-4000-8000-000000000001',
            'c0000000-0000-4000-8000-000000000001', 'Gate internal note', true);
  exception when others then
    v_internal_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.support_ticket_messages
   where message like 'Gate customer reply' or message like 'Gate internal note';
  insert into _phase6_verification values
    (45, 'RLS: ticket replies are self-authored and internal notes are staff-only',
     case when v_own and v_internal_blocked then 'PASS' else 'FAIL' end,
     'reply=' || v_own || ', internal blocked=' || v_internal_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.support_ticket_messages
   where message like 'Gate customer reply' or message like 'Gate internal note';
  insert into _phase6_verification values
    (45, 'RLS: ticket replies are self-authored and internal notes are staff-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_insert_active boolean := false;
  v_insert_read_only_blocked boolean := false;
  v_insert_nonparticipant_blocked boolean := false;
  v_msg_id bigint;
  v_edit_ok boolean := false;
  v_soft_delete_ok boolean := false;
  v_physical_delete_blocked boolean := false;
  v_old_edit_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  begin
    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body)
    values ('7e000000-0000-4000-8000-000000000002',
            'c0000000-0000-4000-8000-000000000002', 'text', 'Gate active message')
    returning id into v_msg_id;
    v_insert_active := true;
  exception when others then
    v_insert_active := false;
  end;

  begin
    update public.chat_messages set body = 'Gate edited message'
     where id = v_msg_id;
    v_edit_ok := true;
  exception when others then
    v_edit_ok := false;
  end;

  begin
    update public.chat_messages set body = 'Gate old edit'
     where id = (
       select min(id) from public.chat_messages
        where thread_id = '7e000000-0000-4000-8000-000000000002'
          and sender_profile_id = 'c0000000-0000-4000-8000-000000000002'
          and message_type = 'text'
     );
  exception when others then
    v_old_edit_blocked := true;
  end;

  begin
    delete from public.chat_messages where id = v_msg_id;
  exception when others then
    v_physical_delete_blocked := true;
  end;

  begin
    update public.chat_messages
       set is_deleted = true, deleted_at = now()
     where id = v_msg_id;
    v_soft_delete_ok := true;
  exception when others then
    v_soft_delete_ok := false;
  end;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body)
    values ('7e000000-0000-4000-8000-000000000001',
            'c0000000-0000-4000-8000-000000000001', 'text', 'Gate read-only message');
  exception when others then
    v_insert_read_only_blocked := true;
  end;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  begin
    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body)
    values ('7e000000-0000-4000-8000-000000000002',
            'c0000000-0000-4000-8000-000000000003', 'text', 'Gate nonparticipant message');
  exception when others then
    v_insert_nonparticipant_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.chat_messages where body like 'Gate %';
  update public.chat_threads t
     set last_message_at = (
           select max(m.created_at) from public.chat_messages m where m.thread_id = t.id
         ),
         last_message_preview = (
           select case
                    when m.message_type = 'image' then '[image]'
                    when m.message_type = 'location' then '[location]'
                    else m.body
                  end
             from public.chat_messages m
            where m.thread_id = t.id
            order by m.created_at desc
            limit 1
         )
   where t.id in ('7e000000-0000-4000-8000-000000000001',
                  '7e000000-0000-4000-8000-000000000002');

  insert into _phase6_verification values
    (46, 'RLS: chat writes are active-thread participant-only',
     case when v_insert_active and v_insert_read_only_blocked
            and v_insert_nonparticipant_blocked
          then 'PASS' else 'FAIL' end,
     'active=' || v_insert_active
       || ', read_only blocked=' || v_insert_read_only_blocked
       || ', nonparticipant blocked=' || v_insert_nonparticipant_blocked),
    (47, 'Chat edit window, soft delete, and physical delete trigger',
     case when v_edit_ok and v_old_edit_blocked and v_soft_delete_ok
            and v_physical_delete_blocked
          then 'PASS' else 'FAIL' end,
     'edit=' || v_edit_ok || ', old edit blocked=' || v_old_edit_blocked
       || ', soft delete=' || v_soft_delete_ok
       || ', physical delete blocked=' || v_physical_delete_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.chat_messages where body like 'Gate %';
  insert into _phase6_verification values
    (46, 'RLS: chat writes and immutability', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_message_id bigint;
  v_attachment_ok boolean := false;
  v_attachment_other_blocked boolean := false;
begin
  select min(id) into v_message_id
    from public.chat_messages
   where thread_id = '7e000000-0000-4000-8000-000000000002';

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  begin
    insert into public.chat_attachments (message_id, thread_id, storage_path)
    values (v_message_id, '7e000000-0000-4000-8000-000000000002', 'gate/attachment.jpg');
    v_attachment_ok := true;
  exception when others then
    v_attachment_ok := false;
  end;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  begin
    insert into public.chat_attachments (message_id, thread_id, storage_path)
    values (v_message_id, '7e000000-0000-4000-8000-000000000002', 'gate/other.jpg');
  exception when others then
    v_attachment_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.chat_attachments where storage_path like 'gate/%';
  insert into _phase6_verification values
    (48, 'RLS: chat attachments are participant-only',
     case when v_attachment_ok and v_attachment_other_blocked then 'PASS' else 'FAIL' end,
     'participant=' || v_attachment_ok || ', nonparticipant blocked=' || v_attachment_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.chat_attachments where storage_path like 'gate/%';
  insert into _phase6_verification values
    (48, 'RLS: chat attachments are participant-only', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_incident_ok boolean := false;
  v_incident_spoof_blocked boolean := false;
  v_incident_nonparticipant_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  begin
    insert into public.incidents (
      job_id, reported_by, incident_type, severity, status, description, occurred_at
    ) values (
      '4f000000-0000-4000-8000-000000000002',
      'c0000000-0000-4000-8000-000000000002',
      'other', 'low', 'open', 'Gate incident', now()
    );
    v_incident_ok := true;
  exception when others then
    v_incident_ok := false;
  end;

  begin
    insert into public.incidents (
      job_id, reported_by, incident_type, severity, status, description, occurred_at
    ) values (
      '4f000000-0000-4000-8000-000000000002',
      'c0000000-0000-4000-8000-000000000001',
      'other', 'low', 'open', 'Gate spoofed incident', now()
    );
  exception when others then
    v_incident_spoof_blocked := true;
  end;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  begin
    insert into public.incidents (
      job_id, reported_by, incident_type, severity, status, description, occurred_at
    ) values (
      '4f000000-0000-4000-8000-000000000002',
      'c0000000-0000-4000-8000-000000000003',
      'other', 'low', 'open', 'Gate nonparticipant incident', now()
    );
  exception when others then
    v_incident_nonparticipant_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.incidents where description like 'Gate %';
  insert into _phase6_verification values
    (49, 'RLS: incident inserts require self-reporting and job participation',
     case when v_incident_ok and v_incident_spoof_blocked
            and v_incident_nonparticipant_blocked
          then 'PASS' else 'FAIL' end,
     'own=' || v_incident_ok || ', spoof blocked=' || v_incident_spoof_blocked
       || ', nonparticipant blocked=' || v_incident_nonparticipant_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.incidents where description like 'Gate %';
  insert into _phase6_verification values
    (49, 'RLS: incident inserts require self-reporting and job participation', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_own boolean := false;
  v_other_blocked boolean := false;
begin
  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.data_subject_requests (
      request_number, requester_profile_id, request_type, status
    ) values (
      'GATE6-DSR-1', 'c0000000-0000-4000-8000-000000000001', 'export', 'received'
    );
    v_own := true;
  exception when others then
    v_own := false;
  end;

  begin
    insert into public.data_subject_requests (
      request_number, requester_profile_id, request_type, status
    ) values (
      'GATE6-DSR-2', 'c0000000-0000-4000-8000-000000000002', 'export', 'received'
    );
  exception when others then
    v_other_blocked := true;
  end;
  perform pg_temp.clear_auth();

  delete from public.data_subject_requests where request_number like 'GATE6-DSR-%';
  insert into _phase6_verification values
    (50, 'RLS: data subject requests are self-opened',
     case when v_own and v_other_blocked then 'PASS' else 'FAIL' end,
     'own=' || v_own || ', other blocked=' || v_other_blocked);
exception when others then
  perform pg_temp.clear_auth();
  delete from public.data_subject_requests where request_number like 'GATE6-DSR-%';
  insert into _phase6_verification values
    (50, 'RLS: data subject requests are self-opened', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_privileged_ok integer := 0;
  v_customer_blocked integer := 0;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000001');

  begin
    insert into public.notification_templates (
      country_id, language_id, code, channel, title_template, body_template
    ) values (
      '33333333-0000-4000-8000-000000000001',
      '22222222-0000-4000-8000-000000000001',
      'gate_write_template', 'push', 'Gate', 'Gate body'
    );
    v_privileged_ok := v_privileged_ok + 1;
  exception when others then null;
  end;

  begin
    insert into public.prohibited_items (
      country_id, category, name, severity
    ) values (
      '33333333-0000-4000-8000-000000000001', 'other', 'Gate Prohibited Item', 'prohibited'
    );
    v_privileged_ok := v_privileged_ok + 1;
  exception when others then null;
  end;

  begin
    insert into public.support_categories (country_id, code, name)
    values ('33333333-0000-4000-8000-000000000001', 'gate_support_category', 'Gate category');
    v_privileged_ok := v_privileged_ok + 1;
  exception when others then null;
  end;

  begin
    insert into public.retention_policies (table_name, retention_period, action)
    values ('gate_retention_policy', interval '1 day', 'delete');
    v_privileged_ok := v_privileged_ok + 1;
  exception when others then null;
  end;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  begin
    insert into public.notification_templates (
      country_id, language_id, code, channel, title_template, body_template
    ) values (
      '33333333-0000-4000-8000-000000000001',
      '22222222-0000-4000-8000-000000000001',
      'gate_customer_template', 'push', 'Gate', 'Gate body'
    );
  exception when others then v_customer_blocked := v_customer_blocked + 1;
  end;

  begin
    insert into public.prohibited_items (country_id, category, name, severity)
    values ('33333333-0000-4000-8000-000000000001', 'other', 'Gate Customer Item', 'prohibited');
  exception when others then v_customer_blocked := v_customer_blocked + 1;
  end;

  begin
    insert into public.support_categories (country_id, code, name)
    values ('33333333-0000-4000-8000-000000000001', 'gate_customer_category', 'Gate customer category');
  exception when others then v_customer_blocked := v_customer_blocked + 1;
  end;

  begin
    insert into public.retention_policies (table_name, retention_period, action)
    values ('gate_customer_policy', interval '1 day', 'delete');
  exception when others then v_customer_blocked := v_customer_blocked + 1;
  end;
  perform pg_temp.clear_auth();

  delete from public.notification_templates where code like 'gate_%_template';
  delete from public.prohibited_items where name like 'Gate %Item';
  delete from public.support_categories where code like 'gate_%_category';
  delete from public.retention_policies where table_name like 'gate_%_policy';

  insert into _phase6_verification values
    (51, 'RLS: catalogue writes require their manage permissions',
     case when v_privileged_ok = 4 and v_customer_blocked = 4
          then 'PASS' else 'FAIL' end,
     'super_admin=' || v_privileged_ok || '/4, customer blocked='
       || v_customer_blocked || '/4');
exception when others then
  perform pg_temp.clear_auth();
  delete from public.notification_templates where code like 'gate_%_template';
  delete from public.prohibited_items where name like 'Gate %Item';
  delete from public.support_categories where code like 'gate_%_category';
  delete from public.retention_policies where table_name like 'gate_%_policy';
  insert into _phase6_verification values
    (51, 'RLS: catalogue writes require their manage permissions', 'FAIL', sqlerrm);
end $$;

insert into _phase6_verification (check_no, check_name, status, details)
select 52, 'Client write grants are absent on append-only and metrics tables',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(table_name || '.' || privilege, ', '), 'no client write grants')
from (values
  ('notification_log', 'INSERT'),
  ('notification_log', 'UPDATE'),
  ('notification_log', 'DELETE'),
  ('data_access_log', 'INSERT'),
  ('data_access_log', 'UPDATE'),
  ('data_access_log', 'DELETE'),
  ('incident_actions', 'INSERT'),
  ('incident_actions', 'UPDATE'),
  ('incident_actions', 'DELETE'),
  ('support_ticket_messages', 'UPDATE'),
  ('support_ticket_messages', 'DELETE'),
  ('chat_messages', 'DELETE'),
  ('daily_metrics', 'INSERT'),
  ('daily_metrics', 'UPDATE'),
  ('daily_metrics', 'DELETE'),
  ('zone_metrics', 'INSERT'),
  ('zone_metrics', 'UPDATE'),
  ('zone_metrics', 'DELETE'),
  ('driver_metrics', 'INSERT'),
  ('driver_metrics', 'UPDATE'),
  ('driver_metrics', 'DELETE'),
  ('customer_metrics', 'INSERT'),
  ('customer_metrics', 'UPDATE'),
  ('customer_metrics', 'DELETE'),
  ('demand_snapshots', 'INSERT'),
  ('demand_snapshots', 'UPDATE'),
  ('demand_snapshots', 'DELETE')
) as expected(table_name, privilege)
where has_table_privilege(
  'authenticated',
  format('public.%I', expected.table_name),
  expected.privilege
);

insert into _phase6_verification (check_no, check_name, status, details)
select 52, 'Own-row SELECT grants remain on notification_log',
       case when has_table_privilege('authenticated', 'public.notification_log', 'SELECT')
             and not has_table_privilege('authenticated', 'public.notification_log', 'INSERT')
            then 'PASS' else 'FAIL' end,
       'select='
       || has_table_privilege('authenticated', 'public.notification_log', 'SELECT')::text
       || ', insert='
       || has_table_privilege('authenticated', 'public.notification_log', 'INSERT')::text;

insert into _phase6_verification (check_no, check_name, status, details)
select 53, 'All 10 Phase 6 immutability/writer triggers exist',
       case when count(distinct tgname) = 10 then 'PASS' else 'FAIL' end,
       count(distinct tgname) || ' of 10'
from pg_trigger
where not tgisinternal
  and tgname in (
    'trg_notification_log_immutable',
    'trg_chat_messages_immutable',
    'trg_incident_actions_immutable',
    'trg_support_ticket_messages_immutable',
    'trg_data_access_log_immutable',
    'trg_daily_metrics_writer',
    'trg_zone_metrics_writer',
    'trg_driver_metrics_writer',
    'trg_customer_metrics_writer',
    'trg_demand_snapshots_writer'
  );

insert into _phase6_verification (check_no, check_name, status, details)
select 53, 'Mutable Phase 6 roots use private.audit_trigger()',
       case when count(distinct t.tgname) = 12
             and to_regprocedure('private.audit_trigger()') is not null
            then 'PASS' else 'FAIL' end,
       count(distinct t.tgname) || ' of 12 audit triggers'
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and not t.tgisinternal
  and c.relname in (
    'push_tokens','notification_templates','notification_preferences','chat_threads',
    'emergency_contacts','incidents','blocked_users','prohibited_items',
    'support_categories','support_tickets','retention_policies','data_subject_requests'
  )
  and t.tgfoid = to_regprocedure('private.audit_trigger()');

insert into _phase6_verification (check_no, check_name, status, details)
select 53, 'PII logging is wired into the four non-owner read policies',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' of 4 policies use log_pii_select()'
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles','driver_documents','vehicle_documents','driver_locations')
  and coalesce(qual, '') like '%log_pii_select%';

-- ----------------------------------------------------------------------------
-- 13. Chat integrity triggers
-- ----------------------------------------------------------------------------
do $$
declare
  v_reply_blocked boolean := false;
  v_attachment_blocked boolean := false;
  v_receipt_blocked boolean := false;
  v_thread1_message bigint;
begin
  select min(id) into v_thread1_message
    from public.chat_messages
   where thread_id = '7e000000-0000-4000-8000-000000000001';

  begin
    insert into public.chat_messages (
      thread_id, sender_profile_id, message_type, body, reply_to_message_id
    ) values (
      '7e000000-0000-4000-8000-000000000002',
      'c0000000-0000-4000-8000-000000000002',
      'text', 'Gate cross-thread reply', v_thread1_message
    );
  exception when others then v_reply_blocked := true;
  end;

  begin
    insert into public.chat_attachments (message_id, thread_id, storage_path)
    values (v_thread1_message, '7e000000-0000-4000-8000-000000000002', 'gate/cross.jpg');
  exception when others then v_attachment_blocked := true;
  end;

  begin
    insert into public.chat_read_receipts (
      thread_id, profile_id, last_read_message_id
    ) values (
      '7e000000-0000-4000-8000-000000000002',
      'c0000000-0000-4000-8000-000000000001', v_thread1_message
    );
  exception when others then v_receipt_blocked := true;
  end;

  delete from public.chat_attachments where storage_path like 'gate/%';
  insert into _phase6_verification values
    (54, 'Chat reply/attachment/receipt cross-thread integrity is enforced',
     case when v_reply_blocked and v_attachment_blocked and v_receipt_blocked
          then 'PASS' else 'FAIL' end,
     'reply=' || v_reply_blocked || ', attachment=' || v_attachment_blocked
       || ', receipt=' || v_receipt_blocked);
exception when others then
  delete from public.chat_attachments where storage_path like 'gate/%';
  insert into _phase6_verification values
    (54, 'Chat reply/attachment/receipt cross-thread integrity is enforced', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 14. PII access logging
-- ----------------------------------------------------------------------------
do $$
declare
  v_before integer;
  v_after integer;
  v_own_before integer;
  v_own_after integer;
begin
  select count(*) into v_before
    from public.data_access_log
   where accessor_profile_id = 'a0000000-0000-4000-8000-000000000001'
     and target_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and purpose = 'rls_pii_select';

  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
  perform 1 from public.profiles
   where id = 'c0000000-0000-4000-8000-000000000001';
  perform pg_temp.clear_auth();

  select count(*) into v_after
    from public.data_access_log
   where accessor_profile_id = 'a0000000-0000-4000-8000-000000000001'
     and target_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and purpose = 'rls_pii_select';

  select count(*) into v_own_before
    from public.data_access_log
   where accessor_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and target_profile_id = 'c0000000-0000-4000-8000-000000000001';

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  perform 1 from public.profiles
   where id = 'c0000000-0000-4000-8000-000000000001';
  perform pg_temp.clear_auth();

  select count(*) into v_own_after
    from public.data_access_log
   where accessor_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and target_profile_id = 'c0000000-0000-4000-8000-000000000001';

  insert into _phase6_verification values
    (55, 'PDPC logging records staff PII reads but not self reads',
     case when v_after = v_before + 1 and v_own_after = v_own_before
          then 'PASS' else 'FAIL' end,
     'staff before/after=' || v_before || '/' || v_after
       || ', self before/after=' || v_own_before || '/' || v_own_after);

  delete from public.data_access_log
   where accessor_profile_id = 'a0000000-0000-4000-8000-000000000001'
     and target_profile_id = 'c0000000-0000-4000-8000-000000000001'
     and purpose = 'rls_pii_select';
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (55, 'PDPC logging records staff PII reads but not self reads', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_id bigint;
  v_exists boolean;
begin
  v_id := public.log_data_access(
    'a0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'profiles',
    'phone',
    'c0000000-0000-4000-8000-000000000001',
    'read',
    'gate_log_data_access',
    true
  );

  select exists(
    select 1 from public.data_access_log
     where id = v_id and purpose = 'gate_log_data_access'
  ) into v_exists;

  delete from public.data_access_log where id = v_id;

  insert into _phase6_verification values
    (56, 'log_data_access() writes and returns a BIGINT id',
     case when v_id is not null and v_exists then 'PASS' else 'FAIL' end,
     'id=' || coalesce(v_id::text, 'null') || ', exists=' || v_exists);
exception when others then
  delete from public.data_access_log where purpose = 'gate_log_data_access';
  insert into _phase6_verification values
    (56, 'log_data_access() writes and returns a BIGINT id', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 15. Notification send pipeline and preferences
-- ----------------------------------------------------------------------------
do $$
declare
  v_public_id uuid;
  v_logged integer;
  v_body text;
  v_skipped uuid;
  v_missing_blocked boolean := false;
begin
  v_public_id := public.send_notification(
    'c0000000-0000-4000-8000-000000000001',
    'job_offer',
    'push',
    '{"vehicle_type":"Small van","eta_minutes":"8","fare":"TZS 29,559"}'::jsonb,
    'job',
    '4f000000-0000-4000-8000-000000000001'
  );

  select count(*), max(body) into v_logged, v_body
    from public.notification_log
   where public_id = v_public_id
     and status = 'pending';

  update public.notification_preferences
     set is_enabled = false
   where profile_id = 'c0000000-0000-4000-8000-000000000001'
     and category = 'job_updates' and channel = 'push';

  v_skipped := public.send_notification(
    'c0000000-0000-4000-8000-000000000001',
    'job_offer',
    'push',
    '{}'::jsonb,
    null,
    null
  );

  update public.notification_preferences
     set is_enabled = true
   where profile_id = 'c0000000-0000-4000-8000-000000000001'
     and category = 'job_updates' and channel = 'push';

  begin
    perform public.send_notification(
      'c0000000-0000-4000-8000-000000000001',
      'gate_missing_template',
      'push',
      '{}'::jsonb,
      null,
      null
    );
  exception when others then v_missing_blocked := true;
  end;

  delete from public.notification_log where public_id = v_public_id;

  insert into _phase6_verification values
    (57, 'send_notification() returns public_id and writes a pending row',
     case when v_public_id is not null and v_logged = 1
            and v_body like '%Small van%' and v_skipped is null
            and v_missing_blocked
          then 'PASS' else 'FAIL' end,
     'public_id=' || coalesce(v_public_id::text, 'null')
       || ', logged=' || v_logged
       || ', preference skip=' || (v_skipped is null)::text
       || ', missing template blocked=' || v_missing_blocked);
exception when others then
  update public.notification_preferences
     set is_enabled = true
   where profile_id = 'c0000000-0000-4000-8000-000000000001'
     and category = 'job_updates' and channel = 'push';
  delete from public.notification_log where template_code in ('job_offer','gate_missing_template')
    and created_at > now() - interval '10 minutes';
  insert into _phase6_verification values
    (57, 'send_notification() returns public_id and writes a pending row', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 16. Analytics functions and retention
-- ----------------------------------------------------------------------------
do $$
declare
  v_daily integer;
  v_zone integer;
  v_driver integer;
  v_customer integer;
  v_demand integer;
  v_bucket timestamptz;
  v_existed boolean;
begin
  v_daily := public.compute_daily_metrics(current_date - 1);
  v_zone := public.compute_zone_metrics(current_date - 1);
  v_driver := public.compute_driver_metrics(current_date - 1);
  v_customer := public.compute_customer_metrics(current_date - 1);

  v_bucket := to_timestamp(floor(extract(epoch from now()) / 300) * 300);
  select exists(
    select 1 from public.demand_snapshots where snapshot_at = v_bucket
  ) into v_existed;
  v_demand := public.capture_demand_snapshot();

  if not v_existed then
    delete from public.demand_snapshots where snapshot_at = v_bucket;
  end if;

  insert into _phase6_verification values
    (60, 'Analytics batch functions write/update their target tables',
     case when v_daily > 0 and v_zone > 0 and v_driver > 0
            and v_customer > 0 and v_demand > 0
          then 'PASS' else 'FAIL' end,
     'daily=' || v_daily || ', zone=' || v_zone || ', driver=' || v_driver
       || ', customer=' || v_customer || ', demand=' || v_demand);
exception when others then
  insert into _phase6_verification values
    (60, 'Analytics batch functions write/update their target tables', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_rows bigint := 0;
  v_before integer;
  v_after integer;
  v_policy_rows bigint;
  v_archive_count integer;
begin
  insert into public.data_access_log (
    accessor_profile_id, target_profile_id, target_table, access_type,
    purpose, was_authorized, created_at
  ) values (
    'a0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'profiles', 'read', 'gate_retention', true, now() - interval '8 years'
  );

  select count(*) into v_before
    from public.data_access_log where purpose = 'gate_retention';

  select coalesce(sum(rows_deleted), 0) into v_rows
    from public.apply_retention_policies();

  select count(*) into v_after
    from public.data_access_log where purpose = 'gate_retention';

  select last_run_rows_affected into v_policy_rows
    from public.retention_policies
   where table_name = 'data_access_log';

  v_archive_count := public.archive_stale_chat_threads();

  insert into _phase6_verification values
    (61, 'Retention policies delete expired logs and update run metadata',
     case when v_before = 1 and v_after = 0 and v_rows >= 1
            and v_policy_rows >= 1 and v_archive_count >= 0
          then 'PASS' else 'FAIL' end,
     'before/after=' || v_before || '/' || v_after
       || ', rows=' || v_rows || ', policy rows=' || v_policy_rows
       || ', archive calls=' || v_archive_count);
exception when others then
  delete from public.data_access_log where purpose = 'gate_retention';
  insert into _phase6_verification values
    (61, 'Retention policies delete expired logs and update run metadata', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 17. View behaviour
-- ----------------------------------------------------------------------------
do $$
declare
  v_dashboard integer;
  v_zones integer;
  v_incidents integer;
  v_tickets integer;
  v_c2_unread integer;
  v_c3_unread integer;
  v_c1_notifications integer;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000001');
  select count(*) into v_dashboard from public.operational_dashboard;
  select count(*) into v_zones from public.active_demand_zones;
  select count(*) into v_incidents from public.incident_summary;
  select count(*) into v_tickets from public.support_ticket_summary;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000002');
  select count(*) into v_c2_unread from public.chat_unread_summary;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000003');
  select count(*) into v_c3_unread from public.chat_unread_summary;
  perform pg_temp.clear_auth();

  perform pg_temp.as_user('c0000000-0000-4000-8000-000000000001');
  select count(*) into v_c1_notifications from public.notification_summary;
  perform pg_temp.clear_auth();

  insert into _phase6_verification values
    (62, 'Operational views respect RLS and return expected row counts',
     case when v_dashboard = 1 and v_zones = 3 and v_incidents = 2
            and v_tickets = 2 and v_c2_unread = 1 and v_c3_unread = 0
            and v_c1_notifications = 0
          then 'PASS' else 'FAIL' end,
     'dashboard=' || v_dashboard || ', zones=' || v_zones
       || ', incidents=' || v_incidents || ', tickets=' || v_tickets
       || ', c2 unread=' || v_c2_unread || ', c3 unread=' || v_c3_unread
       || ', c1 notifications=' || v_c1_notifications);
exception when others then
  perform pg_temp.clear_auth();
  insert into _phase6_verification values
    (62, 'Operational views respect RLS and return expected row counts', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 18. Results
-- ----------------------------------------------------------------------------
select
  check_no,
  lpad(check_no::text, 2, '0') as no,
  check_name,
  status,
  details
from _phase6_verification
order by check_no, check_name;

select
  'PHASE 6 SCHEMA VERIFICATION: '
  || count(*) filter (where status = 'PASS')
  || ' PASS, '
  || count(*) filter (where status = 'FAIL')
  || ' FAIL' as result
from _phase6_verification;

drop table if exists _phase6_verification;
drop table if exists _phase6_tables;
drop table if exists _phase6_views;
drop table if exists _phase6_functions;
drop table if exists _phase6_status_columns;


