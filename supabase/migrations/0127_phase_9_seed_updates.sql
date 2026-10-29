-- ============================================================================
-- SafeShift — Phase 9 / Migration 0127
-- Idempotent reference data for the Phase 9 console and mobile flows.
--
-- This is migration data, not production seed data. It is safe to run on an
-- existing database and is intentionally limited to catalogues, role grants,
-- and feature flags.
-- ============================================================================

-- The seeded fleet owner can use the fleet portal immediately. Real fleet
-- owners receive the same grant through the admin role workflow.
insert into public.admin_roles (profile_id, role_name, country_id, city_id, is_active, granted_by)
select 'f0000000-0000-4000-8000-000000000001'::uuid,
       'fleet_owner',
       '33333333-0000-4000-8000-000000000001'::uuid,
       null,
       true,
       'a0000000-0000-4000-8000-000000000001'::uuid
where exists (select 1 from public.profiles where id = 'f0000000-0000-4000-8000-000000000001'::uuid)
  and not exists (
    select 1 from public.admin_roles
     where profile_id = 'f0000000-0000-4000-8000-000000000001'::uuid
       and role_name = 'fleet_owner'
  );

insert into public.admin_role_permissions (role_name, permission_key)
select 'fleet_owner', permission_key
from public.admin_permissions_catalog
where permission_key in ('view_fleet', 'manage_fleet_vehicles', 'manage_fleet_drivers',
                         'view_fleet_earnings')
on conflict do nothing;

insert into public.support_categories (country_id, code, name, description, display_order, is_active)
select c.id, v.code, v.name, v.description, v.display_order, true
from public.countries c
cross join (values
  ('business_account', 'Business account', 'Business registration, verification, and invoicing.', 60),
  ('safety', 'Safety concern', 'Safety, SOS, trip sharing, and emergency support.', 70),
  ('driver_onboarding', 'Driver onboarding', 'Driver documents, verification, and vehicle checks.', 80),
  ('trip_issue', 'Trip issue', 'Live trip, delivery code, or route issue.', 90)
) as v(code, name, description, display_order)
where c.id = '33333333-0000-4000-8000-000000000001'::uuid
on conflict (country_id, code) do nothing;

insert into public.feature_flags (flag_key, country_id, city_id, profile_id, is_enabled, rollout_percentage, description) values
  ('phase9_driver_onboarding', null, null, null, true, 100, 'Guided driver onboarding and document capture.'),
  ('phase9_business_accounts', null, null, null, true, 100, 'Business account self-service and recurring jobs.'),
  ('phase9_safety_suite', null, null, null, true, 100, 'Emergency contacts, SOS, and trip sharing.'),
  ('phase9_admin_console', null, null, null, true, 100, 'Next.js operations console for admins and fleet owners.')
on conflict (flag_key, country_id, city_id, profile_id) do nothing;
