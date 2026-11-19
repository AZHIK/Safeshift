-- Geography administration for the operator console.
--
-- Countries, regions, cities, service zones, neighbourhoods and addresses are
-- the hierarchy every quote and booking depends on. The catalogue tables need
-- to be editable from the admin console without handing the browser direct
-- write access to PostGIS columns. The RPCs below are the only write path:
-- they check the caller's permission, accept WKT text for geometry columns and
-- convert it with ST_GeogFromText before the row is written.

-- ----------------------------------------------------------------------------
-- 1. Permission family
-- ----------------------------------------------------------------------------
create or replace function public.config_permission_keys()
returns text[]
language sql
stable
set search_path = ''
as $$
  select array[
    'manage_vehicle_catalog',
    'manage_cargo_catalog',
    'manage_document_types',
    'manage_support',
    'manage_prohibited_items',
    'manage_notifications',
    'manage_localization',
    'manage_features',
    'manage_cancellation_policies',
    'manage_dispatch',
    'manage_ratings',
    'manage_countries',
    'manage_geography'
  ];
$$;

insert into public.admin_permissions_catalog (permission_key, description, category)
values ('manage_geography', 'Create and edit countries, regions, cities, zones and neighbourhoods.', 'operations')
on conflict (permission_key) do nothing;

-- Give the administrator every permission the console knows about. New
-- permissions added later are picked up by the same grant on the next push.
insert into public.admin_role_permissions (role_name, permission_key)
select role_name, permission_key
from (values ('super_admin'::text), ('operations_admin'::text)) as r(role_name)
cross join public.admin_permissions_catalog
on conflict (role_name, permission_key) do nothing;

