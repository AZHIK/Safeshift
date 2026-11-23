-- Verifies 0166_refund_reversal_and_payout_controls.sql against real data.
--
-- Needs one active super_admin and one completed job with a driver. Every
-- change is made inside a transaction that is always rolled back.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-money-controls.sql

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (owner): commission for a completed job and a succeeded charge.
-- ---------------------------------------------------------------------------
create temporary table t_balance (profile_id uuid primary key, before numeric) on commit drop;

do $$
declare
  v_admin uuid;
  v_job public.jobs%rowtype;
  v_provider uuid;
  v_payment uuid := gen_random_uuid();
begin
  select profile_id into v_admin from public.admin_roles
  where role_name = 'super_admin' and is_active and revoked_at is null limit 1;
  select * into v_job from public.jobs
  where status = 'completed' and driver_id is not null and final_amount > 0
    and not exists (select 1 from public.commission_ledger l where l.job_id = jobs.id)
  limit 1;
  select id into v_provider from public.payment_providers where code = 'selcom';
  if v_admin is null or v_job.id is null or v_provider is null then
    raise exception 'FIXTURE: need a super_admin, an uncommissioned completed job and the selcom provider';
  end if;

  perform public.calculate_and_record_commission(v_job.id);

  insert into public.payments (
    id, job_id, customer_id, provider_id, amount, currency_code,
    provider_reference, provider_status, payment_type, completed_at
  ) values (
    v_payment, v_job.id, v_job.customer_id, v_provider, v_job.final_amount, v_job.final_currency_code,
    'TEST-' || substr(v_payment::text, 1, 8), 'succeeded', 'charge', now()
  );
  update public.jobs set payment_status = 'paid' where id = v_job.id;

  insert into t_balance
  select p, coalesce((select sum(w.cached_balance) from public.wallets w where w.profile_id = p), 0)
  from unnest(array[v_job.driver_id, '00000000-0000-4000-8000-000000000000'::uuid]) p;

  perform set_config('t.admin', v_admin::text, true);
  perform set_config('t.job', v_job.id::text, true);
  perform set_config('t.driver', v_job.driver_id::text, true);
  perform set_config('t.payment', v_payment::text, true);
  perform set_config('t.currency', v_job.final_currency_code, true);
end $$;

-- ---------------------------------------------------------------------------
-- A. Refund as the admin, then reverse it as the provider-failure path does.
-- ---------------------------------------------------------------------------
set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated')::text, true);

do $$
begin
  perform set_config('t.refund_payment',
    public.payment_refund(current_setting('t.payment')::uuid, 20000, 'partial', 'verify-money-controls')::text, true);
end $$;

reset role;

do $$
declare
  v_driver_after numeric;
  v_refund uuid;
begin
  select coalesce(sum(cached_balance), 0) into v_driver_after
  from public.wallets where profile_id = current_setting('t.driver')::uuid;
  if v_driver_after >= (select before from t_balance where profile_id = current_setting('t.driver')::uuid) then
    raise exception 'CHECK A1: refund must claw back from the driver wallet';
  end if;
  if (select payment_status from public.jobs where id = current_setting('t.job')::uuid) <> 'partially_refunded' then
    raise exception 'CHECK A1: job must be marked partially refunded after a partial refund';
  end if;

  select id into v_refund from public.refunds
  where refund_payment_id = current_setting('t.refund_payment')::uuid;
  perform set_config('t.refund', v_refund::text, true);

  -- Nothing has been paid out yet: the refund waits for the provider.
  if (select status from public.refunds where id = v_refund) <> 'processing'
     or (select provider_status from public.payments where id = current_setting('t.refund_payment')::uuid) <> 'pending' then
    raise exception 'CHECK A1: a new refund must be processing with a pending refund payment';
  end if;

  -- Recording the provider reference while processing is allowed.
  update public.refunds set provider_reference = 'SEL-R-1' where id = v_refund;

  -- Provider rejected it: reverse, twice (idempotent).
  perform public.reverse_failed_refund(v_refund, 'Provider rejected the refund');
  perform public.reverse_failed_refund(v_refund, 'Provider rejected the refund');
end $$;

do $$
declare
  v_row record;
begin
  for v_row in
    select b.profile_id, b.before,
           coalesce((select sum(w.cached_balance) from public.wallets w where w.profile_id = b.profile_id), 0) as now
    from t_balance b
  loop
    if v_row.now <> v_row.before then
      raise exception 'CHECK A2: wallet % not restored (before %, now %)', v_row.profile_id, v_row.before, v_row.now;
    end if;
  end loop;

  if (select status from public.refunds where id = current_setting('t.refund')::uuid) <> 'failed' then
    raise exception 'CHECK A2: refund must be failed';
  end if;
  if (select provider_status from public.payments where id = current_setting('t.refund_payment')::uuid) <> 'failed' then
    raise exception 'CHECK A2: refund payment must be failed';
  end if;
  if (select payment_status from public.jobs where id = current_setting('t.job')::uuid) <> 'paid' then
    raise exception 'CHECK A2: job must be back to paid';
  end if;
  if exists (select 1 from public.commission_ledger where job_id = current_setting('t.job')::uuid and is_refunded) then
    raise exception 'CHECK A2: commission ledger must no longer be flagged refunded';
  end if;
  if (select count(*) from public.job_events
      where job_id = current_setting('t.job')::uuid and details ->> 'kind' = 'refund_failed') <> 1 then
    raise exception 'CHECK A2: exactly one refund_failed event expected';
  end if;
