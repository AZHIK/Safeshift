-- An individual can belong to several companies. Bill only jobs attributed to
-- a particular account, either by its recurring booking or by a finance reviewer.
create table public.business_job_allocations(
 job_id uuid primary key references public.jobs on delete restrict,
 business_account_id uuid not null references public.business_accounts on delete restrict,
 allocated_by uuid not null references public.profiles, reason text not null, created_at timestamptz not null default now()
);
alter table public.business_job_allocations enable row level security;
revoke all on public.business_job_allocations from public,anon,authenticated;

create function private.invoice_scope(p_account uuid,p_permission text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select from public.business_accounts a where a.id=p_account and private.staff_scope(p_permission,a.country_id,a.city_id))
$$;
revoke all on function private.invoice_scope(uuid,text) from public,anon;
grant execute on function private.invoice_scope(uuid,text) to authenticated;
alter policy invoices_select_member_or_staff on public.invoices using (
 private.invoice_scope(business_account_id,'view_invoices') or private.invoice_scope(business_account_id,'manage_invoices')
 or (status<>'draft' and exists(select from public.business_members m where m.business_account_id=invoices.business_account_id and m.profile_id=auth.uid() and m.accepted_at is not null))
);

create function public.admin_billable_accounts() returns table(id uuid,name text)
language sql stable security definer set search_path='' as $$
 select a.id,a.legal_name from public.business_accounts a where a.is_active and private.invoice_scope(a.id,'manage_invoices') order by a.legal_name
$$;

