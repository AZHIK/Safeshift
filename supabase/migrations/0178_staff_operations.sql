-- Scope triage to the ticket's country and, for a city grant, its job.
create function private.ticket_scope(p_ticket uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select from public.support_tickets t left join public.jobs j on j.id=t.related_job_id
 where t.id=p_ticket and private.staff_scope('manage_tickets',t.country_id,j.city_id))
$$;
revoke all on function private.ticket_scope(uuid) from public,anon,authenticated;
create or replace function public.admin_ticket_agents(p_ticket_id uuid)
returns table(id uuid,name text) language sql stable security definer set search_path='' as $$
 select distinct p.id,coalesce(p.full_name,p.display_name,p.id::text)
 from public.support_tickets t join public.admin_roles r on (r.country_id is null or r.country_id=t.country_id)
 join public.profiles p on p.id=r.profile_id and p.is_active
 join public.admin_role_permissions rp on rp.role_name=r.role_name and rp.permission_key='manage_tickets'
 where t.id=p_ticket_id and private.ticket_scope(p_ticket_id) and r.is_active
 and r.revoked_at is null and (r.expires_at is null or r.expires_at>now())
 and (r.city_id is null or exists(select from public.jobs j where j.id=t.related_job_id and j.city_id=r.city_id))
 order by 2,1
