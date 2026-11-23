insert into public.admin_permissions_catalog(permission_key,description,category) values
 ('export_regulator_reports','Export country operating reports','compliance'),
 ('review_government_requests','Approve or reject government data requests','compliance');
insert into public.admin_role_permissions(role_name,permission_key) values
 ('super_admin','export_regulator_reports'),('super_admin','review_government_requests');

create table public.government_requests (
 id uuid primary key default gen_random_uuid(),country_id uuid not null references public.countries,
 authority text not null check(length(btrim(authority)) between 1 and 200),
 reference text not null check(length(btrim(reference)) between 1 and 200),
 legal_basis text not null check(length(btrim(legal_basis)) between 3 and 4000),
 period_start date not null, period_end date not null check(period_end>=period_start),
 opened_by uuid not null references public.profiles, created_at timestamptz not null default now(),
 status text not null default 'pending' check(status in ('pending','approved','rejected','exported')),
 reviewed_by uuid references public.profiles, reviewed_at timestamptz, review_note text,
 report jsonb, last_export_at timestamptz,unique(country_id,authority,reference)
);
alter table public.government_requests enable row level security;
revoke all on public.government_requests from public,anon,authenticated;
-- The frozen report is accessible only through the audited export function.
grant select(id,country_id,authority,reference,legal_basis,period_start,period_end,opened_by,created_at,status,reviewed_by,reviewed_at,review_note,last_export_at) on public.government_requests to authenticated;
create policy government_requests_read on public.government_requests for select to authenticated
using(private.staff_scope('manage_data_requests',country_id,null) or private.staff_scope('review_government_requests',country_id,null));

create function private.country_operating_report(p_country uuid,p_start date,p_end date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare start_at timestamptz; end_at timestamptz; zone text; iso text; result jsonb;
begin
 if p_start is null or p_end is null or p_end<p_start then raise exception 'Choose a valid date range'; end if;
 select default_timezone,iso_code into strict zone,iso from public.countries where id=p_country;
 start_at:=p_start::timestamp at time zone zone;end_at:=(p_end+1)::timestamp at time zone zone;
 with trips as (
  select j.* from public.jobs j join public.cities c on c.id=j.city_id
  where c.country_id=p_country and j.completed_at>=start_at and j.completed_at<end_at
 ), safety as (
  select count(*) as incidents from public.incidents i left join public.jobs j on j.id=i.job_id
  left join public.cities c on c.id=j.city_id join public.profiles p on p.id=i.reported_by
  where coalesce(c.country_id,p.default_country_id)=p_country and i.occurred_at>=start_at and i.occurred_at<end_at
 ), revenue as (
  select l.currency_code,sum(l.commission_amount) amount from public.commission_ledger l
  join public.jobs j on j.id=l.job_id join public.cities c on c.id=j.city_id
  where c.country_id=p_country and l.calculated_at>=start_at and l.calculated_at<end_at and not l.is_refunded group by l.currency_code
 )
 select jsonb_build_object('country',iso,'period_start',p_start,'period_end',p_end,'completed_trips',count(*),
 'active_drivers',count(distinct driver_id),'active_vehicles',count(distinct vehicle_id),
 'safety_incidents',(select incidents from safety),
 'recorded_commission',coalesce((select jsonb_object_agg(currency_code,amount) from revenue),'{}'::jsonb))
 into result from trips;
 return result;
end $$;
revoke all on function private.country_operating_report(uuid,date,date) from public,anon,authenticated;

create function public.admin_regulator_report(p_country uuid,p_start date,p_end date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not coalesce(private.staff_scope('export_regulator_reports',p_country,null),false) then raise insufficient_privilege; end if;
 result:=private.country_operating_report(p_country,p_start,p_end);
 perform private.audit_admin_change('regulator_export','countries',p_country,null,jsonb_build_object('start',p_start,'end',p_end));
 return result;
end $$;
create function public.admin_open_government_request(p_country uuid,p_authority text,p_reference text,p_basis text,p_start date,p_end date)
returns uuid language plpgsql security definer set search_path='' as $$
declare request_id uuid;
begin
 if not coalesce(private.staff_scope('manage_data_requests',p_country,null),false) then raise insufficient_privilege; end if;
 insert into public.government_requests(country_id,authority,reference,legal_basis,period_start,period_end,opened_by)
 values(p_country,btrim(p_authority),btrim(p_reference),btrim(p_basis),p_start,p_end,auth.uid()) returning id into request_id;
 perform private.audit_admin_change('government_request_opened','government_requests',request_id,null,jsonb_build_object('country',p_country,'start',p_start,'end',p_end));
 return request_id;
end $$;
create function public.admin_review_government_request(p_id uuid,p_decision text,p_note text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.government_requests;
begin
 select * into strict r from public.government_requests where id=p_id for update;
 if not coalesce(private.staff_scope('review_government_requests',r.country_id,null),false) then raise insufficient_privilege; end if;
 if r.status<>'pending' or p_decision not in ('approved','rejected') or length(btrim(coalesce(p_note,'')))<3 then raise exception 'A pending request and review reason are required';end if;
 update public.government_requests set status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_note,
 report=case when p_decision='approved' then private.country_operating_report(r.country_id,r.period_start,r.period_end) end where id=p_id;
 perform private.audit_admin_change('government_request_reviewed','government_requests',p_id,null,jsonb_build_object('decision',p_decision,'reason',p_note));
end $$;
create function public.admin_export_government_request(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.government_requests;
begin
 select * into strict r from public.government_requests where id=p_id for update;
 if not coalesce(private.staff_scope('manage_data_requests',r.country_id,null),false) then raise insufficient_privilege; end if;
 if r.status not in ('approved','exported') or r.report is null then raise exception 'Legal approval required'; end if;
 update public.government_requests set status='exported',last_export_at=now() where id=p_id;
 perform private.audit_admin_change('government_request_exported','government_requests',p_id,null,jsonb_build_object('reviewed_by',r.reviewed_by));
 return r.report;
end $$;
revoke all on function public.admin_regulator_report(uuid,date,date),public.admin_open_government_request(uuid,text,text,text,date,date),public.admin_review_government_request(uuid,text,text),public.admin_export_government_request(uuid) from public, anon;
grant execute on function public.admin_regulator_report(uuid,date,date),public.admin_open_government_request(uuid,text,text,text,date,date),public.admin_review_government_request(uuid,text,text),public.admin_export_government_request(uuid) to authenticated;
