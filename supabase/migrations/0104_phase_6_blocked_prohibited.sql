-- ============================================================================
-- 0104 — Phase 6: blocked users and prohibited items
-- ============================================================================

create table public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  blocker_profile_id uuid not null references public.profiles(id) on delete cascade,
  blocked_profile_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  scope text not null default 'global',
  job_id uuid references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint blocked_users_not_self_check
    check (blocker_profile_id <> blocked_profile_id),
  constraint blocked_users_scope_check
    check (scope in ('global', 'job_specific')),
  constraint blocked_users_job_scope_check
    check ((scope = 'global' and job_id is null) or (scope = 'job_specific' and job_id is not null)),
  constraint blocked_users_scope_key
    unique nulls not distinct (blocker_profile_id, blocked_profile_id, scope, job_id)
);

comment on table public.blocked_users is
  'A user can block another user globally or only for one job.';

create table public.prohibited_items (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete cascade,
  category text not null,
  name text not null,
  description text,
  legal_reference text,
  severity text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prohibited_items_category_check
    check (category in ('weapons', 'drugs', 'hazardous_materials', 'live_animals', 'cash', 'illegal_goods', 'other')),
  constraint prohibited_items_severity_check
    check (severity in ('prohibited', 'requires_licence', 'restricted_route')),
  constraint prohibited_items_name_not_blank_check check (length(btrim(name)) > 0)
);

comment on table public.prohibited_items is
  'Jurisdiction-specific prohibited, licensed, and restricted-route cargo catalogue.';

create trigger trg_prohibited_items_updated_at
  before update on public.prohibited_items
  for each row execute function public.set_updated_at();
