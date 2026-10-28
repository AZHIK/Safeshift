-- ============================================================================
-- SafeShift — Phase 1 schema verification
--
-- Usage (local only):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -f supabase/scripts/verify-phase-1-schema.sql
--
-- Run AFTER `supabase db reset` (or after migrations + seed) so that the seed
-- count checks can pass. Every check prints PASS or FAIL; the final line must
-- read "PHASE 1 SCHEMA VERIFICATION: X PASS, 0 FAIL".
-- ============================================================================

drop table if exists _phase1_verification;

create temporary table _phase1_verification (
  check_no   integer not null,
  check_name text    not null,
  status     text    not null,
  details    text
);

-- ----------------------------------------------------------------------------
-- 1. Extensions
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 1, 'Extension ' || e.name,
       case when x.extname is not null then 'PASS' else 'FAIL' end,
       coalesce(x.extversion, 'not installed')
from (values ('postgis'), ('pg_cron'), ('pgcrypto')) as e(name)
left join pg_extension x on x.extname = e.name;

-- ----------------------------------------------------------------------------
-- 2. Tables (30 Phase 1 tables)
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 2, 'Table ' || t.name,
       case when to_regclass(t.name) is not null then 'PASS' else 'FAIL' end,
       case when to_regclass(t.name) is null then 'missing' else 'present' end
from (values
  ('public.countries'),
  ('public.regions'),
  ('public.cities'),
  ('public.service_zones'),
  ('public.neighborhoods'),
  ('public.addresses'),
  ('public.zone_pricing_overrides'),
  ('public.profiles'),
  ('public.user_devices'),
  ('public.user_sessions'),
  ('public.customers'),
  ('public.business_accounts'),
  ('public.business_members'),
  ('public.drivers'),
  ('public.driver_status_history'),
  ('public.driver_operating_zones'),
  ('public.driver_service_hours'),
  ('public.user_referrals'),
  ('public.saved_addresses'),
  ('public.admin_roles'),
  ('public.admin_permissions_catalog'),
  ('public.admin_role_permissions'),
  ('public.admin_actions_log'),
  ('public.currencies'),
  ('public.exchange_rates'),
  ('public.languages'),
  ('public.localization_strings'),
  ('public.feature_flags'),
  ('public.consent_records'),
  ('private.audit_log')
) as t(name);

-- ----------------------------------------------------------------------------
-- 3. Enums and exact values
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 3, 'Enum public.' || e.typname,
       case when v.labels is not null and v.labels = e.expected then 'PASS' else 'FAIL' end,
       coalesce(array_to_string(v.labels, ','), 'missing')
from (
  values
    ('user_role',
     array['customer','driver','business','admin','fleet_owner']),
    ('driver_verification_status',
     array['pending','verified','rejected','re_verification_due','suspended']),
    ('driver_risk_tier',
     array['standard','enhanced','restricted']),
    ('audit_action',
     array['insert','update','delete','login','logout','verification_approved','verification_rejected','payout_changed','pricing_changed','admin_override','consent_granted','consent_revoked','user_suspended','user_reactivated'])
) as e(typname, expected)
left join lateral (
  select array_agg(en.enumlabel::text order by en.enumsortorder) as labels
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    join pg_enum en on en.enumtypid = t.oid
   where n.nspname = 'public' and t.typname = e.typname
) v on true;

-- ----------------------------------------------------------------------------
-- 4. Foreign keys validated
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 4, 'All foreign keys validated',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*)::text || ' unvalidated FK(s)'
from pg_constraint
where contype = 'f' and not convalidated;

insert into _phase1_verification (check_no, check_name, status, details)
select 4, 'No orphaned Phase 1 foreign keys',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*)::text || ' FK(s) reference a missing table'
from pg_constraint c
where c.contype = 'f'
  and c.connamespace = 'public'::regnamespace
  and not exists (
    select 1 from pg_class rc
    join pg_namespace rn on rn.oid = rc.relnamespace
    where rc.oid = c.confrelid
  );

-- ----------------------------------------------------------------------------
-- 5. RLS enabled on every public table
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 5, 'RLS enabled on every public table',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       case when count(*) = 0 then 'all public tables'
            else string_agg(n.nspname || '.' || c.relname, ', ')
       end
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and not c.relispartition
  and not c.relrowsecurity;

