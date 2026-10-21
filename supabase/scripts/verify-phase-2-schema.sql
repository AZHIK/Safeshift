-- ============================================================================
-- SafeShift — Phase 2 schema verification
--
-- Usage (local):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-2-schema.sql
--
-- Run after migrations and after seed.sql + seed-phase-2.sql. The controlled
-- audit test deliberately changes and restores one seeded document status, so
-- run this against a disposable local/test database.
--
-- The script is read-only except for item 14 (the audit trigger test) and a
-- temporary results table that lives only for this session.
-- ============================================================================

drop table if exists _phase2_verification;
create temporary table _phase2_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

-- ----------------------------------------------------------------------------
-- 1. Phase 1 gate: foundational tables, columns and audit trigger remain.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 1, 'Phase 1 table ' || x.name,
       case when to_regclass(x.name) is not null then 'PASS' else 'FAIL' end,
       case when to_regclass(x.name) is not null then 'present' else 'missing' end
from (values
  ('public.profiles'),
  ('public.customers'),
  ('public.drivers'),
  ('public.business_accounts'),
  ('public.countries'),
  ('public.cities'),
  ('public.admin_roles'),
  ('public.admin_permissions_catalog'),
  ('private.audit_log')
) x(name);

insert into _phase2_verification
select 1, 'Phase 1 column ' || x.table_name || '.' || x.column_name,
       case when exists (
         select 1 from information_schema.columns c
         where c.table_schema = 'public'
           and c.table_name = x.table_name
           and c.column_name = x.column_name
       ) then 'PASS' else 'FAIL' end,
       'required by Phase 2'
from (values
  ('profiles', 'id'),
  ('profiles', 'primary_role'),
  ('profiles', 'default_country_id'),
  ('drivers', 'id'),
  ('drivers', 'country_id'),
  ('drivers', 'current_vehicle_id'),
  ('drivers', 'current_fleet_id'),
  ('countries', 'id'),
  ('countries', 'iso_code')
) x(table_name, column_name);

insert into _phase2_verification
select 1, 'Phase 1 driver audit trigger retained',
       case when exists (
         select 1 from pg_trigger t
         where t.tgrelid = 'public.drivers'::regclass
           and t.tgname = 'trg_drivers_audit'
           and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end,
       'trg_drivers_audit';

-- ----------------------------------------------------------------------------
-- 2. Phase 1 placeholders are now real foreign keys with ON DELETE SET NULL.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 2, 'drivers.current_vehicle_id FK to vehicles',
       case when exists (
         select 1 from pg_constraint
         where conrelid = 'public.drivers'::regclass
           and contype = 'f'
           and conkey = array[(select attnum from pg_attribute where attrelid = 'public.drivers'::regclass and attname = 'current_vehicle_id')]
           and confrelid = 'public.vehicles'::regclass
           and confdeltype = 'n'
       ) then 'PASS' else 'FAIL' end,
       'ON DELETE SET NULL';
insert into _phase2_verification
select 2, 'drivers.current_fleet_id FK to fleets',
       case when exists (
         select 1 from pg_constraint
         where conrelid = 'public.drivers'::regclass
           and contype = 'f'
           and conkey = array[(select attnum from pg_attribute where attrelid = 'public.drivers'::regclass and attname = 'current_fleet_id')]
           and confrelid = 'public.fleets'::regclass
           and confdeltype = 'n'
       ) then 'PASS' else 'FAIL' end,
       'ON DELETE SET NULL';

-- ----------------------------------------------------------------------------
-- 3. Phase 2 table inventory (22 tables across four domains).
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 3, 'Phase 2 table ' || x.name,
       case when to_regclass(x.name) is not null then 'PASS' else 'FAIL' end,
       coalesce(to_regclass(x.name)::text, 'missing')
from (values
  ('public.document_types'),
  ('public.driver_documents'),
  ('public.vehicle_documents'),
  ('public.verification_requests'),
  ('public.verification_history'),
  ('public.document_expiry_reminders'),
  ('public.verification_checklist_templates'),
  ('public.vehicle_types'),
  ('public.vehicle_makes'),
  ('public.vehicle_models'),
  ('public.vehicles'),
  ('public.vehicle_equipment_catalog'),
  ('public.vehicle_equipment'),
  ('public.cargo_categories'),
  ('public.cargo_types'),
  ('public.cargo_restrictions'),
  ('public.cargo_packaging_options'),
  ('public.fleets'),
  ('public.fleet_members'),
  ('public.fleet_vehicles'),
  ('public.vehicle_assignments'),
  ('public.fleet_reports')
) x(name);

insert into _phase2_verification
select 3, 'Phase 2 table count is 22',
       case when count(*) = 22 then 'PASS' else 'FAIL' end,
       count(*) || ' of 22 present'
from (values
  ('public.document_types'), ('public.driver_documents'), ('public.vehicle_documents'),
  ('public.verification_requests'), ('public.verification_history'), ('public.document_expiry_reminders'),
  ('public.verification_checklist_templates'), ('public.vehicle_types'), ('public.vehicle_makes'),
  ('public.vehicle_models'), ('public.vehicles'), ('public.vehicle_equipment_catalog'),
  ('public.vehicle_equipment'), ('public.cargo_categories'), ('public.cargo_types'),
  ('public.cargo_restrictions'), ('public.cargo_packaging_options'), ('public.fleets'),
  ('public.fleet_members'), ('public.fleet_vehicles'), ('public.vehicle_assignments'),
  ('public.fleet_reports')
) x(name)
where to_regclass(x.name) is not null;

-- ----------------------------------------------------------------------------
-- 4. Every public foreign key is validated.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 4, 'All public foreign keys validated',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*) || ' unvalidated'
from pg_constraint
where contype = 'f'
  and connamespace = 'public'::regnamespace
  and not convalidated;

