-- ============================================================================
-- SafeShift — Phase 5 / Migration 0076
-- Payment providers per country.
--
-- A provider row never stores a secret. webhook_secret_reference is the name
-- of a Supabase Vault entry; Edge Functions resolve it at verification time.
-- ============================================================================

create table public.payment_providers (
  id                       uuid primary key default gen_random_uuid(),
  country_id               uuid not null references public.countries (id) on delete cascade,
  code                     text not null,
  name                     text not null,
  provider_type            text not null,
  webhook_secret_reference text,
  supports_refunds         boolean not null default true,
  supports_partial_refunds boolean not null default true,
  supports_payouts         boolean not null default false,
  config                   jsonb not null default '{}'::jsonb,
  is_active                boolean not null default true,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  constraint payment_providers_country_code_key unique (country_id, code),
  constraint payment_providers_code_format_check
    check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint payment_providers_type_check
    check (provider_type in ('mobile_money_aggregator', 'card_processor', 'bank_transfer', 'wallet')),
  constraint payment_providers_name_check check (length(btrim(name)) > 0),
  constraint payment_providers_config_object_check check (jsonb_typeof(config) = 'object')
);

comment on table public.payment_providers is
  'Country-scoped payment providers. Secrets live in Supabase Vault; only the Vault key name is stored here.';

comment on column public.payment_providers.webhook_secret_reference is
  'Supabase Vault key name used by the Phase 6 webhook verifier. Never a raw secret.';

create trigger trg_payment_providers_updated_at
  before update on public.payment_providers
  for each row execute function public.set_updated_at();
