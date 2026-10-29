-- ============================================================================
-- SafeShift — Phase 9 schema verification
--
-- Usage (local):
--   docker exec -i supabase_db_safeshift psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-9-schema.sql
--
-- Run after migrations 0001–0127 and all seeds. This gate verifies the
-- backend contract used by the Phase 9 mobile flows and admin console.
-- Edge Function file checks live in scripts/verify-phase-9-functions.sh.
-- ============================================================================

set search_path = public, extensions;

drop table if exists _phase9_verification;
create temporary table _phase9_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

-- ----------------------------------------------------------------------------
-- 1. New safety tables and columns
-- ----------------------------------------------------------------------------
insert into _phase9_verification (check_no, check_name, status, details)
select 1, 'trip_alerts has all required columns',
       case when count(*) = 14 then 'PASS' else 'FAIL' end,
       count(*) || ' of 14 columns present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'trip_alerts'
  and column_name in (
    'id', 'job_id', 'profile_id', 'alert_type', 'status', 'location', 'details',
    'metadata', 'acknowledged_by', 'acknowledged_at', 'resolved_by',
    'resolved_at', 'created_at', 'updated_at'
  );

insert into _phase9_verification (check_no, check_name, status, details)
select 2, 'trip_share_tokens has all required columns',
       case when count(*) = 6 then 'PASS' else 'FAIL' end,
       count(*) || ' of 6 columns present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'trip_share_tokens'
  and column_name in ('id', 'job_id', 'token', 'created_by', 'expires_at', 'created_at');

insert into _phase9_verification (check_no, check_name, status, details)
select 3, 'trip_alerts and trip_share_tokens have RLS enabled',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' of 2 tables have RLS'
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('trip_alerts', 'trip_share_tokens')
  and c.relrowsecurity;

insert into _phase9_verification (check_no, check_name, status, details)
select 4, 'trip_alerts has participant and staff policies',
       case when count(*) >= 3 then 'PASS' else 'FAIL' end,
       count(*) || ' policies (expected >= 3)'
from pg_policies
where schemaname = 'public' and tablename = 'trip_alerts';

insert into _phase9_verification (check_no, check_name, status, details)
select 5, 'trip_share_tokens has participant and staff policies',
       case when count(*) >= 3 then 'PASS' else 'FAIL' end,
       count(*) || ' policies (expected >= 3)'
from pg_policies
where schemaname = 'public' and tablename = 'trip_share_tokens';

insert into _phase9_verification (check_no, check_name, status, details)
select 6, 'trip_alerts references jobs and profiles',
       case when count(*) filter (where ccu.table_name = 'jobs') >= 1
                  and count(*) filter (where ccu.table_name = 'profiles') >= 1
            then 'PASS' else 'FAIL' end,
       count(*) || ' foreign-key columns present'
from information_schema.table_constraints tc
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
 and ccu.constraint_schema = tc.constraint_schema
where tc.table_schema = 'public'
  and tc.table_name = 'trip_alerts'
  and tc.constraint_type = 'FOREIGN KEY'
  and ccu.table_name in ('jobs', 'profiles');

insert into _phase9_verification (check_no, check_name, status, details)
select 7, 'trip_share_tokens.token is unique',
       case when count(*) >= 1 then 'PASS' else 'FAIL' end,
       count(*) || ' unique constraint/index found'
from pg_indexes
where schemaname = 'public'
  and tablename = 'trip_share_tokens'
  and indexdef ilike '%unique%token%';

insert into _phase9_verification (check_no, check_name, status, details)
select 8, 'trip_alerts updated_at trigger exists',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' trigger found'
from pg_trigger
where tgrelid = 'public.trip_alerts'::regclass
  and tgname = 'trg_trip_alerts_updated_at'
  and not tgisinternal;

-- ----------------------------------------------------------------------------
-- 2. Security-definer functions
-- ----------------------------------------------------------------------------
insert into _phase9_verification (check_no, check_name, status, details)
select 9, 'Phase 9 functions are security definer with empty search_path',
       case when count(*) = 8 then 'PASS' else 'FAIL' end,
       count(*) || ' of 8 functions hardened'
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'generate_recurring_scheduled_jobs', 'create_trip_share_token',
    'trip_share_snapshot', 'admin_approve_verification',
    'admin_reject_verification', 'admin_search_profiles',
    'admin_recent_activity', 'admin_console_role'
  )
  and p.prosecdef
  and p.proconfig::text like '%search_path%';

insert into _phase9_verification (check_no, check_name, status, details)
select 10, 'create_trip_share_token is executable by authenticated users',
       case when has_function_privilege('authenticated', 'public.create_trip_share_token(uuid)', 'EXECUTE')
            then 'PASS' else 'FAIL' end,
       'authenticated execute privilege';

