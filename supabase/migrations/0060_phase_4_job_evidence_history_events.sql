-- ============================================================================
-- SafeShift — Phase 4 / Migration 0060
-- Evidence, immutable status history and partitioned lifecycle events.
--
-- job_events is monthly-partitioned like private.audit_log because it grows per
-- ping/status/note and is queried by job plus time. The primary key includes the
-- partition key as PostgreSQL requires.
-- ============================================================================

create table public.job_evidence (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references public.jobs (id) on delete cascade,
  stop_id         uuid references public.job_stops (id) on delete set null,
  evidence_type   public.evidence_type not null,
  storage_path    text not null,
  file_mime_type  text,
  file_size_bytes bigint,
  metadata        jsonb not null default '{}'::jsonb,
  created_by      uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),

  constraint job_evidence_storage_path_check check (length(btrim(storage_path)) > 0),
  constraint job_evidence_size_check check (file_size_bytes is null or file_size_bytes >= 0),
  constraint job_evidence_metadata_object_check check (jsonb_typeof(metadata) = 'object')
);

comment on table public.job_evidence is
  'Proof files attached to a job or to a specific ordered stop. Append-only: no client UPDATE or DELETE grant, and a trigger blocks mutation.';

create table public.job_status_history (
  id          bigint generated always as identity primary key,
  job_id      uuid not null references public.jobs (id) on delete cascade,
  from_status public.job_status,
  to_status   public.job_status not null,
  changed_by  uuid references public.profiles (id) on delete set null,
  reason      text,
  location    geography(point, 4326),
  created_at  timestamptz not null default now(),

  constraint job_status_history_transition_check
    check (from_status is null or from_status <> to_status)
);

comment on table public.job_status_history is
  'Append-only record of every job status transition. UPDATE and DELETE are blocked for client roles.';

create table public.job_events (
  id          bigint generated always as identity,
  job_id      uuid not null references public.jobs (id) on delete cascade,
  event_type  text not null,
  actor_id    uuid references public.profiles (id) on delete set null,
  location    geography(point, 4326),
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),

  primary key (id, created_at),
  constraint job_events_type_check check (
    event_type in (
      'created',
      'driver_assigned',
      'driver_arrived',
      'pickup_completed',
      'in_transit',
      'delivered',
      'completed',
      'cancelled',
      'route_deviation',
      'prolonged_stop',
      'sos',
      'chat_message',
      'call_made',
      'note'
    )
  ),
  constraint job_events_details_object_check check (jsonb_typeof(details) = 'object')
) partition by range (created_at);

comment on table public.job_events is
  'Append-only lifecycle event stream, partitioned monthly. Indexes are declared on the parent and cascade to partitions.';

create table if not exists public.job_events_default
  partition of public.job_events default;

create or replace function private.ensure_job_event_partitions(p_months_ahead integer default 12)
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
    v_name := 'job_events_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.job_events for values from (%L) to (%L)',
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

comment on function private.ensure_job_event_partitions(integer) is
  'Creates missing monthly job_events partitions up to p_months_ahead months from the current month. Schedule monthly (pg_cron) in Phase 5.';

revoke all on function private.ensure_job_event_partitions(integer) from public;
revoke all on function private.ensure_job_event_partitions(integer) from anon;
revoke all on function private.ensure_job_event_partitions(integer) from authenticated;
grant execute on function private.ensure_job_event_partitions(integer) to service_role;

do $$
declare
  v_base date := date_trunc('month', now())::date;
  v_i    integer;
  v_name text;
begin
  for v_i in 0..11 loop
    v_name := 'job_events_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.job_events for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
    end if;
  end loop;
end $$;
