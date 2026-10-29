-- ============================================================================
-- SafeShift — Phase 9 local-only seed
--
-- Adds the fleet-owner console grant and demo safety contacts after the
-- Phase 1–6 seeds have created the profiles. Never run against staging or
-- production.
-- ============================================================================

set search_path = public, extensions;

begin;

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

insert into public.emergency_contacts (profile_id, name, phone, relationship, is_primary, notify_on_trip_start, notify_on_sos)
select v.profile_id, v.name, v.phone, v.relationship, v.is_primary, v.notify_on_trip_start, v.notify_on_sos
from (values
  ('d0000000-0000-4000-8000-000000000001'::uuid, 'Neema Mwakyusa', '+255712000101', 'Spouse', true, true, true)
) as v(profile_id, name, phone, relationship, is_primary, notify_on_trip_start, notify_on_sos)
where exists (select 1 from public.profiles p where p.id = v.profile_id)
  and not exists (
    select 1 from public.emergency_contacts e
     where e.profile_id = v.profile_id and e.phone = v.phone
  );

commit;
