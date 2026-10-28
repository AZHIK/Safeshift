-- ============================================================================
-- 0102 — Phase 6: emergency contacts
-- ============================================================================

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  phone text not null,
  relationship text,
  is_primary boolean not null default false,
  notify_on_trip_start boolean not null default true,
  notify_on_sos boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint emergency_contacts_name_not_blank_check check (length(btrim(name)) > 0),
  constraint emergency_contacts_phone_not_blank_check check (length(btrim(phone)) > 0)
);

comment on table public.emergency_contacts is
  'Safety contacts for a profile. A partial unique index in 0113 enforces one primary contact per profile.';

create trigger trg_emergency_contacts_updated_at
  before update on public.emergency_contacts
  for each row execute function public.set_updated_at();
