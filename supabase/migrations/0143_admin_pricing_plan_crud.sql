-- Admin CRUD helper for pricing plans.
--
-- A pricing plan is not useful without a published version and base rates, so
-- this helper creates the plan, its first version, and the base-rate row in one
-- transaction and publishes the version immediately. There is no fallback price:
-- if no active published plan matches a booking, quote_calculate_and_persist
-- raises "no active pricing plan".
create or replace function public.admin_create_pricing_plan(
  p_country_id uuid,
  p_city_id uuid,
  p_vehicle_type_id uuid,
  p_code text,
  p_name text,
  p_description text default null,
  p_service_zone_id uuid default null,
  p_currency_code char(3) default 'TZS',
  p_base_fare numeric default 0,
  p_per_km_rate numeric default 0,
  p_per_min_rate numeric default 0,
  p_minimum_charge numeric default 0,
  p_vat_rate numeric default 0.18
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_plan_id uuid := gen_random_uuid();
  v_version_id uuid := gen_random_uuid();
  v_city_country uuid;
  v_zone_city uuid;
  v_vehicle_country uuid;
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;

  if p_country_id is null or p_city_id is null or p_vehicle_type_id is null then
    raise exception 'country, city and vehicle type are required' using errcode = '22004';
  end if;
  if p_code is null or btrim(p_code) = '' then
    raise exception 'code is required' using errcode = '22004';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'name is required' using errcode = '22004';
  end if;

  select c.country_id into v_city_country
  from public.cities c where c.id = p_city_id;
  if v_city_country is null then
    raise exception 'city % does not exist', p_city_id using errcode = '23503';
  end if;
  if v_city_country <> p_country_id then
    raise exception 'city does not belong to the selected country' using errcode = '23514';
  end if;

  if p_service_zone_id is not null then
    select sz.city_id into v_zone_city
    from public.service_zones sz where sz.id = p_service_zone_id;
    if v_zone_city is null then
      raise exception 'service zone % does not exist', p_service_zone_id using errcode = '23503';
    end if;
    if v_zone_city <> p_city_id then
      raise exception 'service zone does not belong to the selected city' using errcode = '23514';
    end if;
  end if;

  select vt.country_id into v_vehicle_country
  from public.vehicle_types vt where vt.id = p_vehicle_type_id;
  if v_vehicle_country is not null and v_vehicle_country <> p_country_id then
    raise exception 'vehicle type does not belong to the selected country' using errcode = '23514';
  end if;

  insert into public.pricing_plans (
    id, country_id, city_id, service_zone_id, vehicle_type_id, code, name, description, is_active
  ) values (
    v_plan_id, p_country_id, p_city_id, p_service_zone_id, p_vehicle_type_id,
    p_code, p_name, p_description, true
  );

  insert into public.pricing_plan_versions (
    id, pricing_plan_id, version_number, currency_code, effective_from,
    published_at, published_by
  ) values (
    v_version_id, v_plan_id, 1, p_currency_code, now(), now(), v_actor
  );

  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate,
    minimum_charge, vat_rate
  ) values (
    v_version_id, p_currency_code, p_base_fare, p_per_km_rate, p_per_min_rate,
    p_minimum_charge, p_vat_rate
  );

  return v_plan_id;
end;
$$;

comment on function public.admin_create_pricing_plan(
  uuid, uuid, uuid, text, text, text, uuid, char, numeric, numeric, numeric, numeric, numeric
) is
  'Creates a pricing plan with its first published version and base rates in one transaction.';

revoke all on function public.admin_create_pricing_plan(
  uuid, uuid, uuid, text, text, text, uuid, char, numeric, numeric, numeric, numeric, numeric
) from public;
revoke all on function public.admin_create_pricing_plan(
  uuid, uuid, uuid, text, text, text, uuid, char, numeric, numeric, numeric, numeric, numeric
) from anon;
grant execute on function public.admin_create_pricing_plan(
  uuid, uuid, uuid, text, text, text, uuid, char, numeric, numeric, numeric, numeric, numeric
) to authenticated, service_role;

create or replace function public.admin_deactivate_pricing_plan(p_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;
  update public.pricing_plans set is_active = false where id = p_plan_id;
end;
$$;

revoke all on function public.admin_deactivate_pricing_plan(uuid) from public;
revoke all on function public.admin_deactivate_pricing_plan(uuid) from anon;
grant execute on function public.admin_deactivate_pricing_plan(uuid) to authenticated, service_role;
