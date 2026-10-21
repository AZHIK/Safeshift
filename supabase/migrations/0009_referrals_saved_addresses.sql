-- ============================================================================
-- SafeShift — Phase 1 / Migration 0009
-- Referrals and saved addresses.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.user_referrals
-- ----------------------------------------------------------------------------
create table public.user_referrals (
  id                  uuid primary key default gen_random_uuid(),
  referrer_profile_id uuid not null references public.profiles (id) on delete cascade,
  referred_profile_id uuid references public.profiles (id) on delete set null,
  referral_code       text not null unique,
  status              text not null default 'pending',
  reward_granted      boolean not null default false,
  reward_amount       numeric(12, 2),
  created_at          timestamptz not null default now(),
  completed_at        timestamptz,

  constraint user_referrals_status_check
    check (status in ('pending', 'signed_up', 'completed', 'expired')),
  constraint user_referrals_reward_amount_check
    check (reward_amount is null or reward_amount >= 0)
);

comment on table public.user_referrals is
  'Referral codes and reward lifecycle. referred_profile_id is null until the invitee signs up.';

-- ----------------------------------------------------------------------------
-- public.saved_addresses
-- ----------------------------------------------------------------------------
create table public.saved_addresses (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  address_id uuid not null references public.addresses (id) on delete cascade,
  label      text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.saved_addresses is
  'A profile''s labelled shortcuts (Home, Work, Warehouse) to shared addresses.';

-- At most one default saved address per profile.
create unique index if not exists saved_addresses_one_default_idx
  on public.saved_addresses (profile_id)
  where is_default;
