-- ============================================================================
-- SafeShift — Phase 3 / Migration 0046
-- Promotions: promo codes, redemption ledger and advanced eligibility rules.
--
-- Validity (window, limits, active flag) is data. Eligibility (new user,
-- minimum completed jobs, zone, day of week) is data too. Cart-dependent
-- filters (vehicle type, city, cargo type) are validated by Phase 4's quote
-- engine, because they need the booking request.
-- ============================================================================

create table public.promo_codes (
  id                         uuid primary key default gen_random_uuid(),
  country_id                 uuid references public.countries (id) on delete restrict,
  code                       text not null,
  name                       text not null,
  description                text,
  discount_type              text not null,
  discount_value             numeric(14,4) not null,
  max_discount_amount        numeric(14,2),
  min_purchase_amount        numeric(14,2) not null default 0,
  currency_code              char(3) references public.currencies (code) on update cascade on delete restrict,
  valid_from                 timestamptz not null,
  valid_to                   timestamptz not null,
  total_redemption_limit     integer,
  per_user_redemption_limit  integer not null default 1,
  new_users_only             boolean not null default false,
  applicable_vehicle_type_ids uuid[] not null default '{}',
  applicable_city_ids        uuid[] not null default '{}',
  applicable_cargo_type_ids  uuid[] not null default '{}',
  is_active                  boolean not null default true,
  created_by                 uuid references public.profiles (id) on delete set null,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now(),

  constraint promo_codes_code_key unique (code),
  constraint promo_codes_code_format_check
    check (code ~ '^[A-Z0-9][A-Z0-9_-]{2,31}$'),
  constraint promo_codes_discount_type_check
    check (discount_type in ('flat_amount', 'percentage', 'free_ride', 'capped_percentage')),
  constraint promo_codes_discount_value_check check (discount_value > 0),
  constraint promo_codes_percentage_range_check
    check (discount_type not in ('percentage', 'capped_percentage') or discount_value <= 100),
  constraint promo_codes_capped_amount_check
    check (discount_type <> 'capped_percentage' or max_discount_amount is not null),
  constraint promo_codes_max_discount_check
    check (max_discount_amount is null or max_discount_amount >= 0),
  constraint promo_codes_min_purchase_check check (min_purchase_amount >= 0),
  constraint promo_codes_window_check check (valid_to > valid_from),
  constraint promo_codes_total_limit_check
    check (total_redemption_limit is null or total_redemption_limit > 0),
  constraint promo_codes_per_user_limit_check check (per_user_redemption_limit > 0)
);

comment on table public.promo_codes is
  'Promotion definitions. percentage/capped_percentage values are percentage points (10.0000 = 10%). Empty applicability arrays mean "all".';

create table public.promo_redemptions (
  id              uuid primary key default gen_random_uuid(),
  promo_code_id   uuid not null references public.promo_codes (id) on delete restrict,
  profile_id      uuid not null references public.profiles (id) on delete restrict,
  job_id          uuid,
  discount_amount numeric(14,2) not null,
  currency_code   char(3) not null references public.currencies (code) on update cascade on delete restrict,
  redeemed_at     timestamptz not null default now(),
  created_at      timestamptz not null default now(),

  constraint promo_redemptions_discount_check check (discount_amount >= 0)
);

comment on table public.promo_redemptions is
  'Append-only redemption ledger. Writes are server-side only (Phase 4 quote engine).';

comment on column public.promo_redemptions.job_id is
  'Reserved for the Phase 4 jobs FK. Deliberately a bare UUID until the jobs table exists.';

create table public.promo_code_eligibility_rules (
  id            uuid primary key default gen_random_uuid(),
  promo_code_id uuid not null references public.promo_codes (id) on delete cascade,
  rule_type     text not null,
  rule_value    jsonb not null default '{}'::jsonb,
  description   text,
  created_at    timestamptz not null default now(),

  constraint promo_code_eligibility_rules_type_check check (
    rule_type in (
      'min_jobs_completed',
      'min_account_age_days',
      'specific_zone',
      'specific_day_of_week',
      'first_job'
    )
  ),
  constraint promo_code_eligibility_rules_value_object_check
    check (jsonb_typeof(rule_value) = 'object')
);

comment on table public.promo_code_eligibility_rules is
  'Advanced targeting rules evaluated after basic validity. rule_value carries rule-specific JSON.';

create trigger trg_promo_codes_updated_at
  before update on public.promo_codes
  for each row execute function public.set_updated_at();
