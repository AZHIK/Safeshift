-- ============================================================================
-- SafeShift — Phase 3 / Migration 0037
-- Wire Phase 1's zone_pricing_overrides.pricing_plan_id to Phase 3 pricing
-- plan versions.
--
-- Dependency note: pricing_plan_versions is created in migration 0040, so the
-- constraint cannot be added unconditionally here. This migration installs the
-- idempotent constraint routine and invokes it; 0040 invokes the same routine
-- again after the target table exists. The end state is one FK:
--
--   zone_pricing_overrides.pricing_plan_id
--     -> pricing_plan_versions(id) ON DELETE RESTRICT
--
-- The column is intentionally not backfilled: Phase 2 ends with the table
-- historically empty, and seed data/back-office tooling decides which version
-- an override applies to.
-- ============================================================================

create or replace function private.ensure_zone_pricing_override_fk()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if to_regclass('public.pricing_plan_versions') is null then
    return;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.zone_pricing_overrides'::regclass
      and conname = 'zone_pricing_overrides_pricing_plan_id_fkey'
  ) then
    alter table public.zone_pricing_overrides
      add constraint zone_pricing_overrides_pricing_plan_id_fkey
      foreign key (pricing_plan_id)
      references public.pricing_plan_versions (id)
      on delete restrict;
  end if;
end;
$$;

comment on function private.ensure_zone_pricing_override_fk() is
  'Idempotently adds the zone_pricing_overrides -> pricing_plan_versions FK once the target table exists.';

revoke all on function private.ensure_zone_pricing_override_fk() from public;
revoke all on function private.ensure_zone_pricing_override_fk() from anon;
revoke all on function private.ensure_zone_pricing_override_fk() from authenticated;

select private.ensure_zone_pricing_override_fk();

comment on column public.zone_pricing_overrides.pricing_plan_id is
  'Phase 3 pricing plan version this override applies to. FK is created by private.ensure_zone_pricing_override_fk() after pricing_plan_versions exists.';
