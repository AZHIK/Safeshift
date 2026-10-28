-- ============================================================================
-- SafeShift — Phase 5 / Migration 0092
-- Immutability, wallet derivation, deduplication and audit triggers.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Payments
-- ----------------------------------------------------------------------------
create or replace function private.enforce_payments_immutability()
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
    raise exception 'payments are append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array[
    'provider_status', 'completed_at', 'failure_reason', 'failure_code', 'updated_at'
  ];
  v_old_core := to_jsonb(old) - array[
    'provider_status', 'completed_at', 'failure_reason', 'failure_code', 'updated_at'
  ];

  if v_new_core is distinct from v_old_core then
    raise exception 'payment identity and financial terms are immutable'
      using errcode = '42501';
  end if;

  if old.provider_status <> 'pending'
     or new.provider_status not in ('succeeded', 'failed', 'cancelled')
  then
    raise exception 'payment status can only move once from pending to a terminal state'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_payments_immutability() from public;
revoke all on function private.enforce_payments_immutability() from anon;
revoke all on function private.enforce_payments_immutability() from authenticated;

create trigger trg_payments_immutable
  before update or delete on public.payments
  for each row execute function private.enforce_payments_immutability();

-- ----------------------------------------------------------------------------
-- 2. Payment webhooks
-- ----------------------------------------------------------------------------
create or replace function private.enforce_payment_webhook_immutability()
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
    raise exception 'payment_webhooks are append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array['processing_status', 'processing_error', 'processed_at'];
  v_old_core := to_jsonb(old) - array['processing_status', 'processing_error', 'processed_at'];

  if v_new_core is distinct from v_old_core then
    raise exception 'webhook payload, provider reference and partition key are immutable'
      using errcode = '42501';
  end if;

  if old.processing_status <> 'pending'
     or new.processing_status not in ('processed', 'ignored', 'error')
  then
    raise exception 'webhook processing status can only move once from pending'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_payment_webhook_immutability() from public;
revoke all on function private.enforce_payment_webhook_immutability() from anon;
revoke all on function private.enforce_payment_webhook_immutability() from authenticated;

create trigger trg_payment_webhooks_immutable
  before update or delete on public.payment_webhooks
  for each row execute function private.enforce_payment_webhook_immutability();

create or replace function private.payment_webhook_dedupe()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.event_id is not null then
    perform pg_advisory_xact_lock(
      hashtext(new.provider_id::text || ':' || new.event_id)::bigint
    );

    if exists (
      select 1
      from public.payment_webhooks w
      where w.provider_id = new.provider_id
        and w.event_id = new.event_id
    ) then
      raise exception 'duplicate webhook event % for provider %', new.event_id, new.provider_id
        using errcode = '23505';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.payment_webhook_dedupe() from public;
revoke all on function private.payment_webhook_dedupe() from anon;
revoke all on function private.payment_webhook_dedupe() from authenticated;

create trigger trg_payment_webhooks_dedupe
  before insert on public.payment_webhooks
  for each row execute function private.payment_webhook_dedupe();

-- ----------------------------------------------------------------------------
-- 3. Refunds
-- ----------------------------------------------------------------------------
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
    (old.status = 'requested' and new.status in ('processing', 'succeeded', 'failed'))
    or (old.status = 'processing' and new.status in ('succeeded', 'failed'))
  ) then
    raise exception 'illegal refund status transition: % -> %', old.status, new.status
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_refunds_immutability() from public;
revoke all on function private.enforce_refunds_immutability() from anon;
revoke all on function private.enforce_refunds_immutability() from authenticated;

create trigger trg_refunds_immutable
  before update or delete on public.refunds
  for each row execute function private.enforce_refunds_immutability();

-- ----------------------------------------------------------------------------
-- 4. Wallet ledger and cached balance
-- ----------------------------------------------------------------------------
create or replace function private.enforce_wallet_transactions_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'wallet_transactions are append-only; % is not allowed', tg_op
    using errcode = '42501';
end;
$$;

revoke all on function private.enforce_wallet_transactions_immutability() from public;
revoke all on function private.enforce_wallet_transactions_immutability() from anon;
revoke all on function private.enforce_wallet_transactions_immutability() from authenticated;

create trigger trg_wallet_transactions_immutable
  before update or delete on public.wallet_transactions
  for each row execute function private.enforce_wallet_transactions_immutability();

create or replace function private.apply_wallet_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wallet public.wallets%rowtype;
  v_new_balance numeric(14,2);
begin
  select * into v_wallet
  from public.wallets
  where id = new.wallet_id
  for update;

  if not found then
    raise exception 'wallet % not found', new.wallet_id using errcode = 'P0002';
  end if;

  if new.currency_code <> v_wallet.currency_code then
    raise exception 'wallet transaction currency % does not match wallet currency %',
      new.currency_code, v_wallet.currency_code
      using errcode = '23514';
  end if;

  v_new_balance := round(v_wallet.cached_balance + new.amount, 2);
  new.balance_after := v_new_balance;

  update public.wallets
     set cached_balance = v_new_balance,
         updated_at = now()
   where id = v_wallet.id;

  return new;
