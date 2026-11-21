-- When dispatch finds no online driver with the booked vehicle class, the
-- customer app offers other classes that do have drivers nearby. This counts,
-- per vehicle type, the drivers that would pass every match_dispatch filter
-- except the vehicle-type one. Only counts are exposed, never driver identity
-- or location.

create or replace function public.job_available_vehicle_types(
  p_job_id uuid,
  p_radius_km numeric default 15
)
returns table (vehicle_type_id uuid, driver_count integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor    uuid := auth.uid();
  v_job      public.jobs%rowtype;
  v_pickup   extensions.geography;
  v_radius_m numeric;
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or v_actor = v_job.customer_id
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to inspect job %', p_job_id
      using errcode = '42501';
  end if;

  if p_radius_km is null or p_radius_km <= 0 then
    raise exception 'radius_km must be > 0' using errcode = '22023';
  end if;
  v_radius_m := least(p_radius_km, 50) * 1000;

  select qr.pickup_location
    into v_pickup
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  if v_pickup is null then
    return;
  end if;

  return query
  select v.vehicle_type_id, count(*)::integer
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and not exists (
       select 1 from public.jobs aj
       where aj.driver_id = d.id
         and aj.status between 'accepted' and 'delivered'
     )
     and not exists (
       select 1 from public.job_offers po
       where po.driver_id = d.id
         and po.job_id <> p_job_id
         and po.response = 'pending'
         and po.expires_at > now()
     )
     and extensions.ST_DWithin(d.current_location, v_pickup, v_radius_m)
   group by v.vehicle_type_id;
end;
$$;

revoke all on function public.job_available_vehicle_types(uuid, numeric) from public, anon;
grant execute on function public.job_available_vehicle_types(uuid, numeric) to authenticated, service_role;
