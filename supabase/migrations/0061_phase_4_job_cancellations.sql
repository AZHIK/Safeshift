-- ============================================================================
-- SafeShift — Phase 4 / Migration 0061
-- Job cancellations: the financial and policy record of a cancelled job.
--
-- Jobs keep a denormalised cancellation_fee for fast reads. This table stores
-- the structured reason, policy, refund state and currency needed for support
-- and Phase 5 refund processing.
-- ============================================================================

create table public.job_cancellations (
  id                     uuid primary key default gen_random_uuid(),
  job_id                 uuid not null references public.jobs (id) on delete restrict,
  cancelled_by           uuid not null references public.profiles (id) on delete restrict,
  canceller_role         public.user_role not null,
  reason                 text not null,
  cancellation_policy_id uuid references public.cancellation_policies (id) on delete restrict,
  fee_applied            numeric(14,2) not null default 0,
  refund_amount          numeric(14,2) not null default 0,
  currency_code          char(3) references public.currencies (code) on update cascade on delete restrict,
  refund_status          text,
  notes                  text,
  created_at             timestamptz not null default now(),

  constraint job_cancellations_job_key unique (job_id),
  constraint job_cancellations_role_check
    check (canceller_role in ('customer', 'driver', 'admin')),
  constraint job_cancellations_reason_check
    check (length(btrim(reason)) > 0),
  constraint job_cancellations_fee_check check (fee_applied >= 0),
  constraint job_cancellations_refund_check check (refund_amount >= 0),
  constraint job_cancellations_refund_status_check check (
    refund_status is null
    or refund_status in ('not_applicable', 'pending', 'completed', 'failed')
  ),
  constraint job_cancellations_currency_check
    check (fee_applied = 0 and refund_amount = 0 or currency_code is not null)
);

comment on table public.job_cancellations is
  'Structured cancellation record. refund_status is intentionally mutable so Phase 5 can mark a refund completed/failed without rewriting the fee history.';

comment on column public.job_cancellations.refund_status is
  'not_applicable when nothing was paid; pending/completed/failed once Phase 5 payment integration exists.';
