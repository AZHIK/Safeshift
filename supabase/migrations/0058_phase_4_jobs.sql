-- ============================================================================
-- SafeShift — Phase 4 / Migration 0058
-- Jobs: the core marketplace transaction.
--
-- Every job is created from a persisted quote. The quote keeps the priced
-- promise; the job records what actually happened. A BEFORE INSERT trigger in
-- migration 0071 copies customer/city/distance/amount from the quote so those
-- fields cannot silently disagree at creation.
-- ============================================================================

create table public.jobs (
  id                           uuid primary key default gen_random_uuid(),
  quote_id                     uuid not null references public.quotes (id) on delete restrict,
  city_id                      uuid not null references public.cities (id) on delete restrict,
  customer_id                  uuid not null references public.profiles (id) on delete restrict,
  driver_id                    uuid references public.drivers (id) on delete set null,
  vehicle_id                   uuid references public.vehicles (id) on delete set null,
  status                       public.job_status not null default 'requested',
  scheduled_at                 timestamptz,
  accepted_at                  timestamptz,
  started_at                   timestamptz,
  completed_at                 timestamptz,
  cancelled_at                 timestamptz,
  final_amount                 numeric(14,2),
  final_currency_code          char(3) references public.currencies (code) on update cascade on delete restrict,
  payment_status               public.payment_status not null default 'pending',
  payment_method               public.payment_method,
  cancellation_policy_applied  text,
  cancellation_fee             numeric(14,2) not null default 0,
  distance_km                  numeric(8,2) not null,
  actual_duration_min          integer,
  actual_distance_km           numeric(8,2),
  notes                        text,
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),

  constraint jobs_final_amount_check check (final_amount is null or final_amount >= 0),
  constraint jobs_cancellation_fee_check check (cancellation_fee >= 0),
  constraint jobs_distance_check check (distance_km >= 0),
  constraint jobs_actual_duration_check check (actual_duration_min is null or actual_duration_min >= 0),
  constraint jobs_actual_distance_check check (actual_distance_km is null or actual_distance_km >= 0),
  constraint jobs_final_currency_check check (final_amount is null or final_currency_code is not null),
  constraint jobs_completed_amount_check check (status <> 'completed' or final_amount is not null),
  constraint jobs_cancelled_timestamp_check check (status <> 'cancelled' or cancelled_at is not null),
  constraint jobs_timestamp_order_check check (
    (accepted_at is null or started_at is null or accepted_at <= started_at)
    and (started_at is null or completed_at is null or started_at <= completed_at)
  )
);

comment on table public.jobs is
  'Marketplace job created from an accepted quote. Status changes, driver assignment and cancellation go through Phase 4 helper functions, not direct client updates.';

comment on column public.jobs.final_amount is
  'Contract amount for the job. Initialised from the quote and adjusted only by controlled cancellation/charging flows.';

comment on column public.jobs.distance_km is
  'Quoted route distance. actual_distance_km captures GPS/telemetry distance after completion.';

comment on column public.jobs.cancellation_policy_applied is
  'Human-readable policy snapshot used for the cancellation fee; the full structured record is in job_cancellations.';
