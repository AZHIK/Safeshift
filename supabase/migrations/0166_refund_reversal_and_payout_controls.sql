-- Money-flow fixes and controls for the admin console.
--
-- 1. Refunds have a real lifecycle (processing → succeeded | failed).
--    public.payment_refund booked refunds as already paid out before the
--    provider was called, and the immutability triggers then rejected every
--    later update, so provider-backed refunds could not complete and failed
--    refunds left the driver clawed back. See section 1.
--
-- 2. Payouts can be held, released and retried.
--    New status 'on_hold' (with reason) blocks a payout from being sent until
--    released. A failed payout can be reset to 'pending' to try again.

-- ----------------------------------------------------------------------------
-- 1. Refund lifecycle
-- ----------------------------------------------------------------------------
--
-- payment_refund used to insert the refund as 'succeeded' (and its refund
-- payment as a terminal 'succeeded') before any provider call. The refund and
-- payment immutability triggers forbid every transition out of those states,
-- so payment-refund failed on its first update for every outcome, and refunds
-- started inside the database (job cancellation, job_refund) were recorded as
-- paid out although no provider was ever called.
--
-- Now: payment_refund records 'processing' (refund payment 'pending') and
-- reserves the wallet clawbacks. The refund then ends exactly once:
--   succeeded  private.finish_refund_success   (provider confirmed / admin)
--   failed     private.finish_refund_failure   (clawbacks returned, job and
--                                               ledger restored)

-- Same-status updates (e.g. recording the provider reference while still
-- processing) are allowed; status transitions are unchanged.
create or replace function private.enforce_refunds_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_new_core jsonb;
  v_old_core jsonb;
begin
  if tg_op = 'DELETE' then
    raise exception 'refunds are append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array[
    'status', 'completed_at', 'failure_reason', 'provider_reference', 'updated_at'
  ];
  v_old_core := to_jsonb(old) - array[
    'status', 'completed_at', 'failure_reason', 'provider_reference', 'updated_at'
  ];

  if v_new_core is distinct from v_old_core then
    raise exception 'refund financial terms are immutable'
      using errcode = '42501';
  end if;

  if not (
    (old.status = 'requested' and new.status in ('requested', 'processing', 'succeeded', 'failed'))
    or (old.status = 'processing' and new.status in ('processing', 'succeeded', 'failed'))
  ) then
    raise exception 'illegal refund status transition: % -> %', old.status, new.status
      using errcode = '23514';
  end if;

  return new;
end;
$$;

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
    v_original.currency_code, v_refund_ref, 'pending', v_payment_type,
    p_payment_id, null,
    jsonb_build_object('refund_type', p_refund_type, 'reason', p_reason)
  );

  insert into public.refunds (
    payment_id, refund_payment_id, job_id, reason, requested_by, amount,
    currency_code, status, refund_type, provider_reference, completed_at
  ) values (
    p_payment_id, v_refund_payment, v_original.job_id, p_reason,
    coalesce(auth.uid(), v_original.customer_id), p_refund_amount,
    v_original.currency_code, 'processing', p_refund_type, v_refund_ref, null
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
     set payment_status = case when v_payment_type = 'refund' then 'refunded'
                               else 'partially_refunded' end::public.payment_status
   where id = v_original.job_id;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    v_original.job_id, 'note', coalesce(auth.uid(), v_original.customer_id),
    jsonb_build_object(
      'refund_payment_id', v_refund_payment,
      'original_payment_id', p_payment_id,
      'amount', p_refund_amount,
      'refund_type', p_refund_type,
      'status', 'processing'
    )
  );

  return v_refund_payment;
end;
$$;


-- The commission ledger stays append-only. is_refunded may return to false
-- only inside private.finish_refund_failure (refund_reversal context), so a
-- refund that never paid out does not keep the driver's earnings out of
-- payout batches forever.
create or replace function private.enforce_commission_ledger_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_new_core jsonb;
  v_old_core jsonb;
  v_reversal boolean := coalesce(current_setting('safeshift.refund_reversal', true), '') = 'on';
