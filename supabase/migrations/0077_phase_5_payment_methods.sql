-- ============================================================================
-- SafeShift — Phase 5 / Migration 0077
-- Saved payment sources per profile.
--
-- provider_token is always a provider-issued token, never a raw card number
-- or phone number. One active default method per profile is enforced by a
-- partial unique index in migration 0093.
-- ============================================================================

create table public.payment_methods (
  id                   uuid primary key default gen_random_uuid(),
  profile_id           uuid not null references public.profiles (id) on delete cascade,
  provider_id          uuid not null references public.payment_providers (id) on delete restrict,
  method_type          public.payment_method not null,
  display_name         text,
  provider_token       text not null,
  provider_customer_id text,
  is_default           boolean not null default false,
  is_active            boolean not null default true,
  last_used_at         timestamptz,
  expires_at           timestamptz,
  metadata             jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint payment_methods_token_check check (length(btrim(provider_token)) > 0),
  constraint payment_methods_metadata_object_check check (jsonb_typeof(metadata) = 'object'),
  constraint payment_methods_default_inactive_check check (not is_default or is_active)
);

comment on table public.payment_methods is
  'Saved provider tokens for a profile. Methods are inserted by the Phase 7 Edge Function; clients may only change default/active flags.';

comment on column public.payment_methods.provider_token is
  'Provider token or vault-backed reference. Never a raw PAN, CVV or phone number.';

create trigger trg_payment_methods_updated_at
  before update on public.payment_methods
  for each row execute function public.set_updated_at();
