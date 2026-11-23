create table public.admin_role_definitions (
 role_name text primary key check (role_name ~ '^[a-z][a-z0-9_]{1,63}$'),
 label text not null check (length(trim(label)) between 1 and 100)
);
insert into public.admin_role_definitions(role_name,label) values
 ('super_admin','Super admin'),('operations_admin','Operations admin'),
 ('verification_admin','Verification admin'),('support_agent','Support agent'),
 ('finance_admin','Finance admin'),('analyst','Analyst'),('fleet_owner','Fleet owner');
alter table public.admin_roles drop constraint admin_roles_role_name_check,
 add foreign key(role_name) references public.admin_role_definitions;
alter table public.admin_role_permissions drop constraint admin_role_permissions_role_name_check,
 add foreign key(role_name) references public.admin_role_definitions;
alter table public.admin_role_definitions enable row level security;
revoke all on public.admin_role_definitions from public, anon, authenticated;
grant select on public.admin_role_definitions to authenticated;
create policy role_definitions_read on public.admin_role_definitions for select to authenticated
using ((select public.has_permission('manage_admins')));
create function public.admin_create_role_definition(p_name text,p_label text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.has_permission('manage_admins') then raise insufficient_privilege; end if;
 insert into public.admin_role_definitions values(p_name,btrim(p_label));
 perform private.audit_admin_change('role_created','admin_role_definitions',null,null,jsonb_build_object('role_name',p_name,'label',btrim(p_label)));
end $$;
revoke all on function public.admin_create_role_definition(text,text) from public,anon;
grant execute on function public.admin_create_role_definition(text,text) to authenticated;

-- Representative role for display and audit attribution. Entitlements use all grants.
create or replace function public.admin_console_role() returns text
language sql stable security definer set search_path='' as $$
 select r.role_name from public.admin_roles r join public.profiles p on p.id=r.profile_id
 where r.profile_id=auth.uid() and p.is_active and r.is_active and r.revoked_at is null
 and (r.expires_at is null or r.expires_at > now())
 and (r.country_id is null or r.country_id=p.default_country_id)
 order by (r.role_name='fleet_owner'),(r.role_name='super_admin') desc,r.granted_at,r.id limit 1
$$;