-- ----------------------------------------------------------------------------
-- 2. Write path
-- ----------------------------------------------------------------------------
create or replace function public.admin_write_geography(
  p_table text,
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed     text[] := array['regions', 'cities', 'service_zones', 'neighborhoods', 'addresses', 'zone_pricing_overrides'];
  v_geometries  text[] := array['boundary', 'centroid', 'location'];
  v_keys        text[];
  v_geom_keys   text[];
  v_col_list    text;
  v_val_list    text;
  v_assignments text;
  v_key         text;
  v_id          uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (
    public.has_permission('manage_geography')
    or public.has_permission('manage_countries')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  if not p_table = any(v_allowed) then
    raise exception 'unsupported geography table %', p_table using errcode = '22023';
  end if;

  v_keys := coalesce(
    array(
      select key
        from jsonb_object_keys(p_payload) as key
       where key not in ('id', 'boundary', 'centroid', 'location')
    ),
    array[]::text[]
  );
  v_geom_keys := coalesce(
    array(
      select key
        from unnest(v_geometries) as key
       where p_payload ? key
         and nullif(p_payload ->> key, '') is not null
    ),
    array[]::text[]
  );

  -- Fail before any write if an operator supplied malformed WKT.
  foreach v_key in array v_geom_keys loop
    perform extensions.ST_GeogFromText(p_payload ->> v_key);
  end loop;

  if p_action = 'create' then
    select
      string_agg(format('%I', key), ', ' order by key),
      string_agg(
        format('(jsonb_populate_record(null::public.%I, $1)).%I', p_table, key),
        ', ' order by key
      )
      into v_col_list, v_val_list
      from unnest(v_keys) as key;

    if array_length(v_geom_keys, 1) > 0 then
      v_col_list := concat_ws(', ', v_col_list,
        (select string_agg(format('%I', key), ', ' order by key) from unnest(v_geom_keys) as key));
      v_val_list := concat_ws(', ', v_val_list,
        (select string_agg(
          format('extensions.ST_GeogFromText(($1->>%L)::text)', key),
          ', ' order by key
        ) from unnest(v_geom_keys) as key));
    end if;

    if v_col_list is null or v_col_list = '' then
      execute format('insert into public.%I default values returning id', p_table) into v_id;
    else
      execute format(
        'insert into public.%I (%s) select %s returning id',
        p_table, v_col_list, v_val_list
      ) into v_id using p_payload;
    end if;
    return v_id;

  elsif p_action in ('update', 'deactivate', 'delete') then
    if p_id is null then
      raise exception 'a record id is required' using errcode = '22023';
    end if;
    v_id := p_id;

    if p_action = 'deactivate' then
      execute format('update public.%I set is_active = false where id = $1', p_table) using v_id;
      return v_id;
    end if;
    if p_action = 'delete' then
      execute format('delete from public.%I where id = $1', p_table) using v_id;
      return v_id;
    end if;

    select string_agg(
      format('%I = (jsonb_populate_record(null::public.%I, $1)).%I', key, p_table, key),
      ', ' order by key
    ) into v_assignments from unnest(v_keys) as key;

    if array_length(v_geom_keys, 1) > 0 then
      v_assignments := concat_ws(', ', v_assignments,
        (select string_agg(
          format('%I = extensions.ST_GeogFromText(($1->>%L)::text)', key, key),
          ', ' order by key
        ) from unnest(v_geom_keys) as key));
    end if;

    if v_assignments is not null and v_assignments <> '' then
      execute format('update public.%I set %s where id = $2', p_table, v_assignments)
        using p_payload, v_id;
    end if;
    return v_id;
  end if;

  raise exception 'unsupported geography action %', p_action using errcode = '22023';
end;
$$;

comment on function public.admin_write_geography(text, text, jsonb, uuid) is
  'Writes geography catalogue rows for the operator console, converting WKT strings to PostGIS geography values.';

revoke all on function public.admin_write_geography(text, text, jsonb, uuid) from public, anon;
grant execute on function public.admin_write_geography(text, text, jsonb, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Read path — geometry as WKT for the edit form
-- ----------------------------------------------------------------------------
create or replace function public.admin_geography_wkt(p_table text, p_ids uuid[])
returns table (id uuid, boundary text, centroid text, location text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (
    public.has_permission('manage_geography')
    or public.has_permission('manage_countries')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  if p_table = 'cities' then
    return query
      select c.id, extensions.ST_AsText(c.boundary), null::text, null::text
        from public.cities c where c.id = any(p_ids);
  elsif p_table = 'service_zones' then
    return query
      select z.id, extensions.ST_AsText(z.boundary), extensions.ST_AsText(z.centroid), null::text
        from public.service_zones z where z.id = any(p_ids);
  elsif p_table = 'neighborhoods' then
    return query
      select n.id, extensions.ST_AsText(n.boundary), extensions.ST_AsText(n.centroid), null::text
        from public.neighborhoods n where n.id = any(p_ids);
  elsif p_table = 'addresses' then
    return query
      select a.id, null::text, null::text, extensions.ST_AsText(a.location)
        from public.addresses a where a.id = any(p_ids);
  else
    return query select null::uuid, null::text, null::text, null::text where false;
  end if;
end;
$$;

comment on function public.admin_geography_wkt(text, uuid[]) is
  'Returns geography columns as WKT so the console can show them in a text form field.';

revoke all on function public.admin_geography_wkt(text, uuid[]) from public, anon;
grant execute on function public.admin_geography_wkt(text, uuid[]) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Deactivation guards
-- ----------------------------------------------------------------------------
create or replace function public.admin_geography_reference_counts(p_table text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_counts jsonb := '{}'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (
    public.has_permission('manage_geography')
    or public.has_permission('manage_countries')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  if p_table = 'regions' then
    v_counts := jsonb_build_object(
      'cities', (select count(*) from public.cities where region_id = p_id and is_active)
    );
  elsif p_table = 'cities' then
    v_counts := jsonb_build_object(
      'service_zones',  (select count(*) from public.service_zones where city_id = p_id and is_active),
      'neighborhoods',  (select count(*) from public.neighborhoods where city_id = p_id and is_active),
      'addresses',      (select count(*) from public.addresses where city_id = p_id)
    );
  elsif p_table = 'service_zones' then
    v_counts := jsonb_build_object(
      'neighborhoods',         (select count(*) from public.neighborhoods where service_zone_id = p_id and is_active),
      'addresses',             (select count(*) from public.addresses where neighborhood_id in (select id from public.neighborhoods where service_zone_id = p_id)),
      'zone_pricing_overrides', (select count(*) from public.zone_pricing_overrides where service_zone_id = p_id)
    );
  elsif p_table = 'neighborhoods' then
    v_counts := jsonb_build_object(
      'addresses', (select count(*) from public.addresses where neighborhood_id = p_id)
    );
  end if;

  return v_counts;
end;
$$;

comment on function public.admin_geography_reference_counts(text, uuid) is
  'Live references to a geography row, used by the console deactivation guard.';

revoke all on function public.admin_geography_reference_counts(text, uuid) from public, anon;
grant execute on function public.admin_geography_reference_counts(text, uuid) to authenticated, service_role;
