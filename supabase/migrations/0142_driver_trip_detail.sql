-- The driver trip-detail route opens a single trip by id. Resolving it from the
-- history page would fail for trips older than the page limit, so expose a
-- dedicated lookup that returns exactly one row owned by the authenticated
-- driver. The column shape mirrors driver_trips(integer) so both endpoints can
-- share one client mapper.
create or replace function public.driver_trip_detail(p_job_id uuid)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  scheduled_at timestamptz,
  completed_at timestamptz,
  customer_name text,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    j.id,
    j.status,
    qr.pickup_address,
    qr.destination_address,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.scheduled_at,
    j.completed_at,
    coalesce(cp.full_name, cp.display_name),
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    vt.name,
    vt.id,
    vt.icon_url
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.id = p_job_id
    and j.driver_id = auth.uid()
    and j.status in ('completed', 'cancelled', 'delivered')
  limit 1;
$$;

comment on function public.driver_trip_detail(uuid) is
  'One completed/cancelled trip owned by the authenticated driver, including parcel details. Returns no row for foreign, active, or unknown jobs.';

revoke all on function public.driver_trip_detail(uuid) from public;
revoke all on function public.driver_trip_detail(uuid) from anon;
grant execute on function public.driver_trip_detail(uuid)
  to authenticated, service_role;
