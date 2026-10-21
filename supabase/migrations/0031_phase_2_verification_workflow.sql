-- ============================================================================
-- SafeShift — Phase 2 / Migration 0031
-- Verification work queue, immutable history, and country checklists.
-- ============================================================================

create table public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  request_type text not null,
  driver_id uuid references public.drivers (id) on delete cascade,
  vehicle_id uuid references public.vehicles (id) on delete cascade,
  business_account_id uuid references public.business_accounts (id) on delete cascade,
  requested_by uuid not null references public.profiles (id) on delete restrict,
  assigned_to uuid references public.profiles (id) on delete set null,
  assigned_at timestamptz,
  status text not null default 'pending',
  priority text not null default 'normal',
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  decided_at timestamptz,
  decision_notes text,
  sla_due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verification_requests_type_check check (request_type in ('driver_verification', 'vehicle_verification', 'document_renewal', 'business_verification')),
  constraint verification_requests_status_check check (status in ('pending', 'in_review', 'approved', 'rejected', 'expired')),
  constraint verification_requests_priority_check check (priority in ('low', 'normal', 'high', 'urgent')),
  constraint verification_requests_subject_check check (
    (request_type = 'driver_verification' and driver_id is not null and vehicle_id is null and business_account_id is null)
    or (request_type = 'vehicle_verification' and vehicle_id is not null and driver_id is null and business_account_id is null)
    or (request_type = 'business_verification' and business_account_id is not null and driver_id is null and vehicle_id is null)
    or (request_type = 'document_renewal' and ((driver_id is not null)::integer + (vehicle_id is not null)::integer + (business_account_id is not null)::integer) = 1)
  ),
  constraint verification_requests_assigned_check check ((assigned_to is null and assigned_at is null) or (assigned_to is not null and assigned_at is not null))
);

create table public.verification_history (
  id bigint generated always as identity primary key,
  verification_request_id uuid references public.verification_requests (id) on delete set null,
  driver_id uuid references public.drivers (id) on delete set null,
  vehicle_id uuid references public.vehicles (id) on delete set null,
  business_account_id uuid references public.business_accounts (id) on delete set null,
  driver_document_id uuid references public.driver_documents (id) on delete set null,
  vehicle_document_id uuid references public.vehicle_documents (id) on delete set null,
  action text not null,
  actor_id uuid references public.profiles (id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  constraint verification_history_action_check check (action in ('submitted', 'assigned', 'approved', 'rejected', 'expired', 'reopened')),
  constraint verification_history_document_check check (not (driver_document_id is not null and vehicle_document_id is not null))
);

create table public.verification_checklist_templates (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries (id) on delete cascade,
  request_type text not null,
  required_document_codes text[] not null default '{}',
  optional_document_codes text[] not null default '{}',
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verification_checklist_country_type_key unique (country_id, request_type),
  constraint verification_checklist_type_check check (request_type in ('driver_verification', 'vehicle_verification', 'business_verification'))
);

create trigger trg_verification_requests_updated_at before update on public.verification_requests
  for each row execute function public.set_updated_at();
create trigger trg_verification_checklist_templates_updated_at before update on public.verification_checklist_templates
  for each row execute function public.set_updated_at();