-- ----------------------------------------------------------------------------
-- 5–6. RLS enabled and at least one policy on every Phase 2 table.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 5, 'RLS enabled on every Phase 2 table',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'all enabled')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = any(array[
    'document_types','driver_documents','vehicle_documents','verification_requests',
    'verification_history','document_expiry_reminders','verification_checklist_templates',
    'vehicle_types','vehicle_makes','vehicle_models','vehicles','vehicle_equipment_catalog',
    'vehicle_equipment','cargo_categories','cargo_types','cargo_restrictions',
    'cargo_packaging_options','fleets','fleet_members','fleet_vehicles',
    'vehicle_assignments','fleet_reports'
  ])
  and not c.relrowsecurity;

insert into _phase2_verification
select 6, 'Every Phase 2 table has a policy',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'all covered')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = any(array[
    'document_types','driver_documents','vehicle_documents','verification_requests',
    'verification_history','document_expiry_reminders','verification_checklist_templates',
    'vehicle_types','vehicle_makes','vehicle_models','vehicles','vehicle_equipment_catalog',
    'vehicle_equipment','cargo_categories','cargo_types','cargo_restrictions',
    'cargo_packaging_options','fleets','fleet_members','fleet_vehicles',
    'vehicle_assignments','fleet_reports'
  ])
  and not exists (select 1 from pg_policy p where p.polrelid = c.oid);

-- ----------------------------------------------------------------------------
-- 7. Named access-path and partial-uniqueness indexes.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 7, 'Index ' || x.name,
       case when to_regclass('public.' || x.name) is not null then 'PASS' else 'FAIL' end,
       x.table_name
