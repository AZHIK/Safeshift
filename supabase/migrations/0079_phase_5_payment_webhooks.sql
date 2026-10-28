-- ============================================================================
-- SafeShift — Phase 5 / Migration 0079
-- Raw provider webhook log, partitioned monthly.
--
-- This is the reconciliation source of truth. Webhook signatures are verified
-- by the Phase 6 Edge Function before processing; the log always stores the
-- raw payload and verification result.
-- ============================================================================

create table public.payment_webhooks (
  id                bigint generated always as identity,
  provider_id       uuid not null references public.payment_providers (id) on delete restrict,
  event_type        text not null,
  event_id          text,
  provider_reference text,
  payload           jsonb not null,
  signature_header  text,
  signature_valid   boolean not null default false,
  processing_status text not null default 'pending',
  processing_error  text,
  processed_at      timestamptz,
  received_at       timestamptz not null default now(),
  created_at        timestamptz not null default now(),

  primary key (id, received_at),
  constraint payment_webhooks_event_type_check check (length(btrim(event_type)) > 0),
  constraint payment_webhooks_payload_object_check check (jsonb_typeof(payload) = 'object'),
  constraint payment_webhooks_processing_status_check
    check (processing_status in ('pending', 'processed', 'ignored', 'error')),
  constraint payment_webhooks_processed_at_check
    check (processing_status = 'pending' or processed_at is not null)
) partition by range (received_at);

comment on table public.payment_webhooks is
  'Append-only provider webhook log partitioned monthly with 24 months of partitions. UPDATE is limited to processing fields.';

comment on column public.payment_webhooks.provider_reference is
  'Provider reference used to reconcile the webhook with a payments row. Not an FK because some provider events precede payment creation.';

create table if not exists public.payment_webhooks_default
  partition of public.payment_webhooks default;

create or replace function private.ensure_payment_webhook_partitions(p_months_ahead integer default 24)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base  date := date_trunc('month', now())::date;
  v_i     integer;
  v_name  text;
  v_count integer := 0;
begin
  if p_months_ahead is null or p_months_ahead < 1 then
    raise exception 'p_months_ahead must be >= 1';
  end if;

  for v_i in 0..(p_months_ahead - 1) loop
    v_name := 'payment_webhooks_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.payment_webhooks for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

comment on function private.ensure_payment_webhook_partitions(integer) is
  'Creates missing monthly payment_webhooks partitions. Retention is 24 months; purge scheduling is Phase 5/6 operations.';

revoke all on function private.ensure_payment_webhook_partitions(integer) from public;
revoke all on function private.ensure_payment_webhook_partitions(integer) from anon;
revoke all on function private.ensure_payment_webhook_partitions(integer) from authenticated;
grant execute on function private.ensure_payment_webhook_partitions(integer) to service_role;

do $$
declare
  v_base date := date_trunc('month', now())::date;
  v_i    integer;
  v_name text;
begin
  for v_i in 0..23 loop
    v_name := 'payment_webhooks_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.payment_webhooks for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
    end if;
  end loop;
end $$;