begin
  if tg_op = 'DELETE' then
    raise exception 'commission_ledger is append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array['is_refunded', 'withholding_tax_amount'];
  v_old_core := to_jsonb(old) - array['is_refunded', 'withholding_tax_amount'];

  if v_new_core is distinct from v_old_core then
    raise exception 'commission ledger financial fields are immutable'
      using errcode = '42501';
  end if;

  if new.is_refunded is distinct from old.is_refunded
     and not (old.is_refunded = false and new.is_refunded = true)
     and not (v_reversal and old.is_refunded = true and new.is_refunded = false)
  then
    raise exception 'commission is_refunded can only move from false to true'
      using errcode = '23514';
  end if;

  if new.withholding_tax_amount is distinct from old.withholding_tax_amount
     and not (old.withholding_tax_amount = 0 and new.withholding_tax_amount >= 0)
  then
    raise exception 'withholding tax can only be set once from zero'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function private.finish_refund_success(p_refund_id uuid, p_provider_reference text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund public.refunds%rowtype;
  v_ref text := nullif(btrim(coalesce(p_provider_reference, '')), '');
begin
  select * into v_refund from public.refunds where id = p_refund_id for update;
  if not found then
    raise exception 'refund % not found', p_refund_id using errcode = 'P0002';
  end if;
  if v_refund.status = 'succeeded' then
    return;
  end if;
  if v_refund.status = 'failed' then
    raise exception 'refund % already failed and was reversed', p_refund_id using errcode = '23514';
  end if;

  update public.payments
     set provider_status = 'succeeded',
         provider_reference = coalesce(v_ref, provider_reference),
         completed_at = now()
   where id = v_refund.refund_payment_id and provider_status = 'pending';

  update public.refunds
     set status = 'succeeded',
         provider_reference = coalesce(v_ref, provider_reference),
         completed_at = now(),
         failure_reason = null
   where id = p_refund_id;
end;
$$;

create or replace function private.finish_refund_failure(p_refund_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund public.refunds%rowtype;
  v_tx record;
  v_other_active integer;
  v_reason text := coalesce(nullif(btrim(coalesce(p_reason, '')), ''), 'provider_refund_failed');
begin
  select * into v_refund from public.refunds where id = p_refund_id for update;
  if not found then
    raise exception 'refund % not found', p_refund_id using errcode = 'P0002';
  end if;
  if v_refund.status = 'failed' then
    return;  -- idempotent
  end if;
  if v_refund.status = 'succeeded' then
    raise exception 'refund % already succeeded and cannot be reversed', p_refund_id using errcode = '23514';
  end if;

  update public.refunds
     set status = 'failed', completed_at = null, failure_reason = v_reason
   where id = p_refund_id;

  update public.payments
     set provider_status = 'failed', completed_at = now()
   where id = v_refund.refund_payment_id and provider_status = 'pending';

  -- Return every clawback reserved against the refund payment.
  for v_tx in
    select w.profile_id, t.amount, t.currency_code
    from public.wallet_transactions t
    join public.wallets w on w.id = t.wallet_id
    where t.reference_type = 'payment'
      and t.reference_id = v_refund.refund_payment_id
      and t.transaction_type = 'refund'
  loop
    perform private.wallet_post(
      v_tx.profile_id, -v_tx.amount, v_tx.currency_code,
      'adjustment', 'refund', p_refund_id,
      'Refund failed: clawback returned', false, true
    );
  end loop;

  select count(*) into v_other_active
  from public.refunds
  where job_id = v_refund.job_id and id <> p_refund_id and status <> 'failed';

  if v_other_active = 0 then
    -- The ledger guard allows is_refunded true → false only during a reversal.
    perform set_config('safeshift.refund_reversal', 'on', true);
    update public.commission_ledger set is_refunded = false
     where job_id = v_refund.job_id and is_refunded;
    perform set_config('safeshift.refund_reversal', 'off', true);
    update public.jobs set payment_status = 'paid'
     where id = v_refund.job_id and payment_status in ('refunded', 'partially_refunded');
  end if;

  -- 'note', like payment_refund itself: job_events_type_check has no refund types.
  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    v_refund.job_id, 'note', auth.uid(),
    jsonb_build_object(
      'kind', 'refund_failed',
      'refund_id', p_refund_id,
      'refund_payment_id', v_refund.refund_payment_id,
      'amount', v_refund.amount,
      'reason', v_reason
    )
  );
end;
$$;

revoke all on function private.finish_refund_success(uuid, text) from public, anon, authenticated;
revoke all on function private.finish_refund_failure(uuid, text) from public, anon, authenticated;

-- Service-role entry points used by the payment-refund function.
create or replace function private.require_service()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (coalesce(auth.role(), '') = 'service_role'
          or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'service role required' using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.require_service() from public, anon, authenticated;

create or replace function public.complete_refund(p_refund_id uuid, p_provider_reference text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_service();
  perform private.finish_refund_success(p_refund_id, p_provider_reference);
end;
$$;

create or replace function public.reverse_failed_refund(p_refund_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_service();
  perform private.finish_refund_failure(p_refund_id, p_reason);
end;
$$;

revoke all on function public.complete_refund(uuid, text) from public, anon, authenticated;
revoke all on function public.reverse_failed_refund(uuid, text) from public, anon, authenticated;
grant execute on function public.complete_refund(uuid, text) to service_role;
grant execute on function public.reverse_failed_refund(uuid, text) to service_role;

-- Admin entry points for refunds no provider will settle on its own (for
-- example refunds started by a job cancellation, or paid out manually).
create or replace function public.admin_complete_refund(p_refund_id uuid, p_reference text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('process_refunds') then
    raise exception 'process_refunds permission required' using errcode = '42501';
  end if;
  if btrim(coalesce(p_reference, '')) = '' then
    raise exception 'enter the transfer reference that proves the refund was paid' using errcode = '22004';
  end if;
  perform private.finish_refund_success(p_refund_id, p_reference);
end;
$$;

create or replace function public.admin_fail_refund(p_refund_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('process_refunds') then
    raise exception 'process_refunds permission required' using errcode = '42501';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'a reason is required' using errcode = '22004';
  end if;
  perform private.finish_refund_failure(p_refund_id, p_reason);
end;
$$;

revoke all on function public.admin_complete_refund(uuid, text) from public, anon;
revoke all on function public.admin_fail_refund(uuid, text) from public, anon;
grant execute on function public.admin_complete_refund(uuid, text) to authenticated, service_role;
grant execute on function public.admin_fail_refund(uuid, text) to authenticated, service_role;

-- Refund history with requester names for the console (view_payments).
create or replace function public.admin_payment_refunds(p_payment_id uuid)
returns table (
  id uuid,
  amount numeric,
  currency_code char(3),
  refund_type text,
  status text,
  reason text,
  failure_reason text,
  provider_reference text,
  requested_by_name text,
  created_at timestamptz,
  completed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('view_payments') or public.has_permission('process_refunds')) then
    raise exception 'view_payments permission required' using errcode = '42501';
  end if;
  return query
    select r.id, r.amount, r.currency_code, r.refund_type, r.status, r.reason, r.failure_reason,
           r.provider_reference,
           coalesce(nullif(btrim(p.full_name), ''), p.display_name, 'Unknown'),
           r.created_at, r.completed_at
    from public.refunds r
    left join public.profiles p on p.id = r.requested_by
    where r.payment_id = p_payment_id
    order by r.created_at desc;
end;
$$;

revoke all on function public.admin_payment_refunds(uuid) from public, anon;
grant execute on function public.admin_payment_refunds(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Payout hold / release / retry
-- ----------------------------------------------------------------------------

alter table public.payouts drop constraint if exists payouts_status_check;
alter table public.payouts add constraint payouts_status_check
  check (status in ('pending', 'on_hold', 'processing', 'completed', 'failed', 'cancelled'));

alter table public.payouts
  add column if not exists hold_reason text,
  add column if not exists held_by uuid references public.profiles (id) on delete set null,
  add column if not exists held_at timestamptz;

-- Payouts stay append-only with a single list of legal status moves, now
-- including holds and retries:
--   pending    → processing | completed | failed | cancelled | on_hold
--   on_hold    → pending (release) | cancelled          never sent while held
--   processing → completed | failed | cancelled
--   failed     → pending (retry: the failed transfer moved no money)
create or replace function private.enforce_payouts_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_mutable constant text[] := array[
    'status', 'completed_at', 'failure_reason', 'provider_reference', 'updated_at',
    'hold_reason', 'held_by', 'held_at'
  ];
begin
  if tg_op = 'DELETE' then
    raise exception 'payouts are append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  if (to_jsonb(new) - v_mutable) is distinct from (to_jsonb(old) - v_mutable) then
    raise exception 'payout financial terms are immutable'
      using errcode = '42501';
  end if;

  if new.status is distinct from old.status and not (
    (old.status = 'pending' and new.status in ('processing', 'completed', 'failed', 'cancelled', 'on_hold'))
    or (old.status = 'on_hold' and new.status in ('pending', 'cancelled'))
    or (old.status = 'processing' and new.status in ('completed', 'failed', 'cancelled'))
    or (old.status = 'failed' and new.status = 'pending')
  ) then
    if old.status = 'on_hold' then
      raise exception 'payout % is on hold; release it before paying', old.id using errcode = '23514';
    end if;
    raise exception 'illegal payout status transition: % -> %', old.status, new.status
      using errcode = '23514';
  end if;

  return new;
end;
$$;

-- Superseded by the rules above.
drop trigger if exists trg_payouts_guard_hold on public.payouts;
drop function if exists private.guard_payout_hold();

create or replace function private.require_payout_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('process_payouts') then
    raise exception 'process_payouts permission required' using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.require_payout_admin() from public, anon, authenticated;

create or replace function public.admin_hold_payout(p_payout_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_payout_admin();
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'a reason is required to hold a payout' using errcode = '22004';
  end if;
  update public.payouts
     set status = 'on_hold', hold_reason = btrim(p_reason), held_by = auth.uid(), held_at = now()
   where id = p_payout_id and status = 'pending';
  if not found then
    raise exception 'only pending payouts can be held' using errcode = '23514';
  end if;
end;
$$;

create or replace function public.admin_release_payout(p_payout_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_payout_admin();
  update public.payouts
     set status = 'pending', hold_reason = null, held_by = null, held_at = null
   where id = p_payout_id and status = 'on_hold';
  if not found then
    raise exception 'only held payouts can be released' using errcode = '23514';
  end if;
end;
$$;

-- A failed transfer moved no money (payout-execute only marks a payout failed
-- when the provider did not accept it), so it is safe to send again.
create or replace function public.admin_retry_payout(p_payout_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_payout_admin();
  update public.payouts
     set status = 'pending', failure_reason = null, provider_reference = null
   where id = p_payout_id and status = 'failed';
  if not found then
    raise exception 'only failed payouts can be retried' using errcode = '23514';
  end if;
  update public.payout_batches b
     set status = 'processing', failure_reason = null
   where b.id = (select batch_id from public.payouts where id = p_payout_id)
     and b.status in ('failed', 'partial');
end;
$$;

revoke all on function public.admin_hold_payout(uuid, text) from public, anon;
revoke all on function public.admin_release_payout(uuid) from public, anon;
revoke all on function public.admin_retry_payout(uuid) from public, anon;
grant execute on function public.admin_hold_payout(uuid, text) to authenticated, service_role;
grant execute on function public.admin_release_payout(uuid) to authenticated, service_role;
grant execute on function public.admin_retry_payout(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Platform account
-- ----------------------------------------------------------------------------
--
-- Commission and refund clawbacks post to the platform wallet
-- (profile 00000000-0000-4000-8000-000000000000). Only seed.sql created that
-- profile, and seeds never run on hosted projects, so on a fresh hosted
-- database every refund failed on wallets_profile_id_fkey. It is platform
-- infrastructure, so it is guaranteed here.

do $$
declare
  v_platform constant uuid := '00000000-0000-4000-8000-000000000000';
  v_country uuid;
begin
  if not exists (select 1 from auth.users where id = v_platform) then
    insert into auth.users (
      instance_id, id, aud, role, email, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_platform, 'authenticated', 'authenticated',
      'platform@safeshift.local', now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"SafeShift Platform"}'::jsonb,
      '', '', '', '', '', '', '', ''
    );
  end if;

  select id into v_country from public.countries where btrim(iso_code) = 'TZ' limit 1;

  insert into public.profiles (
    id, primary_role, full_name, display_name, email, email_verified,
    default_country_id, is_active
  ) values (
    v_platform, 'admin', 'SafeShift Platform', 'SafeShift Platform',
    'platform@safeshift.local', true, v_country, true
  )
  on conflict (id) do nothing;
end $$;
