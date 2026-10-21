-- ============================================================================
-- SafeShift — Phase 2 / Migration 0018
-- Configurable document types. Country NULL means the type is global.
-- ============================================================================

create table public.document_types (
  id uuid primary key default gen_random_uuid(),
  country_id uuid references public.countries (id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  applies_to text not null,
  is_required boolean not null default false,
  has_expiry boolean not null default true,
  validity_days integer,
  verification_sla_hours integer not null default 24,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint document_types_scope_code_key unique nulls not distinct (country_id, code),
  constraint document_types_applies_to_check check (applies_to in ('driver', 'vehicle', 'business', 'both')),
  constraint document_types_validity_check check (
    (has_expiry and (validity_days is null or validity_days > 0))
    or (not has_expiry and validity_days is null)
  ),
  constraint document_types_sla_check check (verification_sla_hours > 0)
);

create trigger trg_document_types_updated_at before update on public.document_types
  for each row execute function public.set_updated_at();

