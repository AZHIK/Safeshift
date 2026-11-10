-- ============================================================================
-- SafeShift — Phase 8+ / Migration 0128
-- Customer place/address RPCs for mobile clients.
--
-- Returns lat/lng as plain numbers so clients don't need to parse PostGIS
-- geography text/binary formats. Search includes the customer's own saved
-- addresses and, as a safe catalog fallback, active neighborhoods.
-- ============================================================================
-- 1. Saved places with coordinates
-- ----------------------------------------------------------------------------
create or replace function public.customer_saved_places()
returns table (
  place_id uuid,
  address_id uuid,
  label text,
  name text,
  district text,
  latitude double precision,
  longitude double precision,
  is_default boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    sa.id,
    sa.address_id,
    sa.label,
    coalesce(nullif(btrim(sa.label), ''), a.line_1) as name,
    coalesce(n.name, c.name, a.landmark, '') as district,
    extensions.st_y(a.location::extensions.geometry) as latitude,
    extensions.st_x(a.location::extensions.geometry) as longitude,
    sa.is_default
  from public.saved_addresses sa
  join public.addresses a on a.id = sa.address_id
  left join public.neighborhoods n on n.id = a.neighborhood_id
  left join public.cities c on c.id = a.city_id
  where sa.profile_id = auth.uid()
    and a.location is not null
  order by sa.is_default desc, sa.created_at desc;
$$;

comment on function public.customer_saved_places() is
  'Returns the authenticated customer''s saved addresses with lat/lng for mobile selection.';

revoke all on function public.customer_saved_places() from public;
revoke all on function public.customer_saved_places() from anon;
grant execute on function public.customer_saved_places() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Place search with coordinates
-- ----------------------------------------------------------------------------
create or replace function public.customer_search_places(
  p_query text default '',
  p_limit integer default 20
)
returns table (
  place_id text,
  address_id uuid,
  label text,
  name text,
  district text,
  latitude double precision,
  longitude double precision,
  source text
)
language sql
stable
security definer
set search_path = ''
as $$
  with q as (
    select nullif(btrim(coalesce(p_query, '')), '') as term,
           greatest(1, least(coalesce(p_limit, 20), 50)) as lim
  ),
  saved as (
    select
      sa.id::text as place_id,
      sa.address_id,
      sa.label,
      coalesce(nullif(btrim(sa.label), ''), a.line_1) as name,
      coalesce(n.name, c.name, a.landmark, '') as district,
      extensions.st_y(a.location::extensions.geometry) as latitude,
      extensions.st_x(a.location::extensions.geometry) as longitude,
      'saved'::text as source,
      sa.is_default,
      sa.created_at
    from public.saved_addresses sa
    join public.addresses a on a.id = sa.address_id
    left join public.neighborhoods n on n.id = a.neighborhood_id
    left join public.cities c on c.id = a.city_id
    cross join q
    where sa.profile_id = auth.uid()
      and a.location is not null
      and (
        q.term is null
        or sa.label ilike '%' || q.term || '%'
        or a.line_1 ilike '%' || q.term || '%'
        or coalesce(a.landmark, '') ilike '%' || q.term || '%'
      )
  ),
  own as (
    select
      a.id::text as place_id,
      a.id as address_id,
      null::text as label,
      a.line_1 as name,
      coalesce(n.name, c.name, a.landmark, '') as district,
      extensions.st_y(a.location::extensions.geometry) as latitude,
      extensions.st_x(a.location::extensions.geometry) as longitude,
      'address'::text as source,
      false as is_default,
      a.created_at
    from public.addresses a
    left join public.neighborhoods n on n.id = a.neighborhood_id
    left join public.cities c on c.id = a.city_id
    cross join q
    where a.created_by = auth.uid()
      and a.location is not null
      and q.term is not null
      and (
        a.line_1 ilike '%' || q.term || '%'
        or coalesce(a.landmark, '') ilike '%' || q.term || '%'
        or coalesce(a.line_2, '') ilike '%' || q.term || '%'
      )
      and not exists (
        select 1 from public.saved_addresses sa
        where sa.address_id = a.id and sa.profile_id = auth.uid()
      )
  ),
  catalog as (
    select
      ('neighborhood:' || n.id::text) as place_id,
      null::uuid as address_id,
      null::text as label,
      n.name as name,
      coalesce(c.name, '') as district,
      extensions.st_y(n.centroid::extensions.geometry) as latitude,
      extensions.st_x(n.centroid::extensions.geometry) as longitude,
      'neighborhood'::text as source,
      false as is_default,
      n.created_at
    from public.neighborhoods n
    left join public.cities c on c.id = n.city_id
    cross join q
    where n.is_active
      and n.centroid is not null
      and q.term is not null
      and n.name ilike '%' || q.term || '%'
  )
  select place_id, address_id, label, name, district, latitude, longitude, source
  from (
    select * from saved
    union all
    select * from own
    union all
    select * from catalog
  ) x
  order by
    case source when 'saved' then 0 when 'address' then 1 else 2 end,
    is_default desc,
    created_at desc
  limit (select lim from q);
$$;

comment on function public.customer_search_places(text, integer) is
  'Searches saved/user addresses and active neighborhoods for customer pickup/destination selection. Returns lat/lng.';

revoke all on function public.customer_search_places(text, integer) from public;
revoke all on function public.customer_search_places(text, integer) from anon;
grant execute on function public.customer_search_places(text, integer) to authenticated, service_role;
