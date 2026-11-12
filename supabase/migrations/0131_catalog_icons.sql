-- ============================================================================
-- SafeShift — Migration 0131
-- Catalogue icons (vehicle categories and cargo types).
--
-- Problem
-- -------
-- The vehicle and cargo catalogues are database rows (public.vehicle_types,
-- public.cargo_types) and both tables already carry an `icon_url` column, but
-- nothing ever used it:
--
--   * the column was NULL for every seeded row;
--   * there was no bucket to serve icons from;
--   * the mobile apps picked an icon by matching keywords against the row's
--     code and name ("if the name contains 'truck', draw a truck"), which is a
--     hard-coded catalogue living in the client.
--
-- Fix
-- ---
--   1. A public `catalog-icons` storage bucket that holds the artwork.
--   2. `icon_url` populated for every catalogue row, pointing at the object
--      path inside that bucket.
--   3. The driver RPCs return the catalogue ids and icon paths, so a job
--      sheet can show the same icon the customer picked.
--
-- The stored value is a bucket-relative path ("vehicle/pickup.svg"), not an
-- absolute URL: the same row then works on the local stack, on staging, and in
-- production, because the app resolves the path against its own Supabase
-- project URL. An absolute https:// value is still honoured.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Storage bucket
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catalog-icons', 'catalog-icons', true, 262144,
  array['image/svg+xml','image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

-- The bucket is public: catalogue artwork is not sensitive, and the mobile
-- apps load it straight from the CDN without an authenticated request.
--
-- SVG is allowed because the apps tint it with the surrounding text colour.
-- Only staff who already manage the catalogues can write here, so the
-- artwork is trusted input.
create policy catalog_icons_storage_select
  on storage.objects for select to public
  using (bucket_id = 'catalog-icons');

-- Only staff who already manage the catalogues may change the artwork.
create policy catalog_icons_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'catalog-icons'
    and (
      (select public.has_permission('manage_vehicle_catalog'))
      or (select public.has_permission('manage_cargo_catalog'))
    )
  );

create policy catalog_icons_storage_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'catalog-icons'
    and (
      (select public.has_permission('manage_vehicle_catalog'))
      or (select public.has_permission('manage_cargo_catalog'))
    )
  )
  with check (
    bucket_id = 'catalog-icons'
    and (
      (select public.has_permission('manage_vehicle_catalog'))
      or (select public.has_permission('manage_cargo_catalog'))
    )
  );