create function public.admin_allocate_business_job(p_account uuid,p_job uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare j public.jobs; a public.business_accounts;
begin
 if not private.invoice_scope(p_account,'manage_invoices') then raise insufficient_privilege;end if;
 select * into strict a from public.business_accounts where id=p_account and is_active for update;
 select * into strict j from public.jobs where id=p_job and status='completed' for update;
 if length(trim(coalesce(p_reason,''))) not between 3 and 1000
 or not exists(select from public.business_members m where m.business_account_id=a.id and m.profile_id=j.customer_id and m.accepted_at<=j.completed_at)
 or not exists(select from public.cities c where c.id=j.city_id and c.country_id=a.country_id and private.staff_scope('manage_invoices',c.country_id,c.id))
 or exists(select from public.invoice_line_items l where l.job_id=j.id)
 or exists(select from public.scheduled_jobs s join public.recurring_job_templates t on t.id=s.template_id where s.job_id=j.id and t.business_account_id<>a.id)
 then raise exception 'Check membership, territory, billing evidence and prior invoices';end if;
 insert into public.business_job_allocations values(j.id,a.id,auth.uid(),trim(p_reason),now()) on conflict(job_id) do nothing;
 if not exists(select from public.business_job_allocations b where b.job_id=j.id and b.business_account_id=a.id) then raise exception 'Job already allocated';end if;
 perform private.audit_admin_change('admin_override','jobs',j.id,null,jsonb_build_object('billing_account',a.id,'reason',p_reason));
end $$;

create or replace function public.generate_invoice(p_business_account_id uuid,p_period_start timestamptz,p_period_end timestamptz) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.business_accounts; currency char(3); invoice uuid; gross numeric; tax numeric; net numeric; item record;
begin
 if not (private.invoice_scope(p_business_account_id,'manage_invoices') or current_setting('role',true)='service_role') then raise insufficient_privilege;end if;
 select * into strict a from public.business_accounts where id=p_business_account_id and is_active for update;
 if p_period_start is null or p_period_end is null or p_period_end<=p_period_start then raise exception 'Invalid billing period';end if;
 select id into invoice from public.invoices where business_account_id=a.id and period_start=p_period_start and period_end=p_period_end and status<>'cancelled' order by created_at limit 1;
 if found then return invoice;end if;
 select u.code into strict currency from public.countries c join public.currencies u on u.id=c.default_currency_id where c.id=a.country_id;
 insert into public.invoices(business_account_id,invoice_number,currency_code,period_start,period_end)
 values(a.id,'INV-'||to_char(p_period_start,'YYYYMM')||'-'||upper(substr(gen_random_uuid()::text,1,8)),currency,p_period_start,p_period_end) returning id into invoice;
 gross:=0; tax:=0;
 for item in
  select j.id,coalesce(j.final_amount,q.total) as fare,q.total as quoted,q.vat,q.currency_code from public.jobs j join public.quotes q on q.id=j.quote_id
  where j.status='completed' and j.completed_at>=p_period_start and j.completed_at<p_period_end
  and (exists(select from public.business_job_allocations b where b.job_id=j.id and b.business_account_id=a.id)
  or exists(select from public.scheduled_jobs s join public.recurring_job_templates t on t.id=s.template_id where s.job_id=j.id and t.business_account_id=a.id))
  and not exists(select from public.invoice_line_items l join public.invoices i on l.invoice_id=i.id where l.job_id=j.id and i.status<>'cancelled')
  order by j.id for update of j
 loop
  if item.currency_code<>currency then raise exception 'Job and billing account currencies differ';end if;
  net:=item.fare-coalesce(round(item.fare*item.vat/nullif(item.quoted,0),2),0);
  insert into public.invoice_line_items(invoice_id,description,unit_price,amount,job_id) values(invoice,'Transport job '||item.id,net,net,item.id);
  gross:=gross+item.fare; tax:=tax+(item.fare-net);
 end loop;
 if not exists(select from public.invoice_line_items where invoice_id=invoice) then raise exception 'No unbilled business jobs in this period';end if;
 update public.invoices set subtotal=gross-tax,tax_amount=tax,total=gross where id=invoice;
 perform private.audit_admin_change('admin_override','invoices',invoice,null,jsonb_build_object('draft_total',gross));
 return invoice;
end $$;

create function public.admin_issue_invoice(p_invoice uuid) returns void language plpgsql security definer set search_path='' as $$
declare i public.invoices; terms integer;
begin
 select * into strict i from public.invoices where id=p_invoice for update;
 if not private.invoice_scope(i.business_account_id,'manage_invoices') then raise insufficient_privilege;end if;
 if i.status='sent' then return;end if;
 if i.status<>'draft' then raise exception 'Only draft invoices can be issued';end if;
 select payment_terms_days into strict terms from public.business_accounts where id=i.business_account_id;
 update public.invoices set issued_at=now(),due_at=now()+make_interval(days=>terms),status='sent' where id=i.id;
 insert into public.inbox_messages(profile_id,title,body)
 select m.profile_id,'Business invoice issued',i.invoice_number||' · '||trim(i.currency_code)||' '||i.total
 from public.business_members m where m.business_account_id=i.business_account_id and m.accepted_at is not null;
 perform private.audit_admin_change('admin_override','invoices',i.id,null,jsonb_build_object('status','sent'));
end $$;

create table public.provider_requests(
 id uuid primary key default gen_random_uuid(),country_id uuid not null references public.countries,city_id uuid references public.cities,
 kind text not null check(kind in ('fiscal_receipt','national_id','driving_licence','tax_id')),
 invoice_id uuid references public.invoices, document_id uuid references public.driver_documents,
 status text not null default 'awaiting_integration' check(status in ('awaiting_integration','confirmed','rejected','cancelled')),
 provider_reference text,finished_at timestamptz, requested_by uuid not null references public.profiles, created_at timestamptz not null default now(),
 check ((kind='fiscal_receipt' and invoice_id is not null and document_id is null) or (kind<>'fiscal_receipt' and document_id is not null and invoice_id is null))
);
create unique index fiscal_request_once on public.provider_requests(invoice_id) where status<>'cancelled';
create unique index document_request_once on public.provider_requests(document_id,kind) where status<>'cancelled';
alter table public.provider_requests enable row level security;
revoke all on public.provider_requests from public,anon,authenticated;
grant select on public.provider_requests to authenticated;
create policy read_provider_requests on public.provider_requests for select to authenticated using(
 private.staff_scope(case when invoice_id is not null then 'manage_invoices' else 'verify_driver' end,country_id,city_id)
);

create function public.admin_request_provider(p_kind text,p_subject uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare country uuid; city uuid; result uuid; invoice uuid; doc uuid;
begin
 if p_kind='fiscal_receipt' then
  select i.id,a.country_id,a.city_id into strict invoice,country,city from public.invoices i join public.business_accounts a on a.id=i.business_account_id
  where i.id=p_subject and i.issued_at is not null and i.status not in ('draft','cancelled','refunded') for update of i;
 elsif p_kind in ('national_id','driving_licence','tax_id') then
  select d.id,c.country_id,c.id into strict doc,country,city from public.driver_documents d join public.drivers dr on dr.id=d.driver_id
  join public.cities c on c.id=dr.home_city_id where d.id=p_subject and d.is_current and d.superseded_by is null for update of d;
 else raise exception 'Unknown provider request'; end if;
 if not coalesce(private.staff_scope(case when invoice is null then 'verify_driver' else 'manage_invoices' end,country,city),false) then raise insufficient_privilege;end if;
 select id into result from public.provider_requests r where r.kind=p_kind and (r.invoice_id=invoice or r.document_id=doc) and r.status<>'cancelled';
 if found then return result;end if;
 insert into public.provider_requests(country_id,city_id,kind,invoice_id,document_id,requested_by) values(country,city,p_kind,invoice,doc,auth.uid()) returning id into result;
 perform private.audit_admin_change('admin_override','provider_requests',result,null,jsonb_build_object('kind',p_kind,'status','awaiting_integration'));
 return result;
end $$;
create function public.admin_cancel_provider_request(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r public.provider_requests;
begin
 select * into strict r from public.provider_requests where id=p_id for update;
 if not coalesce(private.staff_scope(case when r.invoice_id is null then 'verify_driver' else 'manage_invoices' end,r.country_id,r.city_id),false) then raise insufficient_privilege;end if;
 if r.status<>'awaiting_integration' then raise exception 'Only pending requests can be cancelled';end if;
 update public.provider_requests set status='cancelled',finished_at=now() where id=r.id;
 perform private.audit_admin_change('admin_override','provider_requests',r.id,null,jsonb_build_object('status','cancelled'));
end $$;
-- Adapter boundary. A future authenticated provider worker can record its real
-- decision and reference. A pending request changes no verification status.
create function public.record_provider_result(p_id uuid,p_status text,p_reference text) returns void
language plpgsql security definer set search_path='' as $$
declare r public.provider_requests;
begin
 if p_status not in ('confirmed','rejected') or p_status is null or length(trim(coalesce(p_reference,''))) not between 1 and 300 then raise exception 'Invalid provider result';end if;
 select * into strict r from public.provider_requests where id=p_id for update;
 if r.status=p_status and r.provider_reference=trim(p_reference) then return;end if;
 if r.status<>'awaiting_integration' then raise exception 'Request already closed';end if;
 update public.provider_requests set status=p_status,provider_reference=trim(p_reference),finished_at=now() where id=p_id;
end $$;
revoke all on function public.record_provider_result(uuid,text,text) from public,anon,authenticated;
grant execute on function public.record_provider_result(uuid,text,text) to service_role;
revoke all on function public.admin_allocate_business_job(uuid,uuid,text), public.admin_billable_accounts(),public.admin_issue_invoice(uuid),public.admin_request_provider(text,uuid),public.admin_cancel_provider_request(uuid) from public,anon;
grant execute on function public.admin_allocate_business_job(uuid,uuid,text), public.admin_billable_accounts(),public.admin_issue_invoice(uuid),public.admin_request_provider(text,uuid),public.admin_cancel_provider_request(uuid) to authenticated;
