-- ============================================================================
-- SafeShift — Phase 4 / Migration 0055
-- Quote requests: the analytics record of every priced request, accepted or not.
--
-- A quote_request is intentionally independent of a pricing plan version. The
-- quote that follows captures the version, breakdown and final price. This lets
-- operations measure demand that never converted without implying a price was
-- offered.
-- ============================================================================

create table public.quote_requests (
  id                    uuid primary key default gen_random_uuid(),
  country_id            uuid not null references public.countries (id) on delete restrict,
  city_id               uuid not null references public.cities (id) on delete restrict,
  customer_id           uuid not null references public.profiles (id) on delete restrict,
  pickup_location       geography(point, 4326) not null,
  pickup_address        text not null,
  destination_location  geography(point, 4326) not null,
  destination_address   text not null,
  vehicle_type_id       uuid not null references public.vehicle_types (id) on delete restrict,
  cargo_type_id         uuid references public.cargo_types (id) on delete restrict,
  cargo_weight_kg       numeric(10,2),
  cargo_volume_m3       numeric(8,2),
  scheduled_at          timestamptz,
  stop_count            integer not null default 2,
  waiting_minutes       integer not null default 0,
  requested_at          timestamptz not null default now(),
  session_id            text,
  metadata              jsonb not null default '{}'::jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint quote_requests_stop_count_check check (stop_count >= 2),
  constraint quote_requests_waiting_check check (waiting_minutes >= 0),
  constraint quote_requests_weight_check check (cargo_weight_kg is null or cargo_weight_kg >= 0),
  constraint quote_requests_volume_check check (cargo_volume_m3 is null or cargo_volume_m3 >= 0),
  constraint quote_requests_pickup_address_check check (length(btrim(pickup_address)) > 0),
  constraint quote_requests_destination_address_check check (length(btrim(destination_address)) > 0),
  constraint quote_requests_metadata_object_check check (jsonb_typeof(metadata) = 'object')
);

comment on table public.quote_requests is
  'Every quote request, including ones that never become quotes or jobs. Retained for demand, conversion and pricing analytics.';

comment on column public.quote_requests.stop_count is
  'Total number of stops the customer requested, including pickup and dropoff. Minimum 2.';

comment on column public.quote_requests.waiting_minutes is
  'Customer-declared expected waiting time. Charged only above the plan waiting-free window.';

comment on column public.quote_requests.session_id is
  'Client session identifier for funnel analytics; not an authentication credential.';
