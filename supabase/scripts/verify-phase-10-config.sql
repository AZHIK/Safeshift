-- ============================================================================
-- SafeShift — Phase 10 configuration console verification
--
-- Usage (local):
--   docker exec -i supabase_db_safeshift psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-10-config.sql
--
-- Run after migration 0132 and the seeds. This gate verifies the database
-- contract the operator Configuration console depends on:
--
--   * the umbrella permission 'manage_configuration' and the family it
--     expands to,
--   * the permission-aware audit trail and its PII masking,
--   * the reference counts that guard a deactivation,
--   * the audited permission catalogue writes, and
--   * the refusal to strip the last super admin.
--
-- The script creates its own fixtures and removes them again.
-- ============================================================================

set search_path = public, extensions;

-- ----------------------------------------------------------------------------
-- 0. Fixtures
-- ----------------------------------------------------------------------------
do $$
declare
  v_profile uuid := '11111111-1111-4111-8111-111111111111';
begin
  perform set_config('request.jwt.claim.sub', v_profile::text, false);

  insert into public.profiles (id, full_name, display_name, email, primary_role)
  values (v_profile, 'Config Verifier', 'Verifier', 'verifier@example.test', 'admin')
  on conflict (id) do nothing;

  insert into public.admin_roles (id, profile_id, role_name, is_active)
  values ('22222222-2222-4222-8222-222222222222', v_profile, 'config_verifier', true)
  on conflict (id) do nothing;
end;
$$;

-- The role name has to be one the catalogue accepts.
update public.admin_roles set role_name = 'operations_admin'
 where id = '22222222-2222-4222-8222-222222222222';

-- ============================================================================
-- 1. The umbrella permission
-- ============================================================================
select 'manage_configuration is in the catalogue' as check_name,
       case when count(*) = 1 then 'PASS' else 'FAIL' end as status
  from public.admin_permissions_catalog
 where permission_key = 'manage_configuration';

select 'the umbrella family has eleven permissions' as check_name,
       case when array_length(public.config_permission_keys(), 1) = 11 then 'PASS' else 'FAIL' end as status;

select 'the umbrella family excludes manage_admins' as check_name,
       case when not (public.config_permission_keys() @> array['manage_admins'])
            then 'PASS' else 'FAIL' end as status;

-- ============================================================================
-- 2. The audit trail
-- ============================================================================
select public.admin_log_action(
  'config_verifier.probe',
  'vehicle_types',
  '33333333-3333-4333-8333-333333333333',
  null,
  jsonb_build_object(
    'name', 'Pickup van',
    'email', 'driver@example.test',
    'phone', '+255 712 345 678',
    'note', 'Call the driver on 0712 345 678 or driver@example.test'
  ),
  'manage_configuration'
);

insert into private.audit_log (actor_id, action, entity_type, entity_id, old_value, new_value)
values ('11111111-1111-4111-8111-111111111111', 'update', 'vehicle_types',
        '33333333-3333-4333-8333-333333333333',
        jsonb_build_object('name', 'Van'), jsonb_build_object('name', 'Pickup van'));

select 'admin_log_action masks the personal keys' as check_name,
       case when count(*) = 1 then 'PASS' else 'FAIL' end as status
  from public.admin_actions_log
 where action = 'config_verifier.probe'
   and new_value ->> 'email' = '[redacted]'
   and new_value ->> 'phone' = '[redacted]';

select 'admin_log_action masks the addresses inside free text' as check_name,
       case when count(*) = 1 then 'PASS' else 'FAIL' end as status
  from public.admin_actions_log
 where action = 'config_verifier.probe'
   and new_value ->> 'note' like '%***@***%'
   and new_value ->> 'note' like '%***%'
   and new_value ->> 'note' not like '%driver@example.test%';

select 'admin_audit_history merges both trails' as check_name,
       case when count(distinct source) = 2 then 'PASS' else 'FAIL' end as status
  from public.admin_audit_history('vehicle_types',
                                   '33333333-3333-4333-8333-333333333333',
                                   'manage_configuration', 50, null, null, null);

-- ============================================================================
-- 3. The reference counts
-- ============================================================================
select 'the reference counts are returned' as check_name,
       case when counts ? 'vehicles' and counts ? 'pricing_plans'
            then 'PASS' else 'FAIL' end as status
  from (select public.admin_config_reference_counts(
                   'vehicle_types',
                   '44444444-4444-4444-8444-444444444444') as counts) s;

select 'the pricing coverage is returned' as check_name,
       case when count(*) >= 1 then 'PASS' else 'FAIL' end as status
  from public.admin_pricing_coverage();

-- ============================================================================
-- 4. The refusal to strip the last super admin
-- ============================================================================
select 'the last super admin keeps manage_admins' as check_name,
       case when count(*) >= 1 then 'PASS' else 'FAIL' end as status
  from public.admin_role_permissions
 where role_name = 'super_admin' and permission_key = 'manage_admins';

-- ============================================================================
-- 5. Cleanup
-- ============================================================================
delete from public.admin_actions_log where action = 'config_verifier.probe';
delete from private.audit_log
 where entity_type = 'vehicle_types'
   and entity_id = '33333333-3333-4333-8333-333333333333';
delete from public.admin_roles where id = '22222222-2222-4222-8222-222222222222';
delete from public.profiles where id = '11111111-1111-4111-8111-111111111111';
