-- ============================================================================
-- SafeShift — Phase 2 / Migration 0030
-- Versioned vehicle documents.
-- ============================================================================

create table public.vehicle_documents (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  document_type_id uuid not null references public.document_types (id) on delete restrict,
  document_number text,
  issued_at date,
  expires_at date,
  file_path text not null,
  file_mime_type text,
  file_size_bytes bigint,
  verification_status public.driver_verification_status not null default 'pending',
  verified_at timestamptz,
  verified_by uuid references public.profiles (id) on delete set null,
  rejection_reason text,
  superseded_by uuid references public.vehicle_documents (id) on delete set null,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_documents_dates_check check (expires_at is null or issued_at is null or expires_at >= issued_at),
  constraint vehicle_documents_file_size_check check (file_size_bytes is null or file_size_bytes >= 0)
);

create trigger trg_vehicle_documents_updated_at before update on public.vehicle_documents
  for each row execute function public.set_updated_at();

