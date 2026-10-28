-- ============================================================================
-- SafeShift — Phase 5 / Migration 0082
-- Append-only wallet ledger, partitioned monthly.
--
-- Positive amount = credit, negative amount = debit. balance_after is set by
-- the insert trigger from the wallet's current cache under a row lock.
-- ============================================================================

create table public.wallet_transactions (
  id               bigint generated always as identity,
  wallet_id        uuid not null references public.wallets (id) on delete cascade,
  transaction_type text not null,
  amount           numeric(14,2) not null,
  currency_code    char(3) not null references public.currencies (code) on update cascade on delete restrict,
  balance_after    numeric(14,2) not null default 0,
  reference_type   text,
  reference_id     uuid,
  description      text,
  metadata         jsonb not null default '{}'::jsonb,
  created_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),

  primary key (id, created_at),
  constraint wallet_transactions_type_check check (
    transaction_type in (
      'topup', 'payment', 'refund', 'driver_earning', 'commission_deduction',
      'payout', 'promo_credit', 'adjustment', 'cancellation_fee', 'withholding_tax'
    )
  ),
  constraint wallet_transactions_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
) partition by range (created_at);

comment on table public.wallet_transactions is
  'Append-only wallet ledger. UPDATE and DELETE are blocked for every role.';

create table if not exists public.wallet_transactions_default
  partition of public.wallet_transactions default;

create or replace function private.ensure_wallet_transaction_partitions(p_months_ahead integer default 12)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base  date := date_trunc('month', now())::date;
  v_i     integer;
  v_name  text;
  v_count integer := 0;
begin
  if p_months_ahead is null or p_months_ahead < 1 then
    raise exception 'p_months_ahead must be >= 1';
  end if;

  for v_i in 0..(p_months_ahead - 1) loop
    v_name := 'wallet_transactions_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.wallet_transactions for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

comment on function private.ensure_wallet_transaction_partitions(integer) is
  'Creates missing monthly wallet_transactions partitions.';

revoke all on function private.ensure_wallet_transaction_partitions(integer) from public;
revoke all on function private.ensure_wallet_transaction_partitions(integer) from anon;
revoke all on function private.ensure_wallet_transaction_partitions(integer) from authenticated;
grant execute on function private.ensure_wallet_transaction_partitions(integer) to service_role;

do $$
declare
  v_base date := date_trunc('month', now())::date;
  v_i    integer;
  v_name text;
begin
  for v_i in 0..11 loop
    v_name := 'wallet_transactions_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.wallet_transactions for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
    end if;
  end loop;
end $$;
