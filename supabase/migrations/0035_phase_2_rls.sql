-- ============================================================================
-- SafeShift — Phase 2 / Migration 0035
-- RLS for every Phase 2 public table. Service-role writes bypass RLS by design.
--
-- Permission catalogue rows live in this migration (rather than only in the
-- development seed) because every policy below depends on them. A production
-- deployment applies migrations without seed data and must still be operable.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Phase 2 permissions
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('verify_vehicle',          'Approve or reject vehicle and vehicle-document verification', 'trust_safety'),
  ('manage_document_types',   'Manage country document catalogues and checklists',          'trust_safety'),
  ('manage_vehicle_catalog',  'Manage vehicle types, makes, models and equipment',          'operations'),
  ('manage_cargo_catalog',    'Manage cargo categories, types, restrictions and packaging',  'operations'),
  ('view_all_vehicles',       'View all vehicle records',                                   'operations'),
  ('view_all_fleets',         'View all fleet records',                                     'operations'),
  ('assign_vehicles',         'Assign drivers to vehicles',                                 'operations'),
  ('view_fleet_reports',      'View generated fleet reports',                               'operations'),
  ('view_reminders',          'View scheduled document-expiry reminders',                   'trust_safety')
on conflict (permission_key) do nothing;

-- super_admin receives every permission, including permissions added later.
insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'verify_vehicle', 'manage_document_types', 'manage_vehicle_catalog',
  'manage_cargo_catalog', 'view_all_vehicles', 'view_all_fleets',
  'assign_vehicles', 'view_fleet_reports', 'view_reminders'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('verification_admin', 'verify_vehicle'),
  ('verification_admin', 'view_all_vehicles'),
  ('verification_admin', 'view_reminders'),
  ('verification_admin', 'manage_document_types'),
  ('operations_admin',  'manage_vehicle_catalog'),
  ('operations_admin',  'manage_cargo_catalog'),
  ('operations_admin',  'view_all_vehicles'),
  ('operations_admin',  'view_all_fleets'),
  ('operations_admin',  'assign_vehicles'),
  ('operations_admin',  'view_fleet_reports')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 2. SECURITY DEFINER membership helpers
-- These avoid recursive fleet/vehicle policies. search_path is empty.
-- ----------------------------------------------------------------------------
create or replace function public.is_fleet_member(p_fleet_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.fleet_members fm
    where fm.fleet_id = p_fleet_id
      and fm.driver_id = auth.uid()
      and fm.is_active
  );
$$;

comment on function public.is_fleet_member(uuid) is
  'True when the caller is an active member of the fleet. SECURITY DEFINER to avoid recursive RLS.';

create or replace function public.is_fleet_owner(p_fleet_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.fleets f
    where f.id = p_fleet_id
      and f.owner_profile_id = auth.uid()
  )
  or exists (
    select 1
    from public.fleet_members fm
    where fm.fleet_id = p_fleet_id
      and fm.driver_id = auth.uid()
      and fm.role = 'owner'
      and fm.is_active
  );
$$;

comment on function public.is_fleet_owner(uuid) is
  'True when the caller owns the fleet directly or holds an active owner membership.';

-- "Owner" here means any party allowed to manage the asset: the individual
-- owner, an owner/manager of the owning fleet, or an admin of the owning
-- business account. Drivers are handled separately by the vehicles policy.
create or replace function public.is_vehicle_owner(p_vehicle_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and (
        v.owner_profile_id = auth.uid()
        or (v.owner_fleet_id is not null and public.is_fleet_owner(v.owner_fleet_id))
        or (v.owner_business_account_id is not null and public.is_business_admin(v.owner_business_account_id))
      )
  );
$$;

comment on function public.is_vehicle_owner(uuid) is
  'True when the caller may manage the vehicle as individual owner, fleet owner/manager or business admin.';

alter table public.document_types enable row level security;
alter table public.driver_documents enable row level security;
alter table public.vehicle_documents enable row level security;
alter table public.verification_requests enable row level security;
alter table public.verification_history enable row level security;
alter table public.document_expiry_reminders enable row level security;
alter table public.verification_checklist_templates enable row level security;
alter table public.vehicle_types enable row level security;
alter table public.vehicle_makes enable row level security;
alter table public.vehicle_models enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_equipment_catalog enable row level security;
alter table public.vehicle_equipment enable row level security;
alter table public.cargo_categories enable row level security;
alter table public.cargo_types enable row level security;
alter table public.cargo_restrictions enable row level security;
alter table public.cargo_packaging_options enable row level security;
alter table public.fleets enable row level security;
alter table public.fleet_members enable row level security;
alter table public.fleet_vehicles enable row level security;
alter table public.vehicle_assignments enable row level security;
alter table public.fleet_reports enable row level security;