-- ----------------------------------------------------------------------------
-- 6. Every public table has at least one policy
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 6, 'Every public table has at least one policy',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       case when count(*) = 0 then 'all public tables'
            else string_agg(n.nspname || '.' || c.relname, ', ')
       end
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and not c.relispartition
  and not exists (select 1 from pg_policy p where p.polrelid = c.oid);

-- ----------------------------------------------------------------------------
-- 7. private schema inaccessible to anon/authenticated
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 7, 'private schema not usable by anon/authenticated',
       case
         when not has_schema_privilege('anon', 'private', 'USAGE')
          and not has_schema_privilege('authenticated', 'private', 'USAGE')
         then 'PASS' else 'FAIL'
       end,
       'anon=' || has_schema_privilege('anon', 'private', 'USAGE')::text
       || ', authenticated=' || has_schema_privilege('authenticated', 'private', 'USAGE')::text;

insert into _phase1_verification (check_no, check_name, status, details)
select 7, 'private.audit_log not readable by anon/authenticated',
       case
         when not has_table_privilege('anon', 'private.audit_log', 'SELECT')
          and not has_table_privilege('authenticated', 'private.audit_log', 'SELECT')
         then 'PASS' else 'FAIL'
       end,
       'anon=' || has_table_privilege('anon', 'private.audit_log', 'SELECT')::text
       || ', authenticated=' || has_table_privilege('authenticated', 'private.audit_log', 'SELECT')::text;

-- ----------------------------------------------------------------------------
-- 8. audit_log is partitioned with >= 24 monthly partitions
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 8, 'audit_log partitioned monthly',
       case when c.relkind = 'p' then 'PASS' else 'FAIL' end,
       'relkind=' || c.relkind::text
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'private' and c.relname = 'audit_log';

insert into _phase1_verification (check_no, check_name, status, details)
select 8, 'audit_log has >= 24 monthly partitions',
       case when count(*) >= 24 then 'PASS' else 'FAIL' end,
       count(*)::text || ' partitions'
from pg_partition_tree('private.audit_log'::regclass)
where isleaf;

-- ----------------------------------------------------------------------------
-- 9. Required indexes
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 9, 'Index ' || i.label,
       case when exists (
         select 1 from pg_indexes x
          where x.schemaname = i.schema_name
            and x.tablename = i.table_name
            and x.indexdef ilike i.pattern
       ) then 'PASS' else 'FAIL' end,
       i.table_name || ' ~ ' || i.pattern
