-- ============================================================================
-- SafeShift — Phase 5 / Migration 0090
-- Money helper functions.
--
-- Every SECURITY DEFINER function pins search_path = ''. Clients never write
-- the money tables directly; these functions are the only public mutation path.
-- Provider calls are intentionally stubbed with TODO comments until Phase 7.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Deterministic platform profile
-- ----------------------------------------------------------------------------
do $$
declare
  v_platform uuid := '00000000-0000-4000-8000-000000000000';
  v_tz       uuid;
begin
  select id into v_tz from public.countries where btrim(iso_code) = 'TZ' limit 1;

  if not exists (select 1 from auth.users where id = v_platform) then
    insert into auth.users (
      instance_id, id, aud, role, email, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data
    ) values (
      '00000000-0000-0000-0000-000000000000', v_platform,
      'authenticated', 'authenticated', 'platform@safeshift.local', now(),
      now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"SafeShift Platform","country_code":"TZ"}'::jsonb
    );
  end if;

  insert into public.profiles (
    id, primary_role, full_name, display_name, phone, email,
    phone_verified, email_verified, default_country_id, is_active,
    created_at, updated_at
  ) values (
    v_platform, 'admin', 'SafeShift Platform', 'SafeShift Platform',
    '+255700000000', 'platform@safeshift.local', true, true, v_tz, true,
    now(), now()
  )
  on conflict (id) do update
    set primary_role = 'admin',
        full_name = excluded.full_name,
        display_name = excluded.display_name,
        default_country_id = excluded.default_country_id,
        is_active = true,
        updated_at = now();
end $$;