create policy document_types_select_authenticated on public.document_types for select to authenticated using (true);
create policy document_types_manage on public.document_types for all to authenticated using ((select public.has_permission('manage_document_types'))) with check ((select public.has_permission('manage_document_types')));

create policy driver_documents_select_own_or_verify on public.driver_documents for select to authenticated using (driver_id = (select auth.uid()) or (select public.has_permission('verify_driver')));
create policy driver_documents_insert_own on public.driver_documents for insert to authenticated with check (driver_id = (select auth.uid()));
create policy driver_documents_update_pending_own on public.driver_documents for update to authenticated using (driver_id = (select auth.uid()) and verification_status = 'pending') with check (driver_id = (select auth.uid()) and verification_status = 'pending');
create policy driver_documents_update_verify on public.driver_documents for update to authenticated using ((select public.has_permission('verify_driver'))) with check ((select public.has_permission('verify_driver')));

create policy vehicle_documents_select_owner_or_verify on public.vehicle_documents for select to authenticated using ((select public.is_vehicle_owner(vehicle_id)) or (select public.has_permission('verify_vehicle')));
create policy vehicle_documents_insert_owner on public.vehicle_documents for insert to authenticated with check ((select public.is_vehicle_owner(vehicle_id)));
create policy vehicle_documents_update_pending_owner on public.vehicle_documents for update to authenticated using ((select public.is_vehicle_owner(vehicle_id)) and verification_status = 'pending') with check ((select public.is_vehicle_owner(vehicle_id)) and verification_status = 'pending');
create policy vehicle_documents_update_verify on public.vehicle_documents for update to authenticated using ((select public.has_permission('verify_vehicle'))) with check ((select public.has_permission('verify_vehicle')));

create policy vehicle_types_select_authenticated on public.vehicle_types for select to authenticated using (true);
create policy vehicle_types_manage on public.vehicle_types for all to authenticated using ((select public.has_permission('manage_vehicle_catalog'))) with check ((select public.has_permission('manage_vehicle_catalog')));
create policy vehicle_makes_select_authenticated on public.vehicle_makes for select to authenticated using (true);
create policy vehicle_makes_manage on public.vehicle_makes for all to authenticated using ((select public.has_permission('manage_vehicle_catalog'))) with check ((select public.has_permission('manage_vehicle_catalog')));
create policy vehicle_models_select_authenticated on public.vehicle_models for select to authenticated using (true);
create policy vehicle_models_manage on public.vehicle_models for all to authenticated using ((select public.has_permission('manage_vehicle_catalog'))) with check ((select public.has_permission('manage_vehicle_catalog')));
create policy vehicle_equipment_catalog_select_authenticated on public.vehicle_equipment_catalog for select to authenticated using (true);
create policy vehicle_equipment_catalog_manage on public.vehicle_equipment_catalog for all to authenticated using ((select public.has_permission('manage_vehicle_catalog'))) with check ((select public.has_permission('manage_vehicle_catalog')));

create policy vehicles_select_owner_driver_or_view_all on public.vehicles for select to authenticated using (
  (select public.is_vehicle_owner(id)) or primary_driver_id = (select auth.uid())
  or exists (select 1 from public.vehicle_assignments va where va.vehicle_id = vehicles.id and va.driver_id = (select auth.uid()) and va.is_active)
  or (select public.has_permission('view_all_vehicles'))
);
create policy vehicles_insert_own on public.vehicles for insert to authenticated with check (
  owner_profile_id = (select auth.uid())
  or (owner_fleet_id is not null and (select public.is_fleet_owner(owner_fleet_id)))
  or (owner_business_account_id is not null and (select public.is_business_admin(owner_business_account_id)))
  or (select public.has_permission('manage_fleets'))
);
create policy vehicles_update_owner on public.vehicles for update to authenticated using ((select public.is_vehicle_owner(id))) with check ((select public.is_vehicle_owner(id)));
create policy vehicles_update_verify on public.vehicles for update to authenticated using ((select public.has_permission('verify_vehicle'))) with check ((select public.has_permission('verify_vehicle')));

-- A caller who can read the vehicle through vehicles RLS can read its
-- installed equipment. The EXISTS subquery is itself subject to vehicles RLS.
create policy vehicle_equipment_select_vehicle_reader on public.vehicle_equipment for select to authenticated using (
  exists (select 1 from public.vehicles v where v.id = vehicle_equipment.vehicle_id)
);
create policy vehicle_equipment_manage_owner on public.vehicle_equipment for all to authenticated using ((select public.is_vehicle_owner(vehicle_id))) with check ((select public.is_vehicle_owner(vehicle_id)));

