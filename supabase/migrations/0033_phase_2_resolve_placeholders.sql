-- ============================================================================
-- SafeShift — Phase 2 / Migration 0033
-- Resolve the Phase 1 drivers placeholders now that vehicles and fleets exist.
-- FK to pricing_plans will be added in Phase 3.
-- ============================================================================

alter table public.drivers
  add constraint drivers_current_vehicle_id_fkey
  foreign key (current_vehicle_id) references public.vehicles (id) on delete set null;

alter table public.drivers
  add constraint drivers_current_fleet_id_fkey
  foreign key (current_fleet_id) references public.fleets (id) on delete set null;

comment on column public.drivers.current_vehicle_id is
  'Current active vehicle; FK added in Phase 2 and cleared when the vehicle is removed.';
comment on column public.drivers.current_fleet_id is
  'Current active fleet; FK added in Phase 2 and cleared when the fleet is removed.';

-- FK to pricing_plans will be added in Phase 3.
