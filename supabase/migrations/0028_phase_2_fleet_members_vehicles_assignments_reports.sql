-- ============================================================================
-- SafeShift — Phase 2 / Migration 0028
-- Fleet membership, fleet vehicles, driver/vehicle assignment history, reports.
-- ============================================================================

create table public.fleet_members (
  id uuid primary key default gen_random_uuid(),
  fleet_id uuid not null references public.fleets (id) on delete cascade,
  driver_id uuid not null references public.drivers (id) on delete cascade,
  role text not null,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fleet_members_role_check check (role in ('owner', 'manager', 'driver')),
  constraint fleet_members_dates_check check (left_at is null or left_at >= joined_at)
);

create table public.fleet_vehicles (
  id uuid primary key default gen_random_uuid(),
  fleet_id uuid not null references public.fleets (id) on delete cascade,
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  assigned_at timestamptz not null default now(),
  unassigned_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fleet_vehicles_dates_check check (unassigned_at is null or unassigned_at >= assigned_at)
);

create table public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  driver_id uuid not null references public.drivers (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null,
  assigned_at timestamptz not null default now(),
  unassigned_at timestamptz,
  unassign_reason text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_assignments_dates_check check (unassigned_at is null or unassigned_at >= assigned_at)
);

create table public.fleet_reports (
  id uuid primary key default gen_random_uuid(),
  fleet_id uuid not null references public.fleets (id) on delete cascade,
  report_type text not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  file_path text,
  generated_at timestamptz not null default now(),
  generated_by uuid references public.profiles (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint fleet_reports_type_check check (report_type in ('daily_summary', 'weekly_summary', 'monthly_summary', 'utilization', 'earnings', 'driver_performance')),
  constraint fleet_reports_period_check check (period_end > period_start),
  constraint fleet_reports_metadata_object_check check (jsonb_typeof(metadata) = 'object')
);

create trigger trg_fleet_members_updated_at before update on public.fleet_members
  for each row execute function public.set_updated_at();
create trigger trg_fleet_vehicles_updated_at before update on public.fleet_vehicles
  for each row execute function public.set_updated_at();
create trigger trg_vehicle_assignments_updated_at before update on public.vehicle_assignments
  for each row execute function public.set_updated_at();