from (values
  ('profiles (phone) unique',              'public', 'profiles',                 '%(phone)%'),
  ('profiles (email) unique',              'public', 'profiles',                 '%(email)%'),
  ('profiles (primary_role)',              'public', 'profiles',                 '%(primary_role)%'),
  ('profiles (default_country_id)',        'public', 'profiles',                 '%(default_country_id)%'),
  ('profiles (is_active)',                 'public', 'profiles',                 '%(is_active)%'),
  ('user_devices (profile_id, device_id)', 'public', 'user_devices',             '%(profile_id, device_id)%'),
  ('user_devices (push_token)',            'public', 'user_devices',             '%push_token%'),
  ('user_sessions (profile_id)',           'public', 'user_sessions',            '%(profile_id)%'),
  ('user_sessions (session_token_hash)',   'public', 'user_sessions',            '%(session_token_hash)%'),
  ('user_sessions (expires_at active)',    'public', 'user_sessions',            '%expires_at%'),
  ('customers (id) primary key',           'public', 'customers',                '%(id)%'),
  ('business_accounts (country_id)',       'public', 'business_accounts',        '%(country_id)%'),
  ('business_accounts (registration_number)', 'public', 'business_accounts',     '%(registration_number)%'),
  ('business_members (account, profile)',  'public', 'business_members',         '%(business_account_id, profile_id)%'),
  ('business_members (profile_id)',        'public', 'business_members',         '%(profile_id)%'),
  ('drivers (country_id)',                 'public', 'drivers',                  '%(country_id)%'),
  ('drivers (verification_status)',        'public', 'drivers',                  '%(verification_status)%'),
  ('drivers (is_available)',               'public', 'drivers',                  '%is_available%'),
  ('drivers (current_location) gist',      'public', 'drivers',                  '%using gist%current_location%'),
  ('drivers (home_city_id)',               'public', 'drivers',                  '%(home_city_id)%'),
  ('driver_operating_zones (driver_id)',   'public', 'driver_operating_zones',   '%(driver_id)%'),
  ('driver_operating_zones (service_zone_id)', 'public', 'driver_operating_zones', '%(service_zone_id)%'),
  ('driver_service_hours (driver, day)',   'public', 'driver_service_hours',     '%(driver_id, day_of_week)%'),
  ('user_referrals (referral_code)',       'public', 'user_referrals',           '%(referral_code)%'),
  ('user_referrals (referrer)',            'public', 'user_referrals',           '%(referrer_profile_id)%'),
  ('user_referrals (referred)',            'public', 'user_referrals',           '%(referred_profile_id)%'),
  ('saved_addresses (profile_id)',         'public', 'saved_addresses',          '%(profile_id)%'),
  ('admin_roles (profile_id, is_active)',  'public', 'admin_roles',              '%(profile_id, is_active)%'),
  ('admin_roles (role_name)',              'public', 'admin_roles',              '%(role_name)%'),
  ('admin_role_permissions unique',        'public', 'admin_role_permissions',   '%(role_name, permission_key)%'),
  ('admin_actions_log (admin, created_at)','public', 'admin_actions_log',        '%admin_profile_id, created_at%'),
  ('admin_actions_log (action, created_at)','public','admin_actions_log',        '%action, created_at%'),
  ('cities (country_id)',                  'public', 'cities',                   '%(country_id)%'),
  ('cities (is_active)',                   'public', 'cities',                   '%is_active%'),
  ('cities (boundary) gist',               'public', 'cities',                   '%using gist%boundary%'),
  ('regions (country_id)',                 'public', 'regions',                  '%(country_id)%'),
  ('service_zones (city_id)',              'public', 'service_zones',            '%(city_id)%'),
  ('service_zones (zone_type)',            'public', 'service_zones',            '%(zone_type)%'),
  ('service_zones (boundary) gist',        'public', 'service_zones',            '%using gist%boundary%'),
  ('service_zones (centroid) gist',        'public', 'service_zones',            '%using gist%centroid%'),
  ('neighborhoods (city_id)',              'public', 'neighborhoods',            '%(city_id)%'),
  ('neighborhoods (centroid) gist',        'public', 'neighborhoods',            '%using gist%centroid%'),
  ('addresses (country_id)',               'public', 'addresses',                '%(country_id)%'),
  ('addresses (city_id)',                  'public', 'addresses',                '%(city_id)%'),
  ('addresses (location) gist',            'public', 'addresses',                '%using gist%location%'),
  ('addresses (created_by)',               'public', 'addresses',                '%(created_by)%'),
  ('zone_pricing_overrides (service_zone_id)', 'public', 'zone_pricing_overrides', '%(service_zone_id)%'),
  ('zone_pricing_overrides (pricing_plan_id)', 'public', 'zone_pricing_overrides', '%pricing_plan_id%'),
  ('localization_strings unique',          'public', 'localization_strings',     '%(language_id, namespace, key)%'),
  ('feature_flags (flag_key)',             'public', 'feature_flags',            '%(flag_key)%'),
  ('feature_flags (country_id, city_id)',  'public', 'feature_flags',            '%(country_id, city_id)%'),
  ('consent_records (profile_id, type)',   'public', 'consent_records',          '%(profile_id, consent_type)%'),
  ('consent_records (granted_at)',         'public', 'consent_records',          '%(granted_at)%'),
  ('exchange_rates (pair, effective_from)','public', 'exchange_rates',           '%from_currency_id, to_currency_id, effective_from%'),
  ('audit_log (created_at)',               'private','audit_log',                '%created_at%'),
  ('audit_log (actor, created_at)',        'private','audit_log',                '%actor_id, created_at%'),
  ('audit_log (entity)',                   'private','audit_log',                '%entity_type, entity_id%')
) as i(label, schema_name, table_name, pattern);

