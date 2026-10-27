-- ============================================================================
-- SafeShift — Phase 4 / Migration 0063
-- Matching attempts and dispatch policy.
--
-- Dispatch rules resolve in a priority cascade: vehicle+city > city >
-- country > global. The unique constraint prevents duplicate rows at the same
-- scope; public.dispatch_rule_for() implements the cascade.
-- ============================================================================

create table public.matching_attempts (
  id                  uuid primary key default gen_random_uuid(),
  job_id              uuid not null references public.jobs (id) on delete cascade,
  attempt_number      integer not null,
  matched_driver_id   uuid references public.drivers (id) on delete set null,
  drivers_considered  integer not null default 0,
  drivers_offered     integer not null default 0,
  match_successful    boolean not null default false,
  failure_reason      text,
  started_at          timestamptz not null default now(),
  ended_at            timestamptz,
  metadata            jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),

  constraint matching_attempts_number_check check (attempt_number >= 1),
  constraint matching_attempts_considered_check check (drivers_considered >= 0),
  constraint matching_attempts_offered_check check (drivers_offered >= 0),
  constraint matching_attempts_window_check
    check (ended_at is null or ended_at >= started_at),
  constraint matching_attempts_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),
  constraint matching_attempts_job_number_key unique (job_id, attempt_number)
);

comment on table public.matching_attempts is
  'One row per dispatch match cycle for analytics. Server-written by the matching worker; no client write grant.';

create table public.dispatch_rules (
  id                       uuid primary key default gen_random_uuid(),
  country_id               uuid references public.countries (id) on delete cascade,
  city_id                  uuid references public.cities (id) on delete cascade,
  vehicle_type_id          uuid references public.vehicle_types (id) on delete cascade,
  max_search_radius_km     numeric(8,2) not null default 10,
  offer_timeout_seconds    integer not null default 30,
  max_concurrent_offers    integer not null default 1,
  reassign_after_seconds   integer not null default 60,
  minimum_acceptance_rate  numeric(5,4) default 0.5000,
  min_driver_rating        numeric(3,2) default 4.00,
  is_active                boolean not null default true,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  constraint dispatch_rules_radius_check check (max_search_radius_km > 0),
  constraint dispatch_rules_offer_timeout_check check (offer_timeout_seconds >= 5),
  constraint dispatch_rules_concurrent_check check (max_concurrent_offers >= 1),
  constraint dispatch_rules_reassign_check check (reassign_after_seconds >= 0),
  constraint dispatch_rules_acceptance_check
    check (minimum_acceptance_rate is null or (minimum_acceptance_rate >= 0 and minimum_acceptance_rate <= 1)),
  constraint dispatch_rules_rating_check
    check (min_driver_rating is null or (min_driver_rating >= 0 and min_driver_rating <= 5)),
  constraint dispatch_rules_scope_key unique nulls not distinct (country_id, city_id, vehicle_type_id)
);

comment on table public.dispatch_rules is
  'Dispatch tuning by scope. NULL means broader scope; the most specific active row wins.';

comment on column public.dispatch_rules.reassign_after_seconds is
  'How long the matcher waits before widening or reassigning when no offer is accepted.';