end $$;

-- A retry refunds again and claws back once, not twice.
set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated')::text, true);
do $$ begin
  perform set_config('t.refund_payment2',
    public.payment_refund(current_setting('t.payment')::uuid, 20000, 'partial', 'verify-money-controls retry')::text, true);
  -- Paid by hand (e.g. M-Pesa): the admin completes it with the reference.
  perform public.admin_complete_refund(
    (select id from public.refunds where refund_payment_id = current_setting('t.refund_payment2')::uuid),
    'MPESA-QX12');
end $$;
do $$
declare v_failed boolean := false;
begin
  begin
    perform public.admin_fail_refund(
      (select id from public.refunds where refund_payment_id = current_setting('t.refund_payment2')::uuid),
      'too late');
  exception when check_violation then v_failed := sqlerrm like '%already succeeded%';
  end;
  if not v_failed then raise exception 'CHECK A4: a succeeded refund must not be reversible'; end if;
end $$;
reset role;

do $$
declare v_r public.refunds%rowtype;
begin
  select * into v_r from public.refunds where refund_payment_id = current_setting('t.refund_payment2')::uuid;
  if v_r.status <> 'succeeded' or v_r.provider_reference <> 'MPESA-QX12' or v_r.completed_at is null then
    raise exception 'CHECK A4: completed refund not recorded (%)', row_to_json(v_r);
  end if;
  if (select provider_status from public.payments where id = current_setting('t.refund_payment2')::uuid) <> 'succeeded' then
    raise exception 'CHECK A4: refund payment must succeed with the refund';
  end if;
end $$;

do $$
declare
  v_ledger public.commission_ledger%rowtype;
  v_expected numeric;
  v_now numeric;
begin
  select * into v_ledger from public.commission_ledger where job_id = current_setting('t.job')::uuid;
  v_expected := (select before from t_balance where profile_id = current_setting('t.driver')::uuid)
    - round(v_ledger.driver_net_earning * (20000 / (select amount from public.payments where id = current_setting('t.payment')::uuid)), 2);
  select coalesce(sum(cached_balance), 0) into v_now from public.wallets where profile_id = current_setting('t.driver')::uuid;
  if v_now <> v_expected then
    raise exception 'CHECK A3: driver must be clawed back exactly once (expected %, got %)', v_expected, v_now;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- B. Payout hold / release / retry.
-- ---------------------------------------------------------------------------
do $$
declare v_payout uuid := gen_random_uuid();
begin
  insert into public.payouts (
    id, driver_id, period_start, period_end, amount, currency_code,
    gross_earnings, commission_deducted, withholding_tax, net_amount, status
  ) values (
    v_payout, current_setting('t.driver')::uuid, now() - interval '7 days', now(), 10000,
    current_setting('t.currency'), 11000, 1000, 0, 10000, 'pending'
  );
  perform set_config('t.payout', v_payout::text, true);
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated')::text, true);

do $$
declare
  v_payout uuid := current_setting('t.payout')::uuid;
  v_failed boolean;
begin
  v_failed := false;
  begin perform public.admin_hold_payout(v_payout, '  ');
  exception when null_value_not_allowed then v_failed := true; end;
  if not v_failed then raise exception 'CHECK B1: holding without a reason must fail'; end if;

  perform public.admin_hold_payout(v_payout, 'Fraud review');

  v_failed := false;
  begin perform public.admin_retry_payout(v_payout);
  exception when check_violation then v_failed := true; end;
  if not v_failed then raise exception 'CHECK B2: retry of a held payout must fail'; end if;
end $$;

reset role;
do $$
declare v_failed boolean := false;
begin
  -- Even the owner cannot send a held payout.
  begin
    update public.payouts set status = 'processing' where id = current_setting('t.payout')::uuid;
  exception when check_violation then v_failed := sqlerrm like '%on hold%';
  end;
  if not v_failed then raise exception 'CHECK B3: a held payout must not move to processing'; end if;
  if (select hold_reason from public.payouts where id = current_setting('t.payout')::uuid) <> 'Fraud review' then
    raise exception 'CHECK B1: hold reason not stored';
  end if;
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated')::text, true);
do $$ begin
  perform public.admin_release_payout(current_setting('t.payout')::uuid);
end $$;
reset role;

update public.payouts set status = 'failed', failure_reason = 'provider down' where id = current_setting('t.payout')::uuid;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated')::text, true);
do $$
declare v_failed boolean := false;
begin
  perform public.admin_retry_payout(current_setting('t.payout')::uuid);
  begin perform public.admin_release_payout(current_setting('t.payout')::uuid);
  exception when check_violation then v_failed := true; end;
  if not v_failed then raise exception 'CHECK B5: releasing a payout that is not held must fail'; end if;
end $$;
reset role;

do $$
declare v_p public.payouts%rowtype;
begin
  select * into v_p from public.payouts where id = current_setting('t.payout')::uuid;
  if v_p.status <> 'pending' or v_p.failure_reason is not null or v_p.hold_reason is not null then
    raise exception 'CHECK B4: retried payout must be clean and pending (%)', row_to_json(v_p);
  end if;
end $$;

select 'verify-money-controls: all checks passed' as result;

rollback;
