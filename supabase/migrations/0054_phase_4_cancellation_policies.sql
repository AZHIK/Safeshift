-- ============================================================================
-- SafeShift — Phase 4 / Migration 0054
-- Cancellation policies and the shared service-context helper.
--
-- Policies are country-scoped because cancellation law and commercial norms
-- differ by market. A job resolves the most recently created active policy for
-- its country and the cancelling party's role.
-- ============================================================================

create or replace function private.is_service_context()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.role(), '') = 'service_role'
      or (
        session_user in ('postgres', 'supabase_admin')
        and coalesce(auth.role(), '') in ('', 'service_role')
      );
$$;

comment on function private.is_service_context() is
  'True for service-role callers and local/migration database owners. Used by operational SECURITY DEFINER routines; never exposed to clients.';

revoke all on function private.is_service_context() from public;
revoke all on function private.is_service_context() from anon;
revoke all on function private.is_service_context() from authenticated;

create table public.cancellation_policies (
  id                              uuid primary key default gen_random_uuid(),
  country_id                      uuid not null references public.countries (id) on delete cascade,
  name                            text not null,
  description                     text,
  applies_to_role                 public.user_role not null,
  free_cancellation_window_minutes integer not null default 5,
  fee_type                        text not null,
  fee_value                       numeric(14,4) not null default 0,
  currency_code                   char(3) references public.currencies (code) on update cascade on delete restrict,
  fee_tiers                       jsonb,
  is_active                       boolean not null default true,
  created_at                      timestamptz not null default now(),
  updated_at                      timestamptz not null default now(),

  constraint cancellation_policies_role_check
    check (applies_to_role in ('customer', 'driver')),
  constraint cancellation_policies_free_window_check
    check (free_cancellation_window_minutes >= 0),
  constraint cancellation_policies_fee_type_check
    check (fee_type in ('flat', 'percentage_of_quote', 'tiered')),
  constraint cancellation_policies_fee_value_check
    check (fee_value >= 0),
  constraint cancellation_policies_percentage_check
    check (fee_type <> 'percentage_of_quote' or fee_value <= 100),
  constraint cancellation_policies_flat_currency_check
    check (fee_type <> 'flat' or currency_code is not null),
  constraint cancellation_policies_tiers_check
    check (
      fee_type <> 'tiered'
      or (
        fee_tiers is not null
        and jsonb_typeof(fee_tiers) = 'array'
        and jsonb_array_length(fee_tiers) > 0
      )
    )
);

comment on table public.cancellation_policies is
  'Country-scoped customer/driver cancellation rules. fee_value is a flat amount for flat policies and percentage points for percentage_of_quote policies; tiered policies read fee_tiers.';

comment on column public.cancellation_policies.fee_tiers is
  'Array of {"minutes_before_pickup": number, "fee": amount}. Tier selection uses the largest threshold <= minutes before the scheduled pickup.';

comment on column public.cancellation_policies.currency_code is
  'Required for flat policies. Percentage/tiered policies inherit the quote currency when this is null.';

comment on column public.cancellation_policies.fee_value is
  'NUMERIC(14,4) because the same column stores a flat amount or percentage points. Rounded to NUMERIC(14,2) when a fee is applied.';
