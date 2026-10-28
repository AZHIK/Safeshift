-- ============================================================================
-- 0106 — Phase 6: data access log and retention policies
-- ============================================================================
-- PDPC accountability requires a durable record of personal-data access. The
-- database-level implementation is deliberately supplemented (not replaced) by
-- service-layer logging in Phase 7.
-- ============================================================================

create table public.data_access_log (
  id bigint generated always as identity,
  accessor_profile_id uuid references public.profiles(id) on delete set null,
  accessor_role public.user_role,
  accessor_ip inet,
  target_profile_id uuid references public.profiles(id) on delete set null,
  target_table text not null,
  target_field text,
  target_id uuid,
  access_type text not null,
  purpose text,
  was_authorized boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (id, created_at),
  constraint data_access_log_target_table_not_blank_check
    check (length(btrim(target_table)) > 0),
  constraint data_access_log_access_type_check
    check (access_type in ('read', 'export', 'modify'))
) partition by range (created_at);

comment on table public.data_access_log is
  'PDPC personal-data access record, partitioned monthly for seven years. Service-role reads must be logged explicitly by Edge Functions.';

create table public.data_access_log_default
  partition of public.data_access_log default;
revoke all on table public.data_access_log_default from anon, authenticated;

select private.ensure_monthly_partitions('public', 'data_access_log', 'created_at', 84);

create table public.retention_policies (
  id uuid primary key default gen_random_uuid(),
  table_name text not null unique,
  retention_period interval not null,
  action text not null,
  last_run_at timestamptz,
  last_run_rows_affected bigint,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint retention_policies_table_name_not_blank_check
    check (length(btrim(table_name)) > 0),
  constraint retention_policies_period_positive_check
    check (retention_period > interval '0'),
  constraint retention_policies_action_check
    check (action in ('delete', 'archive', 'anonymize')),
  constraint retention_policies_rows_check
    check (last_run_rows_affected is null or last_run_rows_affected >= 0)
);

comment on table public.retention_policies is
  'Declarative retention catalogue consumed by public.apply_retention_policies().';

create trigger trg_retention_policies_updated_at
  before update on public.retention_policies
  for each row execute function public.set_updated_at();