create policy cargo_categories_select_authenticated on public.cargo_categories for select to authenticated using (true);
create policy cargo_categories_manage on public.cargo_categories for all to authenticated using ((select public.has_permission('manage_cargo_catalog'))) with check ((select public.has_permission('manage_cargo_catalog')));
create policy cargo_types_select_authenticated on public.cargo_types for select to authenticated using (true);
create policy cargo_types_manage on public.cargo_types for all to authenticated using ((select public.has_permission('manage_cargo_catalog'))) with check ((select public.has_permission('manage_cargo_catalog')));
create policy cargo_restrictions_select_authenticated on public.cargo_restrictions for select to authenticated using (true);
create policy cargo_restrictions_manage on public.cargo_restrictions for all to authenticated using ((select public.has_permission('manage_cargo_catalog'))) with check ((select public.has_permission('manage_cargo_catalog')));
create policy cargo_packaging_select_authenticated on public.cargo_packaging_options for select to authenticated using (true);
create policy cargo_packaging_manage on public.cargo_packaging_options for all to authenticated using ((select public.has_permission('manage_cargo_catalog'))) with check ((select public.has_permission('manage_cargo_catalog')));

create policy fleets_select_member_or_view_all on public.fleets for select to authenticated using ((select public.is_fleet_member(id)) or owner_profile_id = (select auth.uid()) or (select public.has_permission('view_all_fleets')));
create policy fleets_insert_authenticated on public.fleets for insert to authenticated with check (
  owner_profile_id = (select auth.uid())
  or (select public.has_permission('manage_fleets'))
);
create policy fleets_update_owner_or_manage on public.fleets for update to authenticated using ((select public.is_fleet_owner(id)) or (select public.has_permission('manage_fleets'))) with check ((select public.is_fleet_owner(id)) or (select public.has_permission('manage_fleets')));

create policy fleet_members_select_member_or_view_all on public.fleet_members for select to authenticated using ((select public.is_fleet_member(fleet_id)) or (select public.is_fleet_owner(fleet_id)) or (select public.has_permission('view_all_fleets')));
create policy fleet_members_manage_owner on public.fleet_members for all to authenticated using ((select public.is_fleet_owner(fleet_id)) or (select public.has_permission('manage_fleets'))) with check ((select public.is_fleet_owner(fleet_id)) or (select public.has_permission('manage_fleets')));
create policy fleet_vehicles_select_member_or_view_all on public.fleet_vehicles for select to authenticated using ((select public.is_fleet_member(fleet_id)) or (select public.is_fleet_owner(fleet_id)) or (select public.has_permission('view_all_fleets')));
create policy fleet_vehicles_manage_owner on public.fleet_vehicles for all to authenticated using ((select public.is_fleet_owner(fleet_id)) or (select public.has_permission('manage_fleets'))) with check ((select public.is_fleet_owner(fleet_id)) or (select public.has_permission('manage_fleets')));
create policy vehicle_assignments_select_subject_owner_or_view_all on public.vehicle_assignments for select to authenticated using (driver_id = (select auth.uid()) or (select public.is_vehicle_owner(vehicle_id)) or (select public.has_permission('view_all_vehicles')));
create policy vehicle_assignments_insert_assigner on public.vehicle_assignments for insert to authenticated with check ((select public.has_permission('assign_vehicles')) or (select public.is_vehicle_owner(vehicle_id)));
create policy vehicle_assignments_update_assigner on public.vehicle_assignments for update to authenticated using ((select public.has_permission('assign_vehicles')) or (select public.is_vehicle_owner(vehicle_id))) with check ((select public.has_permission('assign_vehicles')) or (select public.is_vehicle_owner(vehicle_id)));
create policy fleet_reports_select_member_or_reports on public.fleet_reports for select to authenticated using ((select public.is_fleet_member(fleet_id)) or (select public.is_fleet_owner(fleet_id)) or (select public.has_permission('view_fleet_reports')));
-- Reports are generated server-side; deliberately no client INSERT/UPDATE/DELETE policy.

