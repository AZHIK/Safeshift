-- Vehicle picker availability.
--
-- Before a job exists, the customer app shows every vehicle that can carry
-- the cargo together with how available it is near the pickup point:
--
--   available  a free driver is within 10 km (the first dispatch rounds)
--   limited    no free driver that close, but a free driver within the widest
--              dispatch radius (25 km) or an online driver who is busy on a
--              job or an offer; booking works, the search may take longer
--   none       nobody online within 25 km; only scheduling makes sense
--
-- Only a status and a rounded ETA leave the database: never driver identity,
-- position or counts. Vehicle types missing from the result are "none".

create or replace function public.vehicle_availability_near(
  p_lat double precision,
  p_lng double precision
)
returns table (vehicle_type_id uuid, status text, eta_min integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pickup extensions.geography;
  -- Must match the widest radius of private.dispatch_radius_km.
  c_near_m constant numeric := 10000;
  c_far_m  constant numeric := 25000;
begin
  if auth.uid() is null and not private.is_service_context() then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90
     or p_lng not between -180 and 180 then
    raise exception 'a valid pickup point is required' using errcode = '22023';
  end if;

  v_pickup := extensions.ST_SetSRID(
    extensions.ST_MakePoint(p_lng, p_lat), 4326
  )::extensions.geography;

  return query
  with online as (
    select v.vehicle_type_id as type_id,
           extensions.ST_Distance(d.current_location, v_pickup) as metres,
           (
             exists (
               select 1 from public.jobs aj
               where aj.driver_id = d.id
                 and aj.status between 'accepted' and 'delivered'
             )
             or exists (
               select 1 from public.job_offers po
               where po.driver_id = d.id
                 and po.response = 'pending'
                 and po.expires_at > now()
             )
           ) as busy
      from public.drivers d
      join public.profiles p on p.id = d.id and p.is_active
      join public.vehicles v on v.id = d.current_vehicle_id
     where d.verification_status = 'verified'
       and d.is_available
       and d.current_location is not null
       and d.location_updated_at > now() - interval '10 minutes'
       and v.is_active
       and v.verification_status = 'verified'
       and extensions.ST_DWithin(d.current_location, v_pickup, c_far_m)
  ),
  per_type as (
    select type_id,
           min(metres) filter (where not busy) as nearest_free_m,
           bool_or(true) as any_online
      from online
     group by type_id
  )
  select type_id,
         case
           when nearest_free_m <= c_near_m then 'available'
           else 'limited'
         end,
         case
           when nearest_free_m is null then null
           -- Straight line x1.4 for roads at ~22 km/h city speed, plus a
           -- minute to accept; never promise less than 3 minutes.
           else greatest(3, ceil(nearest_free_m * 1.4 / 1000 / 22 * 60) + 1)::integer
         end
    from per_type
   where any_online;
end;
$$;

comment on function public.vehicle_availability_near(double precision, double precision) is
  'Per vehicle type near a pickup point: available / limited, with a rounded ETA to the nearest free driver. Missing types have no driver online within 25 km.';

revoke all on function public.vehicle_availability_near(double precision, double precision) from public, anon;
grant execute on function public.vehicle_availability_near(double precision, double precision) to authenticated, service_role;
