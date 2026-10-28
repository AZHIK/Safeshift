-- ============================================================================
-- 0103 — Phase 6: incidents and incident actions
-- ============================================================================

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  reported_by uuid not null references public.profiles(id) on delete restrict,
  incident_type text not null,
  severity text not null,
  status text not null default 'open',
  description text not null,
  location geography(point, 4326),
  occurred_at timestamptz not null,
  assigned_to uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  resolution_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint incidents_type_check
    check (incident_type in ('accident', 'theft', 'harassment', 'damage', 'medical', 'security', 'other')),
  constraint incidents_severity_check
    check (severity in ('low', 'medium', 'high', 'critical')),
  constraint incidents_status_check
    check (status in ('open', 'investigating', 'resolved', 'closed')),
  constraint incidents_description_not_blank_check
    check (length(btrim(description)) > 0),
  constraint incidents_resolved_at_check
    check (status not in ('resolved', 'closed') or resolved_at is not null)
);

comment on table public.incidents is
  'Safety incidents, optionally linked to a job but deliberately not a dispute domain.';

create trigger trg_incidents_updated_at
  before update on public.incidents
  for each row execute function public.set_updated_at();

create table public.incident_actions (
  id bigint generated always as identity primary key,
  incident_id uuid not null references public.incidents(id) on delete cascade,
  action_type text not null,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  from_status text,
  to_status text,
  notes text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  constraint incident_actions_type_check
    check (action_type in ('created', 'assigned', 'status_changed', 'note_added', 'evidence_uploaded', 'escalated', 'resolved')),
  constraint incident_actions_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

comment on table public.incident_actions is
  'Append-only audit trail for incident lifecycle actions. UPDATE and DELETE are blocked in 0112.';
