-- ============================================================================
-- 0097 — Phase 6: push tokens, notification templates, notification log
-- ============================================================================
-- Phase 6 begins the communication, safety, compliance, and analytics layer.
-- Money conventions are unchanged: no money columns are introduced here.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Shared partition helper
-- ----------------------------------------------------------------------------
-- Phase 6 has four monthly partitioned tables. This helper creates a fixed
-- number of forward monthly partitions from the current month, and revokes
-- direct client access on every child partition. Partition children are never
-- queried directly by clients; RLS and grants live on the parent table.
create or replace function private.ensure_monthly_partitions(
  p_schema text,
  p_table text,
  p_key_column text,
  p_months integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base date := date_trunc('month', now())::date;
  v_start date;
  v_end date;
  v_name text;
  v_created integer := 0;
begin
  if p_months < 1 or p_months > 240 then
    raise exception 'partition month count must be between 1 and 240'
      using errcode = '22023';
  end if;

  if p_schema not in ('public', 'private') then
    raise exception 'unsupported partition schema: %', p_schema
      using errcode = '22023';
  end if;

  if p_key_column !~ '^[a-z_][a-z0-9_]*$' then
    raise exception 'invalid partition key column: %', p_key_column
      using errcode = '22023';
  end if;

  if to_regclass(format('%I.%I', p_schema, p_table)) is null then
    raise exception 'partition parent %.% does not exist', p_schema, p_table
      using errcode = '42P01';
  end if;

  for i in 0..(p_months - 1) loop
    v_start := (v_base + make_interval(months => i))::date;
    v_end := (v_start + interval '1 month')::date;
    v_name := format('%s_%s', p_table, to_char(v_start, 'YYYY_MM'));

    if to_regclass(format('%I.%I', p_schema, v_name)) is null then
      execute format(
        'create table %I.%I partition of %I.%I for values from (%L) to (%L)',
        p_schema, v_name, p_schema, p_table, v_start, v_end
      );
      execute format(
        'revoke all on table %I.%I from anon, authenticated',
        p_schema, v_name
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

comment on function private.ensure_monthly_partitions(text, text, text, integer) is
  'Creates forward monthly partitions from the current month and removes direct client grants from partition children.';

revoke all on function private.ensure_monthly_partitions(text, text, text, integer) from public;
revoke all on function private.ensure_monthly_partitions(text, text, text, integer) from anon;
revoke all on function private.ensure_monthly_partitions(text, text, text, integer) from authenticated;
grant execute on function private.ensure_monthly_partitions(text, text, text, integer) to service_role;

-- ----------------------------------------------------------------------------
-- 2. Push tokens
-- ----------------------------------------------------------------------------
create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  device_id uuid not null references public.user_devices(id) on delete cascade,
  token text not null,
  provider text not null default 'fcm',
  platform text not null,
  app_version text,
  is_active boolean not null default true,
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_tokens_token_not_blank_check check (length(btrim(token)) > 0),
  constraint push_tokens_provider_check check (provider = 'fcm'),
  constraint push_tokens_platform_check check (platform in ('ios', 'android', 'web')),
  constraint push_tokens_profile_device_key unique (profile_id, device_id)
);

comment on table public.push_tokens is
  'One active push registration per (profile_id, device_id). FCM is the Phase 6 provider; APNs is reached through FCM bridging.';

-- ----------------------------------------------------------------------------
-- 3. Notification templates
-- ----------------------------------------------------------------------------
create table public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  country_id uuid references public.countries(id) on delete cascade,
  language_id uuid not null references public.languages(id) on delete restrict,
  code text not null,
  channel text not null,
  title_template text,
  body_template text not null,
  variables text[] not null default '{}',
  deep_link_template text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_templates_code_not_blank_check check (length(btrim(code)) > 0),
  constraint notification_templates_channel_check check (channel in ('push', 'sms', 'email')),
  constraint notification_templates_title_for_push_check check (channel <> 'push' or title_template is not null),
  constraint notification_templates_body_not_blank_check check (length(btrim(body_template)) > 0),
  constraint notification_templates_variables_no_nulls_check
    check (array_position(variables, null) is null),
  constraint notification_templates_scope_key
    unique nulls not distinct (country_id, language_id, code, channel)
);

comment on table public.notification_templates is
  'Per-country, per-language notification templates. country_id NULL means a global fallback.';

-- ----------------------------------------------------------------------------
-- 4. Notification log (monthly partition, 24 months retained)
-- ----------------------------------------------------------------------------
create table public.notification_log (
  id bigint generated always as identity,
  public_id uuid not null default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null,
  template_code text,
  recipient text not null,
  subject text,
  body text not null,
  status text not null default 'pending',
  provider text,
  provider_message_id text,
  provider_response jsonb,
  failure_reason text,
  reference_type text,
  reference_id uuid,
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (id, created_at),
  constraint notification_log_channel_check check (channel in ('push', 'sms', 'email')),
  constraint notification_log_status_check
    check (status in ('pending', 'sent', 'delivered', 'failed', 'bounced', 'read')),
  constraint notification_log_recipient_not_blank_check check (length(btrim(recipient)) > 0),
  constraint notification_log_body_not_blank_check check (length(btrim(body)) > 0),
  constraint notification_log_provider_response_object_check
    check (provider_response is null or jsonb_typeof(provider_response) = 'object'),
  constraint notification_log_reference_pair_check
    check ((reference_type is null) = (reference_id is null))
) partition by range (created_at);

comment on table public.notification_log is
  'Append-only notification delivery log, partitioned monthly. public_id is the API-facing identifier because id is a BIGINT identity and the partition key is required in the primary key.';

create table public.notification_log_default
  partition of public.notification_log default;
revoke all on table public.notification_log_default from anon, authenticated;

select private.ensure_monthly_partitions('public', 'notification_log', 'created_at', 24);

-- ----------------------------------------------------------------------------
-- 5. Phase 6 audit coverage
-- ----------------------------------------------------------------------------
create trigger trg_push_tokens_updated_at
  before update on public.push_tokens
  for each row execute function public.set_updated_at();

create trigger trg_notification_templates_updated_at
  before update on public.notification_templates
  for each row execute function public.set_updated_at();
