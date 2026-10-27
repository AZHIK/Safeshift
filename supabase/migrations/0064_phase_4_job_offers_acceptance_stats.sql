-- ============================================================================
-- SafeShift — Phase 4 / Migration 0064
-- Driver offers and rolling acceptance statistics.
--
-- Offers are written only by the dispatch functions. Drivers can respond only
-- through accept/decline helpers, which update response fields and then call
-- the assignment workflow.
-- ============================================================================

create table public.job_offers (
  id                    uuid primary key default gen_random_uuid(),
  job_id                uuid not null references public.jobs (id) on delete cascade,
  driver_id             uuid not null references public.drivers (id) on delete cascade,
  offer_sequence        integer not null default 1,
  offered_at            timestamptz not null default now(),
  expires_at            timestamptz not null,
  responded_at          timestamptz,
  response              text not null default 'pending',
  decline_reason        text,
  distance_to_pickup_km numeric(8,2),
  eta_minutes           integer,
  payout_estimate       numeric(14,2),
  currency_code         char(3) references public.currencies (code) on update cascade on delete restrict,
  created_at            timestamptz not null default now(),

  constraint job_offers_sequence_check check (offer_sequence >= 1),
  constraint job_offers_expiry_check check (expires_at > offered_at),
  constraint job_offers_response_check check (
    response in ('pending', 'accepted', 'declined', 'expired', 'auto_reassigned')
  ),
  constraint job_offers_distance_check check (distance_to_pickup_km is null or distance_to_pickup_km >= 0),
  constraint job_offers_eta_check check (eta_minutes is null or eta_minutes >= 0),
  constraint job_offers_payout_check check (payout_estimate is null or payout_estimate >= 0),
  constraint job_offers_payout_currency_check check (
    payout_estimate is null or currency_code is not null
  ),
  constraint job_offers_job_driver_time_key unique (job_id, driver_id, offered_at)
);

comment on table public.job_offers is
  'Every offer sent to a driver. Identity fields are immutable; response fields move only forward from pending.';

create table public.driver_acceptance_stats (
  driver_id            uuid primary key references public.drivers (id) on delete cascade,
  window_start         timestamptz not null,
  window_end           timestamptz not null,
  offers_received      integer not null default 0,
  offers_accepted      integer not null default 0,
  offers_declined      integer not null default 0,
  offers_expired       integer not null default 0,
  acceptance_rate      numeric(5,4),
  avg_response_seconds numeric(8,2),
  updated_at           timestamptz not null default now(),

  constraint driver_acceptance_stats_window_check check (window_end > window_start),
  constraint driver_acceptance_stats_received_check check (offers_received >= 0),
  constraint driver_acceptance_stats_accepted_check check (offers_accepted >= 0),
  constraint driver_acceptance_stats_declined_check check (offers_declined >= 0),
  constraint driver_acceptance_stats_expired_check check (offers_expired >= 0),
  constraint driver_acceptance_stats_rate_check
    check (acceptance_rate is null or (acceptance_rate >= 0 and acceptance_rate <= 1)),
  constraint driver_acceptance_stats_response_check
    check (avg_response_seconds is null or avg_response_seconds >= 0)
);

comment on table public.driver_acceptance_stats is
  'Rolling 30-day offer response metrics maintained by trigger from job_offers. Used by dispatch filters and ops dashboards.';

comment on column public.driver_acceptance_stats.acceptance_rate is
  'accepted offers / offers received in the rolling window, rounded to four decimals.';
