-- ============================================================================
-- 0107 — Phase 6: GDPR/PDPC data subject requests
-- ============================================================================
-- Requests are recorded and processed manually by an administrator in Phase 6.
-- Automated export and deletion workflows are deferred to Phase 7.
-- ============================================================================

create table public.data_subject_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text not null unique,
  requester_profile_id uuid not null references public.profiles(id) on delete restrict,
  request_type text not null,
  status text not null default 'received',
  reason text,
  requested_at timestamptz not null default now(),
  verified_at timestamptz,
  completed_at timestamptz,
  rejected_reason text,
  delivered_file_path text,
  assigned_to uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint data_subject_requests_number_not_blank_check
    check (length(btrim(request_number)) > 0),
  constraint data_subject_requests_type_check
    check (request_type in ('export', 'delete', 'rectify', 'restrict_processing')),
  constraint data_subject_requests_status_check
    check (status in ('received', 'identity_verifying', 'in_progress', 'completed', 'rejected', 'partially_completed')),
  constraint data_subject_requests_completed_at_check
    check (status not in ('completed', 'partially_completed') or completed_at is not null),
  constraint data_subject_requests_rejected_reason_check
    check (status <> 'rejected' or rejected_reason is not null)
);

comment on table public.data_subject_requests is
  'Manual GDPR/PDPC export, delete, rectify, and restrict-processing request tracker.';

create trigger trg_data_subject_requests_updated_at
  before update on public.data_subject_requests
  for each row execute function public.set_updated_at();
