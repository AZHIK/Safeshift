-- Every assignment path, including an offer acceptance racing a manual assignment,
-- must claim the same driver at most once.
create unique index jobs_one_active_assignment on public.jobs(driver_id)
where driver_id is not null and status between 'accepted' and 'delivered';

create function public.admin_job_candidates(p_job uuid) returns table(id uuid,name text,registration text)
language sql stable security definer set search_path='' as $$
 select d.id,coalesce(p.full_name,p.display_name,d.id::text),v.registration_number
 from public.jobs j join public.cities c on c.id=j.city_id join public.quotes q on q.id=j.quote_id
 join public.quote_requests qr on qr.id=q.quote_request_id
 join public.drivers d on d.home_city_id=j.city_id and d.is_available and d.verification_status='verified'
 join public.profiles p on p.id=d.id and p.is_active
 join public.vehicles v on v.id=d.current_vehicle_id and v.vehicle_type_id=qr.vehicle_type_id and v.is_active and v.verification_status='verified'
 where j.id=p_job and j.status in ('quoted','requested','matched') and private.staff_scope('assign_drivers',c.country_id,c.id)
 and (d.current_fleet_id is null or exists(select from public.fleets f where f.id=d.current_fleet_id and f.is_active))
 and (v.primary_driver_id=d.id or exists(select from public.vehicle_assignments a where a.vehicle_id=v.id and a.driver_id=d.id and a.is_active and a.unassigned_at is null))
 and private.driver_active_job_count(d.id)=0 order by 2,1
$$;
create function public.admin_assign_job(p_job uuid,p_driver uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if length(btrim(coalesce(p_reason,'')))<3 then raise exception 'A reason is required'; end if;
 perform 1 from public.jobs where id=p_job for update;
 perform 1 from public.drivers where id=p_driver for update;
 if not exists(select from public.admin_job_candidates(p_job) where id=p_driver) then raise exception 'Driver unavailable or assignment not permitted';end if;
 perform public.job_assign_driver(p_job,p_driver);
 update public.job_offers set response='auto_reassigned',responded_at=now(),decline_reason='Assigned by dispatch'
 where (job_id=p_job or driver_id=p_driver) and response='pending';
 perform private.audit_admin_change('admin_override','jobs',p_job,null,jsonb_build_object('driver_id',p_driver,'reason',p_reason));
end $$;

create function public.admin_update_job(p_job uuid,p_reason text,p_amount numeric default null) returns void
language plpgsql security definer set search_path='' as $$
declare j public.jobs; country uuid; cap numeric;
begin
 select * into strict j from public.jobs where id=p_job for update;
 select country_id into strict country from public.cities where id=j.city_id;
 if not coalesce(private.staff_scope(case when p_amount is null then 'manage_dispatch' else 'adjust_pricing' end,country,j.city_id),false) then raise insufficient_privilege;end if;
 if length(trim(coalesce(p_reason,''))) not between 3 and 2000 then raise exception 'A reason of 3 to 2000 characters is required';end if;
 if p_amount is not null then
  select regulated_max_fare into cap from public.quotes where id=j.quote_id;
  if p_amount<=0 or p_amount<>round(p_amount,2) or p_amount>cap then raise exception 'Invalid fare or tariff ceiling exceeded'; end if;
  if j.payment_status<>'pending' or j.status in ('completed','cancelled','disputed') or exists(select from public.payments where job_id=j.id) then raise exception 'Fare is locked after charging or closure';end if;
  update public.jobs set final_amount=p_amount where id=j.id;
 end if;
 perform private.audit_admin_change(case when p_amount is null then 'admin_override' else 'pricing_changed' end,'jobs',j.id,
 jsonb_build_object('fare',j.final_amount),jsonb_build_object('fare',coalesce(p_amount,j.final_amount),'staff_note',p_reason));
end $$;
revoke all on function public.admin_job_candidates(uuid),public.admin_assign_job(uuid,uuid,text),public.admin_update_job(uuid,text,numeric) from public,anon;
grant execute on function public.admin_job_candidates(uuid),public.admin_assign_job(uuid,uuid,text),public.admin_update_job(uuid,text,numeric) to authenticated;

create or replace function public.job_payment_initiate(
  p_job_id uuid,
  p_provider_code text,
  p_amount numeric default null,
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_payment_method_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job      public.jobs%rowtype;
  v_quote    public.quotes%rowtype;
  v_provider public.payment_providers%rowtype;
  v_method   public.payment_methods%rowtype;
  v_existing uuid;
  v_payment  uuid;
  v_reference text;
begin
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or auth.uid() = v_job.customer_id) then
    raise exception 'only the job customer may initiate payment for job %', p_job_id
      using errcode = '42501';
  end if;

  if v_job.status not in ('delivered', 'completed') then
    raise exception 'job % is not payable in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  if v_job.payment_status <> 'pending' then
    raise exception 'job % is already %', p_job_id, v_job.payment_status
      using errcode = '23514';
  end if;

  select * into v_quote from public.quotes where id = v_job.quote_id;
  if not found then
    raise exception 'quote for job % not found', p_job_id using errcode = 'P0002';
  end if;

  if p_amount is not null and p_amount <> coalesce(v_job.final_amount, v_quote.total) then
    raise exception 'payment amount % does not match job fare %', p_amount, coalesce(v_job.final_amount, v_quote.total)
      using errcode = '23514';
  end if;

  select * into v_provider
    from public.payment_providers pp
   where pp.code = p_provider_code
     and pp.is_active
     and pp.country_id = (select c.country_id from public.cities c where c.id = v_job.city_id);

  if not found then
    raise exception 'payment provider % not found or inactive for this job country', p_provider_code
      using errcode = 'P0002';
  end if;

  if p_payment_method_id is not null then
    select * into v_method
      from public.payment_methods pm
     where pm.id = p_payment_method_id
       and pm.profile_id = v_job.customer_id
       and pm.provider_id = v_provider.id
       and pm.is_active;

    if not found then
      raise exception 'payment method % is not active or does not belong to the customer',
        p_payment_method_id
        using errcode = '42501';
    end if;
  end if;

  select p.id into v_existing
    from public.payments p
   where p.job_id = p_job_id
     and p.payment_type = 'charge'
     and p.metadata ->> 'idempotency_key' = p_idempotency_key
   order by p.created_at desc
   limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  v_reference := 'init:' || replace(gen_random_uuid()::text, '-', '');

  insert into public.payments (
    job_id, customer_id, provider_id, payment_method_id, amount, currency_code,
    provider_reference, provider_status, payment_type, metadata
  ) values (
    p_job_id, v_job.customer_id, v_provider.id, p_payment_method_id,
    coalesce(v_job.final_amount, v_quote.total), v_quote.currency_code,
    v_reference, 'pending', 'charge',
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'idempotency_key', p_idempotency_key,
      'provider_code', p_provider_code,
      'initiated_by', 'edge_function'
    )
  )
  returning id into v_payment;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id, 'note', v_job.customer_id,
    jsonb_build_object(
      'payment_id', v_payment,
      'provider_code', p_provider_code,
      'stage', 'payment_initiated'
    )
  );

  return v_payment;
end;
$$;