insert into _phase9_verification (check_no, check_name, status, details)
select 11, 'trip_share_snapshot is executable by anon (public tracking)',
       case when has_function_privilege('anon', 'public.trip_share_snapshot(text)', 'EXECUTE')
            then 'PASS' else 'FAIL' end,
       'anon execute privilege';

insert into _phase9_verification (check_no, check_name, status, details)
select 12, 'trip tables deny anon direct access',
       case when not has_table_privilege('anon', 'public.trip_alerts', 'SELECT')
             and not has_table_privilege('anon', 'public.trip_share_tokens', 'SELECT')
            then 'PASS' else 'FAIL' end,
       'anon has no direct SELECT on either table';

-- ----------------------------------------------------------------------------
-- 3. Recurring scheduler
-- ----------------------------------------------------------------------------
insert into _phase9_verification (check_no, check_name, status, details)
select 13, 'recurring scheduler function returns integer',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' function signature found'
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'generate_recurring_scheduled_jobs'
  and pg_get_function_result(p.oid) = 'integer';

insert into _phase9_verification (check_no, check_name, status, details)
select 14, 'pg_cron job safeshift_generate_scheduled_jobs is registered',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' cron job(s) found'
from cron.job
where jobname = 'safeshift_generate_scheduled_jobs';

insert into _phase9_verification (check_no, check_name, status, details)
select 15, 'scheduled_jobs keeps its template/time uniqueness guard',
       case when count(*) >= 1 then 'PASS' else 'FAIL' end,
       count(*) || ' matching unique constraint/index(es)'
from pg_indexes
where schemaname = 'public'
  and tablename = 'scheduled_jobs'
  and indexdef ilike '%template_id%'
  and indexdef ilike '%scheduled_for%'
  and indexdef ilike '%unique%';

-- ----------------------------------------------------------------------------
-- 4. Admin console view, roles, permissions
-- ----------------------------------------------------------------------------
insert into _phase9_verification (check_no, check_name, status, details)
select 16, 'admin_dashboard_metrics view exists with security_invoker',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' view with security_invoker=true'
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'admin_dashboard_metrics'
  and c.relkind = 'v'
  and c.reloptions::text like '%security_invoker=true%';

insert into _phase9_verification (check_no, check_name, status, details)
select 17, 'admin_dashboard_metrics exposes Phase 9 counters',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' of 4 Phase 9 counters present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'admin_dashboard_metrics'
  and column_name in ('open_sos_alerts', 'open_disputes', 'pending_verifications', 'active_jobs');

insert into _phase9_verification (check_no, check_name, status, details)
select 18, 'fleet_owner is allowed by both role-name checks',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' of 2 role-name constraints include fleet_owner'
from pg_constraint
where conname in ('admin_roles_role_name_check', 'admin_role_permissions_role_name_check')
  and pg_get_constraintdef(oid) like '%fleet_owner%';

insert into _phase9_verification (check_no, check_name, status, details)
select 19, 'fleet_owner has scoped fleet permissions',
       case when count(*) >= 4 then 'PASS' else 'FAIL' end,
       count(*) || ' fleet_owner permission grants'
from public.admin_role_permissions
where role_name = 'fleet_owner';

insert into _phase9_verification (check_no, check_name, status, details)
select 20, 'seeded fleet owner has an active console role',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' active fleet_owner admin role(s)'
from public.admin_roles
where profile_id = 'f0000000-0000-4000-8000-000000000001'::uuid
  and role_name = 'fleet_owner'
  and is_active;

insert into _phase9_verification (check_no, check_name, status, details)
select 21, 'Phase 9 permissions exist in the catalogue',
       case when count(*) = 15 then 'PASS' else 'FAIL' end,
       count(*) || ' of 15 Phase 9 permissions present'
from public.admin_permissions_catalog
where permission_key in (
  'view_verifications', 'manage_verifications', 'manage_business_verifications',
  'view_fleet', 'manage_fleet_vehicles', 'manage_fleet_drivers',
  'view_fleet_earnings', 'manage_tariffs', 'manage_promos',
  'view_support_tickets', 'manage_support_tickets', 'view_payouts',
  'manage_payouts', 'view_all_businesses', 'manage_support'
);

-- ----------------------------------------------------------------------------
-- 5. Dispute evidence storage and Phase 9 reference data
-- ----------------------------------------------------------------------------
insert into _phase9_verification (check_no, check_name, status, details)
select 22, 'dispute evidence storage policies exist',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' of 2 policies present'
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname in ('dispute_evidence_storage_select', 'dispute_evidence_storage_insert');

