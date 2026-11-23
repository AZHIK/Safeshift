-- Administrative grants become effective after authenticator verification.
-- admin_console_role remains available for sign-in and enrollment.
create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select distinct arp.permission_key
      from public.admin_roles ar
      join public.admin_role_permissions arp
        on arp.role_name = ar.role_name
     where ar.profile_id = auth.uid()
       and (select auth.jwt()->>'aal') = 'aal2'
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
       -- Country scoping: a grant with country_id NULL applies everywhere,
       -- otherwise it must match the caller's country.
       and (
         ar.country_id is null
         or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
       )
  )
  select
      exists (
        select 1 from held where held.permission_key = has_permission.permission_key
      )
      or (
        has_permission.permission_key = any (public.config_permission_keys())
        and exists (
          select 1 from held where held.permission_key = 'manage_configuration'
        )
      );
$$;

create or replace function public.has_permission(permission_key text, city_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select distinct arp.permission_key
      from public.admin_roles ar
      join public.admin_role_permissions arp
        on arp.role_name = ar.role_name
     where ar.profile_id = auth.uid()
       and (select auth.jwt()->>'aal') = 'aal2'
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
       and (
         ar.country_id is null
         or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
       )
       and (ar.city_id is null or ar.city_id = has_permission.city_id)
  )
  select
      exists (
        select 1 from held where held.permission_key = has_permission.permission_key
      )
      or (
        has_permission.permission_key = any (public.config_permission_keys())
        and exists (
          select 1 from held where held.permission_key = 'manage_configuration'
        )
      );
$$;

create or replace function public.admin_my_permissions()
returns table (
  permission_key text,
  role_name      text
)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct arp.permission_key, ar.role_name
    from public.admin_roles ar
    join public.admin_role_permissions arp
      on arp.role_name = ar.role_name
   where ar.profile_id = auth.uid()
       and (select auth.jwt()->>'aal') = 'aal2'
     and ar.is_active
     and ar.revoked_at is null
     and (ar.expires_at is null or ar.expires_at > now())
     and (
       ar.country_id is null
       or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
     )
   order by arp.permission_key, ar.role_name;
$$;

create or replace function public.has_admin_role(role_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.admin_roles ar
     where ar.profile_id = auth.uid()
       and (select auth.jwt()->>'aal') = 'aal2'
       and ar.role_name = has_admin_role.role_name
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
  );
$$;

create or replace function public.current_permissions()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct arp.permission_key order by arp.permission_key), '{}'::text[])
    from public.admin_roles ar
    join public.admin_role_permissions arp on arp.role_name = ar.role_name
   where ar.profile_id = auth.uid()
       and (select auth.jwt()->>'aal') = 'aal2'
     and ar.is_active
     and ar.revoked_at is null
     and (ar.expires_at is null or ar.expires_at > now())
     and (
       ar.country_id is null
       or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
     );
$$;

create or replace function public.pending_verifications_for_admin(p_admin_profile_id uuid)
returns setof public.verification_requests
language sql stable security definer set search_path = '' as $$
  select vr.*
  from public.verification_requests vr
  left join public.drivers d on d.id = vr.driver_id
  left join public.vehicles v on v.id = vr.vehicle_id
  left join public.business_accounts ba on ba.id = vr.business_account_id
  where (
      (p_admin_profile_id = auth.uid() and (select auth.jwt()->>'aal') = 'aal2')
      or coalesce(auth.role(), '') = 'service_role'
    )
    and vr.status in ('pending', 'in_review')
    and (vr.assigned_to is null or vr.assigned_to = p_admin_profile_id)
    and exists (
      select 1
      from public.admin_roles ar
      join public.admin_role_permissions arp on arp.role_name = ar.role_name
      where ar.profile_id = p_admin_profile_id
        and ar.is_active
        and ar.revoked_at is null
        and (ar.expires_at is null or ar.expires_at > now())
        and (
          (vr.driver_id is not null and arp.permission_key = 'verify_driver')
          or (vr.vehicle_id is not null and arp.permission_key = 'verify_vehicle')
          or (vr.business_account_id is not null and arp.permission_key in ('verify_driver', 'verify_vehicle'))
        )
        and (ar.country_id is null or ar.country_id = coalesce(d.country_id, v.country_id, ba.country_id))
        and (ar.city_id is null or ar.city_id = coalesce(d.home_city_id, v.home_city_id, ba.city_id))
    );
$$;