from (values
  ('driver_documents_one_current_idx','driver_documents'),
  ('driver_documents_current_idx','driver_documents'),
  ('driver_documents_type_idx','driver_documents'),
  ('driver_documents_status_idx','driver_documents'),
  ('driver_documents_expires_idx','driver_documents'),
  ('vehicle_documents_one_current_idx','vehicle_documents'),
  ('vehicle_documents_current_idx','vehicle_documents'),
  ('vehicle_documents_type_idx','vehicle_documents'),
  ('vehicle_documents_status_idx','vehicle_documents'),
  ('vehicle_documents_expires_idx','vehicle_documents'),
  ('document_types_active_applies_to_idx','document_types'),
  ('verification_requests_queue_idx','verification_requests'),
  ('verification_requests_assignee_idx','verification_requests'),
  ('verification_requests_driver_idx','verification_requests'),
  ('verification_requests_vehicle_idx','verification_requests'),
  ('verification_requests_business_idx','verification_requests'),
  ('verification_history_request_created_idx','verification_history'),
  ('verification_history_driver_idx','verification_history'),
  ('verification_history_vehicle_idx','verification_history'),
  ('document_expiry_reminders_pending_idx','document_expiry_reminders'),
  ('document_expiry_reminders_driver_document_idx','document_expiry_reminders'),
  ('document_expiry_reminders_vehicle_document_idx','document_expiry_reminders'),
  ('vehicle_types_active_idx','vehicle_types'),
  ('vehicle_models_type_idx','vehicle_models'),
  ('vehicles_country_idx','vehicles'),
  ('vehicles_owner_profile_idx','vehicles'),
  ('vehicles_owner_fleet_idx','vehicles'),
  ('vehicles_owner_business_idx','vehicles'),
  ('vehicles_type_idx','vehicles'),
  ('vehicles_verification_status_idx','vehicles'),
  ('vehicles_active_idx','vehicles'),
  ('cargo_categories_parent_idx','cargo_categories'),
  ('cargo_types_category_idx','cargo_types'),
  ('cargo_types_active_idx','cargo_types'),
  ('cargo_restrictions_cargo_type_idx','cargo_restrictions'),
  ('cargo_restrictions_type_idx','cargo_restrictions'),
  ('fleets_country_idx','fleets'),
  ('fleets_owner_profile_idx','fleets'),
  ('fleets_active_idx','fleets'),
  ('fleet_members_one_active_driver_idx','fleet_members'),
  ('fleet_members_fleet_idx','fleet_members'),
  ('fleet_vehicles_one_active_vehicle_idx','fleet_vehicles'),
  ('fleet_vehicles_fleet_idx','fleet_vehicles'),
  ('vehicle_assignments_one_active_vehicle_idx','vehicle_assignments'),
  ('vehicle_assignments_one_active_driver_idx','vehicle_assignments'),
  ('vehicle_assignments_assigned_at_idx','vehicle_assignments'),
  ('fleet_reports_fleet_generated_idx','fleet_reports')
) x(name, table_name);

insert into _phase2_verification
select 7, 'Partial unique guard ' || x.name,
       case when exists (
         select 1 from pg_index i
         join pg_class c on c.oid = i.indexrelid
         where c.relname = x.name
           and i.indisunique
           and i.indpred is not null
       ) then 'PASS' else 'FAIL' end,
       'partial unique index'
from (values
  ('driver_documents_one_current_idx'),
  ('vehicle_documents_one_current_idx'),
  ('fleet_members_one_active_driver_idx'),
  ('fleet_vehicles_one_active_vehicle_idx'),
  ('vehicle_assignments_one_active_vehicle_idx'),
  ('vehicle_assignments_one_active_driver_idx')
) x(name);

-- ----------------------------------------------------------------------------
-- 8. Helper functions exist, are SECURITY DEFINER and have an empty search_path.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 8, 'Function ' || x.name,
       case when to_regprocedure(x.signature) is not null then 'PASS' else 'FAIL' end,
       x.signature
from (values
  ('vehicle_current_driver','public.vehicle_current_driver(uuid)'),
  ('driver_current_vehicle','public.driver_current_vehicle(uuid)'),
  ('driver_requires_verification','public.driver_requires_verification(uuid)'),
  ('vehicle_requires_verification','public.vehicle_requires_verification(uuid)'),
  ('can_carry_cargo','public.can_carry_cargo(uuid,uuid)'),
  ('pending_verifications_for_admin','public.pending_verifications_for_admin(uuid)'),
  ('is_fleet_member','public.is_fleet_member(uuid)'),
  ('is_fleet_owner','public.is_fleet_owner(uuid)'),
  ('is_vehicle_owner','public.is_vehicle_owner(uuid)')
) x(name, signature);

insert into _phase2_verification
select 8, 'Helper hardening: ' || x.signature,
       case when p.prosecdef and p.proconfig @> array['search_path=""'] then 'PASS' else 'FAIL' end,
       'SECURITY DEFINER + empty search_path'
from (values
  ('public.vehicle_current_driver(uuid)'),
  ('public.driver_current_vehicle(uuid)'),
  ('public.driver_requires_verification(uuid)'),
  ('public.vehicle_requires_verification(uuid)'),
  ('public.can_carry_cargo(uuid,uuid)'),
  ('public.pending_verifications_for_admin(uuid)'),
  ('public.is_fleet_member(uuid)'),
  ('public.is_fleet_owner(uuid)'),
  ('public.is_vehicle_owner(uuid)')
) x(signature)
left join pg_proc p on p.oid = to_regprocedure(x.signature);

