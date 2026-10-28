-- ============================================================================
-- SafeShift — Phase 5 / Migration 0081
-- One wallet per profile/currency. cached_balance is a derived cache maintained
-- only by the wallet_transactions insert trigger.
-- ============================================================================

create table public.wallets (
  id               uuid primary key default gen_random_uuid(),
  profile_id       uuid not null references public.profiles (id) on delete cascade,
  currency_code    char(3) not null references public.currencies (code) on update cascade on delete restrict,
  cached_balance   numeric(14,2) not null default 0,
  is_frozen        boolean not null default false,
  frozen_reason    text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  constraint wallets_profile_currency_key unique (profile_id, currency_code),
  constraint wallets_frozen_reason_check
    check (not is_frozen or frozen_reason is not null)
);

comment on table public.wallets is
  'Wallet header. cached_balance must equal the sum of wallet_transactions.amount; the transaction insert trigger maintains it.';

comment on column public.wallets.cached_balance is
  'Derived cache, never authoritative. A nightly verifier raises a warning if it drifts from the ledger sum.';

create trigger trg_wallets_updated_at
  before update on public.wallets
  for each row execute function public.set_updated_at();