$$;
revoke all on function public.admin_ticket_agents(uuid) from public,anon;
grant execute on function public.admin_ticket_agents(uuid) to authenticated;
create or replace function public.admin_triage_ticket(p_ticket_id uuid,p_status text,p_priority text,p_assigned uuid,p_due timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare old public.support_tickets%rowtype;
begin
 if not private.ticket_scope(p_ticket_id) then raise insufficient_privilege; end if;
 select * into strict old from public.support_tickets where id=p_ticket_id for update;
 if p_assigned is not null and p_assigned is distinct from old.assigned_to and not exists(select from public.admin_ticket_agents(p_ticket_id) a where a.id=p_assigned) then raise exception 'Select an eligible agent'; end if;
 update public.support_tickets set status=p_status,priority=p_priority,assigned_to=p_assigned,sla_due_at=p_due,
 resolved_at=case when p_status in ('resolved','closed') then coalesce(old.resolved_at,now()) end,
 closed_at=case when p_status='closed' then coalesce(old.closed_at,now()) end where id=p_ticket_id;
 perform private.audit_admin_change('ticket_triaged','support_tickets',p_ticket_id,
 jsonb_build_object('status',old.status,'assigned_to',old.assigned_to,'sla_due_at',old.sla_due_at),
 jsonb_build_object('status',p_status,'assigned_to',p_assigned,'sla_due_at',p_due));
end $$;
revoke all on function public.admin_triage_ticket(uuid,text,text,uuid,timestamptz) from public,anon;
grant execute on function public.admin_triage_ticket(uuid,text,text,uuid,timestamptz) to authenticated;

create function public.admin_update_account(p_id uuid,p_operation text,p_reason text,p_full_name text default null,p_display_name text default null)
returns void language plpgsql security definer set search_path='' as $$
declare p public.profiles; city uuid; country uuid; perm text;
begin
 select * into strict p from public.profiles where id=p_id for update;
 select d.home_city_id,c.country_id into city,country from public.drivers d join public.cities c on c.id=d.home_city_id where d.id=p_id;
 perm:=case when p_operation='end_sessions' then 'suspend_user' else 'manage_customers' end;
 if not coalesce(private.staff_scope(perm,coalesce(country,p.default_country_id),city),false)
 or (exists(select from public.admin_roles where profile_id=p.id and is_active and revoked_at is null) and not public.has_permission('manage_admins'))
 or p.id in(auth.uid(),'00000000-0000-4000-8000-000000000000') then raise insufficient_privilege;end if;
 if length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'Enter a reason';end if;
 if p_operation='end_sessions' then
  delete from auth.sessions where user_id=p.id;
  update public.user_sessions set revoked_at=now(),revoked_reason='staff_signout' where profile_id=p.id and revoked_at is null;
 elsif p_operation='edit_profile' then
  if length(trim(coalesce(p_full_name,''))) not between 1 and 150 or length(coalesce(p_display_name,''))>150 then raise exception 'Invalid profile name';end if;
  update public.profiles set full_name=trim(p_full_name),display_name=nullif(trim(p_display_name),'') where id=p.id;
 else raise exception 'Unknown account operation';end if;
 perform private.audit_admin_change('admin_override','profiles',p.id,null,jsonb_build_object('operation',p_operation,'reason',p_reason));
end $$;

create function public.admin_onboard_fleet(p_id uuid,p_city uuid,p_name text,p_owner uuid,p_registration text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.cities;
begin
 select * into strict c from public.cities where id=p_city and is_active;
 if not coalesce(private.staff_scope('manage_fleets',c.country_id,c.id),false) then raise insufficient_privilege;end if;
 if length(trim(coalesce(p_name,''))) not between 1 and 160 or length(trim(coalesce(p_registration,''))) not between 1 and 100
 or not exists(select from public.profiles where id=p_owner and is_active and default_country_id=c.country_id) then raise exception 'Check registration and owner country';end if;
 insert into public.fleets(id,country_id,primary_city_id,name,owner_profile_id,registration_number)
 values(p_id,c.country_id,c.id,trim(p_name),p_owner,trim(p_registration)) on conflict(id) do nothing;
 if not found then
  if not exists(select from public.fleets where id=p_id and country_id=c.country_id and owner_profile_id=p_owner and registration_number=trim(p_registration)) then raise exception 'Request conflict';end if;
  return p_id;
 end if;
 perform private.audit_admin_change('admin_override','fleets',p_id,null,jsonb_build_object('operation','onboard','owner',p_owner));
 return p_id;
end $$;
create function public.admin_review_fleet(p_id uuid,p_operation text,p_reason text,p_rate numeric default null) returns void
language plpgsql security definer set search_path='' as $$
declare f public.fleets;
begin
 select * into strict f from public.fleets where id=p_id and is_active for update;
 if not coalesce(private.staff_scope(case when p_operation='commission' then 'manage_commission' else 'manage_fleets' end,f.country_id,f.primary_city_id),false) then raise insufficient_privilege;end if;
 if length(trim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'Enter a reason';end if;
 if p_operation='verify' then
  if f.owner_profile_id is null or nullif(trim(f.registration_number),'') is null then raise exception 'Record owner and registration first';end if;
  if f.verified_at is not null then return;end if;
  update public.fleets set verified_at=now(),verified_by=auth.uid() where id=f.id;
 elsif p_operation='commission' then
  if p_rate is not null and (p_rate<0 or p_rate>100 or p_rate<>round(p_rate,2)) then raise exception 'Invalid commission percentage';end if;
  update public.fleets set commission_rate_override=p_rate where id=f.id;
 else raise exception 'Unknown fleet operation';end if;
 perform private.audit_admin_change('admin_override','fleets',f.id,jsonb_build_object('rate',f.commission_rate_override),jsonb_build_object('operation',p_operation,'rate',p_rate,'reason',p_reason));
end $$;

create function private.incident_scope(p_id uuid,p_permission text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select from public.incidents i join public.profiles p on p.id=i.reported_by left join public.jobs j on j.id=i.job_id
 left join public.cities c on c.id=j.city_id where i.id=p_id and private.staff_scope(p_permission,coalesce(c.country_id,p.default_country_id),c.id))
$$;
revoke all on function private.incident_scope(uuid,text) from public,anon,authenticated;
create function public.admin_incident_contacts(p_id uuid) returns table(id uuid,name text,phone text,relationship text)
language sql stable security definer set search_path='' as $$
 select e.id,e.name,e.phone,e.relationship from public.incidents i join public.emergency_contacts e on e.profile_id=i.reported_by and e.notify_on_sos
 where i.id=p_id and private.incident_scope(i.id,'manage_incidents') order by e.is_primary desc,e.name
$$;
create function public.admin_incident_action(p_id uuid,p_note text,p_contact uuid default null) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.incident_scope(p_id,'manage_incidents') then raise insufficient_privilege;end if;
 if length(trim(coalesce(p_note,''))) not between 3 and 2000 then raise exception 'Enter a note';end if;
 if p_contact is not null and not exists(select from public.admin_incident_contacts(p_id) c where c.id=p_contact) then raise exception 'Invalid emergency contact';end if;
 insert into public.incident_actions(incident_id,actor_id,action_type,notes,metadata) values(p_id,auth.uid(),
 case when p_contact is null then 'note_added' else 'escalated' end,trim(p_note),jsonb_strip_nulls(jsonb_build_object('contact_id',p_contact)));
end $$;
create policy blocked_users_staff_read on public.blocked_users for select to authenticated using(
 exists(select from public.profiles p where p.id=blocker_profile_id and private.staff_scope('manage_customers',p.default_country_id,(select city_id from public.jobs where id=blocked_users.job_id)))
);
revoke all on function public.admin_update_account(uuid,text,text,text,text),public.admin_onboard_fleet(uuid,uuid,text,uuid,text),public.admin_review_fleet(uuid,text,text,numeric),public.admin_incident_contacts(uuid),public.admin_incident_action(uuid,text,uuid) from public,anon;
grant execute on function public.admin_update_account(uuid,text,text,text,text),public.admin_onboard_fleet(uuid,uuid,text,uuid,text),public.admin_review_fleet(uuid,text,text,numeric),public.admin_incident_contacts(uuid),public.admin_incident_action(uuid,text,uuid) to authenticated;