-- ----------------------------------------------------------------------------
-- 9. Views exist and are security_invoker = true.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 9, 'security_invoker view ' || x.name,
       case when c.reloptions @> array['security_invoker=true'] then 'PASS' else 'FAIL' end,
       coalesce(array_to_string(c.reloptions, ','), '')
from (values
  ('vehicle_public_view'),
  ('driver_verification_summary'),
  ('vehicle_verification_summary'),
  ('active_fleet_roster')
) x(name)
left join pg_class c on c.oid = to_regclass('public.' || x.name);

-- ----------------------------------------------------------------------------
-- 10. No new enum types were created in Phase 2.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 10, 'No Phase 2 enums created',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' public enum(s); Phase 1 owns exactly four'
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
  and t.typtype = 'e';

-- ----------------------------------------------------------------------------
-- 11. Seed and permission gates.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 11, x.label,
       case when x.actual = x.expected then 'PASS' else 'FAIL' end,
       x.actual || ' expected ' || x.expected
from (values
  ('document_types', (select count(*)::int from public.document_types), 10),
  ('vehicle_makes', (select count(*)::int from public.vehicle_makes), 8),
  ('vehicle_models', (select count(*)::int from public.vehicle_models), 20),
  ('vehicle_types', (select count(*)::int from public.vehicle_types), 6),
  ('vehicle_equipment_catalog', (select count(*)::int from public.vehicle_equipment_catalog), 8),
  ('vehicle_equipment', (select count(*)::int from public.vehicle_equipment), 7),
  ('cargo_categories', (select count(*)::int from public.cargo_categories), 3),
  ('cargo_types', (select count(*)::int from public.cargo_types), 10),
  ('cargo_packaging_options', (select count(*)::int from public.cargo_packaging_options), 6),
  ('cargo_restrictions', (select count(*)::int from public.cargo_restrictions), 5),
  ('verification_checklist_templates', (select count(*)::int from public.verification_checklist_templates), 3),
  ('fleets', (select count(*)::int from public.fleets), 1),
  ('active_fleet_members', (select count(*)::int from public.fleet_members where is_active), 2),
  ('active_fleet_vehicles', (select count(*)::int from public.fleet_vehicles where is_active), 1),
  ('active_vehicle_assignments', (select count(*)::int from public.vehicle_assignments where is_active), 3),
  ('drivers_with_current_vehicle', (select count(*)::int from public.drivers where current_vehicle_id is not null), 3),
  ('drivers_with_current_fleet', (select count(*)::int from public.drivers where current_fleet_id is not null), 2),
  ('driver_documents', (select count(*)::int from public.driver_documents), 6),
  ('vehicle_documents', (select count(*)::int from public.vehicle_documents), 9),
  ('pending_verification_requests', (select count(*)::int from public.verification_requests where status = 'pending'), 2),
  ('approved_verification_requests', (select count(*)::int from public.verification_requests where status = 'approved'), 2),
  ('verification_history', (select count(*)::int from public.verification_history), 6),
  ('document_expiry_reminders', (select count(*)::int from public.document_expiry_reminders), 3)
) x(label, actual, expected);

insert into _phase2_verification
select 11, 'Phase 2 permission ' || x.key,
       case when exists (
         select 1 from public.admin_permissions_catalog p where p.permission_key = x.key
       ) then 'PASS' else 'FAIL' end,
       'catalogue entry'
from (values
  ('verify_vehicle'), ('manage_document_types'), ('manage_vehicle_catalog'),
  ('manage_cargo_catalog'), ('view_all_vehicles'), ('view_all_fleets'),
  ('assign_vehicles'), ('view_fleet_reports'), ('view_reminders')
) x(key);

insert into _phase2_verification
select 11, 'super_admin holds every Phase 2 permission',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(p.permission_key, ', '), 'all granted')
from public.admin_permissions_catalog p
where p.permission_key in (
  'verify_vehicle','manage_document_types','manage_vehicle_catalog','manage_cargo_catalog',
  'view_all_vehicles','view_all_fleets','assign_vehicles','view_fleet_reports','view_reminders'
)
and not exists (
  select 1 from public.admin_role_permissions rp
  where rp.role_name = 'super_admin' and rp.permission_key = p.permission_key
);

