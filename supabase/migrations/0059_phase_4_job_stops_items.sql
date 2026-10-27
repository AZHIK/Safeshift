-- ============================================================================
-- SafeShift — Phase 4 / Migration 0059
-- Ordered job stops and the cargo manifest.
--
-- Decision H: stops are ordered, typed (pickup/waypoint/dropoff), and each stop
-- can own its own evidence through job_evidence.stop_id.
-- ============================================================================

create table public.job_stops (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references public.jobs (id) on delete cascade,
  stop_sequence   integer not null,
  stop_type       text not null,
  location        geography(point, 4326) not null,
  address         text not null,
  contact_name    text,
  contact_phone   text,
  notes           text,
  arrived_at      timestamptz,
  completed_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint job_stops_sequence_check check (stop_sequence >= 1),
  constraint job_stops_type_check check (stop_type in ('pickup', 'waypoint', 'dropoff')),
  constraint job_stops_address_check check (length(btrim(address)) > 0),
  constraint job_stops_job_sequence_key unique (job_id, stop_sequence),
  constraint job_stops_time_order_check check (
    arrived_at is null or completed_at is null or completed_at >= arrived_at
  )
);

comment on table public.job_stops is
  'Ordered multi-stop route. stop_sequence is unique per job; stop_type distinguishes pickup, intermediate waypoint and final dropoff.';

comment on column public.job_stops.stop_sequence is
  '1-based route order. The first stop is normally pickup and the last is normally dropoff.';

create table public.job_items (
  id                        uuid primary key default gen_random_uuid(),
  job_id                    uuid not null references public.jobs (id) on delete cascade,
  description               text not null,
  quantity                  integer not null default 1,
  weight_kg                 numeric(10,2),
  volume_m3                 numeric(8,2),
  declared_value            numeric(14,2),
  currency_code             char(3) references public.currencies (code) on update cascade on delete restrict,
  is_fragile                boolean not null default false,
  requires_special_handling boolean not null default false,
  photo_urls                text[] not null default '{}'::text[],
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),

  constraint job_items_description_check check (length(btrim(description)) > 0),
  constraint job_items_quantity_check check (quantity > 0),
  constraint job_items_weight_check check (weight_kg is null or weight_kg >= 0),
  constraint job_items_volume_check check (volume_m3 is null or volume_m3 >= 0),
  constraint job_items_declared_value_check check (declared_value is null or declared_value >= 0),
  constraint job_items_declared_currency_check check (declared_value is null or currency_code is not null)
);

comment on table public.job_items is
  'Item-level cargo manifest for a job. Declared value is optional but requires a currency when present.';

comment on column public.job_items.photo_urls is
  'Array of object-storage paths for item photos. Structured proof of pickup/delivery belongs in job_evidence.';
