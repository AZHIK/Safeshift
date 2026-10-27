-- ============================================================================
-- SafeShift — Phase 4 / Migration 0070
-- The authoritative quote engine.
--
-- Phase 3's quote_preview() remains the side-effect-free preview helper. This
-- migration adds the persisted engine used by Phase 5 Edge Functions:
--
--   private.quote_calculate_core(...)      -- fare calculation
--   public.quote_calculate_and_persist(...) -- request + quote persistence
--   public.quote_get_breakdown(uuid)        -- authorised snapshot access
--
-- Decisions implemented here:
--   A  quotes store pricing_plan_version_id plus a JSONB snapshot
--   B  LATRA cap is a maximum total including VAT
--   C  one promo per quote
--   E  the public function accepts waiting_minutes, stop_count, promo_code_id
--   F  active surge is applied on top of the version multipliers
--
-- Plan/version/promo validity and surge selection use now(). Time-of-day
-- multipliers use the scheduled pickup time when one is supplied. Promo
-- discounts apply to the net subtotal; VAT is recalculated on the discounted
-- net, so a promo can never push the total above the regulated cap.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Private calculation core
-- ----------------------------------------------------------------------------
create or replace function private.quote_calculate_core(
  p_pricing_plan_version_id uuid,
  p_distance_km numeric,
  p_duration_min numeric,
  p_weight_kg numeric,
  p_volume_m3 numeric,
  p_cargo_type_id uuid,
  p_equipment_ids uuid[],
  p_zone_id uuid,
  p_waiting_minutes integer,
  p_stop_count integer,
  p_at_time timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_version            public.pricing_plan_versions%rowtype;
  v_base               public.pricing_plan_base_rates%rowtype;
  v_distance_charge    numeric := 0;
  v_time_charge        numeric := 0;
  v_weight_surcharge   numeric := 0;
  v_volume_surcharge   numeric := 0;
  v_cargo_surcharge    numeric := 0;
  v_equipment_surcharge numeric := 0;
  v_waiting_charge     numeric := 0;
  v_multi_stop_charge  numeric := 0;
  v_component          numeric;
  v_component_base     numeric;
  v_pre_multiplier     numeric;
  v_zone_multiplier    numeric := 1;
  v_time_multiplier    numeric := 1;
  v_subtotal           numeric;
  v_vat                numeric;
  v_total              numeric;
  v_pre_cap_total      numeric;
  v_cap                numeric;
  v_is_capped          boolean := false;
  v_min_applied        boolean := false;
  v_tier               record;
  v_weight_tier        record;
  v_volume_tier        record;
  v_cargo              record;
  v_equipment          record;
  v_equipment_id       uuid;
  v_equipment_amount   numeric;
  v_overlap_km         numeric;
  v_covered_km         numeric := 0;
  v_distance_details   jsonb := '[]'::jsonb;
  v_weight_detail      jsonb;
  v_volume_detail      jsonb;
  v_time_details       jsonb := '[]'::jsonb;
  v_equipment_details  jsonb := '[]'::jsonb;
  v_match              record;
  v_local_ts           timestamp;
  v_dow                smallint;
  v_clock              time;
  v_equipment_ids      uuid[] := coalesce(p_equipment_ids, '{}'::uuid[]);
begin
  if p_distance_km is null or p_distance_km < 0 then
    raise exception 'distance_km must be >= 0' using errcode = '22023';
  end if;
  if p_duration_min is null or p_duration_min < 0 then
    raise exception 'duration_min must be >= 0' using errcode = '22023';
  end if;
  if p_weight_kg is not null and p_weight_kg < 0 then
    raise exception 'weight_kg must be >= 0' using errcode = '22023';
  end if;
  if p_volume_m3 is not null and p_volume_m3 < 0 then
    raise exception 'volume_m3 must be >= 0' using errcode = '22023';
  end if;
  if p_waiting_minutes is null or p_waiting_minutes < 0 then
    raise exception 'waiting_minutes must be >= 0' using errcode = '22023';
  end if;
  if p_stop_count is null or p_stop_count < 2 then
    raise exception 'stop_count must be >= 2' using errcode = '22023';
  end if;
  if p_at_time is null then
    raise exception 'p_at_time is required' using errcode = '22004';
  end if;

  select * into v_version
  from public.pricing_plan_versions
  where id = p_pricing_plan_version_id;

  if not found then
    raise exception 'pricing plan version % not found', p_pricing_plan_version_id
      using errcode = 'P0002';
  end if;

  select * into v_base
  from public.pricing_plan_base_rates
  where pricing_plan_version_id = p_pricing_plan_version_id;

  if not found then
    raise exception 'pricing plan version % has no base rates', p_pricing_plan_version_id
      using errcode = 'P0002';
  end if;

  -- Distance: tier slices where present, base rate for any uncovered remainder.
  if p_distance_km > 0 and exists (
    select 1 from public.pricing_distance_tiers
    where pricing_plan_version_id = p_pricing_plan_version_id
  ) then
    for v_tier in
      select * from public.pricing_distance_tiers
      where pricing_plan_version_id = p_pricing_plan_version_id
      order by min_km, display_order
    loop
      v_overlap_km := greatest(
        0,
        least(coalesce(v_tier.max_km, p_distance_km), p_distance_km) - v_tier.min_km
      );

      if v_overlap_km > 0 then
        v_distance_charge := v_distance_charge + v_overlap_km * v_tier.per_km_rate;
        v_covered_km := v_covered_km + v_overlap_km;
        v_distance_details := v_distance_details || jsonb_build_object(
          'from_km', v_tier.min_km,
          'to_km', least(coalesce(v_tier.max_km, p_distance_km), p_distance_km),
          'km', round(v_overlap_km, 2),
          'per_km_rate', round(v_tier.per_km_rate, 2)
        );
      end if;
    end loop;

    if p_distance_km > v_covered_km then
      v_distance_charge := v_distance_charge + (p_distance_km - v_covered_km) * v_base.per_km_rate;
      v_distance_details := v_distance_details || jsonb_build_object(
        'from_km', v_covered_km,
        'to_km', p_distance_km,
        'km', round(p_distance_km - v_covered_km, 2),
        'per_km_rate', round(v_base.per_km_rate, 2),
        'source', 'base_rate'
      );
    end if;
  else
    v_distance_charge := p_distance_km * v_base.per_km_rate;
    if p_distance_km > 0 then
      v_distance_details := v_distance_details || jsonb_build_object(
        'from_km', 0,
        'to_km', p_distance_km,
        'km', round(p_distance_km, 2),
        'per_km_rate', round(v_base.per_km_rate, 2),
        'source', 'base_rate'
      );
    end if;
  end if;

  v_time_charge := p_duration_min * v_base.per_min_rate;
  v_component := v_base.base_fare + v_distance_charge + v_time_charge;

  -- Weight tier.
  if p_weight_kg is not null then
    select * into v_weight_tier
    from public.pricing_weight_tiers
    where pricing_plan_version_id = p_pricing_plan_version_id
      and p_weight_kg >= min_kg
      and (max_kg is null or p_weight_kg < max_kg)
    order by min_kg
    limit 1;

    if found then
      if v_weight_tier.surcharge_type = 'flat_fee' then
        v_weight_surcharge := v_weight_tier.surcharge_value;
      else
        v_weight_surcharge := v_component * (v_weight_tier.surcharge_value - 1);
      end if;

      v_weight_detail := jsonb_build_object(
        'min_kg', v_weight_tier.min_kg,
        'max_kg', v_weight_tier.max_kg,
        'surcharge_type', v_weight_tier.surcharge_type,
        'surcharge_value', v_weight_tier.surcharge_value
      );
    end if;
  end if;

  -- Volume tier.
  if p_volume_m3 is not null then
    select * into v_volume_tier
    from public.pricing_volume_tiers
    where pricing_plan_version_id = p_pricing_plan_version_id
      and p_volume_m3 >= min_m3
      and (max_m3 is null or p_volume_m3 < max_m3)
    order by min_m3
    limit 1;

    if found then
      if v_volume_tier.surcharge_type = 'flat_fee' then
        v_volume_surcharge := v_volume_tier.surcharge_value;
      else
        v_volume_surcharge := v_component * (v_volume_tier.surcharge_value - 1);
      end if;

      v_volume_detail := jsonb_build_object(
        'min_m3', v_volume_tier.min_m3,
        'max_m3', v_volume_tier.max_m3,
        'surcharge_type', v_volume_tier.surcharge_type,
        'surcharge_value', v_volume_tier.surcharge_value
      );
    end if;
  end if;

  v_component_base := v_component + v_weight_surcharge + v_volume_surcharge;

  -- Cargo surcharge.
  if p_cargo_type_id is not null then
    select * into v_cargo
    from public.pricing_cargo_surcharges
    where pricing_plan_version_id = p_pricing_plan_version_id
      and cargo_type_id = p_cargo_type_id;

    if found then
      if v_cargo.surcharge_type = 'flat_fee' then
        v_cargo_surcharge := v_cargo.surcharge_value;
      elsif v_cargo.surcharge_type = 'multiplier' then
        v_cargo_surcharge := v_component_base * (v_cargo.surcharge_value - 1);
      else
        v_cargo_surcharge := v_component_base * v_cargo.surcharge_value / 100.0;
      end if;
    end if;
  end if;

  -- Equipment surcharges (summed, each applied to the component base).
  foreach v_equipment_id in array v_equipment_ids loop
    select * into v_equipment
    from public.pricing_equipment_surcharges
    where pricing_plan_version_id = p_pricing_plan_version_id
      and equipment_id = v_equipment_id;

    if found then
      if v_equipment.surcharge_type = 'flat_fee' then
        v_equipment_amount := v_equipment.surcharge_value;
      else
        v_equipment_amount := v_component_base * (v_equipment.surcharge_value - 1);
      end if;

      v_equipment_surcharge := v_equipment_surcharge + v_equipment_amount;
      v_equipment_details := v_equipment_details || jsonb_build_object(
        'equipment_id', v_equipment_id,
        'surcharge_type', v_equipment.surcharge_type,
        'surcharge_value', v_equipment.surcharge_value,
        'amount', round(v_equipment_amount, 2)
      );
    end if;
  end loop;

  -- Waiting and multi-stop are net components and participate in the minimum
  -- charge and version multipliers, like every other component.
  v_waiting_charge := round(
    greatest(0, p_waiting_minutes - v_base.waiting_free_minutes) * v_base.waiting_per_min_rate,
    2
  );
  v_multi_stop_charge := round(
    greatest(0, p_stop_count - 2) * v_base.multi_stop_fee,
    2
  );

  v_pre_multiplier := v_component_base + v_cargo_surcharge + v_equipment_surcharge
                      + v_waiting_charge + v_multi_stop_charge;

  if v_pre_multiplier < v_base.minimum_charge then
    v_pre_multiplier := v_base.minimum_charge;
    v_min_applied := true;
  end if;

  -- Zone multiplier.
  if p_zone_id is not null then
    select zm.multiplier into v_zone_multiplier
    from public.pricing_zone_multipliers zm
    where zm.pricing_plan_version_id = p_pricing_plan_version_id
      and zm.service_zone_id = p_zone_id;

    if not found then
      v_zone_multiplier := 1;
    end if;
  end if;

  -- Time multipliers: one best non-stacking match plus every stacking match.
  for v_match in
    select * from public.pricing_time_multipliers
    where pricing_plan_version_id = p_pricing_plan_version_id
      and not stacks
    order by priority desc, created_at, id
  loop
    v_local_ts := p_at_time at time zone v_match.timezone;
    v_dow := extract(dow from v_local_ts)::smallint;
    v_clock := v_local_ts::time;

    if v_dow = any(v_match.days_of_week)
       and (
         (v_match.start_time < v_match.end_time
           and v_clock >= v_match.start_time and v_clock < v_match.end_time)
         or
         (v_match.start_time >= v_match.end_time
           and (v_clock >= v_match.start_time or v_clock < v_match.end_time))
       )
    then
      v_time_multiplier := v_time_multiplier * v_match.multiplier;
      v_time_details := v_time_details || jsonb_build_object(
        'name', v_match.name,
        'multiplier', v_match.multiplier,
        'priority', v_match.priority,
        'stacks', false
      );
      exit;
    end if;
  end loop;

  for v_match in
    select * from public.pricing_time_multipliers
    where pricing_plan_version_id = p_pricing_plan_version_id
      and stacks
    order by priority desc, created_at, id
  loop
    v_local_ts := p_at_time at time zone v_match.timezone;
    v_dow := extract(dow from v_local_ts)::smallint;
    v_clock := v_local_ts::time;

    if v_dow = any(v_match.days_of_week)
       and (
         (v_match.start_time < v_match.end_time
           and v_clock >= v_match.start_time and v_clock < v_match.end_time)
         or
         (v_match.start_time >= v_match.end_time
           and (v_clock >= v_match.start_time or v_clock < v_match.end_time))
       )
    then
      v_time_multiplier := v_time_multiplier * v_match.multiplier;
      v_time_details := v_time_details || jsonb_build_object(
        'name', v_match.name,
        'multiplier', v_match.multiplier,
        'priority', v_match.priority,
        'stacks', true
      );
    end if;
  end loop;

  v_subtotal := v_pre_multiplier * v_zone_multiplier * v_time_multiplier;
  v_vat := round(v_subtotal * v_base.vat_rate, 2);
  v_total := round(v_subtotal + v_vat, 2);
  v_pre_cap_total := v_total;

  if v_version.regulated_tariff_id is not null then
    v_cap := public.regulated_max_fare(
      v_version.regulated_tariff_id, p_distance_km, p_weight_kg
    );

    if v_cap is not null and v_total > v_cap then
      -- The legal cap is a maximum total. Re-derive net and VAT from it so the
      -- breakdown remains internally consistent. The uncapped total is kept in
      -- breakdown_details.pre_regulated_total for audit.
      v_total := v_cap;
      v_subtotal := round(v_cap / (1 + v_base.vat_rate), 2);
      v_vat := round(v_cap - v_subtotal, 2);
      v_is_capped := true;
    end if;
  end if;

  return jsonb_build_object(
    'base_fare', round(v_base.base_fare, 2),
    'distance_charge', round(v_distance_charge, 2),
    'time_charge', round(v_time_charge, 2),
    'weight_surcharge', round(v_weight_surcharge, 2),
    'volume_surcharge', round(v_volume_surcharge, 2),
    'cargo_surcharge', round(v_cargo_surcharge, 2),
    'equipment_surcharge', round(v_equipment_surcharge, 2),
    'waiting_charge', v_waiting_charge,
    'multi_stop_charge', v_multi_stop_charge,
    'zone_multiplier', round(v_zone_multiplier, 4),
    'time_multiplier', round(v_time_multiplier, 4),
    'subtotal', round(v_subtotal, 2),
    'vat', v_vat,
    'total', v_total,
    'currency_code', v_base.currency_code,
    'vat_rate', v_base.vat_rate,
    'regulated_max_fare', v_cap,
    'is_capped', v_is_capped,
    'distance_km', p_distance_km,
    'duration_min', p_duration_min,
    'weight_kg', p_weight_kg,
    'volume_m3', p_volume_m3,
    'cargo_type_id', p_cargo_type_id,
    'stop_count', p_stop_count,
    'waiting_minutes', p_waiting_minutes,
    'breakdown_details', jsonb_build_object(
      'distance_tiers', v_distance_details,
      'weight_tier', v_weight_detail,
      'volume_tier', v_volume_detail,
      'cargo_type_id', p_cargo_type_id,
      'equipment', v_equipment_details,
      'time_multipliers', v_time_details,
      'minimum_charge_applied', v_min_applied,
      'pre_multiplier', round(v_pre_multiplier, 2),
      'pre_regulated_total', v_pre_cap_total,
      'waiting_free_minutes', v_base.waiting_free_minutes,
      'waiting_per_min_rate', v_base.waiting_per_min_rate,
      'multi_stop_fee', v_base.multi_stop_fee,
      'loading_fee', v_base.loading_fee,
      'unloading_fee', v_base.unloading_fee,
      'distance_km', p_distance_km,
      'duration_min', p_duration_min,
      'weight_kg', p_weight_kg,
      'volume_m3', p_volume_m3,
      'stop_count', p_stop_count,
      'waiting_minutes', p_waiting_minutes
    )
  );
end;
$$;

comment on function private.quote_calculate_core(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, integer, integer, timestamptz) is
  'Pure Phase 4 fare calculation. Applies version rates, waiting/multi-stop, zone/time multipliers and the regulated total cap. Returns a complete JSONB breakdown.';

revoke all on function private.quote_calculate_core(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, integer, integer, timestamptz) from public;
revoke all on function private.quote_calculate_core(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, integer, integer, timestamptz) from anon;
revoke all on function private.quote_calculate_core(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, integer, integer, timestamptz) from authenticated;
grant execute on function private.quote_calculate_core(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, integer, integer, timestamptz) to service_role;

-- ----------------------------------------------------------------------------
-- 2. Public authoritative quote function
-- ----------------------------------------------------------------------------
create or replace function public.quote_calculate_and_persist(
  p_customer_id uuid,
  p_pickup_location extensions.geography,
  p_pickup_address text,
  p_destination_location extensions.geography,
  p_destination_address text,
  p_vehicle_type_id uuid,
  p_cargo_type_id uuid,
  p_cargo_weight_kg numeric default null,
  p_cargo_volume_m3 numeric default null,
  p_scheduled_at timestamptz default null,
  p_stop_count integer default 2,
  p_waiting_minutes integer default 0,
  p_equipment_ids uuid[] default '{}'::uuid[],
  p_promo_code_id uuid default null,
  p_distance_km numeric default null,
  p_duration_min numeric default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor              uuid := auth.uid();
  v_now                timestamptz := now();
  v_city               public.cities%rowtype;
  v_zone_id            uuid;
  v_plan_id            uuid;
  v_plan_version_id    uuid;
  v_version            public.pricing_plan_versions%rowtype;
  v_plan               public.pricing_plans%rowtype;
  v_request_id         uuid := gen_random_uuid();
  v_quote_id           uuid := gen_random_uuid();
  v_distance_km        numeric;
  v_duration_min       numeric;
  v_scheduled_at       timestamptz := coalesce(p_scheduled_at, v_now);
  v_core               jsonb;
  v_surge              record;
  v_surge_multiplier   numeric := 1;
  v_vat_rate           numeric;
  v_subtotal           numeric;
  v_vat                numeric;
  v_total              numeric;
  v_cap                numeric;
  v_is_capped          boolean := false;
  v_promo              public.promo_codes%rowtype;
  v_promo_rules        record;
  v_promo_valid        boolean;
  v_promo_reason       text;
  v_discount           numeric := 0;
  v_promo_object       jsonb;
  v_breakdown          jsonb;
  v_session_id         text;
  v_equipment_ids      uuid[] := coalesce(p_equipment_ids, '{}'::uuid[]);
  v_match_count        integer;
begin
  -- 1. Authenticated customer (or trusted service/owner context).
  if v_actor is null and not private.is_service_context() then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if v_actor is not null
     and v_actor <> p_customer_id
     and not private.is_service_context()
  then
    raise exception 'caller % cannot create a quote for customer %', v_actor, p_customer_id
      using errcode = '42501';
  end if;

  if p_customer_id is null then
    raise exception 'p_customer_id is required' using errcode = '22004';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_customer_id
      and p.is_active
  ) then
    raise exception 'customer profile % not found or inactive', p_customer_id
      using errcode = 'P0002';
  end if;

  if p_pickup_location is null or p_destination_location is null then
    raise exception 'pickup and destination locations are required' using errcode = '22004';
  end if;

  if p_pickup_address is null or btrim(p_pickup_address) = ''
     or p_destination_address is null or btrim(p_destination_address) = ''
  then
    raise exception 'pickup and destination addresses are required' using errcode = '22004';
  end if;

  if p_cargo_weight_kg is not null and p_cargo_weight_kg < 0 then
    raise exception 'cargo_weight_kg must be >= 0' using errcode = '22023';
  end if;

  if p_cargo_volume_m3 is not null and p_cargo_volume_m3 < 0 then
    raise exception 'cargo_volume_m3 must be >= 0' using errcode = '22023';
  end if;

  if p_stop_count is null or p_stop_count < 2 then
    raise exception 'stop_count must be >= 2' using errcode = '22023';
  end if;

  if p_waiting_minutes is null or p_waiting_minutes < 0 then
    raise exception 'waiting_minutes must be >= 0' using errcode = '22023';
  end if;

  if p_distance_km is not null and p_distance_km < 0 then
    raise exception 'distance_km must be >= 0' using errcode = '22023';
  end if;

  -- 2. Derive city and service zone from the pickup point.
  select c.* into v_city
  from public.cities c
  where c.is_active
    and c.boundary is not null
    and extensions.ST_Covers(c.boundary, p_pickup_location)
  order by c.id
  limit 1;

  if not found then
    raise exception 'pickup point is outside every active service city'
      using errcode = '22023';
  end if;

  select z.id into v_zone_id
  from public.service_zones z
  where z.city_id = v_city.id
    and z.is_active
    and z.boundary is not null
    and extensions.ST_Covers(z.boundary, p_pickup_location)
  order by z.id
  limit 1;

  if not exists (
    select 1 from public.vehicle_types vt
    where vt.id = p_vehicle_type_id
      and vt.is_active
      and (vt.country_id is null or vt.country_id = v_city.country_id)
  ) then
    raise exception 'vehicle type % is not available in %', p_vehicle_type_id, v_city.name
      using errcode = 'P0002';
  end if;

  if p_cargo_type_id is not null and not exists (
    select 1 from public.cargo_types ct
    where ct.id = p_cargo_type_id
      and ct.is_active
      and (ct.country_id is null or ct.country_id = v_city.country_id)
  ) then
    raise exception 'cargo type % is not available in %', p_cargo_type_id, v_city.name
      using errcode = 'P0002';
  end if;

  -- 3. Distance and duration.
  if p_distance_km is null then
    v_distance_km := round(
      (extensions.ST_Distance(p_pickup_location, p_destination_location) / 1000.0)::numeric,
      2
    );
  else
    v_distance_km := round(p_distance_km, 2);
  end if;

  if v_distance_km < 0 then
    raise exception 'distance_km must be >= 0' using errcode = '22023';
  end if;

  if p_duration_min is null then
    -- Conservative 20 km/h urban average; callers with a routing engine should
    -- pass the routed duration explicitly.
    v_duration_min := greatest(1, ceil(v_distance_km / 20.0 * 60.0))::integer;
  else
    if p_duration_min < 0 then
      raise exception 'duration_min must be >= 0' using errcode = '22023';
    end if;
    v_duration_min := round(p_duration_min);
  end if;

  -- 4. Resolve the active plan, then its published version for now().
  v_plan_id := public.active_pricing_plan_for(
    v_city.id, v_zone_id, p_vehicle_type_id, v_now
  );

  if v_plan_id is null then
    raise exception 'no active pricing plan for city %, zone %, vehicle type %',
      v_city.id, coalesce(v_zone_id::text, 'none'), p_vehicle_type_id
      using errcode = 'P0002';
  end if;

  v_plan_version_id := public.active_pricing_plan_version(v_plan_id, v_now);

  if v_plan_version_id is null then
    raise exception 'no active published version for pricing plan %', v_plan_id
      using errcode = 'P0002';
  end if;

  select * into v_version
  from public.pricing_plan_versions
  where id = v_plan_version_id;

  select * into v_plan
  from public.pricing_plans
  where id = v_version.pricing_plan_id;

  -- 5. Fare core (scheduled time drives time-of-day multipliers).
  v_core := private.quote_calculate_core(
    v_plan_version_id,
    v_distance_km,
    v_duration_min,
    p_cargo_weight_kg,
    p_cargo_volume_m3,
    p_cargo_type_id,
    v_equipment_ids,
    v_zone_id,
    p_waiting_minutes,
    p_stop_count,
    v_scheduled_at
  );

  v_vat_rate := (v_core ->> 'vat_rate')::numeric;
  v_cap := (v_core ->> 'regulated_max_fare')::numeric;
  v_is_capped := coalesce((v_core ->> 'is_capped')::boolean, false);

  -- 6. Highest matching active surge, if any (Decision F).
  select s.* into v_surge
  from public.surge_multipliers s
  where s.city_id = v_city.id
    and s.starts_at <= v_now
    and s.ends_at > v_now
    and (s.service_zone_id is null or s.service_zone_id = v_zone_id)
    and (s.vehicle_type_id is null or s.vehicle_type_id = p_vehicle_type_id)
  order by s.multiplier desc, s.starts_at desc, s.id
  limit 1;

  if found then
    v_surge_multiplier := v_surge.multiplier;
  end if;

  v_subtotal := round((v_core ->> 'subtotal')::numeric * v_surge_multiplier, 2);
  v_vat := round(v_subtotal * v_vat_rate, 2);
  v_total := round(v_subtotal + v_vat, 2);

  if v_cap is not null and v_total > v_cap then
    v_total := v_cap;
    v_subtotal := round(v_cap / (1 + v_vat_rate), 2);
    v_vat := round(v_cap - v_subtotal, 2);
    v_is_capped := true;
  end if;

  -- 7. Promotion validation and one-promo discount (Decision C).
  v_promo_object := jsonb_build_object(
    'promo_code_id', null,
    'code', null,
    'discount_type', null,
    'discount_value', null,
    'discount_amount', 0.00,
    'applied', false,
    'reason', null
  );

  if p_promo_code_id is not null then
    select * into v_promo
    from public.promo_codes
    where id = p_promo_code_id;

    if not found then
      raise exception 'promo code % not found', p_promo_code_id using errcode = 'P0002';
    end if;

    v_promo_valid := public.promo_code_valid(p_promo_code_id, p_customer_id, v_now);
    v_promo_reason := null;

    if not v_promo_valid then
      v_promo_reason := 'promo is expired, inactive, outside its country, or outside redemption limits';
    end if;

    if v_promo_valid and v_promo.currency_code is not null
       and v_promo.currency_code <> (v_core ->> 'currency_code')::char(3)
    then
      v_promo_valid := false;
      v_promo_reason := format(
        'promo currency %s does not match quote currency %s',
        btrim(v_promo.currency_code), btrim((v_core ->> 'currency_code')::text)
      );
    end if;

    if v_promo_valid
       and cardinality(v_promo.applicable_vehicle_type_ids) > 0
       and not (p_vehicle_type_id = any(v_promo.applicable_vehicle_type_ids))
    then
      v_promo_valid := false;
      v_promo_reason := 'promo does not apply to this vehicle type';
    end if;

    if v_promo_valid
       and cardinality(v_promo.applicable_city_ids) > 0
       and not (v_city.id = any(v_promo.applicable_city_ids))
    then
      v_promo_valid := false;
      v_promo_reason := 'promo does not apply to this city';
    end if;

    if v_promo_valid
       and cardinality(v_promo.applicable_cargo_type_ids) > 0
       and (p_cargo_type_id is null or not (p_cargo_type_id = any(v_promo.applicable_cargo_type_ids)))
    then
      v_promo_valid := false;
      v_promo_reason := 'promo does not apply to this cargo type';
    end if;

    if v_promo_valid and v_subtotal < v_promo.min_purchase_amount then
      v_promo_valid := false;
      v_promo_reason := format(
        'promo requires a minimum net subtotal of %s %s',
        v_promo.min_purchase_amount, btrim(v_promo.currency_code)
      );
    end if;

    -- Advanced eligibility rules are evaluated against the same now() clock.
    if v_promo_valid then
      for v_promo_rules in
        select * from public.promo_code_eligibility_rules
        where promo_code_id = p_promo_code_id
        order by rule_type, id
      loop
        if v_promo_rules.rule_type = 'first_job' then
          if exists (select 1 from public.jobs j where j.customer_id = p_customer_id) then
            v_promo_valid := false;
            v_promo_reason := 'promo is limited to a customer''s first job';
          end if;

        elsif v_promo_rules.rule_type = 'min_jobs_completed' then
          v_match_count := coalesce((v_promo_rules.rule_value ->> 'min_jobs')::integer, 0);
          if (
            select count(*) from public.jobs j
            where j.customer_id = p_customer_id and j.status = 'completed'
          ) < v_match_count then
            v_promo_valid := false;
            v_promo_reason := format(
              'promo requires at least %s completed jobs', v_match_count
            );
          end if;

        elsif v_promo_rules.rule_type = 'min_account_age_days' then
          v_match_count := coalesce((v_promo_rules.rule_value ->> 'min_days')::integer, 0);
          if not exists (
            select 1 from public.profiles p
            where p.id = p_customer_id
              and p.created_at <= v_now - make_interval(days => v_match_count)
          ) then
            v_promo_valid := false;
            v_promo_reason := format(
              'promo requires an account at least %s days old', v_match_count
            );
          end if;

        elsif v_promo_rules.rule_type = 'specific_zone' then
          if v_zone_id is null
             or coalesce(
                  (v_promo_rules.rule_value ->> 'zone_id')::uuid,
                  (v_promo_rules.rule_value ->> 'service_zone_id')::uuid
                ) is distinct from v_zone_id
          then
            v_promo_valid := false;
            v_promo_reason := 'promo is limited to a different service zone';
          end if;

        elsif v_promo_rules.rule_type = 'specific_day_of_week' then
          if extract(
               dow from (v_now at time zone v_city.timezone)
             )::integer <> coalesce((v_promo_rules.rule_value ->> 'day_of_week')::integer, -1)
          then
            v_promo_valid := false;
            v_promo_reason := 'promo is limited to a different day of week';
          end if;

        else
          v_promo_valid := false;
          v_promo_reason := format(
            'unsupported promo eligibility rule: %s', v_promo_rules.rule_type
          );
        end if;

        exit when not v_promo_valid;
      end loop;
    end if;

    if not v_promo_valid then
      raise exception 'promo code % is not valid: %', v_promo.code, v_promo_reason
        using errcode = '22023';
    end if;

    if v_promo.discount_type = 'flat_amount' then
      v_discount := least(v_promo.discount_value, v_subtotal);
    elsif v_promo.discount_type = 'percentage' then
      v_discount := round(v_subtotal * v_promo.discount_value / 100.0, 2);
    elsif v_promo.discount_type = 'capped_percentage' then
      v_discount := least(
        round(v_subtotal * v_promo.discount_value / 100.0, 2),
        coalesce(v_promo.max_discount_amount, v_subtotal)
      );
    elsif v_promo.discount_type = 'free_ride' then
      v_discount := v_subtotal;
    else
      raise exception 'unsupported promo discount type: %', v_promo.discount_type
        using errcode = '22023';
    end if;

    v_discount := round(least(greatest(v_discount, 0), v_subtotal), 2);

    -- VAT is charged on the discounted net. The regulated cap is a cap on the
    -- total, so a discount can only reduce the total.
    v_vat := round((v_subtotal - v_discount) * v_vat_rate, 2);
    v_total := round(v_subtotal - v_discount + v_vat, 2);

    v_promo_object := jsonb_build_object(
      'promo_code_id', v_promo.id,
      'code', v_promo.code,
      'discount_type', v_promo.discount_type,
      'discount_value', v_promo.discount_value,
      'discount_amount', v_discount,
      'applied', true,
      'reason', null
    );
  end if;

  -- 8. One transaction: request, quote, immutable snapshot.
  begin
    v_session_id := auth.jwt() ->> 'session_id';
  exception when others then
    v_session_id := null;
  end;

  insert into public.quote_requests (
    id, country_id, city_id, customer_id,
    pickup_location, pickup_address, destination_location, destination_address,
    vehicle_type_id, cargo_type_id, cargo_weight_kg, cargo_volume_m3,
    scheduled_at, stop_count, waiting_minutes, requested_at, session_id, metadata
  ) values (
    v_request_id, v_city.country_id, v_city.id, p_customer_id,
    p_pickup_location, p_pickup_address, p_destination_location, p_destination_address,
    p_vehicle_type_id, p_cargo_type_id, p_cargo_weight_kg, p_cargo_volume_m3,
    p_scheduled_at, p_stop_count, p_waiting_minutes, v_now, v_session_id,
    jsonb_build_object(
      'source', 'quote_calculate_and_persist',
      'engine', 'phase4-v1',
      'equipment_ids', to_jsonb(v_equipment_ids)
    )
  );

  v_breakdown := jsonb_build_object(
    'quote_id', v_quote_id,
    'quote_request_id', v_request_id,
    'generated_at', v_now,
    'inputs', jsonb_build_object(
      'customer_id', p_customer_id,
      'pickup_location', extensions.ST_AsGeoJSON(p_pickup_location)::jsonb,
      'pickup_address', p_pickup_address,
      'destination_location', extensions.ST_AsGeoJSON(p_destination_location)::jsonb,
      'destination_address', p_destination_address,
      'vehicle_type_id', p_vehicle_type_id,
      'cargo_type_id', p_cargo_type_id,
      'cargo_weight_kg', p_cargo_weight_kg,
      'cargo_volume_m3', p_cargo_volume_m3,
      'scheduled_at', p_scheduled_at,
      'stop_count', p_stop_count,
      'waiting_minutes', p_waiting_minutes,
      'equipment_ids', to_jsonb(v_equipment_ids),
      'promo_code_id', p_promo_code_id,
      'distance_km_input', p_distance_km,
      'duration_min_input', p_duration_min
    ),
    'service', jsonb_build_object(
      'country_id', v_city.country_id,
      'city_id', v_city.id,
      'city_name', v_city.name,
      'timezone', v_city.timezone,
      'service_zone_id', v_zone_id
    ),
    'plan', jsonb_build_object(
      'pricing_plan_version_id', v_plan_version_id,
      'pricing_plan_id', v_plan.id,
      'plan_code', v_plan.code,
      'plan_name', v_plan.name,
      'version_number', v_version.version_number,
      'currency_code', v_version.currency_code,
      'regulated_tariff_id', v_version.regulated_tariff_id,
      'effective_from', v_version.effective_from,
      'published_at', v_version.published_at
    ),
    'calculation', v_core,
    'surge', jsonb_build_object(
      'surge_id', case when v_surge.id is null then null else v_surge.id end,
      'multiplier', v_surge_multiplier,
      'reason', case when v_surge.id is null then null else v_surge.reason end,
      'starts_at', case when v_surge.id is null then null else v_surge.starts_at end,
      'ends_at', case when v_surge.id is null then null else v_surge.ends_at end
    ),
    'promo', v_promo_object,
    'final', jsonb_build_object(
      'currency_code', (v_core ->> 'currency_code')::char(3),
      'subtotal', v_subtotal,
      'promo_discount', v_discount,
      'discounted_subtotal', round(v_subtotal - v_discount, 2),
      'vat', v_vat,
      'total', v_total,
      'is_capped', v_is_capped,
      'regulated_max_fare', v_cap,
      'vat_rate', v_vat_rate,
      'expires_at', v_now + interval '15 minutes'
    )
  );

  insert into public.quotes (
    id, quote_request_id, pricing_plan_version_id, currency_code,
    base_fare, distance_charge, time_charge, weight_surcharge, volume_surcharge,
    cargo_surcharge, equipment_surcharge, waiting_charge, multi_stop_charge,
    zone_multiplier, time_multiplier, surge_multiplier, promo_code_id,
    promo_discount, subtotal, vat, total, is_capped, regulated_max_fare,
    pricing_breakdown_snapshot, distance_km, estimated_duration_min, expires_at, created_at
  ) values (
    v_quote_id, v_request_id, v_plan_version_id, (v_core ->> 'currency_code')::char(3),
    (v_core ->> 'base_fare')::numeric,
    (v_core ->> 'distance_charge')::numeric,
    (v_core ->> 'time_charge')::numeric,
    (v_core ->> 'weight_surcharge')::numeric,
    (v_core ->> 'volume_surcharge')::numeric,
    (v_core ->> 'cargo_surcharge')::numeric,
    (v_core ->> 'equipment_surcharge')::numeric,
    (v_core ->> 'waiting_charge')::numeric,
    (v_core ->> 'multi_stop_charge')::numeric,
    (v_core ->> 'zone_multiplier')::numeric,
    (v_core ->> 'time_multiplier')::numeric,
    v_surge_multiplier,
    p_promo_code_id,
    v_discount,
    v_subtotal,
    v_vat,
    v_total,
    v_is_capped,
    v_cap,
    v_breakdown,
    v_distance_km,
    v_duration_min,
    v_now + interval '15 minutes',
    v_now
  );

  return v_quote_id;
end;
$$;

comment on function public.quote_calculate_and_persist(uuid, extensions.geography, text, extensions.geography, text, uuid, uuid, numeric, numeric, timestamptz, integer, integer, uuid[], uuid, numeric, numeric) is
  'Authoritative Phase 4 quote function. Validates the caller, resolves the plan, applies surge/promo/LATRA cap, persists a quote_request and quote with a complete JSONB snapshot, and returns the quote id.';

revoke all on function public.quote_calculate_and_persist(uuid, extensions.geography, text, extensions.geography, text, uuid, uuid, numeric, numeric, timestamptz, integer, integer, uuid[], uuid, numeric, numeric) from public;
revoke all on function public.quote_calculate_and_persist(uuid, extensions.geography, text, extensions.geography, text, uuid, uuid, numeric, numeric, timestamptz, integer, integer, uuid[], uuid, numeric, numeric) from anon;
grant execute on function public.quote_calculate_and_persist(uuid, extensions.geography, text, extensions.geography, text, uuid, uuid, numeric, numeric, timestamptz, integer, integer, uuid[], uuid, numeric, numeric) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Authorised snapshot access
-- ----------------------------------------------------------------------------
create or replace function public.quote_get_breakdown(p_quote_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_snapshot jsonb;
  v_customer uuid;
  v_actor    uuid := auth.uid();
begin
  select q.pricing_breakdown_snapshot, qr.customer_id
    into v_snapshot, v_customer
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = p_quote_id;

  if not found then
    raise exception 'quote % not found', p_quote_id using errcode = 'P0002';
  end if;

  if not private.is_service_context()
     and v_actor is distinct from v_customer
     and not public.has_permission('view_all_quotes')
  then
    raise exception 'not authorised to view quote %', p_quote_id using errcode = '42501';
  end if;

  return v_snapshot;
end;
$$;

comment on function public.quote_get_breakdown(uuid) is
  'Returns the immutable pricing snapshot for a quote to its customer, view_all_quotes staff, or the service role.';

revoke all on function public.quote_get_breakdown(uuid) from public;
revoke all on function public.quote_get_breakdown(uuid) from anon;
grant execute on function public.quote_get_breakdown(uuid) to authenticated, service_role;
