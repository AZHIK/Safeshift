-- ============================================================================
-- SafeShift — Phase 4 / Migration 0069
-- Recurring job templates and generated schedule instances.
-- ============================================================================

create table public.recurring_job_templates (
  id                      uuid primary key default gen_random_uuid(),
  business_account_id     uuid not null references public.business_accounts (id) on delete cascade,
  created_by              uuid not null references public.profiles (id) on delete restrict,
  name                    text not null,
  description             text,
  pickup_address_id       uuid references public.addresses (id) on delete set null,
  destination_address_id  uuid references public.addresses (id) on delete set null,
  vehicle_type_id         uuid not null references public.vehicle_types (id) on delete restrict,
  cargo_type_id           uuid references public.cargo_types (id) on delete restrict,
  default_cargo_weight_kg numeric(10,2),
  default_cargo_volume_m3 numeric(8,2),
  recurrence_rule         text not null,
  time_of_day             time not null,
  timezone                text not null,
  preferred_driver_id     uuid references public.drivers (id) on delete set null,
  is_active               boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint recurring_job_templates_name_check check (length(btrim(name)) > 0),
  constraint recurring_job_templates_weight_check
    check (default_cargo_weight_kg is null or default_cargo_weight_kg >= 0),
  constraint recurring_job_templates_volume_check
    check (default_cargo_volume_m3 is null or default_cargo_volume_m3 >= 0),
  constraint recurring_job_templates_rrule_check
    check (recurrence_rule like 'FREQ=%'),
  constraint recurring_job_templates_address_check check (
    pickup_address_id is null
    or destination_address_id is null
    or pickup_address_id <> destination_address_id
  )
);

comment on table public.recurring_job_templates is
  'Business-account recurring booking template. recurrence_rule is an RFC 5545 RRULE such as FREQ=WEEKLY;BYDAY=MO,WE,FR.';

comment on column public.recurring_job_templates.timezone is
  'IANA timezone used to interpret time_of_day and the RRULE, e.g. Africa/Dar_es_Salaam.';

create table public.scheduled_jobs (
  id               uuid primary key default gen_random_uuid(),
  template_id      uuid not null references public.recurring_job_templates (id) on delete cascade,
  quote_request_id uuid references public.quote_requests (id) on delete set null,
  job_id           uuid references public.jobs (id) on delete set null,
  scheduled_for    timestamptz not null,
  status           text not null default 'pending',
  generated_at     timestamptz,
  error_reason     text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  constraint scheduled_jobs_status_check check (
    status in ('pending', 'quoted', 'confirmed', 'cancelled', 'completed', 'failed')
  ),
  constraint scheduled_jobs_template_time_key unique (template_id, scheduled_for)
);

comment on table public.scheduled_jobs is
  'Concrete occurrence generated from a recurring template. status follows pending -> quoted -> confirmed -> completed, or cancelled/failed.';
