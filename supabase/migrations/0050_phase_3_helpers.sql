-- ============================================================================
-- SafeShift — Phase 3 / Migration 0050
-- Pricing engine helpers.
--
-- All SECURITY DEFINER functions set search_path = '' and schema-qualify every
-- object. Admin-only functions check manage_pricing/manage_regulated_tariffs;
-- read/quote helpers are callable by authenticated users.
--
-- quote_preview() is deliberately a preview. Phase 4's authoritative quote
-- engine will persist the chosen version_id and the resulting breakdown.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Internal permission/service helper
-- ----------------------------------------------------------------------------
create or replace function private.is_pricing_service()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.role(), '') = 'service_role'
      or session_user in ('postgres', 'supabase_admin');
$$;

comment on function private.is_pricing_service() is
  'True for service-role callers and local/migration database owners. Used only inside SECURITY DEFINER pricing routines.';

revoke all on function private.is_pricing_service() from public;
revoke all on function private.is_pricing_service() from anon;
revoke all on function private.is_pricing_service() from authenticated;

-- ----------------------------------------------------------------------------
-- 1. Version lifecycle
-- ----------------------------------------------------------------------------
create or replace function public.publish_pricing_plan_version(p_version_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version public.pricing_plan_versions%rowtype;
  v_previous public.pricing_plan_versions%rowtype;
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;

  select * into v_version
  from public.pricing_plan_versions
  where id = p_version_id
  for update;

  if not found then
    raise exception 'pricing plan version % not found', p_version_id using errcode = 'P0002';
  end if;

  if v_version.published_at is not null then
    return v_version.id;
  end if;

  if not exists (
    select 1 from public.pricing_plan_base_rates
    where pricing_plan_version_id = p_version_id
  ) then
    raise exception 'pricing plan version % has no base rates and cannot be published', p_version_id
      using errcode = '23514';
  end if;

  select * into v_previous
  from public.pricing_plan_versions
  where pricing_plan_id = v_version.pricing_plan_id
    and id <> v_version.id
    and published_at is not null
    and (effective_to is null or effective_to > v_version.effective_from)
  order by version_number desc
  limit 1;

  begin
    perform set_config('safeshift.publish_context', 'on', true);

    update public.pricing_plan_versions
       set published_at = now(),
           published_by = coalesce(auth.uid(), published_by)
     where id = p_version_id;

    if v_previous.id is not null then
      update public.pricing_plan_versions
         set effective_to = v_version.effective_from,
             superseded_by_version_id = v_version.id
       where id = v_previous.id;
    end if;

    perform set_config('safeshift.publish_context', 'off', true);
  exception when others then
    perform set_config('safeshift.publish_context', 'off', true);
    raise;
  end;

  return p_version_id;
end;
$$;

comment on function public.publish_pricing_plan_version(uuid) is
  'Atomically publishes a complete draft version and closes/supersedes the previous overlapping published version.';

create or replace function public.draft_pricing_plan_version(p_pricing_plan_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source  uuid;
  v_new     uuid;
  v_next    integer;
  v_notes   text;
  v_currency char(3);
  v_tariff  uuid;
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;

  if not exists (select 1 from public.pricing_plans where id = p_pricing_plan_id) then
    raise exception 'pricing plan % not found', p_pricing_plan_id using errcode = 'P0002';
  end if;

  select id, currency_code, regulated_tariff_id, notes
    into v_source, v_currency, v_tariff, v_notes
  from public.pricing_plan_versions
  where pricing_plan_id = p_pricing_plan_id
  order by (published_at is not null) desc, version_number desc
  limit 1;

  if v_source is null then
    raise exception 'pricing plan % has no version to copy', p_pricing_plan_id using errcode = 'P0002';
  end if;

  select coalesce(max(version_number), 0) + 1
    into v_next
  from public.pricing_plan_versions
  where pricing_plan_id = p_pricing_plan_id;

  insert into public.pricing_plan_versions (
    pricing_plan_id, version_number, currency_code, effective_from,
    regulated_tariff_id, notes
  ) values (
    p_pricing_plan_id, v_next, v_currency, now(), v_tariff, v_notes
  )
  returning id into v_new;

  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate,
    minimum_charge, loading_fee, unloading_fee, waiting_per_min_rate,
    waiting_free_minutes, multi_stop_fee, vat_rate
  )
  select v_new, currency_code, base_fare, per_km_rate, per_min_rate,
         minimum_charge, loading_fee, unloading_fee, waiting_per_min_rate,
         waiting_free_minutes, multi_stop_fee, vat_rate
  from public.pricing_plan_base_rates
  where pricing_plan_version_id = v_source;

  insert into public.pricing_distance_tiers (
    pricing_plan_version_id, currency_code, min_km, max_km, per_km_rate, display_order
  )
  select v_new, currency_code, min_km, max_km, per_km_rate, display_order
  from public.pricing_distance_tiers
  where pricing_plan_version_id = v_source;

  insert into public.pricing_weight_tiers (
    pricing_plan_version_id, currency_code, min_kg, max_kg,
    surcharge_type, surcharge_value, display_order
  )
  select v_new, currency_code, min_kg, max_kg,
         surcharge_type, surcharge_value, display_order
  from public.pricing_weight_tiers
  where pricing_plan_version_id = v_source;

  insert into public.pricing_volume_tiers (
    pricing_plan_version_id, currency_code, min_m3, max_m3,
    surcharge_type, surcharge_value, display_order
  )
  select v_new, currency_code, min_m3, max_m3,
         surcharge_type, surcharge_value, display_order
  from public.pricing_volume_tiers
  where pricing_plan_version_id = v_source;

  insert into public.pricing_cargo_surcharges (
    pricing_plan_version_id, cargo_type_id, currency_code, surcharge_type, surcharge_value
  )
  select v_new, cargo_type_id, currency_code, surcharge_type, surcharge_value
  from public.pricing_cargo_surcharges
  where pricing_plan_version_id = v_source;

  insert into public.pricing_equipment_surcharges (
    pricing_plan_version_id, equipment_id, currency_code, surcharge_type, surcharge_value
  )
  select v_new, equipment_id, currency_code, surcharge_type, surcharge_value
  from public.pricing_equipment_surcharges
  where pricing_plan_version_id = v_source;

  insert into public.pricing_time_multipliers (
    pricing_plan_version_id, name, days_of_week, start_time, end_time,
    timezone, multiplier, applies_to, priority, stacks
  )
  select v_new, name, days_of_week, start_time, end_time,
         timezone, multiplier, applies_to, priority, stacks
  from public.pricing_time_multipliers
  where pricing_plan_version_id = v_source;

  insert into public.pricing_zone_multipliers (
    pricing_plan_version_id, service_zone_id, multiplier, reason
  )
  select v_new, service_zone_id, multiplier, reason
  from public.pricing_zone_multipliers
  where pricing_plan_version_id = v_source;

  insert into public.pricing_plan_zones (
    pricing_plan_version_id, service_zone_id, is_primary
  )
  select v_new, service_zone_id, is_primary
  from public.pricing_plan_zones
  where pricing_plan_version_id = v_source;

  insert into public.pricing_plan_vehicle_types (
    pricing_plan_version_id, vehicle_type_id
  )
  select v_new, vehicle_type_id
  from public.pricing_plan_vehicle_types
  where pricing_plan_version_id = v_source;

  return v_new;
end;
$$;

comment on function public.draft_pricing_plan_version(uuid) is
  'Creates the next draft version by copying the most recent published version''s rates, tiers, surcharges, multipliers and applicability rows.';

-- ----------------------------------------------------------------------------
-- 2. Resolution
-- ----------------------------------------------------------------------------
create or replace function public.active_pricing_plan_version(
  p_pricing_plan_id uuid,
  p_at_time timestamptz default now()
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select v.id
  from public.pricing_plan_versions v
  where v.pricing_plan_id = p_pricing_plan_id
    and v.published_at is not null
    and v.effective_from <= p_at_time
    and (v.effective_to is null or v.effective_to > p_at_time)
  order by v.version_number desc
  limit 1;
$$;

comment on function public.active_pricing_plan_version(uuid, timestamptz) is
  'Published version in effect for a plan at a point in time; NULL when none is active.';

create or replace function public.active_pricing_plan_for(
  p_city_id uuid,
  p_zone_id uuid,
  p_vehicle_type_id uuid,
  p_at_time timestamptz default now()
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.pricing_plans p
  join lateral (
    select public.active_pricing_plan_version(p.id, p_at_time) as version_id
  ) av on av.version_id is not null
  where p.is_active
    and p.city_id = p_city_id
    and (p.service_zone_id is null or p.service_zone_id = p_zone_id)
    and (
      p.vehicle_type_id = p_vehicle_type_id
      or exists (
        select 1
        from public.pricing_plan_vehicle_types pvt
        where pvt.pricing_plan_version_id = av.version_id
          and pvt.vehicle_type_id = p_vehicle_type_id
      )
    )
  order by (p.service_zone_id is not null) desc, p.display_order, p.code
  limit 1;
$$;

comment on function public.active_pricing_plan_for(uuid, uuid, uuid, timestamptz) is
  'Resolves the active plan for a city/zone/vehicle-type combination. Zone-specific plans win over city-wide plans.';

create or replace function public.zone_pricing_override_plan_version(p_zone_pricing_override_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  with o as (
    select zpo.pricing_plan_id, zpo.effective_from, zpo.effective_to
    from public.zone_pricing_overrides zpo
    where zpo.id = p_zone_pricing_override_id
  ), target as (
    select v.pricing_plan_id,
           case
             when now() >= o.effective_from
              and (o.effective_to is null or now() < o.effective_to) then now()
             else o.effective_from
           end as at_time
    from o
    join public.pricing_plan_versions v on v.id = o.pricing_plan_id
  )
  select public.active_pricing_plan_version(t.pricing_plan_id, t.at_time)
  from target t;
$$;

comment on function public.zone_pricing_override_plan_version(uuid) is
  'Resolves the currently active version for the plan referenced by a Phase 1 zone override.';

create or replace function public.regulated_max_fare(
  p_regulated_tariff_id uuid,
  p_distance_km numeric,
  p_weight_kg numeric
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select min(b.max_fare)
  from public.regulated_tariff_bands b
  where b.regulated_tariff_id = p_regulated_tariff_id
    and (
      (b.value_unit = 'km'
        and p_distance_km is not null
        and p_distance_km >= b.min_value
        and (b.max_value is null or p_distance_km < b.max_value))
      or
      (b.value_unit = 'kg'
        and p_weight_kg is not null
        and p_weight_kg >= b.min_value
        and (b.max_value is null or p_weight_kg < b.max_value))
      or
      (b.value_unit = 'tonnes'
        and p_weight_kg is not null
        and (p_weight_kg / 1000.0) >= b.min_value
        and (b.max_value is null or (p_weight_kg / 1000.0) < b.max_value))
    );
$$;

comment on function public.regulated_max_fare(uuid, numeric, numeric) is
  'Minimum applicable legal max_fare across distance and weight bands. NULL when no band applies (or the tariff has no bands).';

-- ----------------------------------------------------------------------------
-- 3. Promotion validity
-- ----------------------------------------------------------------------------
create or replace function public.promo_code_valid(
  p_promo_code_id uuid,
  p_profile_id uuid,
  p_at_time timestamptz default now()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.promo_codes pc
    join public.profiles p
      on p.id = p_profile_id
     and p.is_active
    where pc.id = p_promo_code_id
      and pc.is_active
      and p_at_time >= pc.valid_from
      and p_at_time < pc.valid_to
      and (pc.country_id is null or pc.country_id = p.default_country_id)
      and (
        pc.total_redemption_limit is null
        or (select count(*) from public.promo_redemptions r where r.promo_code_id = pc.id)
             < pc.total_redemption_limit
      )
      and (
        select count(*)
        from public.promo_redemptions r
        where r.promo_code_id = pc.id and r.profile_id = p_profile_id
      ) < pc.per_user_redemption_limit
      and (
        not pc.new_users_only
        or (
          p.created_at >= p_at_time - interval '30 days'
          and not exists (
            select 1 from public.promo_redemptions r where r.profile_id = p_profile_id
          )
        )
      )
  );
$$;

comment on function public.promo_code_valid(uuid, uuid, timestamptz) is
  'Basic validity: active window, country, global/per-user limits and new-user rule. Cart-dependent filters and advanced eligibility rules are evaluated by Phase 4.';

-- ----------------------------------------------------------------------------
-- 4. Quote preview
-- ----------------------------------------------------------------------------
create or replace function public.quote_preview(
  p_pricing_plan_version_id uuid,
  p_distance_km numeric,
  p_duration_min numeric,
  p_weight_kg numeric,
  p_volume_m3 numeric,
  p_cargo_type_id uuid,
  p_equipment_ids uuid[],
  p_zone_id uuid,
  p_at_time timestamptz default now()
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

  -- Distance: use tier slices where present, then the base per-km rate for any
  -- uncovered remainder (including gaps between tiers).
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
  if p_equipment_ids is not null then
    foreach v_equipment_id in array p_equipment_ids loop
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
  end if;

  v_pre_multiplier := v_component_base + v_cargo_surcharge + v_equipment_surcharge;

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
      -- returned breakdown remains internally consistent (subtotal + vat =
      -- total). The uncapped computation stays in breakdown_details.
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
    'zone_multiplier', round(v_zone_multiplier, 4),
    'time_multiplier', round(v_time_multiplier, 4),
    'waiting_charge', 0.00,
    'multi_stop_charge', 0.00,
    'subtotal', round(v_subtotal, 2),
    'vat', v_vat,
    'total', v_total,
    'currency_code', v_base.currency_code,
    'regulated_max_fare', v_cap,
    'is_capped', v_is_capped,
    'breakdown_details', jsonb_build_object(
      'distance_tiers', v_distance_details,
      'weight_tier', v_weight_detail,
      'volume_tier', v_volume_detail,
      'cargo_type_id', p_cargo_type_id,
      'equipment', v_equipment_details,
      'time_multipliers', v_time_details,
      'minimum_charge_applied', v_min_applied,
      'pre_regulated_total', v_pre_cap_total,
      'distance_km', p_distance_km,
      'duration_min', p_duration_min,
      'weight_kg', p_weight_kg,
      'volume_m3', p_volume_m3
    )
  );
end;
$$;

comment on function public.quote_preview(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, timestamptz) is
  'Computes a non-persisted fare breakdown for a pricing version and applies the regulated cap. Phase 4 persists authoritative quotes.';

-- ----------------------------------------------------------------------------
-- 5. Privileges
-- ----------------------------------------------------------------------------
revoke all on function
  public.publish_pricing_plan_version(uuid),
  public.draft_pricing_plan_version(uuid),
  public.active_pricing_plan_version(uuid, timestamptz),
  public.active_pricing_plan_for(uuid, uuid, uuid, timestamptz),
  public.zone_pricing_override_plan_version(uuid),
  public.regulated_max_fare(uuid, numeric, numeric),
  public.promo_code_valid(uuid, uuid, timestamptz),
  public.quote_preview(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, timestamptz)
from public, anon;

grant execute on function
  public.publish_pricing_plan_version(uuid),
  public.draft_pricing_plan_version(uuid),
  public.active_pricing_plan_version(uuid, timestamptz),
  public.active_pricing_plan_for(uuid, uuid, uuid, timestamptz),
  public.zone_pricing_override_plan_version(uuid),
  public.regulated_max_fare(uuid, numeric, numeric),
  public.promo_code_valid(uuid, uuid, timestamptz),
  public.quote_preview(uuid, numeric, numeric, numeric, numeric, uuid, uuid[], uuid, timestamptz)
to authenticated, service_role;
