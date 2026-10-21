-- ============================================================================
-- SafeShift — Phase 1 / Migration 0012
-- Security/audit foundation: partitioned append-only audit log and consent
-- records (PDPC compliance), plus the updated_at trigger rollout and the
-- audit_log partition maintenance helper.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- private.audit_log (append-only, partitioned monthly)
-- ----------------------------------------------------------------------------
-- PRIMARY KEY must include the partition key (created_at).
-- This table is never exposed through the Data API. Reads go through
-- public.audit_log_view, which checks has_permission('view_audit').
create table private.audit_log (
  id          bigint generated always as identity,
  actor_id    uuid references public.profiles (id) on delete set null,
  actor_role  public.user_role,
  action      public.audit_action not null,
  entity_type text not null,
  entity_id   uuid,
  old_value   jsonb,
  new_value   jsonb,
  ip_address  inet,
  user_agent  text,
  session_id  text,
  created_at  timestamptz not null default now(),

  primary key (id, created_at)
) partition by range (created_at);

comment on table private.audit_log is
  'Append-only audit trail, partitioned monthly. 24 months of monthly partitions plus a safety default partition. Never readable by anon/authenticated directly.';

-- ----------------------------------------------------------------------------
-- 24 monthly partitions starting with the current month
-- ----------------------------------------------------------------------------
do $$
declare
  v_base date := date_trunc('month', now())::date;
  v_i    integer;
  v_name text;
begin
  for v_i in 0..23 loop
    v_name := 'audit_log_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    execute format(
      'create table if not exists private.%I partition of private.audit_log for values from (%L) to (%L)',
      v_name,
      v_base + make_interval(months => v_i),
      v_base + make_interval(months => v_i + 1)
    );
  end loop;
end $$;

-- Safety net: rows outside the pre-created monthly ranges still land somewhere
-- instead of failing the triggering transaction. Scheduled maintenance should
-- always run ahead of the default partition.
create table if not exists private.audit_log_default
  partition of private.audit_log default;

-- ----------------------------------------------------------------------------
-- Rolling partition maintenance
-- ----------------------------------------------------------------------------
create or replace function private.ensure_audit_log_partitions(p_months_ahead integer default 12)
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
    v_name := 'audit_log_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('private.' || v_name) is null then
      execute format(
        'create table private.%I partition of private.audit_log for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

comment on function private.ensure_audit_log_partitions(integer) is
  'Creates missing monthly audit_log partitions up to p_months_ahead months from the current month. Schedule monthly (pg_cron).';

revoke all on function private.ensure_audit_log_partitions(integer) from public;
revoke all on function private.ensure_audit_log_partitions(integer) from anon;
revoke all on function private.ensure_audit_log_partitions(integer) from authenticated;
grant execute on function private.ensure_audit_log_partitions(integer) to service_role;

-- Table-level indexes are declared in migration 0016 (they cascade to partitions).

-- ----------------------------------------------------------------------------
-- public.consent_records (PDPC compliance foundation)
-- ----------------------------------------------------------------------------
create table public.consent_records (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null references public.profiles (id) on delete cascade,
  consent_type    text not null,
  consent_version text not null,
  granted         boolean not null,
  ip_address      inet,
  user_agent      text,
  granted_at      timestamptz,
  revoked_at      timestamptz,
  created_at      timestamptz not null default now(),

  constraint consent_records_consent_type_check check (
    consent_type in (
      'terms_of_service',
      'privacy_policy',
      'marketing_email',
      'marketing_sms',
      'data_processing'
    )
  ),
  constraint consent_records_event_check check (
    (granted and granted_at is not null and revoked_at is null)
    or (not granted and revoked_at is not null)
  )
);

comment on table public.consent_records is
  'Immutable consent ledger. Every row records the document version, decision, IP and user agent. No UPDATE or DELETE is ever permitted.';

-- ----------------------------------------------------------------------------
-- updated_at triggers for every public table that has an updated_at column
-- ----------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a
        on a.attrelid = c.oid
       and a.attname = 'updated_at'
       and a.attnum > 0
       and not a.attisdropped
     where n.nspname = 'public'
       and c.relkind = 'r'
  loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || r.relname || '_updated_at',
      r.relname
    );
  end loop;
end $$;