-- ----------------------------------------------------------------------------
-- 12. Audit triggers and RLS hygiene.
-- ----------------------------------------------------------------------------
insert into _phase2_verification
select 12, 'Audit trigger ' || x.name,
       case when exists (
         select 1 from pg_trigger t
         where t.tgrelid = x.table_name::regclass
           and t.tgname = x.name
           and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end,
       x.table_name
from (values
  ('trg_vehicles_audit', 'public.vehicles'),
  ('trg_fleets_audit', 'public.fleets'),
  ('trg_verification_requests_audit', 'public.verification_requests'),
  ('trg_driver_documents_audit', 'public.driver_documents'),
  ('trg_vehicle_documents_audit', 'public.vehicle_documents')
) x(name, table_name);

insert into _phase2_verification
select 12, 'verification_history is append-only',
       case when exists (
         select 1 from pg_trigger t
         where t.tgrelid = 'public.verification_history'::regclass
           and t.tgname = 'trg_verification_history_immutable'
           and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end,
       'trg_verification_history_immutable';

insert into _phase2_verification
select 12, 'Policies use (select auth.uid())',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(tablename || '.' || policyname, ', '), 'all policies use the cached form')
from pg_policies
where schemaname = 'public'
  and tablename = any(array[
    'document_types','driver_documents','vehicle_documents','verification_requests',
    'verification_history','document_expiry_reminders','verification_checklist_templates',
    'vehicle_types','vehicle_makes','vehicle_models','vehicles','vehicle_equipment_catalog',
    'vehicle_equipment','cargo_categories','cargo_types','cargo_restrictions',
    'cargo_packaging_options','fleets','fleet_members','fleet_vehicles',
    'vehicle_assignments','fleet_reports'
  ])
  and (
    (qual is not null and qual ~* 'auth\.uid\(\)' and qual !~* 'select\s+auth\.uid\(\)')
    or (with_check is not null and with_check ~* 'auth\.uid\(\)' and with_check !~* 'select\s+auth\.uid\(\)')
  );

insert into _phase2_verification
select 12, 'anon has no Phase 2 table privilege',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'no anon access')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = any(array[
    'document_types','driver_documents','vehicle_documents','verification_requests',
    'verification_history','document_expiry_reminders','verification_checklist_templates',
    'vehicle_types','vehicle_makes','vehicle_models','vehicles','vehicle_equipment_catalog',
    'vehicle_equipment','cargo_categories','cargo_types','cargo_restrictions',
    'cargo_packaging_options','fleets','fleet_members','fleet_vehicles',
    'vehicle_assignments','fleet_reports'
  ])
  and has_table_privilege('anon', c.oid, 'SELECT');

insert into _phase2_verification
select 12, 'Server-only Phase 2 tables are not client-writable',
       case when not has_table_privilege('authenticated', 'public.verification_history', 'INSERT')
                 and not has_table_privilege('authenticated', 'public.document_expiry_reminders', 'INSERT')
                 and not has_table_privilege('authenticated', 'public.fleet_reports', 'INSERT')
            then 'PASS' else 'FAIL' end,
       'verification_history, reminders and fleet_reports';

-- ----------------------------------------------------------------------------
-- 13. Controlled audit test: update then restore one document verification state.
-- ----------------------------------------------------------------------------
do $$
declare
  v_document uuid;
  v_before   bigint;
  v_after    bigint;
begin
  select id into v_document
  from public.driver_documents
  order by created_at
  limit 1;

  select count(*) into v_before
  from private.audit_log
  where entity_type = 'driver_documents'
    and entity_id = v_document;

  update public.driver_documents
     set verification_status = 're_verification_due'
   where id = v_document;

  update public.driver_documents
     set verification_status = 'verified'
   where id = v_document;

  select count(*) into v_after
  from private.audit_log
  where entity_type = 'driver_documents'
    and entity_id = v_document;

  insert into _phase2_verification
  values (
    13,
    'Document verification audit trigger fires',
    case when v_after >= v_before + 2 then 'PASS' else 'FAIL' end,
    'before=' || v_before || ', after=' || v_after
  );
end $$;

-- ----------------------------------------------------------------------------
-- Report
-- ----------------------------------------------------------------------------
select check_no, check_name, status, details
from _phase2_verification
order by check_no, check_name;

select format(
  'PHASE 2 SCHEMA VERIFICATION: %s PASS, %s FAIL',
  count(*) filter (where status = 'PASS'),
  count(*) filter (where status = 'FAIL')
) as result
from _phase2_verification;
