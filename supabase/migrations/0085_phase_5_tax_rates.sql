-- ============================================================================
-- SafeShift — Phase 5 / Migration 0085
-- Country tax rates for VAT and withholding.
-- ============================================================================

create table public.tax_rates (
  id             uuid primary key default gen_random_uuid(),
  country_id     uuid not null references public.countries (id) on delete cascade,
  tax_type       text not null,
  name           text not null,
  rate           numeric(6,4) not null,
  applies_to     text not null,
  effective_from timestamptz not null,
  effective_to   timestamptz,
  is_active      boolean not null default true,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint tax_rates_type_check
    check (tax_type in ('vat', 'withholding', 'service_tax', 'other')),
  constraint tax_rates_applies_to_check
    check (applies_to in ('customer_charge', 'driver_payout', 'platform_revenue')),
  constraint tax_rates_rate_check check (rate >= 0 and rate <= 1),
  constraint tax_rates_name_check check (length(btrim(name)) > 0),
  constraint tax_rates_window_check
    check (effective_to is null or effective_to > effective_from),
  constraint tax_rates_country_type_applies_from_key
    unique (country_id, tax_type, applies_to, effective_from)
);

comment on table public.tax_rates is
  'Country tax configuration. VAT applies to customer charges; withholding applies to driver payouts.';

create trigger trg_tax_rates_updated_at
  before update on public.tax_rates
  for each row execute function public.set_updated_at();
