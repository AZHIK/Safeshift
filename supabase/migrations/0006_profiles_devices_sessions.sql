-- ============================================================================
-- SafeShift — Phase 1 / Migration 0006
-- Identity core: profiles, user_devices, user_sessions.
--
-- public.profiles extends auth.users 1:1. It is the single row that identifies
-- a human on the platform; every other identity table hangs off it.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.profiles
-- ----------------------------------------------------------------------------
create table public.profiles (
  id                  uuid primary key references auth.users (id) on delete cascade,
  primary_role        public.user_role not null default 'customer',
  full_name           text,
  display_name        text,
  phone               text unique,
  phone_verified      boolean not null default false,
  email               text,
  email_verified      boolean not null default false,
  avatar_url          text,
  preferred_language_id uuid references public.languages (id),
  preferred_currency_id uuid references public.currencies (id),
  default_country_id  uuid references public.countries (id),
  is_active           boolean not null default true,
  deactivated_at      timestamptz,
  deactivation_reason text,
  last_login_at       timestamptz,
  last_login_ip       inet,
  terms_accepted_at   timestamptz,
  privacy_accepted_at timestamptz,
  marketing_opt_in    boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  -- Data minimisation: a profile must be reachable one way or another.
  constraint profiles_contact_present_check
    check (phone is not null or email is not null)
);

comment on table public.profiles is
  'One row per human (customer, driver, business member, admin, fleet owner). Linked 1:1 to auth.users.';

comment on column public.profiles.primary_role is
  'Primary role drives default routing and coarse RLS. Fine-grained authority lives in business_members and admin_roles.';

comment on column public.profiles.email is
  'Unique when present; uniqueness enforced by a partial unique index in migration 0016.';

-- ----------------------------------------------------------------------------
-- public.user_devices
-- ----------------------------------------------------------------------------
create table public.user_devices (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  device_id    text not null,
  device_type  text not null,
  device_name  text,
  os_version   text,
  app_version  text,
  push_token   text,
  push_provider text,
  last_seen_at timestamptz not null default now(),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint user_devices_profile_device_key unique (profile_id, device_id),
  constraint user_devices_device_type_check
    check (device_type in ('ios', 'android', 'web')),
  constraint user_devices_push_provider_check
    check (push_provider is null or push_provider in ('fcm', 'apns'))
);

comment on table public.user_devices is
  'Client devices per profile, used for push notifications and session auditing.';

-- ----------------------------------------------------------------------------
-- public.user_sessions
-- ----------------------------------------------------------------------------
-- Supabase Auth owns the authoritative session state. This table is an audit
-- and administrative-revocation ledger, not the primary auth mechanism.
create table public.user_sessions (
  id                 uuid primary key default gen_random_uuid(),
  profile_id         uuid not null references public.profiles (id) on delete cascade,
  device_id          uuid references public.user_devices (id),
  session_token_hash text not null unique,
  ip_address         inet,
  user_agent         text,
  expires_at         timestamptz not null,
  revoked_at         timestamptz,
  revoked_reason     text,
  created_at         timestamptz not null default now()
);

comment on table public.user_sessions is
  'Session audit/revocation ledger. Partition by RANGE(created_at) once this exceeds ~50 million rows.';

-- ----------------------------------------------------------------------------
-- Deferred foreign keys introduced in 0005
-- ----------------------------------------------------------------------------
alter table public.addresses
  add constraint addresses_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete set null;
