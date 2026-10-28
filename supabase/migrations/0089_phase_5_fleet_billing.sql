-- ============================================================================
-- SafeShift — Phase 5 / Migration 0089
-- Fleet commission accruals, tracked separately from platform commission.
-- ============================================================================

create table public.fleet_billing_events (
  id                     bigint generated always as identity primary key,
  fleet_id               uuid not null references public.fleets (id) on delete restrict,
  job_id                 uuid not null references public.jobs (id) on delete restrict,
  commission_ledger_id   uuid not null,
  commission_calculated_at timestamptz not null,
  fleet_commission_rate  numeric(5,2) not null,
  fleet_commission_amount numeric(14,2) not null,
  currency_code          char(3) not null references public.currencies (code) on update cascade on delete restrict,
  accrued_at             timestamptz not null default now(),
  created_at             timestamptz not null default now(),

  constraint fleet_billing_events_ledger_fkey
    foreign key (commission_ledger_id, commission_calculated_at)
    references public.commission_ledger (id, calculated_at)
    on delete restrict,
  constraint fleet_billing_events_rate_check
    check (fleet_commission_rate >= 0 and fleet_commission_rate <= 100),
  constraint fleet_billing_events_amount_check check (fleet_commission_amount >= 0),
  constraint fleet_billing_events_ledger_key unique (commission_ledger_id)
);

comment on table public.fleet_billing_events is
  'Immutable fleet commission accrual record. One accrual per commission-ledger entry.';
