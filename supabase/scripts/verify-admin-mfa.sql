begin;
do $$
declare staff uuid;
begin
 select profile_id into strict staff from public.admin_roles where role_name='super_admin' and is_active and revoked_at is null and (expires_at is null or expires_at > now()) limit 1;
 perform set_config('request.jwt.claims',json_build_object('sub',staff,'role','authenticated','aal','aal1')::text,true);
 if public.has_permission('manage_admins') or public.has_admin_role('super_admin') or exists(select from public.admin_my_permissions()) then raise exception 'Password-only admin has privileges'; end if;
 perform set_config('request.jwt.claims',json_build_object('sub',staff,'role','authenticated','aal','aal2')::text,true);
 if not public.has_permission('manage_admins') or not public.has_admin_role('super_admin') then raise exception 'Verified admin missing permissions'; end if;
end $$;
rollback;