insert into _phase9_verification (check_no, check_name, status, details)
select 23, 'Phase 9 support categories are seeded',
       case when count(*) >= 4 then 'PASS' else 'FAIL' end,
       count(*) || ' Phase 9 support categories present'
from public.support_categories
where code in ('business_account', 'safety', 'driver_onboarding', 'trip_issue');

insert into _phase9_verification (check_no, check_name, status, details)
select 24, 'Phase 9 feature flags are seeded',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' of 4 feature flags present'
from public.feature_flags
where flag_key in (
  'phase9_driver_onboarding', 'phase9_business_accounts',
  'phase9_safety_suite', 'phase9_admin_console'
);

insert into _phase9_verification (check_no, check_name, status, details)
select 25, 'verification decisions are auditable',
       case when has_function_privilege('authenticated', 'public.admin_approve_verification(uuid,text)', 'EXECUTE')
             and has_function_privilege('authenticated', 'public.admin_reject_verification(uuid,text)', 'EXECUTE')
            then 'PASS' else 'FAIL' end,
       'authenticated execute privileges on approve/reject RPCs';

insert into _phase9_verification (check_no, check_name, status, details)
select 26, 'admin activity feed is permission-gated',
       case when has_function_privilege('authenticated', 'public.admin_recent_activity(integer)', 'EXECUTE')
            then 'PASS' else 'FAIL' end,
       'authenticated execute privilege; function checks view_audit internally';

-- ----------------------------------------------------------------------------
-- 6. Seed fixtures required by manual tests
-- ----------------------------------------------------------------------------
insert into _phase9_verification (check_no, check_name, status, details)
select 27, 'seeded business account is verified for recurring jobs',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' verified business account(s)'
from public.business_accounts
where id = 'b0000000-0000-4000-8000-000000000001'::uuid
  and verified_at is not null;

insert into _phase9_verification (check_no, check_name, status, details)
select 28, 'seeded recurring template is active and weekly',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' active recurring template(s)'
from public.recurring_job_templates
where id = '6d000000-0000-4000-8000-000000000001'::uuid
  and is_active
  and recurrence_rule ilike 'FREQ=WEEKLY%';

insert into _phase9_verification (check_no, check_name, status, details)
select 29, 'seeded emergency contacts exist for customer and driver',
       case when count(*) >= 2 then 'PASS' else 'FAIL' end,
       count(*) || ' seeded emergency contact(s)'
from public.emergency_contacts
where profile_id in (
  'c0000000-0000-4000-8000-000000000001'::uuid,
  'd0000000-0000-4000-8000-000000000001'::uuid
);

insert into _phase9_verification (check_no, check_name, status, details)
select 30, 'Phase 8 storage policy count remains unchanged',
       case when count(*) = 12 then 'PASS' else 'FAIL' end,
       count(*) || ' of 12 Phase 8 bucket policies present'
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    policyname like 'driver_documents_storage_%'
    or policyname like 'vehicle_documents_storage_%'
    or policyname like 'job_evidence_storage_%'
    or policyname like 'chat_attachments_storage_%'
  );

insert into _phase9_verification (check_no, check_name, status, details)
select 31, 'drivers cannot self-verify trust fields',
       case when exists (
              select 1 from pg_trigger
               where tgname = 'trg_protect_driver_trust_fields'
                 and not tgisinternal
            )
            and exists (
              select 1 from pg_policies
               where schemaname = 'public'
                 and tablename = 'drivers'
                 and policyname = 'drivers_insert_self'
            )
            then 'PASS' else 'FAIL' end,
       'trust-field trigger and pending-only insert policy present';

insert into _phase9_verification (check_no, check_name, status, details)
select 32, 'business creators can read a newly inserted account',
       case when exists (
              select 1 from information_schema.columns
               where table_schema = 'public'
                 and table_name = 'business_accounts'
                 and column_name = 'created_by'
            )
            and exists (
              select 1 from pg_policies
               where schemaname = 'public'
                 and tablename = 'business_accounts'
                 and policyname = 'business_accounts_select_creator'
            )
            then 'PASS' else 'FAIL' end,
       'created_by column and creator SELECT policy present';

-- ----------------------------------------------------------------------------
-- Summary
-- ----------------------------------------------------------------------------
\echo ''
\echo 'Phase 9 verification details:'
select check_no, status, check_name, details
from _phase9_verification
order by check_no;

\echo ''
select format(
  'PHASE 9 SCHEMA VERIFICATION: %s PASS, %s FAIL',
  count(*) filter (where status = 'PASS'),
  count(*) filter (where status = 'FAIL')
) as summary
from _phase9_verification;
