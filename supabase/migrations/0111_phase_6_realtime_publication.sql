-- ============================================================================
-- 0111 — Phase 6: Realtime publication
-- ============================================================================
-- Realtime is enabled only for the five Phase 6 surfaces approved by the leads:
-- jobs, driver_locations, job_events, chat_messages, notification_log.
-- Column-level publication is used for driver_locations so location history does
-- not expose unrelated columns to subscribers. RLS on each table still applies.
--
-- Realtime enablement must be tested in Phase 7 with a live client. RLS on these
-- tables applies to Realtime.
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    execute 'create publication supabase_realtime';
  end if;
end;
$$;

alter publication supabase_realtime set (publish_via_partition_root = true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'jobs'
  ) then
    execute 'alter publication supabase_realtime add table public.jobs';
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'driver_locations'
  ) then
    execute 'alter publication supabase_realtime add table public.driver_locations (id, driver_id, job_id, location, heading_degrees, speed_kmh, recorded_at)';
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'job_events'
  ) then
    execute 'alter publication supabase_realtime add table public.job_events';
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'chat_messages'
  ) then
    execute 'alter publication supabase_realtime add table public.chat_messages';
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'notification_log'
  ) then
    execute 'alter publication supabase_realtime add table public.notification_log';
  end if;
end;
$$;

comment on publication supabase_realtime is
  'Phase 6 Realtime surfaces: jobs, driver_locations (subset), job_events, chat_messages, notification_log. Realtime must be validated with a live client in Phase 7; table RLS applies.';