create policy verification_requests_select_subject_or_reviewer on public.verification_requests for select to authenticated using (
  driver_id = (select auth.uid())
  or (vehicle_id is not null and (select public.is_vehicle_owner(vehicle_id)))
  or (business_account_id is not null and (select public.is_business_member(business_account_id)))
  or (driver_id is not null and (select public.has_permission('verify_driver')))
  or (vehicle_id is not null and (select public.has_permission('verify_vehicle')))
  or (
    business_account_id is not null
    and ((select public.has_permission('verify_driver')) or (select public.has_permission('verify_vehicle')))
  )
);
create policy verification_requests_insert_subject on public.verification_requests for insert to authenticated with check (
  requested_by = (select auth.uid())
  and (
    driver_id = (select auth.uid())
    or (vehicle_id is not null and (select public.is_vehicle_owner(vehicle_id)))
    or (business_account_id is not null and (select public.is_business_admin(business_account_id)))
  )
);
create policy verification_requests_update_reviewer on public.verification_requests for update to authenticated
  using (
    (driver_id is not null and (select public.has_permission('verify_driver')))
    or (vehicle_id is not null and (select public.has_permission('verify_vehicle')))
    or (
      business_account_id is not null
      and ((select public.has_permission('verify_driver')) or (select public.has_permission('verify_vehicle')))
    )
  )
  with check (
    (driver_id is not null and (select public.has_permission('verify_driver')))
    or (vehicle_id is not null and (select public.has_permission('verify_vehicle')))
    or (
      business_account_id is not null
      and ((select public.has_permission('verify_driver')) or (select public.has_permission('verify_vehicle')))
    )
  );

create policy verification_history_select_subject_or_audit on public.verification_history for select to authenticated using (
  driver_id = (select auth.uid()) or (vehicle_id is not null and (select public.is_vehicle_owner(vehicle_id)))
  or (business_account_id is not null and (select public.is_business_member(business_account_id)))
  or (select public.has_permission('view_audit')) or (select public.has_permission('verify_driver')) or (select public.has_permission('verify_vehicle'))
);
-- History is service-role only for writes.

create policy document_expiry_reminders_view_permission on public.document_expiry_reminders for select to authenticated using ((select public.has_permission('view_reminders')));
-- Reminder writes are service-role only.

create policy verification_checklists_select_authenticated on public.verification_checklist_templates for select to authenticated using (true);
create policy verification_checklists_manage on public.verification_checklist_templates for all to authenticated using ((select public.has_permission('manage_document_types'))) with check ((select public.has_permission('manage_document_types')));

-- ============================================================================
-- 3. Privileges
-- ============================================================================
-- Supabase's default privileges grant new public tables to anon/authenticated.
-- RLS would still deny anon, but we remove the grant explicitly, matching Phase 1.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- Default privileges also grant authenticated INSERT/UPDATE/DELETE/TRUNCATE on
-- newly created tables. TRUNCATE bypasses RLS, so reset Phase 2 table grants to
-- a known baseline and then grant only the write capabilities the policies use.
revoke all on
  public.document_types,
  public.driver_documents,
  public.vehicle_documents,
  public.verification_requests,
  public.verification_history,
  public.document_expiry_reminders,
  public.verification_checklist_templates,
  public.vehicle_types,
  public.vehicle_makes,
  public.vehicle_models,
  public.vehicles,
  public.vehicle_equipment_catalog,
  public.vehicle_equipment,
  public.cargo_categories,
  public.cargo_types,
  public.cargo_restrictions,
  public.cargo_packaging_options,
  public.fleets,
  public.fleet_members,
  public.fleet_vehicles,
  public.vehicle_assignments,
  public.fleet_reports
from authenticated;

grant select on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Client-writable tables. RLS still decides which rows and columns are safe.
grant insert, update, delete on
  public.document_types,
  public.vehicle_types,
  public.vehicle_makes,
  public.vehicle_models,
  public.vehicle_equipment_catalog,
  public.vehicle_equipment,
  public.cargo_categories,
  public.cargo_types,
  public.cargo_restrictions,
  public.cargo_packaging_options,
  public.fleet_members,
  public.fleet_vehicles,
  public.verification_checklist_templates
to authenticated;

grant insert, update on
  public.driver_documents,
  public.vehicle_documents,
  public.vehicles,
  public.fleets,
  public.vehicle_assignments,
  public.verification_requests
to authenticated;

-- verification_history, document_expiry_reminders and fleet_reports are
-- service-role write paths; they deliberately receive no client write grant.
revoke all on sequence public.verification_history_id_seq from authenticated;

-- SECURITY DEFINER policy helpers are not part of the public API.
revoke all on function
  public.is_fleet_member(uuid),
  public.is_fleet_owner(uuid),
  public.is_vehicle_owner(uuid)
from public, anon;
grant execute on function
  public.is_fleet_member(uuid),
  public.is_fleet_owner(uuid),
  public.is_vehicle_owner(uuid)
to authenticated, service_role;

