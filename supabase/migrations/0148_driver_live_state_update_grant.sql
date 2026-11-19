-- Drivers can change their own availability and publish their own location.
-- The existing drivers_update_own RLS policy limits rows to auth.uid().
-- Verification, risk, earnings, and vehicle assignment fields stay protected.
grant update (is_available, current_location, location_updated_at)
  on public.drivers to authenticated;
