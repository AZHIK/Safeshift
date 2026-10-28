-- ============================================================================
-- SafeShift — Phase 5 / Migration 0087
-- Driver payouts and the commission-ledger items that contributed to them.
--
-- payouts.period_start/period_end are denormalised from the batch so the
-- required UNIQUE(driver_id, period_start, period_end) works per driver.
-- ============================================================================

create table public.payouts (
  id                   uuid primary key default gen_random_uuid(),
  batch_id             uuid references public.payout_batches (id) on delete restrict,
  driver_id            uuid not null references public.drivers (id) on delete restrict,
  period_start         timestamptz not null,
  period_end           timestamptz not null,
  amount               numeric(14,2) not null,
  currency_code        char(3) not null references public.currencies (code) on update cascade on delete restrict,
  gross_earnings       numeric(14,2) not null,
  commission_deducted  numeric(14,2) not null default 0,
  withholding_tax      numeric(14,2) not null default 0,
  net_amount           numeric(14,2) not null,
  payment_provider_id  uuid references public.payment_providers (id) on delete restrict,
  payment_method_id    uuid references public.payment_methods (id) on delete restrict,
  status               text not null default 'pending',
  provider_reference   text,
  failure_reason       text,
  initiated_at         timestamptz not null default now(),
  completed_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint payouts_amount_check check (amount > 0),
  constraint payouts_gross_check check (gross_earnings >= 0),
  constraint payouts_commission_check check (commission_deducted >= 0),
  constraint payouts_withholding_check check (withholding_tax >= 0),
  constraint payouts_net_check check (net_amount >= 0),
  constraint payouts_period_check check (period_end > period_start),
  constraint payouts_status_check
    check (status in ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  constraint payouts_completed_status_check
    check (status <> 'completed' or completed_at is not null),
  constraint payouts_driver_period_key unique (driver_id, period_start, period_end)
);

comment on table public.payouts is
  'One driver payout per batch period. net_amount = gross_earnings - commission_deducted - withholding_tax.';

create trigger trg_payouts_updated_at
  before update on public.payouts
  for each row execute function public.set_updated_at();

create table public.payout_items (
  id                     uuid primary key default gen_random_uuid(),
  payout_id              uuid not null references public.payouts (id) on delete cascade,
  commission_ledger_id   uuid not null,
  commission_calculated_at timestamptz not null,
  job_id                 uuid not null references public.jobs (id) on delete restrict,
  amount                 numeric(14,2) not null,
  created_at             timestamptz not null default now(),

  constraint payout_items_ledger_fkey
    foreign key (commission_ledger_id, commission_calculated_at)
    references public.commission_ledger (id, calculated_at)
    on delete restrict,
  constraint payout_items_amount_check check (amount > 0),
  constraint payout_items_ledger_key unique (commission_ledger_id)
);

comment on table public.payout_items is
  'Links each commission-ledger entry to exactly one payout. A ledger entry can never be paid twice.';
