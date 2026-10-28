-- ============================================================================
-- SafeShift — Phase 5 / Migration 0080
-- Refund workflow records linking a refund payment back to its original charge.
-- ============================================================================

create table public.refunds (
  id                  uuid primary key default gen_random_uuid(),
  payment_id          uuid not null references public.payments (id) on delete restrict,
  refund_payment_id   uuid not null references public.payments (id) on delete restrict,
  job_id              uuid not null references public.jobs (id) on delete restrict,
  reason              text not null,
  requested_by        uuid not null references public.profiles (id) on delete restrict,
  amount              numeric(14,2) not null,
  currency_code       char(3) not null references public.currencies (code) on update cascade on delete restrict,
  status              text not null default 'requested',
  refund_type         text not null,
  provider_reference  text,
  completed_at        timestamptz,
  failure_reason      text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint refunds_amount_check check (amount > 0),
  constraint refunds_reason_check check (length(btrim(reason)) > 0),
  constraint refunds_status_check
    check (status in ('requested', 'processing', 'succeeded', 'failed')),
  constraint refunds_type_check
    check (refund_type in ('full', 'partial', 'cancellation_fee', 'goodwill')),
  constraint refunds_payment_distinct_check check (payment_id <> refund_payment_id),
  constraint refunds_completed_status_check
    check (status <> 'succeeded' or completed_at is not null)
);

comment on table public.refunds is
  'Refund workflow row linking the original charge to the refund payment. Status updates are controlled; financial fields are immutable.';

create trigger trg_refunds_updated_at
  before update on public.refunds
  for each row execute function public.set_updated_at();
