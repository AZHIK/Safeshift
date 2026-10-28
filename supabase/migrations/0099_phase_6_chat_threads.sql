-- ============================================================================
-- 0099 — Phase 6: chat threads
-- ============================================================================
-- A thread is scoped to one job. Threads are created by the service layer when
-- a job is accepted and are archived (read-only) rather than deleted.
-- ============================================================================

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  status text not null default 'active',
  archived_at timestamptz,
  last_message_at timestamptz,
  last_message_preview text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chat_threads_status_check
    check (status in ('active', 'archived', 'read_only')),
  constraint chat_threads_archived_at_check
    check (status <> 'archived' or archived_at is not null),
  constraint chat_threads_preview_length_check
    check (last_message_preview is null or length(last_message_preview) <= 240),
  constraint chat_threads_job_key unique (job_id)
);

comment on table public.chat_threads is
  'One chat thread per job. Completed/cancelled jobs move to read_only and, after the archive window, archived.';

create trigger trg_chat_threads_updated_at
  before update on public.chat_threads
  for each row execute function public.set_updated_at();
