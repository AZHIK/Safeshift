-- ============================================================================
-- SafeShift — Phase 3 / Migration 0038
-- LATRA / national transport regulator tariffs and their legal fare bands.
--
-- A regulated tariff is a country-scoped legal framework. Bands carry the
-- minimum and maximum fare for a distance/weight slice. Pricing plan versions
-- may reference a tariff; the quote engine and public.regulated_max_fare()
-- apply the most restrictive (minimum) applicable max_fare.
-- ============================================================================

create table public.regulated_tariffs (
  id                    uuid primary key default gen_random_uuid(),
  country_id            uuid not null references public.countries (id) on delete restrict,
  regulatory_body       text not null,
  name                  text not null,
  vehicle_type_id       uuid references public.vehicle_types (id) on delete restrict,
  approval_reference    text not null,
  approval_date         date not null,
  published_gazette_date date,
  effective_from        timestamptz not null,
  effective_to          timestamptz,
  tariff_structure      text not null,
  currency_code         char(3) not null references public.currencies (code) on update cascade on delete restrict,
  source_document_url   text,
  notes                 text,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint regulated_tariffs_structure_check check (
    tariff_structure in (
      'distance_band',
      'weight_band',
      'distance_and_weight_band',
      'percentage_of_market',
      'flat'
    )
  ),
  constraint regulated_tariffs_effective_window_check
    check (effective_to is null or effective_to > effective_from),
  constraint regulated_tariffs_approval_reference_key
    unique (country_id, regulatory_body, approval_reference)
);

comment on table public.regulated_tariffs is
  'Country-scoped regulated transport tariff frameworks (e.g. LATRA goods transport). Stored as data so a new country adds rows, not code.';

comment on column public.regulated_tariffs.vehicle_type_id is
  'NULL means the tariff applies to every goods vehicle type in the country.';

comment on column public.regulated_tariffs.tariff_structure is
  'Legal structure of the tariff. TEXT + CHECK rather than an enum so regulators can add forms without an enum migration.';

create table public.regulated_tariff_bands (
  id                  uuid primary key default gen_random_uuid(),
  regulated_tariff_id uuid not null references public.regulated_tariffs (id) on delete cascade,
  band_type           text not null,
  min_value           numeric(10,2) not null,
  max_value           numeric(10,2),
  value_unit          text not null,
  min_fare            numeric(14,2) not null,
  max_fare            numeric(14,2) not null,
  display_order       integer not null default 0,
  created_at          timestamptz not null default now(),

  constraint regulated_tariff_bands_type_check check (
    band_type in ('distance', 'weight', 'combined')
  ),
  constraint regulated_tariff_bands_unit_check check (
    value_unit in ('km', 'kg', 'tonnes', 'm3')
  ),
  constraint regulated_tariff_bands_min_value_check check (min_value >= 0),
  constraint regulated_tariff_bands_max_value_check
    check (max_value is null or max_value > min_value),
  constraint regulated_tariff_bands_min_fare_check check (min_fare >= 0),
  constraint regulated_tariff_bands_max_fare_check check (max_fare >= min_fare)
);

comment on table public.regulated_tariff_bands is
  'Legal minimum/maximum fare slices for a regulated tariff. Bands of the same type may not overlap.';

create trigger trg_regulated_tariffs_updated_at
  before update on public.regulated_tariffs
  for each row execute function public.set_updated_at();
