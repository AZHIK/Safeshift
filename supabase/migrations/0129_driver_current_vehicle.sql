-- ============================================================================
-- SafeShift — Migration 0129
-- Driver "current vehicle" assignment.
--
-- Problem
-- -------
-- public.drivers.current_vehicle_id is the pivot the whole dispatch chain
-- depends on:
--
--   * match_dispatch() joins  vehicles v on v.id = d.current_vehicle_id
--   * accept_job_offer() coalesces p_vehicle_id with
--     d.current_vehicle_id and raises "driver % has no vehicle" without it.
--
-- But nothing ever populated it:
--
--   * no migration or RPC ever wrote the column;
--   * trg_drivers_protect_privileged (migration 0014) rejects any change to
--     current_vehicle_id unless the caller holds 'verify_driver', so the
--     driver could not set it either;
--   * the driver app only ever SELECTed it.
--
-- Because the join is an INNER join on a NULL column, match_dispatch() matched
-- zero drivers for every job on every project. The customer app then reported
-- "No verified drivers are nearby right now." even with a verified, available
-- driver standing on the same street.
--
-- Fix
-- ---
--   1. Backfill current_vehicle_id from the driver's own verified vehicle.
--   2. Add driver_set_current_vehicle(), the only sanctioned way for a driver
--      to change the pointer. It runs SECURITY DEFINER, so it is server
--      controlled like every other privileged driver field, and it validates
--      that the driver actually owns or is assigned the vehicle.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Backfill
-- ----------------------------------------------------------------------------
-- Only vehicles that are active and verified, and only one per driver: the
-- most recently created one wins.
with ranked as (
  select
    v.primary_driver_id as driver_id,
    v.id as vehicle_id,
    row_number() over (
      partition by v.primary_driver_id
      order by v.created_at desc, v.id desc
    ) as rn
  from public.vehicles v
  where v.primary_driver_id is not null
    and v.is_active
    and v.verification_status = 'verified'
)
update public.drivers d
   set current_vehicle_id = ranked.vehicle_id,
       updated_at = now()
  from ranked
 where ranked.driver_id = d.id
   and ranked.rn = 1
   and d.current_vehicle_id is null;

comment on column public.drivers.current_vehicle_id is
  'The vehicle this driver currently operates. Set through public.driver_set_current_vehicle(). Dispatch joins on it, so it must not be NULL for an available driver.';

-- ----------------------------------------------------------------------------
-- 2. public.driver_set_current_vehicle()
-- ----------------------------------------------------------------------------
create or replace function public.driver_set_current_vehicle(p_vehicle_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_vehicle public.vehicles%rowtype;
begin
  if not exists (select 1 from public.drivers d where d.id = v_uid) then
    raise exception 'driver % not found', v_uid using errcode = 'P0002';
  end if;

  -- NULL clears the pointer, so a driver can park a broken vehicle.
  if p_vehicle_id is null then
    update public.drivers
       set current_vehicle_id = null,
           updated_at = now()
     where id = v_uid;
    return null;
  end if;

  select * into v_vehicle from public.vehicles where id = p_vehicle_id;
  if not found then
    raise exception 'vehicle % not found', p_vehicle_id using errcode = 'P0002';
  end if;

  if not v_vehicle.is_active
     or v_vehicle.verification_status <> 'verified'
  then
    raise exception 'vehicle % is not active and verified', p_vehicle_id
      using errcode = '23514';
  end if;

  -- The driver must own the vehicle or hold an active assignment for it.
  if v_vehicle.primary_driver_id is distinct from v_uid
     and not exists (
       select 1
         from public.vehicle_assignments va
        where va.vehicle_id = v_vehicle.id
          and va.driver_id = v_uid
          and va.is_active
          and va.unassigned_at is null
     )
  then
    raise exception 'vehicle % is not assigned to you', p_vehicle_id
      using errcode = '42501';
  end if;

  update public.drivers
     set current_vehicle_id = p_vehicle_id,
         updated_at = now()
   where id = v_uid;

  return p_vehicle_id;
end;
$$;

comment on function public.driver_set_current_vehicle(uuid) is
  'Sets the calling driver''s current vehicle. The vehicle must be active, verified, and owned by or actively assigned to the driver.';

revoke all on function public.driver_set_current_vehicle(uuid) from public;
revoke all on function public.driver_set_current_vehicle(uuid) from anon;
grant execute on function public.driver_set_current_vehicle(uuid) to authenticated, service_role;