-- ----------------------------------------------------------------------------
-- 1. Tax and commission resolution
-- ----------------------------------------------------------------------------
create or replace function public.resolve_tax_rate(
  p_country_id uuid,
  p_tax_type text,
  p_applies_to text,
  p_at_time timestamptz default now()
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select tr.rate
  from public.tax_rates tr
  where tr.country_id = p_country_id
    and tr.tax_type = p_tax_type
    and tr.applies_to = p_applies_to
    and tr.is_active
    and tr.effective_from <= p_at_time
    and (tr.effective_to is null or tr.effective_to > p_at_time)
  order by tr.effective_from desc, tr.id
  limit 1;
$$;

comment on function public.resolve_tax_rate(uuid, text, text, timestamptz) is
  'Returns the active tax rate for a country/type/applies_to at a point in time, or NULL when none is configured.';

revoke all on function public.resolve_tax_rate(uuid, text, text, timestamptz) from public;
revoke all on function public.resolve_tax_rate(uuid, text, text, timestamptz) from anon;
grant execute on function public.resolve_tax_rate(uuid, text, text, timestamptz) to authenticated, service_role;

create or replace function public.resolve_commission_rule(p_job_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  with info as (
    select
      j.id,
      j.driver_id,
      j.city_id,
      c.country_id,
      coalesce(
        d.current_fleet_id,
        (
          select fm.fleet_id
          from public.fleet_members fm
          where fm.driver_id = j.driver_id and fm.is_active
          order by fm.joined_at desc
          limit 1
        )
      ) as fleet_id,
      coalesce(
        (select v.vehicle_type_id from public.vehicles v where v.id = j.vehicle_id),
        qr.vehicle_type_id
      ) as vehicle_type_id
    from public.jobs j
    join public.cities c on c.id = j.city_id
    join public.quotes q on q.id = j.quote_id
    join public.quote_requests qr on qr.id = q.quote_request_id
    left join public.drivers d on d.id = j.driver_id
    where j.id = p_job_id
  )
  select cr.id
  from public.commission_rules cr
  cross join info
  where cr.is_active
    and cr.effective_from <= now()
    and (cr.effective_to is null or cr.effective_to > now())
    and (cr.country_id is null or cr.country_id = info.country_id)
    and (cr.city_id is null or cr.city_id = info.city_id)
    and (cr.vehicle_type_id is null or cr.vehicle_type_id = info.vehicle_type_id)
    and (cr.fleet_id is null or cr.fleet_id = info.fleet_id)
    and (cr.driver_id is null or cr.driver_id = info.driver_id)
  order by
    case
      when cr.driver_id is not null then 6
      when cr.fleet_id is not null then 5
      when cr.vehicle_type_id is not null then 4
      when cr.city_id is not null then 3
      when cr.country_id is not null then 2
      else 1
    end desc,
    cr.priority desc,
    cr.effective_from desc,
    cr.id
  limit 1;
$$;

comment on function public.resolve_commission_rule(uuid) is
  'Resolves the most specific commission rule: driver > fleet > vehicle type > city > country > global default, then priority.';

revoke all on function public.resolve_commission_rule(uuid) from public;
revoke all on function public.resolve_commission_rule(uuid) from anon;
grant execute on function public.resolve_commission_rule(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Wallet posting
-- ----------------------------------------------------------------------------
create or replace function private.wallet_post(
  p_profile_id uuid,
  p_signed_amount numeric,
  p_currency_code char(3),
  p_transaction_type text,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_description text default null,
  p_enforce_balance boolean default false,
  p_allow_negative boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wallet public.wallets%rowtype;
begin
  if p_profile_id is null or p_currency_code is null then
    raise exception 'profile and currency are required' using errcode = '22004';
  end if;

  if p_signed_amount is null or p_signed_amount = 0 then
    raise exception 'wallet amount must be non-zero' using errcode = '22023';
  end if;

  insert into public.wallets (profile_id, currency_code)
  values (p_profile_id, p_currency_code)
  on conflict (profile_id, currency_code) do nothing;

  select * into v_wallet
  from public.wallets
  where profile_id = p_profile_id
    and currency_code = p_currency_code
  for update;

  if not found then
    raise exception 'wallet for profile %/% not found', p_profile_id, p_currency_code
      using errcode = 'P0002';
  end if;

  if v_wallet.is_frozen and p_signed_amount < 0 then
    raise exception 'wallet % is frozen', v_wallet.id using errcode = '42501';
  end if;

  if p_enforce_balance
     and p_signed_amount < 0
     and not p_allow_negative
     and v_wallet.cached_balance + p_signed_amount < 0
  then
    raise exception 'insufficient wallet balance: cached %, debit %',
      v_wallet.cached_balance, abs(p_signed_amount)
      using errcode = '23514';
  end if;

  insert into public.wallet_transactions (
    wallet_id, transaction_type, amount, currency_code, balance_after,
    reference_type, reference_id, description, metadata, created_by
  ) values (
    v_wallet.id, p_transaction_type, p_signed_amount, p_currency_code, 0,
    p_reference_type, p_reference_id, p_description, '{}'::jsonb, auth.uid()
  );

  return v_wallet.id;
end;
$$;

comment on function private.wallet_post(uuid, numeric, char, text, text, uuid, text, boolean, boolean) is
  'Internal wallet posting primitive. The wallet_transactions insert trigger calculates balance_after and updates the cached balance under the wallet row lock.';

revoke all on function private.wallet_post(uuid, numeric, char, text, text, uuid, text, boolean, boolean) from public;
revoke all on function private.wallet_post(uuid, numeric, char, text, text, uuid, text, boolean, boolean) from anon;
revoke all on function private.wallet_post(uuid, numeric, char, text, text, uuid, text, boolean, boolean) from authenticated;

create or replace function public.wallet_credit(
  p_profile_id uuid,
  p_amount numeric,
  p_currency_code char(3),
  p_transaction_type text,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (
    private.is_service_context()
    or public.has_permission('manage_payments')
  ) then
    raise exception 'not authorised to credit wallets' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'credit amount must be > 0' using errcode = '22023';
  end if;

  return private.wallet_post(
    p_profile_id, p_amount, p_currency_code, p_transaction_type,
    p_reference_type, p_reference_id, p_description, false, false
  );
end;
$$;

comment on function public.wallet_credit(uuid, numeric, char, text, text, uuid, text) is
  'Credits a profile wallet and returns the wallet id. Restricted to service/manage_payments callers; the ledger id is BIGINT so the wallet id is the stable public UUID result.';

revoke all on function public.wallet_credit(uuid, numeric, char, text, text, uuid, text) from public;
revoke all on function public.wallet_credit(uuid, numeric, char, text, text, uuid, text) from anon;
grant execute on function public.wallet_credit(uuid, numeric, char, text, text, uuid, text) to authenticated, service_role;

create or replace function public.wallet_debit(
  p_profile_id uuid,
  p_amount numeric,
  p_currency_code char(3),
  p_transaction_type text,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_description text default null,
  p_allow_negative boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (
    private.is_service_context()
    or public.has_permission('manage_payments')
  ) then
    raise exception 'not authorised to debit wallets' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'debit amount must be > 0' using errcode = '22023';
  end if;

  return private.wallet_post(
    p_profile_id, -p_amount, p_currency_code, p_transaction_type,
    p_reference_type, p_reference_id, p_description, true, p_allow_negative
  );
end;
$$;

comment on function public.wallet_debit(uuid, numeric, char, text, text, uuid, text, boolean) is
  'Debits a profile wallet and returns the wallet id. Balance is enforced unless p_allow_negative or the caller is a trusted system function.';

revoke all on function public.wallet_debit(uuid, numeric, char, text, text, uuid, text, boolean) from public;
revoke all on function public.wallet_debit(uuid, numeric, char, text, text, uuid, text, boolean) from anon;
grant execute on function public.wallet_debit(uuid, numeric, char, text, text, uuid, text, boolean) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Commission and withholding
-- ----------------------------------------------------------------------------
create or replace function public.calculate_and_record_commission(p_job_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job              public.jobs%rowtype;
  v_quote            public.quotes%rowtype;
  v_driver           public.drivers%rowtype;
  v_fleet_id         uuid;
  v_fleet_override   numeric(5,2);
  v_rule_id          uuid;
  v_rule             public.commission_rules%rowtype;
  v_rule_found       boolean := false;
  v_use_fleet        boolean := false;
  v_base             numeric(14,2);
  v_commission       numeric(14,2) := 0;
  v_net              numeric(14,2);
  v_rate             numeric(14,4);
  v_ledger_id        uuid;
  v_existing         uuid;
begin
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('manage_commission')
    or auth.uid() = v_job.customer_id
    or auth.uid() = v_job.driver_id
  ) then
    raise exception 'not authorised to calculate commission for job %', p_job_id
      using errcode = '42501';
  end if;

  select cl.id into v_existing
  from public.commission_ledger cl
  where cl.job_id = p_job_id
  order by cl.calculated_at desc
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  if v_job.driver_id is null then
    raise exception 'job % has no driver for commission', p_job_id using errcode = '23514';
  end if;

  select * into v_driver from public.drivers where id = v_job.driver_id;
  select * into v_quote from public.quotes where id = v_job.quote_id;

  select coalesce(
    v_driver.current_fleet_id,
    (
      select fm.fleet_id from public.fleet_members fm
      where fm.driver_id = v_job.driver_id and fm.is_active
      order by fm.joined_at desc
      limit 1
    )
  ) into v_fleet_id;

  if v_fleet_id is not null then
    select f.commission_rate_override into v_fleet_override
    from public.fleets f where f.id = v_fleet_id;
  end if;

  v_rule_id := public.resolve_commission_rule(p_job_id);

  if v_rule_id is not null then
    select * into v_rule from public.commission_rules where id = v_rule_id;
    v_rule_found := found;
  end if;

  -- Driver-specific commission_rules always win. A fleet rule or the fleet
  -- column override wins over vehicle/city/country/default rules.
  if v_rule_found and (v_rule.driver_id is not null or v_rule.fleet_id is not null) then
    v_use_fleet := false;
  elsif v_fleet_override is not null then
    v_use_fleet := true;
    v_rule_found := false;
  elsif v_rule_found then
    v_use_fleet := false;
  else
    raise exception 'no commission rule configured for job %', p_job_id
      using errcode = 'P0002';
  end if;

  v_base := round(coalesce(v_job.final_amount, v_quote.total), 2);

  if v_use_fleet then
    v_rate := round(v_fleet_override / 100.0, 4);
    v_commission := round(v_base * v_fleet_override / 100.0, 2);
  elsif v_rule.commission_type = 'percentage' then
    v_rate := round(v_rule.commission_value / 100.0, 4);
    v_commission := round(v_base * v_rule.commission_value / 100.0, 2);
    v_commission := greatest(v_commission, v_rule.min_commission);
    if v_rule.max_commission is not null then
      v_commission := least(v_commission, v_rule.max_commission);
    end if;
  else
    v_rate := null;
    v_commission := greatest(v_rule.commission_value, v_rule.min_commission);
    if v_rule.max_commission is not null then
      v_commission := least(v_commission, v_rule.max_commission);
    end if;
  end if;

  v_commission := round(least(greatest(v_commission, 0), v_base), 2);
  v_net := round(greatest(v_base - v_commission, 0), 2);

  insert into public.commission_ledger (
    job_id, driver_id, rule_id, commission_amount, commission_rate,
    currency_code, driver_gross_earning, driver_net_earning,
    withholding_tax_amount, is_refunded, calculated_at
  ) values (
    p_job_id, v_job.driver_id,
    case when v_use_fleet then null else v_rule.id end,
    v_commission, v_rate, v_quote.currency_code, v_base, v_net,
    0, false, now()
  )
  returning id into v_ledger_id;

  return v_ledger_id;
end;
$$;

comment on function public.calculate_and_record_commission(uuid) is
  'Resolves driver > fleet > vehicle > city > country > default commission, applies min/max, records one immutable ledger row, and returns its UUID.';

revoke all on function public.calculate_and_record_commission(uuid) from public;
revoke all on function public.calculate_and_record_commission(uuid) from anon;
grant execute on function public.calculate_and_record_commission(uuid) to authenticated, service_role;

create or replace function public.apply_withholding_tax(p_job_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job        public.jobs%rowtype;
  v_ledger     public.commission_ledger%rowtype;
  v_country_id uuid;
  v_rate       numeric(6,4);
  v_tax        numeric(14,2);
begin
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('manage_taxes')
    or auth.uid() = v_job.customer_id
    or auth.uid() = v_job.driver_id
  ) then
    raise exception 'not authorised to apply withholding for job %', p_job_id
      using errcode = '42501';
  end if;

  select * into v_ledger
  from public.commission_ledger
  where job_id = p_job_id
  order by calculated_at desc
  limit 1;

  if not found then
    raise exception 'commission ledger missing for job %', p_job_id using errcode = 'P0002';
  end if;

  if v_ledger.withholding_tax_amount > 0 then
    return v_ledger.withholding_tax_amount;
  end if;

  select c.country_id into v_country_id
  from public.cities c where c.id = v_job.city_id;

  v_rate := coalesce(
    public.resolve_tax_rate(v_country_id, 'withholding', 'driver_payout', now()),
    0
  );

  v_tax := round(v_ledger.driver_net_earning * v_rate, 2);

  update public.commission_ledger
     set withholding_tax_amount = v_tax
   where id = v_ledger.id
     and withholding_tax_amount = 0;

  return v_tax;
end;
$$;

comment on function public.apply_withholding_tax(uuid) is
  'Applies the country withholding rate to the driver net earning and stores it separately on the commission ledger.';

revoke all on function public.apply_withholding_tax(uuid) from public;
revoke all on function public.apply_withholding_tax(uuid) from anon;
grant execute on function public.apply_withholding_tax(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Payment capture and refunds
-- ----------------------------------------------------------------------------
create or replace function public.job_pay(
  p_job_id uuid,
  p_payment_method_id uuid,
  p_provider_id uuid,
  p_provider_reference text,
  p_idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_platform uuid := '00000000-0000-4000-8000-000000000000';
  v_job      public.jobs%rowtype;
  v_quote    public.quotes%rowtype;
  v_provider public.payment_providers%rowtype;
  v_method   public.payment_methods%rowtype;
  v_existing uuid;
  v_payment  uuid;
  v_ledger   public.commission_ledger%rowtype;
  v_tax      numeric(14,2);
begin
  if p_provider_reference is null or btrim(p_provider_reference) = '' then
    raise exception 'provider_reference is required for idempotent capture'
      using errcode = '22004';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or auth.uid() = v_job.customer_id) then
    raise exception 'only the job customer may pay for job %', p_job_id
      using errcode = '42501';
  end if;

  select p.id into v_existing
  from public.payments p
  where p.provider_reference = p_provider_reference;

  if v_existing is not null then
    if (select job_id from public.payments where id = v_existing) <> p_job_id then
      raise exception 'provider_reference % belongs to another job', p_provider_reference
        using errcode = '23505';
    end if;
    return v_existing;
  end if;

  if p_idempotency_key is not null then
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
  end if;

  if v_job.status not in ('delivered', 'completed') then
    raise exception 'job % is not payable in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  if v_job.payment_status <> 'pending' then
    raise exception 'job % is already %', p_job_id, v_job.payment_status
      using errcode = '23514';
  end if;

  select * into v_provider
  from public.payment_providers
  where id = p_provider_id and is_active;

  if not found then
    raise exception 'payment provider % not found or inactive', p_provider_id
      using errcode = 'P0002';
  end if;

  if v_provider.country_id <> (select c.country_id from public.cities c where c.id = v_job.city_id) then
    raise exception 'provider % is not configured for this job country', p_provider_id
      using errcode = '23514';
  end if;

  select * into v_method
  from public.payment_methods
  where id = p_payment_method_id
    and profile_id = v_job.customer_id
    and provider_id = p_provider_id
    and is_active;

  if not found then
    raise exception 'payment method % is not an active method for this customer/provider',
      p_payment_method_id using errcode = 'P0002';
  end if;

  select * into v_quote from public.quotes where id = v_job.quote_id;

  insert into public.payments (
    job_id, customer_id, payment_method_id, provider_id, amount,
    currency_code, provider_reference, provider_status, payment_type,
    completed_at, metadata
  ) values (
    p_job_id, v_job.customer_id, p_payment_method_id, p_provider_id,
    v_quote.total, v_quote.currency_code, p_provider_reference,
    'succeeded', 'charge', now(),
    jsonb_build_object('idempotency_key', p_idempotency_key, 'captured_by', 'job_pay')
  )
  returning id into v_payment;

  if v_quote.promo_code_id is not null
     and not exists (
       select 1 from public.promo_redemptions pr where pr.job_id = p_job_id
     )
  then
    insert into public.promo_redemptions (
      promo_code_id, profile_id, job_id, discount_amount, currency_code,
      redeemed_at, created_at
    ) values (
      v_quote.promo_code_id, v_job.customer_id, p_job_id,
      v_quote.promo_discount, v_quote.currency_code, now(), now()
    );
  end if;

  update public.jobs
     set payment_status = 'paid',
         final_amount = v_quote.total,
         final_currency_code = v_quote.currency_code,
         payment_method = v_method.method_type
   where id = p_job_id;

  perform public.calculate_and_record_commission(p_job_id);
  v_tax := public.apply_withholding_tax(p_job_id);

  select * into v_ledger
  from public.commission_ledger
  where job_id = p_job_id
  order by calculated_at desc
  limit 1;

  perform private.wallet_post(
    v_job.customer_id, -v_quote.total, v_quote.currency_code,
    'payment', 'job', p_job_id, 'Customer payment for job', false, true
  );

  if v_ledger.driver_net_earning > 0 then
    perform private.wallet_post(
      v_ledger.driver_id, v_ledger.driver_net_earning, v_quote.currency_code,
      'driver_earning', 'job', p_job_id, 'Driver earning for job', false, false
    );
  end if;

  if v_ledger.commission_amount > 0 then
    perform private.wallet_post(
      v_platform, v_ledger.commission_amount, v_quote.currency_code,
      'commission_deduction', 'job', p_job_id, 'Platform commission', false, false
    );
  end if;

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, null, v_job.status, coalesce(auth.uid(), v_job.customer_id),
    'Payment captured'
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id, 'note', coalesce(auth.uid(), v_job.customer_id),
    jsonb_build_object(
      'payment_id', v_payment,
      'provider_reference', p_provider_reference,
      'amount', v_quote.total,
      'currency_code', v_quote.currency_code,
      'commission_amount', v_ledger.commission_amount,
      'withholding_tax_amount', v_tax
    )
  );

  return v_payment;
end;
$$;

comment on function public.job_pay(uuid, uuid, uuid, text, text) is
  'Captures a charge idempotently, records commission/withholding, posts customer/driver/platform wallet entries, links the promo redemption and marks the job paid. Provider capture is a Phase 7 stub.';

revoke all on function public.job_pay(uuid, uuid, uuid, text, text) from public;
revoke all on function public.job_pay(uuid, uuid, uuid, text, text) from anon;
grant execute on function public.job_pay(uuid, uuid, uuid, text, text) to authenticated, service_role;

create or replace function public.payment_refund(
  p_payment_id uuid,
  p_refund_amount numeric,
  p_refund_type text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_internal       boolean := coalesce(current_setting('safeshift.refund_context', true), '') = 'on';
  v_original       public.payments%rowtype;
  v_provider       public.payment_providers%rowtype;
  v_already        numeric(14,2);
  v_available      numeric(14,2);
  v_refund_payment uuid := gen_random_uuid();
  v_refund_ref     text;
  v_ledger         public.commission_ledger%rowtype;
  v_ratio          numeric;
  v_driver_debit   numeric(14,2);
  v_platform_debit numeric(14,2);
  v_payment_type   text;
begin
  if not (
    private.is_service_context()
    or v_internal
    or public.has_permission('process_refunds')
  ) then
    raise exception 'process_refunds permission required' using errcode = '42501';
  end if;

  if p_refund_amount is null or p_refund_amount <= 0 then
    raise exception 'refund amount must be > 0' using errcode = '22023';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'refund reason is required' using errcode = '22023';
  end if;

  select * into v_original
  from public.payments
  where id = p_payment_id
  for update;

  if not found then
    raise exception 'payment % not found', p_payment_id using errcode = 'P0002';
  end if;

  if v_original.payment_type <> 'charge' or v_original.provider_status <> 'succeeded' then
    raise exception 'payment % is not a succeeded charge', p_payment_id
      using errcode = '23514';
  end if;

  select * into v_provider
  from public.payment_providers
  where id = v_original.provider_id;

  select coalesce(sum(r.amount), 0) into v_already
  from public.refunds r
  where r.payment_id = p_payment_id
    and r.status <> 'failed';

  v_available := round(v_original.amount - v_already, 2);

  if p_refund_amount > v_available then
    raise exception 'refund % exceeds available %', p_refund_amount, v_available
      using errcode = '23514';
  end if;

  if not v_provider.supports_refunds then
    raise exception 'provider % does not support refunds', v_provider.code
      using errcode = '23514';
  end if;

  if p_refund_amount < v_available and not v_provider.supports_partial_refunds then
    raise exception 'provider % does not support partial refunds', v_provider.code
      using errcode = '23514';
  end if;

  v_payment_type := case
    when p_refund_type = 'full' or p_refund_amount = v_available then 'refund'
    else 'partial_refund'
  end;

  v_refund_ref := 'refund:' || coalesce(v_original.provider_reference, p_payment_id::text)
                  || ':' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  insert into public.payments (
    id, job_id, customer_id, payment_method_id, provider_id, amount,
    currency_code, provider_reference, provider_status, payment_type,
    refund_of_payment_id, completed_at, metadata
  ) values (
    v_refund_payment, v_original.job_id, v_original.customer_id,
    v_original.payment_method_id, v_original.provider_id, p_refund_amount,
    v_original.currency_code, v_refund_ref, 'succeeded', v_payment_type,
    p_payment_id, now(),
    jsonb_build_object('refund_type', p_refund_type, 'reason', p_reason)
  );

  insert into public.refunds (
    payment_id, refund_payment_id, job_id, reason, requested_by, amount,
    currency_code, status, refund_type, provider_reference, completed_at
  ) values (
    p_payment_id, v_refund_payment, v_original.job_id, p_reason,
    coalesce(auth.uid(), v_original.customer_id), p_refund_amount,
    v_original.currency_code, 'succeeded', p_refund_type, v_refund_ref, now()
  );

  select * into v_ledger
  from public.commission_ledger
  where job_id = v_original.job_id
  order by calculated_at desc
  limit 1;

  if found then
    v_ratio := least(greatest(p_refund_amount / v_original.amount, 0), 1);
    v_driver_debit := round(v_ledger.driver_net_earning * v_ratio, 2);
    v_platform_debit := round(v_ledger.commission_amount * v_ratio, 2);

    if v_driver_debit > 0 then
      perform private.wallet_post(
        v_ledger.driver_id, -v_driver_debit, v_original.currency_code,
        'refund', 'payment', v_refund_payment, 'Driver refund clawback', false, true
      );
    end if;

    if v_platform_debit > 0 then
      perform private.wallet_post(
        '00000000-0000-4000-8000-000000000000',
        -v_platform_debit, v_original.currency_code,
        'refund', 'payment', v_refund_payment, 'Platform commission refund clawback', false, true
      );
    end if;

    update public.commission_ledger
       set is_refunded = true
     where id = v_ledger.id
       and is_refunded = false;
  end if;

  update public.jobs
     set payment_status = 'refunded'
   where id = v_original.job_id;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    v_original.job_id, 'note', coalesce(auth.uid(), v_original.customer_id),
    jsonb_build_object(
      'refund_payment_id', v_refund_payment,
      'original_payment_id', p_payment_id,
      'amount', p_refund_amount,
      'refund_type', p_refund_type,
      'status', 'succeeded'
    )
  );

  return v_refund_payment;
end;
$$;

comment on function public.payment_refund(uuid, numeric, text, text) is
  'Creates a refund payment and refund record, claws back driver/platform wallet entries proportionally, marks the commission ledger refunded and marks the job refunded. Provider call is a Phase 7 stub.';

revoke all on function public.payment_refund(uuid, numeric, text, text) from public;
revoke all on function public.payment_refund(uuid, numeric, text, text) from anon;
grant execute on function public.payment_refund(uuid, numeric, text, text) to authenticated, service_role;

create or replace function public.job_refund(
  p_job_id uuid,
  p_refund_amount numeric,
  p_refund_type text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job      public.jobs%rowtype;
  v_payment  public.payments%rowtype;
  v_refund   uuid;
begin
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('process_refunds')
    or auth.uid() = v_job.customer_id
  ) then
    raise exception 'not authorised to refund job %', p_job_id using errcode = '42501';
  end if;

  select * into v_payment
  from public.payments
  where job_id = p_job_id
    and payment_type = 'charge'
    and provider_status = 'succeeded'
  order by completed_at desc nulls last, created_at desc
  limit 1;

  if not found then
    raise exception 'no succeeded charge for job %', p_job_id using errcode = 'P0002';
  end if;

  begin
    perform set_config('safeshift.refund_context', 'on', true);
    v_refund := public.payment_refund(
      v_payment.id, p_refund_amount, p_refund_type, p_reason
    );
    perform set_config('safeshift.refund_context', 'off', true);
  exception when others then
    perform set_config('safeshift.refund_context', 'off', true);
    raise;
  end;

  return v_refund;
end;
$$;

comment on function public.job_refund(uuid, numeric, text, text) is
  'Finds the latest succeeded charge for a job and delegates to payment_refund() with an internal-refund context.';

revoke all on function public.job_refund(uuid, numeric, text, text) from public;
revoke all on function public.job_refund(uuid, numeric, text, text) from anon;
grant execute on function public.job_refund(uuid, numeric, text, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Payout batches and execution
-- ----------------------------------------------------------------------------
create or replace function public.create_payout_batch(
  p_country_id uuid,
  p_period_start timestamptz,
  p_period_end timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing     uuid;
  v_batch        uuid;
  v_currency     char(3);
  v_total        numeric(14,2);
  v_count        integer;
  v_driver       record;
  v_payout       uuid;
  v_provider     uuid;
  v_method       uuid;
begin
  if not (
    private.is_service_context()
    or public.has_permission('process_payouts')
  ) then
    raise exception 'process_payouts permission required' using errcode = '42501';
  end if;

  if p_country_id is null or p_period_start is null or p_period_end is null
     or p_period_end <= p_period_start then
    raise exception 'valid country and period are required' using errcode = '22023';
  end if;

  select pb.id into v_existing
  from public.payout_batches pb
  where pb.country_id = p_country_id
    and pb.period_start = p_period_start
    and pb.period_end = p_period_end;

  if v_existing is not null then
    return v_existing;
  end if;

  select cur.code into v_currency
  from public.countries c
  join public.currencies cur on cur.id = c.default_currency_id
  where c.id = p_country_id;

  if v_currency is null then
    raise exception 'country % has no default currency', p_country_id
      using errcode = 'P0002';
  end if;

  select coalesce(sum(x.net_amount), 0), count(*)
    into v_total, v_count
  from (
    select
      cl.driver_id,
      sum(cl.driver_net_earning - cl.withholding_tax_amount) as net_amount
    from public.commission_ledger cl
    join public.jobs j on j.id = cl.job_id
    join public.cities c on c.id = j.city_id
    left join public.payout_items pi on pi.commission_ledger_id = cl.id
    where j.status = 'completed'
      and j.completed_at >= p_period_start
      and j.completed_at < p_period_end
      and c.country_id = p_country_id
      and cl.is_refunded = false
      and pi.id is null
    group by cl.driver_id
    having sum(cl.driver_net_earning - cl.withholding_tax_amount) > 0
  ) x;

  insert into public.payout_batches (
    country_id, period_start, period_end, status, total_amount,
    currency_code, driver_count, initiated_by
  ) values (
    p_country_id, p_period_start, p_period_end, 'draft', v_total,
    v_currency, v_count, auth.uid()
  )
  returning id into v_batch;

  for v_driver in
    select
      cl.driver_id,
      sum(cl.driver_gross_earning) as gross_earnings,
      sum(cl.commission_amount) as commission_deducted,
      sum(cl.withholding_tax_amount) as withholding_tax,
      sum(cl.driver_net_earning - cl.withholding_tax_amount) as net_amount
    from public.commission_ledger cl
    join public.jobs j on j.id = cl.job_id
    join public.cities c on c.id = j.city_id
    left join public.payout_items pi on pi.commission_ledger_id = cl.id
    where j.status = 'completed'
      and j.completed_at >= p_period_start
      and j.completed_at < p_period_end
      and c.country_id = p_country_id
      and cl.is_refunded = false
      and pi.id is null
    group by cl.driver_id
    having sum(cl.driver_net_earning - cl.withholding_tax_amount) > 0
  loop
    v_provider := null;
    v_method := null;

    select pm.provider_id, pm.id
      into v_provider, v_method
    from public.payment_methods pm
    join public.payment_providers pp on pp.id = pm.provider_id
    where pm.profile_id = v_driver.driver_id
      and pm.is_active
      and pp.is_active
      and pp.supports_payouts
    order by pm.is_default desc, pm.last_used_at desc nulls last, pm.created_at
    limit 1;

    insert into public.payouts (
      batch_id, driver_id, period_start, period_end, amount, currency_code,
      gross_earnings, commission_deducted, withholding_tax, net_amount,
      payment_provider_id, payment_method_id, status
    ) values (
      v_batch, v_driver.driver_id, p_period_start, p_period_end,
      round(v_driver.net_amount, 2), v_currency,
      round(v_driver.gross_earnings, 2),
      round(v_driver.commission_deducted, 2),
      round(v_driver.withholding_tax, 2),
      round(v_driver.net_amount, 2),
      v_provider, v_method, 'pending'
    )
    returning id into v_payout;

    insert into public.payout_items (
      payout_id, commission_ledger_id, commission_calculated_at, job_id, amount
    )
    select
      v_payout, cl.id, cl.calculated_at, cl.job_id,
      round(cl.driver_net_earning - cl.withholding_tax_amount, 2)
    from public.commission_ledger cl
    join public.jobs j on j.id = cl.job_id
    join public.cities c on c.id = j.city_id
    left join public.payout_items pi on pi.commission_ledger_id = cl.id
    where cl.driver_id = v_driver.driver_id
      and j.status = 'completed'
      and j.completed_at >= p_period_start
      and j.completed_at < p_period_end
      and c.country_id = p_country_id
      and cl.is_refunded = false
      and pi.id is null
      and cl.driver_net_earning - cl.withholding_tax_amount > 0;
  end loop;

  return v_batch;
end;
$$;

comment on function public.create_payout_batch(uuid, timestamptz, timestamptz) is
  'Aggregates completed, unrefunded, previously unpaid commission-ledger entries into one batch and one payout per driver, with per-job payout items.';

revoke all on function public.create_payout_batch(uuid, timestamptz, timestamptz) from public;
revoke all on function public.create_payout_batch(uuid, timestamptz, timestamptz) from anon;
grant execute on function public.create_payout_batch(uuid, timestamptz, timestamptz) to authenticated, service_role;

create or replace function public.execute_payout(p_payout_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payout public.payouts%rowtype;
  v_remaining integer;
  v_failed integer;
  v_action public.audit_action := 'payout_changed';
  v_role public.user_role;
begin
  if not (
    private.is_service_context()
    or public.has_permission('process_payouts')
  ) then
    raise exception 'process_payouts permission required' using errcode = '42501';
  end if;

  select * into v_payout from public.payouts where id = p_payout_id for update;
  if not found then
    raise exception 'payout % not found', p_payout_id using errcode = 'P0002';
  end if;

  if v_payout.status = 'completed' then
    return p_payout_id;
  end if;

  if v_payout.status in ('failed', 'cancelled') then
    raise exception 'payout % is %', p_payout_id, v_payout.status using errcode = '23514';
  end if;

  -- TODO Phase 7: call the real payout provider SDK here. Phase 5 records the
  -- state transition and wallet movement only.
  update public.payouts
     set status = 'completed',
         completed_at = now(),
         provider_reference = coalesce(provider_reference, 'payout:' || p_payout_id::text)
   where id = p_payout_id;

  perform private.wallet_post(
    v_payout.driver_id, -v_payout.net_amount, v_payout.currency_code,
    'payout', 'payout', p_payout_id, 'Driver payout', false, true
  );

  update public.payout_batches pb
     set status = case
           when exists (
             select 1 from public.payouts p
             where p.batch_id = pb.id and p.status in ('failed', 'cancelled')
           ) then 'partial'
           else 'completed'
         end,
         completed_at = now()
   where pb.id = v_payout.batch_id
     and not exists (
       select 1 from public.payouts p
       where p.batch_id = pb.id and p.status in ('pending', 'processing')
     );

  select primary_role into v_role from public.profiles where id = auth.uid();

  insert into private.audit_log (
    actor_id, actor_role, action, entity_type, entity_id,
    old_value, new_value, created_at
  ) values (
    auth.uid(), v_role, v_action, 'payouts', p_payout_id,
    jsonb_build_object('status', v_payout.status),
    jsonb_build_object('status', 'completed', 'net_amount', v_payout.net_amount),
    now()
  );

  return p_payout_id;
end;
$$;

comment on function public.execute_payout(uuid) is
  'Marks a payout completed, debits the driver wallet, closes the batch when no pending payouts remain, and writes an audit entry. Provider SDK call is a Phase 7 TODO.';

revoke all on function public.execute_payout(uuid) from public;
revoke all on function public.execute_payout(uuid) from anon;
grant execute on function public.execute_payout(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Invoices
-- ----------------------------------------------------------------------------
create or replace function public.generate_invoice(
  p_business_account_id uuid,
  p_period_start timestamptz,
  p_period_end timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account  public.business_accounts%rowtype;
  v_currency char(3);
  v_invoice  uuid;
  v_subtotal numeric(14,2);
  v_tax      numeric(14,2);
  v_total    numeric(14,2);
  v_number   text;
begin
  if not (
    private.is_service_context()
    or public.has_permission('manage_invoices')
  ) then
    raise exception 'manage_invoices permission required' using errcode = '42501';
  end if;

  if p_period_end <= p_period_start then
    raise exception 'invalid invoice period' using errcode = '22023';
  end if;

  select * into v_account
  from public.business_accounts
  where id = p_business_account_id and is_active;

  if not found then
    raise exception 'business account % not found or inactive', p_business_account_id
      using errcode = 'P0002';
  end if;

  select cur.code into v_currency
  from public.currencies cur
  where cur.id = (select default_currency_id from public.countries where id = v_account.country_id);

  if v_currency is null then
    raise exception 'business account country has no default currency'
      using errcode = 'P0002';
  end if;

  select
    coalesce(sum(q.subtotal), 0),
    coalesce(sum(q.vat), 0),
    coalesce(sum(q.total), 0)
  into v_subtotal, v_tax, v_total
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.business_members bm
    on bm.profile_id = j.customer_id
   and bm.business_account_id = p_business_account_id
   and bm.accepted_at is not null
  where j.status = 'completed'
    and j.completed_at >= p_period_start
    and j.completed_at < p_period_end;

  v_number := 'INV-' || to_char(p_period_start, 'YYYYMM') || '-'
              || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.invoices (
    business_account_id, invoice_number, currency_code,
    period_start, period_end, subtotal, tax_amount, total, amount_paid,
    status, issued_at, due_at
  ) values (
    p_business_account_id, v_number, v_currency,
    p_period_start, p_period_end, v_subtotal, v_tax, v_total, 0,
    'draft', now(), now() + make_interval(days => v_account.payment_terms_days)
  )
  returning id into v_invoice;

  insert into public.invoice_line_items (
    invoice_id, description, quantity, unit_price, amount, job_id
  )
  select
    v_invoice,
    'Transport job ' || j.id::text,
    1,
    round(q.subtotal, 2),
    round(q.subtotal, 2),
    j.id
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.business_members bm
    on bm.profile_id = j.customer_id
   and bm.business_account_id = p_business_account_id
   and bm.accepted_at is not null
  where j.status = 'completed'
    and j.completed_at >= p_period_start
    and j.completed_at < p_period_end;

  return v_invoice;
end;
$$;

comment on function public.generate_invoice(uuid, timestamptz, timestamptz) is
  'Builds a draft invoice and line items from completed jobs of accepted business-account members in the period.';

revoke all on function public.generate_invoice(uuid, timestamptz, timestamptz) from public;
revoke all on function public.generate_invoice(uuid, timestamptz, timestamptz) from anon;
grant execute on function public.generate_invoice(uuid, timestamptz, timestamptz) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Nightly maintenance helpers
-- ----------------------------------------------------------------------------
create or replace function public.recompute_all_driver_acceptance_stats()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver uuid;
  v_count  integer := 0;
begin
  if not private.is_service_context() then
    raise exception 'service context required' using errcode = '42501';
  end if;

  for v_driver in select id from public.drivers loop
    perform private.refresh_driver_acceptance_stats(v_driver);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

comment on function public.recompute_all_driver_acceptance_stats() is
  'Nightly pg_cron job: recomputes the rolling 30-day acceptance statistics for every driver.';

revoke all on function public.recompute_all_driver_acceptance_stats() from public;
revoke all on function public.recompute_all_driver_acceptance_stats() from anon;
revoke all on function public.recompute_all_driver_acceptance_stats() from authenticated;
grant execute on function public.recompute_all_driver_acceptance_stats() to service_role;

create or replace function public.verify_all_wallet_balances()
returns table (
  wallet_id uuid,
  cached numeric,
  computed numeric,
  matches boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    w.id,
    w.cached_balance,
    coalesce(sum(wt.amount), 0)::numeric(14,2),
    w.cached_balance = coalesce(sum(wt.amount), 0)::numeric(14,2)
  from public.wallets w
  left join public.wallet_transactions wt on wt.wallet_id = w.id
  group by w.id, w.cached_balance;
$$;

comment on function public.verify_all_wallet_balances() is
  'Compares every cached wallet balance with the sum of its ledger rows. Returns one row per wallet.';

revoke all on function public.verify_all_wallet_balances() from public;
revoke all on function public.verify_all_wallet_balances() from anon;
revoke all on function public.verify_all_wallet_balances() from authenticated;
grant execute on function public.verify_all_wallet_balances() to service_role;

create or replace function public.wallet_balance_verify()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   record;
  v_count integer := 0;
begin
  if not private.is_service_context() then
    raise exception 'service context required' using errcode = '42501';
  end if;

  for v_row in
    select * from public.verify_all_wallet_balances() where matches = false
  loop
    raise warning 'Wallet drift: % cached=% computed=%',
      v_row.wallet_id, v_row.cached, v_row.computed;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

comment on function public.wallet_balance_verify() is
  'Nightly pg_cron job: raises a warning for every wallet whose cache drifts from its ledger sum.';

revoke all on function public.wallet_balance_verify() from public;
revoke all on function public.wallet_balance_verify() from anon;
revoke all on function public.wallet_balance_verify() from authenticated;
grant execute on function public.wallet_balance_verify() to service_role;

create or replace function public.quote_cleanup()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not private.is_service_context() then
    raise exception 'service context required' using errcode = '42501';
  end if;

  perform set_config('safeshift.quote_cleanup', 'on', true);

  delete from public.quotes q
  where q.expires_at < now()
    and not exists (select 1 from public.jobs j where j.quote_id = q.id);

  get diagnostics v_count = row_count;

  perform set_config('safeshift.quote_cleanup', 'off', true);
  return v_count;
end;
$$;

comment on function public.quote_cleanup() is
  'Deletes expired, unconverted quotes. The Phase 4 append-only trigger permits this one service-only cleanup context.';

revoke all on function public.quote_cleanup() from public;
revoke all on function public.quote_cleanup() from anon;
revoke all on function public.quote_cleanup() from authenticated;
grant execute on function public.quote_cleanup() to service_role;