end;
$$;

comment on function private.apply_wallet_transaction() is
  'BEFORE INSERT wallet ledger trigger. Locks the wallet, sets balance_after and updates the cached balance.';

revoke all on function private.apply_wallet_transaction() from public;
revoke all on function private.apply_wallet_transaction() from anon;
revoke all on function private.apply_wallet_transaction() from authenticated;

create trigger trg_wallet_transactions_apply
  before insert on public.wallet_transactions
  for each row execute function private.apply_wallet_transaction();

create or replace function private.protect_wallet_balance()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
begin
  if new.profile_id is distinct from old.profile_id
     or new.currency_code is distinct from old.currency_code
  then
    raise exception 'wallet identity is immutable' using errcode = '42501';
  end if;

  if new.cached_balance is distinct from old.cached_balance and not v_service then
    raise exception 'wallet cached_balance is derived; use wallet_credit/wallet_debit'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke all on function private.protect_wallet_balance() from public;
revoke all on function private.protect_wallet_balance() from anon;
revoke all on function private.protect_wallet_balance() from authenticated;

create trigger trg_wallets_protect_balance
  before update on public.wallets
  for each row execute function private.protect_wallet_balance();

-- ----------------------------------------------------------------------------
-- 5. Commission ledger and payout items
-- ----------------------------------------------------------------------------
create or replace function private.commission_ledger_unique_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.job_id::text)::bigint);

  if exists (
    select 1 from public.commission_ledger cl where cl.job_id = new.job_id
  ) then
    raise exception 'commission ledger already exists for job %', new.job_id
      using errcode = '23505';
  end if;

  return new;
end;
$$;

revoke all on function private.commission_ledger_unique_guard() from public;
revoke all on function private.commission_ledger_unique_guard() from anon;
revoke all on function private.commission_ledger_unique_guard() from authenticated;

create trigger trg_commission_ledger_unique
  before insert on public.commission_ledger
  for each row execute function private.commission_ledger_unique_guard();

create or replace function private.enforce_commission_ledger_immutability()
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

revoke all on function private.enforce_commission_ledger_immutability() from public;
revoke all on function private.enforce_commission_ledger_immutability() from anon;
revoke all on function private.enforce_commission_ledger_immutability() from authenticated;

create trigger trg_commission_ledger_immutable
  before update or delete on public.commission_ledger
  for each row execute function private.enforce_commission_ledger_immutability();

create or replace function private.enforce_payout_items_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'payout_items are append-only; % is not allowed', tg_op
    using errcode = '42501';
end;
$$;

revoke all on function private.enforce_payout_items_immutability() from public;
revoke all on function private.enforce_payout_items_immutability() from anon;
revoke all on function private.enforce_payout_items_immutability() from authenticated;

create trigger trg_payout_items_immutable
  before update or delete on public.payout_items
  for each row execute function private.enforce_payout_items_immutability();

-- ----------------------------------------------------------------------------
-- 6. Payouts and fleet billing
-- ----------------------------------------------------------------------------
create or replace function private.enforce_payouts_immutability()
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
    raise exception 'payouts are append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array[
    'status', 'completed_at', 'failure_reason', 'provider_reference', 'updated_at'
  ];
  v_old_core := to_jsonb(old) - array[
    'status', 'completed_at', 'failure_reason', 'provider_reference', 'updated_at'
  ];

  if v_new_core is distinct from v_old_core then
    raise exception 'payout financial terms are immutable'
      using errcode = '42501';
  end if;

  if not (
    (old.status = 'pending' and new.status in ('processing', 'completed', 'failed', 'cancelled'))
    or (old.status = 'processing' and new.status in ('completed', 'failed', 'cancelled'))
  ) then
    raise exception 'illegal payout status transition: % -> %', old.status, new.status
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_payouts_immutability() from public;
revoke all on function private.enforce_payouts_immutability() from anon;
revoke all on function private.enforce_payouts_immutability() from authenticated;

create trigger trg_payouts_immutable
  before update or delete on public.payouts
  for each row execute function private.enforce_payouts_immutability();

create or replace function private.enforce_fleet_billing_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'fleet_billing_events are append-only; % is not allowed', tg_op
    using errcode = '42501';
end;
$$;

revoke all on function private.enforce_fleet_billing_immutability() from public;
revoke all on function private.enforce_fleet_billing_immutability() from anon;
revoke all on function private.enforce_fleet_billing_immutability() from authenticated;

create trigger trg_fleet_billing_events_immutable
  before update or delete on public.fleet_billing_events
  for each row execute function private.enforce_fleet_billing_immutability();

-- ----------------------------------------------------------------------------
-- 7. Audit trails on mutable money roots
-- ----------------------------------------------------------------------------
do $$
declare
  v_table text;
  v_tables text[] := array[
    'public.payment_providers',
    'public.payment_methods',
    'public.commission_rules',
    'public.tax_rates',
    'public.payout_batches',
    'public.payouts',
    'public.invoices'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists %I on %s',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
    execute format(
      'create trigger %I after insert or update or delete on %s for each row execute function private.audit_trigger()',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
  end loop;
end $$;