create policy catalog_icons_storage_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'catalog-icons'
    and (
      (select public.has_permission('manage_vehicle_catalog'))
      or (select public.has_permission('manage_cargo_catalog'))
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Icon paths on the catalogue rows
-- ----------------------------------------------------------------------------
-- Every vehicle type gets "vehicle/<code>.svg" and every cargo type gets
-- "cargo/<code>.svg". Rows that already point somewhere are left alone, so
-- an operator can override the artwork for a single market.
update public.vehicle_types
   set icon_url = 'vehicle/' || code || '.svg'
 where icon_url is null;

update public.cargo_types
   set icon_url = 'cargo/' || code || '.svg'
 where icon_url is null;

comment on column public.vehicle_types.icon_url is
  'Path of the icon inside the public catalog-icons bucket ("vehicle/<code>.svg"), or an absolute URL. Resolved by the mobile apps against their Supabase project URL.';

comment on column public.cargo_types.icon_url is
  'Path of the icon inside the public catalog-icons bucket ("cargo/<code>.svg"), or an absolute URL. Resolved by the mobile apps against their Supabase project URL.';

-- ----------------------------------------------------------------------------
-- 3. Client RPCs: expose the catalogue ids and icons
-- ----------------------------------------------------------------------------
-- The job sheets show the cargo type and the vehicle class of the job. They
-- used to receive the names only, which left nothing to draw an icon from.
-- The ids and the icon paths are added alongside the existing columns, so the
-- clients keep working unchanged.
drop function if exists public.driver_pending_offers();
drop function if exists public.driver_active_job();
drop function if exists public.driver_trips(integer);
drop function if exists public.customer_jobs(integer);
drop function if exists public.customer_job(uuid);

create function public.customer_jobs(p_limit integer default 50)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  completed_at timestamptz,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  payment_method public.payment_method
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
    j.completed_at,
    j.driver_id,
    coalesce(dp.full_name, dp.display_name),
    dp.phone,
    d.rating,
    vt.name,
    vt.id,
    vt.icon_url,
    ct.name,
    ct.id,
    ct.icon_url,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.customer_id = auth.uid()
  order by j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

comment on function public.customer_jobs(integer) is
  'Flattened customer job history for the mobile app. Caller sees only their own jobs. Includes the cargo and vehicle catalogue ids and icon paths.';

revoke all on function public.customer_jobs(integer) from public;
revoke all on function public.customer_jobs(integer) from anon;
grant execute on function public.customer_jobs(integer) to authenticated, service_role;

create function public.customer_job(p_job_id uuid)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  completed_at timestamptz,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  driver_verified boolean,
  driver_lat double precision,
  driver_lng double precision,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  payment_method public.payment_method
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
    j.completed_at,
    j.driver_id,
    coalesce(dp.full_name, dp.display_name),
    dp.phone,
    d.rating,
    d.verification_status = 'verified',
    case when d.current_location is null then null
         else extensions.ST_Y(d.current_location::extensions.geometry) end,
    case when d.current_location is null then null
         else extensions.ST_X(d.current_location::extensions.geometry) end,
    vt.name,
    vt.id,
    vt.icon_url,
    ct.name,
    ct.id,
    ct.icon_url,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.id = p_job_id
    and (
      j.customer_id = auth.uid()
      or j.driver_id = auth.uid()
      or public.has_permission('view_all_jobs')
    );
$$;

comment on function public.customer_job(uuid) is
  'Single flattened job for customer tracking/deep links. Participants and staff only. Includes the cargo and vehicle catalogue ids and icon paths.';

revoke all on function public.customer_job(uuid) from public;
revoke all on function public.customer_job(uuid) from anon;
grant execute on function public.customer_job(uuid) to authenticated, service_role;

create function public.driver_pending_offers()
returns table (
  offer_id uuid,
  job_id uuid,
  expires_at timestamptz,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  customer_name text,
  customer_phone text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.id,
    o.job_id,
    o.expires_at,
    o.distance_to_pickup_km,
    o.eta_minutes,
    qr.pickup_address,
    qr.destination_address,
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    ct.name,
    ct.id,
    ct.icon_url,
    vt.name,
    vt.id,
    vt.icon_url,
    coalesce(cp.full_name, cp.display_name),
    cp.phone
  from public.job_offers o
  join public.jobs j on j.id = o.job_id
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where o.driver_id = auth.uid()
    and o.response = 'pending'
    and o.expires_at > now()
    and j.status in ('requested', 'quoted', 'matched')
  order by o.offered_at;
$$;

comment on function public.driver_pending_offers() is
  'Flattened pending offer inbox for the authenticated driver. Includes the cargo and vehicle catalogue ids and icon paths.';

revoke all on function public.driver_pending_offers() from public;
revoke all on function public.driver_pending_offers() from anon;
grant execute on function public.driver_pending_offers() to authenticated, service_role;

create function public.driver_active_job()
returns table (
  offer_id uuid,
  job_id uuid,
  status public.job_status,
  expires_at timestamptz,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  customer_name text,
  customer_phone text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    null::uuid,
    j.id,
    j.status,
    null::timestamptz,
    null::numeric,
    null::integer,
    qr.pickup_address,
    qr.destination_address,
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    ct.name,
    ct.id,
    ct.icon_url,
    vt.name,
    vt.id,
    vt.icon_url,
    coalesce(cp.full_name, cp.display_name),
    cp.phone
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.driver_id = auth.uid()
    and j.status in (
      'accepted', 'heading_to_pickup', 'arrived', 'loading', 'in_transit', 'delivered'
    )
  order by j.accepted_at desc nulls last
  limit 1;
$$;

comment on function public.driver_active_job() is
  'The authenticated driver''s current assigned job, if any. Includes the cargo and vehicle catalogue ids and icon paths.';

revoke all on function public.driver_active_job() from public;
revoke all on function public.driver_active_job() from anon;
grant execute on function public.driver_active_job() to authenticated, service_role;

create function public.driver_trips(p_limit integer default 100)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  completed_at timestamptz,
  customer_name text,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
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
    j.completed_at,
    coalesce(cp.full_name, cp.display_name),
    ct.name,
    ct.id,
    ct.icon_url,
    vt.name,
    vt.id,
    vt.icon_url
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.driver_id = auth.uid()
    and j.status in ('completed', 'cancelled', 'delivered')
  order by j.completed_at desc nulls last, j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
$$;

comment on function public.driver_trips(integer) is
  'Flattened completed/cancelled trips for the authenticated driver. Includes the cargo and vehicle catalogue ids and icon paths.';

revoke all on function public.driver_trips(integer) from public;
revoke all on function public.driver_trips(integer) from anon;
grant execute on function public.driver_trips(integer) to authenticated, service_role;

-- The vehicle card in the driver app shows the vehicle class. It needs the
-- same ids and icon path as the job sheets.
create or replace function public.driver_vehicle_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', v.id,
    'registration_number', v.registration_number,
    'vehicle_type', vt.name,
    'vehicle_type_id', vt.id,
    'vehicle_type_code', vt.code,
    'vehicle_type_icon_url', vt.icon_url,
    'make', vm.name,
    'model', vmo.name,
    'year', v.year,
    'color', v.color,
    'capacity_kg', v.capacity_kg,
    'capacity_m3', v.capacity_m3,
    'verification_status', v.verification_status,
    'is_active', v.is_active,
    'photo_urls', v.photo_urls
  )
  from public.drivers d
  join public.vehicles v on v.id = d.current_vehicle_id
  join public.vehicle_types vt on vt.id = v.vehicle_type_id
  left join public.vehicle_makes vm on vm.id = v.make_id
  left join public.vehicle_models vmo on vmo.id = v.model_id
  where d.id = auth.uid();
$$;

comment on function public.driver_vehicle_info() is
  'Current vehicle for the authenticated driver, including the vehicle catalogue id and icon path.';