-- ----------------------------------------------------------------------------
-- 10. Helper functions exist and are callable
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 10, 'Function ' || f.signature,
       case when to_regprocedure(f.signature) is not null then 'PASS' else 'FAIL' end,
       coalesce(to_regprocedure(f.signature)::text, 'missing')
from (values
  ('public.set_updated_at()'),
  ('public.handle_new_user()'),
  ('public.current_profile_id()'),
  ('public.current_user_role()'),
  ('public.current_country_id()'),
  ('public.has_admin_role(text)'),
  ('public.has_permission(text)'),
  ('public.has_permission(text,uuid)'),
  ('public.custom_access_token_hook(jsonb)'),
  ('public.get_audit_log(integer,text,uuid)'),
  ('public.record_consent(uuid,text,text,boolean)'),
  ('public.deactivate_user(uuid,text)'),
  ('private.audit_trigger()'),
  ('private.ensure_audit_log_partitions(integer)'),
  ('private.try_uuid(text)'),
  ('public.business_has_members(uuid)'),
  ('public.is_business_member(uuid)'),
  ('public.is_business_admin(uuid)'),
  ('public.is_business_owner(uuid)'),
  ('public.get_public_driver_profile(uuid)'),
  ('public.sync_city_country()'),
  ('public.validate_address_hierarchy()'),
  ('public.log_driver_status_change()')
) as f(signature);

insert into _phase1_verification (check_no, check_name, status, details)
select 10, 'Key RPCs executable by authenticated',
       case
         when has_function_privilege('authenticated', 'public.has_permission(text)', 'EXECUTE')
          and has_function_privilege('authenticated', 'public.record_consent(uuid,text,text,boolean)', 'EXECUTE')
          and has_function_privilege('authenticated', 'public.deactivate_user(uuid,text)', 'EXECUTE')
          and has_function_privilege('authenticated', 'public.get_public_driver_profile(uuid)', 'EXECUTE')
         then 'PASS' else 'FAIL'
       end,
       'checked has_permission, record_consent, deactivate_user, get_public_driver_profile';

insert into _phase1_verification (check_no, check_name, status, details)
select 10, 'All SECURITY DEFINER functions set search_path',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       case when count(*) = 0 then 'all security definer functions'
            else string_agg(n.nspname || '.' || p.proname, ', ')
       end
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prosecdef
  and not exists (
    select 1
      from unnest(coalesce(p.proconfig, array[]::text[])) as cfg
     where cfg like 'search_path=%'
  );

-- ----------------------------------------------------------------------------
-- 11. custom_access_token_hook configured and executable by auth admin
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 11, 'custom_access_token_hook granted to supabase_auth_admin',
       case
         when to_regprocedure('public.custom_access_token_hook(jsonb)') is not null
          and exists (select 1 from pg_roles where rolname = 'supabase_auth_admin')
          and has_function_privilege('supabase_auth_admin', 'public.custom_access_token_hook(jsonb)', 'EXECUTE')
         then 'PASS' else 'FAIL'
       end,
       'config.toml [auth.hook.custom_access_token] uri = pg-functions://postgres/public/custom_access_token_hook';

-- ----------------------------------------------------------------------------
-- 12. Auth trigger on auth.users
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 12, 'on_auth_user_created trigger exists',
       case when exists (
         select 1 from pg_trigger
          where tgrelid = to_regclass('auth.users')
            and tgname = 'on_auth_user_created'
            and not tgisinternal
       ) then 'PASS' else 'FAIL' end,
       'auth.users AFTER INSERT -> public.handle_new_user()';

-- ----------------------------------------------------------------------------
-- 13. Column-level security views
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 13, 'View public.driver_public_profile (security_invoker=true)',
       case when exists (
         select 1 from pg_class c
         join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname = 'driver_public_profile'
           and c.relkind = 'v'
           and coalesce(c.reloptions, array[]::text[]) @> array['security_invoker=true']
       ) then 'PASS' else 'FAIL' end,
       'column-limited driver projection';

insert into _phase1_verification (check_no, check_name, status, details)
select 13, 'View public.audit_log_view (security_invoker=true)',
       case when exists (
         select 1 from pg_class c
         join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname = 'audit_log_view'
           and c.relkind = 'v'
           and coalesce(c.reloptions, array[]::text[]) @> array['security_invoker=true']
       ) then 'PASS' else 'FAIL' end,
       'gate: public.has_permission(''view_audit'') via public.get_audit_log()';

