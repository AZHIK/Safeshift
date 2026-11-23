create table public.support_saved_replies(
 id uuid primary key default gen_random_uuid(), name text not null unique check(length(trim(name))>0),
 body text not null check(length(trim(body))>0),is_active boolean not null default true,
 created_at timestamptz not null default now()
);
alter table public.support_saved_replies enable row level security;
revoke all on public.support_saved_replies from public, anon, authenticated;
grant select,insert,update on public.support_saved_replies to authenticated;
create policy saved_reply_read on public.support_saved_replies for select to authenticated using (public.has_permission('view_all_tickets') or public.has_permission('manage_tickets'));
create policy saved_reply_manage on public.support_saved_replies for all to authenticated using(public.has_permission('manage_support')) with check(public.has_permission('manage_support'));

create function public.admin_ticket_agents(p_ticket_id uuid)
returns table(id uuid,name text) language sql stable security definer set search_path='' as $$
 select distinct p.id,coalesce(p.full_name,p.display_name,p.id::text)
 from public.support_tickets t join public.admin_roles r on (r.country_id is null or r.country_id=t.country_id)
 join public.profiles p on p.id=r.profile_id and p.is_active
 join public.admin_role_permissions rp on rp.role_name=r.role_name and rp.permission_key='manage_tickets'
 where t.id=p_ticket_id and public.has_permission('manage_tickets') and r.is_active
 and r.revoked_at is null and (r.expires_at is null or r.expires_at>now())
 and (r.city_id is null or exists(select from public.jobs j where j.id=t.related_job_id and j.city_id=r.city_id))
 order by 2,1
$$;
revoke all on function public.admin_ticket_agents(uuid) from public,anon;
grant execute on function public.admin_ticket_agents(uuid) to authenticated;
create function public.admin_triage_ticket(p_ticket_id uuid,p_status text,p_priority text,p_assigned uuid,p_due timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare old public.support_tickets%rowtype;
begin
 if not public.has_permission('manage_tickets') then raise insufficient_privilege; end if;
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

-- Scope against the affected territory, including when multiple grants are held.
create function private.staff_scope(p_permission text,p_country uuid,p_city uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (auth.jwt()->>'aal')='aal2' and exists (
 select from public.admin_roles r join public.admin_role_permissions rp using(role_name)
 join public.profiles p on p.id=r.profile_id and p.is_active
 where r.profile_id=auth.uid() and r.is_active and r.revoked_at is null and (r.expires_at is null or r.expires_at>now())
 and rp.permission_key=p_permission and (r.country_id is null or r.country_id=p_country)
 and (r.city_id is null or r.city_id=p_city))
$$;
revoke all on function private.staff_scope(text,uuid,uuid) from public,anon;
grant execute on function private.staff_scope(text,uuid,uuid) to authenticated;

create table public.announcements (
 id uuid primary key, created_by uuid not null references public.profiles,
 country_id uuid not null references public.countries, city_id uuid references public.cities,
 audience text not null check(audience in ('customer','driver','all')),
 title text not null check(length(btrim(title)) between 1 and 140), body text not null check(length(btrim(body)) between 1 and 4000),
 recipient_count integer not null default 0, created_at timestamptz not null default now()
);
alter table public.announcements enable row level security;
revoke all on public.announcements from public,anon,authenticated;
grant select on public.announcements to authenticated;
create policy announcements_read on public.announcements for select to authenticated using(private.staff_scope('send_notification',country_id,city_id));
create function public.admin_announce(p_id uuid,p_country uuid,p_city uuid,p_audience text,p_title text,p_body text)
returns integer language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 if not coalesce(private.staff_scope('send_notification',p_country,p_city),false) then raise insufficient_privilege; end if;
 if p_city is not null and not exists(select from public.cities where id=p_city and country_id=p_country) then raise exception 'City must belong to country'; end if;
 insert into public.announcements(id,created_by,country_id,city_id,audience,title,body)
 values (p_id,auth.uid(),p_country,p_city,p_audience,btrim(p_title),btrim(p_body)) on conflict(id) do nothing;
 if not found then
  select recipient_count into strict n from public.announcements where id=p_id and created_by=auth.uid() and country_id=p_country and city_id is not distinct from p_city and audience=p_audience and title=btrim(p_title) and body=btrim(p_body);
  return n;
 end if;
 insert into public.inbox_messages(profile_id,title,body)
 select p.id,btrim(p_title),btrim(p_body) from public.profiles p
 left join public.drivers d on d.id=p.id left join public.customers c on c.id=p.id
 left join public.addresses a on a.id=c.default_address_id
 where p.is_active and p.primary_role in ('customer','driver') and (p_audience='all' or p.primary_role::text=p_audience)
 and case when p.primary_role='driver' then coalesce(d.country_id,p.default_country_id) else coalesce(a.country_id,p.default_country_id) end=p_country
 and (p_city is null or case when p.primary_role='driver' then d.home_city_id else a.city_id end=p_city);
 get diagnostics n=row_count;
 update public.announcements set recipient_count=n where id=p_id;
 perform private.audit_admin_change('announcement_sent','announcements',p_id,null,jsonb_build_object('recipient_count',n,'country_id',p_country,'city_id',p_city,'audience',p_audience));
 return n;
end $$;
revoke all on function public.admin_announce(uuid,uuid,uuid,text,text,text) from public,anon;
grant execute on function public.admin_announce(uuid,uuid,uuid,text,text,text) to authenticated;
