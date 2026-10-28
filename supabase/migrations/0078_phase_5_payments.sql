-- ============================================================================
-- SafeShift — Phase 5 / Migration 0078
-- Payment attempts and provider references.
--
-- A charge and its refunds are separate payment rows. Refunds point at the
-- original charge through refund_of_payment_id. Rows are append-only except
-- for a one-way provider-status transition.
-- ============================================================================

create table public.payments (
  id                     uuid primary key default gen_random_uuid(),
  job_id                 uuid not null references public.jobs (id) on delete restrict,
  customer_id            uuid not null references public.profiles (id) on delete restrict,
  payment_method_id      uuid references public.payment_methods (id) on delete restrict,
  provider_id            uuid not null references public.payment_providers (id) on delete restrict,
  amount                 numeric(14,2) not null,
  currency_code          char(3) not null references public.currencies (code) on update cascade on delete restrict,
  provider_reference     text,
  provider_status        text not null default 'pending',
  payment_type           text not null default 'charge',
  refund_of_payment_id   uuid references public.payments (id) on delete restrict,
  failure_reason         text,
  failure_code           text,
  initiated_at           timestamptz not null default now(),
  completed_at           timestamptz,
  metadata               jsonb not null default '{}'::jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint payments_amount_check check (amount > 0),
  constraint payments_status_check
    check (provider_status in ('initiated', 'pending', 'succeeded', 'failed', 'cancelled')),
  constraint payments_type_check
    check (payment_type in ('charge', 'refund', 'partial_refund')),
  constraint payments_refund_parent_check
    check (
      (payment_type = 'charge' and refund_of_payment_id is null)
      or (payment_type in ('refund', 'partial_refund') and refund_of_payment_id is not null)
    ),
  constraint payments_metadata_object_check check (jsonb_typeof(metadata) = 'object'),
  constraint payments_completed_status_check
    check (
      provider_status not in ('succeeded', 'failed', 'cancelled')
      or completed_at is not null
    )
);

comment on table public.payments is
  'Charge and refund payment attempts. Provider references are unique when present. UPDATE is limited to a terminal provider-status transition.';

comment on column public.payments.provider_reference is
  'Provider idempotency/reference key. Used by job_pay() to make retries return the same payment.';

create trigger trg_payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();
