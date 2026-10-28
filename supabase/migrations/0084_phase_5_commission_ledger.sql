-- ============================================================================
-- SafeShift — Phase 5 / Migration 0084
-- Immutable commission ledger, partitioned monthly.
--
-- A UUID id is used instead of the generic BIGINT identity because payout_items
-- and fleet_billing_events reference this ledger by UUID, and
-- calculate_and_record_commission() returns that id. One commission row per
-- job is enforced by a trigger in 0092 (PostgreSQL cannot put a global UNIQUE
-- constraint on a table partitioned by calculated_at without including the
-- partition key in the constraint).
-- ============================================================================

create table public.commission_ledger (
  id                     uuid default gen_random_uuid(),
  job_id                 uuid not null references public.jobs (id) on delete restrict,
  driver_id              uuid not null references public.drivers (id) on delete restrict,
  rule_id                uuid references public.commission_rules (id) on delete set null,
  commission_amount      numeric(14,2) not null,
  commission_rate        numeric(14,4),
  currency_code          char(3) not null references public.currencies (code) on update cascade on delete restrict,
  driver_gross_earning   numeric(14,2) not null,
  driver_net_earning     numeric(14,2) not null,
  withholding_tax_amount numeric(14,2) not null default 0,
  is_refunded            boolean not null default false,
  calculated_at          timestamptz not null default now(),
  created_at             timestamptz not null default now(),

  primary key (id, calculated_at),
  constraint commission_ledger_commission_check check (commission_amount >= 0),
  constraint commission_ledger_gross_check check (driver_gross_earning >= 0),
  constraint commission_ledger_net_check check (driver_net_earning >= 0),
  constraint commission_ledger_withholding_check check (withholding_tax_amount >= 0),
  constraint commission_ledger_net_not_above_gross_check
    check (driver_net_earning <= driver_gross_earning)
) partition by range (calculated_at);

comment on table public.commission_ledger is
  'Immutable per-job commission calculation partitioned monthly. The one-row-per-job rule is enforced by the ledger guard trigger.';

comment on column public.commission_ledger.driver_net_earning is
  'Driver gross earning minus platform commission, before withholding tax (which is stored separately).';

create table if not exists public.commission_ledger_default
  partition of public.commission_ledger default;

create or replace function private.ensure_commission_ledger_partitions(p_months_ahead integer default 12)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base  date := date_trunc('month', now())::date;
  v_i     integer;
  v_name  text;
  v_count integer := 0;
begin
  if p_months_ahead is null or p_months_ahead < 1 then
    raise exception 'p_months_ahead must be >= 1';
  end if;

  for v_i in 0..(p_months_ahead - 1) loop
    v_name := 'commission_ledger_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.commission_ledger for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

comment on function private.ensure_commission_ledger_partitions(integer) is
  'Creates missing monthly commission_ledger partitions.';

revoke all on function private.ensure_commission_ledger_partitions(integer) from public;
revoke all on function private.ensure_commission_ledger_partitions(integer) from anon;
revoke all on function private.ensure_commission_ledger_partitions(integer) from authenticated;
grant execute on function private.ensure_commission_ledger_partitions(integer) to service_role;

do $$
declare
  v_base date := date_trunc('month', now())::date;
  v_i    integer;
  v_name text;
begin
  for v_i in 0..11 loop
    v_name := 'commission_ledger_' || to_char(v_base + make_interval(months => v_i), 'YYYY_MM');

    if to_regclass('public.' || v_name) is null then
      execute format(
        'create table public.%I partition of public.commission_ledger for values from (%L) to (%L)',
        v_name,
        v_base + make_interval(months => v_i),
        v_base + make_interval(months => v_i + 1)
      );
      execute format('revoke all on table public.%I from anon, authenticated', v_name);
    end if;
  end loop;
end $$;