insert into _phase1_verification (check_no, check_name, status, details)
select 13, 'Function public.get_audit_log is SECURITY DEFINER with search_path',
       case when exists (
         select 1 from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'get_audit_log'
           and p.prosecdef
           and exists (
             select 1 from unnest(coalesce(p.proconfig, array[]::text[])) as cfg
             where cfg like 'search_path=%'
           )
       ) then 'PASS' else 'FAIL' end,
       'privileged read stays in a SECURITY DEFINER function';

-- ----------------------------------------------------------------------------
-- 14. Seed data counts
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 14, 'Seed count: ' || s.label,
       case when s.actual >= s.min_expected then 'PASS' else 'FAIL' end,
       s.actual::text || ' (expected >= ' || s.min_expected::text || ')'
from (
  select 'countries'            as label, (select count(*) from public.countries) as actual, 3::bigint as min_expected
  union all select 'regions',              (select count(*) from public.regions), 2
  union all select 'cities',               (select count(*) from public.cities), 2
  union all select 'service_zones',        (select count(*) from public.service_zones), 3
  union all select 'neighborhoods',        (select count(*) from public.neighborhoods), 8
  union all select 'addresses',            (select count(*) from public.addresses), 8
  union all select 'admin_permissions',    (select count(*) from public.admin_permissions_catalog), 20
  union all select 'admin_role_mappings',  (select count(distinct role_name) from public.admin_role_permissions), 6
  union all select 'super_admin_roles',    (select count(*) from public.admin_roles where role_name = 'super_admin'), 1
  union all select 'operations_admin_roles',(select count(*) from public.admin_roles where role_name = 'operations_admin'), 2
  union all select 'customers',            (select count(*) from public.customers), 3
  union all select 'drivers',              (select count(*) from public.drivers), 3
  union all select 'business_accounts',    (select count(*) from public.business_accounts), 1
  union all select 'localization_strings', (select count(*) from public.localization_strings), 5
  union all select 'consent_records',      (select count(*) from public.consent_records), 3
  union all select 'audit_log_rows',       (select count(*) from private.audit_log), 1
) as s;

-- ----------------------------------------------------------------------------
-- 15. Multi-country proof (1 active, 2 inactive)
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 15, 'Multi-country: 1 active + 2 inactive countries',
       case when (select count(*) from public.countries where is_active) = 1
             and (select count(*) from public.countries where not is_active) >= 2
            then 'PASS' else 'FAIL' end,
       (select string_agg(btrim(c.iso_code) || '=' || c.is_active::text, ', ' order by c.iso_code) from public.countries c);

-- ----------------------------------------------------------------------------
-- 16. No Phase 7+ tables. Phase 6 adds communication, chat, safety, support,
--     compliance, and analytics tables. The Phase 1 gate guards only domains
--     deliberately deferred beyond Phase 6.
-- ----------------------------------------------------------------------------
insert into _phase1_verification (check_no, check_name, status, details)
select 16, 'No Phase 7+ tables created',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       case when count(*) = 0 then 'no Phase 7+ tables'
            else string_agg(tablename, ', ') end
from (
  select tablename from pg_tables
   where schemaname = 'public'
     and tablename in (
       'notification_deliveries', 'analytics_events',
       'ml_models', 'model_predictions', 'eta_predictions',
       'demand_forecasts', 'fraud_scores', 'provider_webhook_deliveries'
     )
) x;

insert into _phase1_verification (check_no, check_name, status, details)
select 16, 'Partition children have no client privileges',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'no direct client access to partitions')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relispartition
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
-- Results
-- ----------------------------------------------------------------------------
select
  check_no,
  lpad(check_no::text, 2, '0') as no,
  check_name,
  status,
  details
from _phase1_verification
order by check_no, check_name;

select
  'PHASE 1 SCHEMA VERIFICATION: '
  || count(*) filter (where status = 'PASS')::text || ' PASS, '
  || count(*) filter (where status = 'FAIL')::text || ' FAIL' as result
from _phase1_verification;

-- List failures a second time for fast triage.
select check_no, check_name, details
from _phase1_verification
where status = 'FAIL'
order by check_no, check_name;
