-- ============================================================================
-- SafeShift — Phase 5 / Migration 0086
-- Payout batches by country and period.
-- ============================================================================

create table public.payout_batches (
  id              uuid primary key default gen_random_uuid(),
  country_id      uuid not null references public.countries (id) on delete restrict,
  period_start    timestamptz not null,
  period_end      timestamptz not null,
  status          text not null default 'draft',
  total_amount    numeric(14,2) not null default 0,
  currency_code   char(3) not null references public.currencies (code) on update cascade on delete restrict,
  driver_count    integer not null default 0,
  initiated_by    uuid references public.profiles (id) on delete set null,
  completed_at    timestamptz,
  failure_reason  text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint payout_batches_period_check check (period_end > period_start),
  constraint payout_batches_status_check
    check (status in ('draft', 'processing', 'completed', 'failed', 'partial')),
  constraint payout_batches_total_check check (total_amount >= 0),
  constraint payout_batches_driver_count_check check (driver_count >= 0),
  constraint payout_batches_country_period_key
    unique (country_id, period_start, period_end)
);

comment on table public.payout_batches is
  'Country payout run. The period is configurable; the default operational cadence is weekly (Monday).';

create trigger trg_payout_batches_updated_at
  before update on public.payout_batches
  for each row execute function public.set_updated_at();
