-- Pricing editor for the admin console.
--
-- Pricing is versioned: a plan has many versions, published versions are
-- immutable, and quotes use the newest published version whose window covers
-- the booking time (public.active_pricing_plan_version). This migration adds
-- the draft workflow the console needs on top of that model:
--
--   admin_update_pricing_plan     plan metadata only (name, description, active)
--   admin_create_pricing_draft    new draft copied from any version (rollback)
--   admin_save_pricing_draft      replace every rate, tier, surcharge and
--                                 multiplier of a draft in one transaction
--   admin_discard_pricing_draft   delete an unpublished draft
--   admin_publish_pricing_draft   publish now or at a scheduled time
--
-- Fixes: admin_update_pricing_plan used to publish a new version holding only
-- the base fare, per-km, per-minute, minimum and VAT values. Every tier,
-- surcharge, multiplier, zone and vehicle-type link, and the loading,
-- unloading, waiting and multi-stop fees, were silently dropped. Rates now
-- change only through drafts.
--
-- These functions are SECURITY DEFINER. The published-version immutability
-- trigger exempts the function owner, so every write below checks for itself
-- that it only touches unpublished versions.

-- ----------------------------------------------------------------------------
-- Shared helpers
-- ----------------------------------------------------------------------------

create or replace function private.require_manage_pricing()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.require_manage_pricing() from public, anon, authenticated;

-- Locks and returns an unpublished version, or raises.
create or replace function private.lock_pricing_draft(p_version_id uuid)
returns public.pricing_plan_versions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version public.pricing_plan_versions%rowtype;
begin
  select * into v_version
  from public.pricing_plan_versions
  where id = p_version_id
  for update;

  if not found then
    raise exception 'pricing plan version % not found', p_version_id using errcode = 'P0002';
  end if;
  if v_version.published_at is not null then
    raise exception 'version % is published and cannot be changed; create a draft instead',
      v_version.version_number
      using errcode = '42501';
  end if;
  return v_version;
end;
$$;

revoke all on function private.lock_pricing_draft(uuid) from public, anon, authenticated;

-- Removes every child row of a version (drafts only; callers lock first).
create or replace function private.clear_pricing_version_rows(p_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.pricing_zone_multipliers where pricing_plan_version_id = p_version_id;
  delete from public.pricing_time_multipliers where pricing_plan_version_id = p_version_id;
  delete from public.pricing_equipment_surcharges where pricing_plan_version_id = p_version_id;
  delete from public.pricing_cargo_surcharges where pricing_plan_version_id = p_version_id;
  delete from public.pricing_volume_tiers where pricing_plan_version_id = p_version_id;
  delete from public.pricing_weight_tiers where pricing_plan_version_id = p_version_id;
  delete from public.pricing_distance_tiers where pricing_plan_version_id = p_version_id;
  delete from public.pricing_plan_zones where pricing_plan_version_id = p_version_id;
  delete from public.pricing_plan_vehicle_types where pricing_plan_version_id = p_version_id;
  delete from public.pricing_plan_base_rates where pricing_plan_version_id = p_version_id;
end;
$$;

revoke all on function private.clear_pricing_version_rows(uuid) from public, anon, authenticated;

-- Copies every child row from one version to another.
create or replace function private.copy_pricing_version_rows(p_source uuid, p_target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate,
    minimum_charge, loading_fee, unloading_fee, waiting_per_min_rate,
    waiting_free_minutes, multi_stop_fee, vat_rate
  )
  select p_target, currency_code, base_fare, per_km_rate, per_min_rate,
         minimum_charge, loading_fee, unloading_fee, waiting_per_min_rate,
         waiting_free_minutes, multi_stop_fee, vat_rate
  from public.pricing_plan_base_rates where pricing_plan_version_id = p_source;

  insert into public.pricing_distance_tiers (
    pricing_plan_version_id, currency_code, min_km, max_km, per_km_rate, display_order
  )
  select p_target, currency_code, min_km, max_km, per_km_rate, display_order
  from public.pricing_distance_tiers where pricing_plan_version_id = p_source;

  insert into public.pricing_weight_tiers (
    pricing_plan_version_id, currency_code, min_kg, max_kg, surcharge_type, surcharge_value, display_order
  )
  select p_target, currency_code, min_kg, max_kg, surcharge_type, surcharge_value, display_order
  from public.pricing_weight_tiers where pricing_plan_version_id = p_source;

  insert into public.pricing_volume_tiers (
    pricing_plan_version_id, currency_code, min_m3, max_m3, surcharge_type, surcharge_value, display_order
  )
  select p_target, currency_code, min_m3, max_m3, surcharge_type, surcharge_value, display_order
  from public.pricing_volume_tiers where pricing_plan_version_id = p_source;

  insert into public.pricing_cargo_surcharges (
    pricing_plan_version_id, cargo_type_id, currency_code, surcharge_type, surcharge_value
  )
  select p_target, cargo_type_id, currency_code, surcharge_type, surcharge_value
  from public.pricing_cargo_surcharges where pricing_plan_version_id = p_source;

  insert into public.pricing_equipment_surcharges (
    pricing_plan_version_id, equipment_id, currency_code, surcharge_type, surcharge_value
  )
  select p_target, equipment_id, currency_code, surcharge_type, surcharge_value
  from public.pricing_equipment_surcharges where pricing_plan_version_id = p_source;

  insert into public.pricing_time_multipliers (
    pricing_plan_version_id, name, days_of_week, start_time, end_time,
    timezone, multiplier, applies_to, priority, stacks
  )
  select p_target, name, days_of_week, start_time, end_time,
         timezone, multiplier, applies_to, priority, stacks
  from public.pricing_time_multipliers where pricing_plan_version_id = p_source;

  insert into public.pricing_zone_multipliers (
    pricing_plan_version_id, service_zone_id, multiplier, reason
  )
  select p_target, service_zone_id, multiplier, reason
  from public.pricing_zone_multipliers where pricing_plan_version_id = p_source;

  insert into public.pricing_plan_zones (pricing_plan_version_id, service_zone_id, is_primary)
  select p_target, service_zone_id, is_primary
  from public.pricing_plan_zones where pricing_plan_version_id = p_source;

  insert into public.pricing_plan_vehicle_types (pricing_plan_version_id, vehicle_type_id)
  select p_target, vehicle_type_id
  from public.pricing_plan_vehicle_types where pricing_plan_version_id = p_source;
end;
$$;

revoke all on function private.copy_pricing_version_rows(uuid, uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- admin_update_pricing_plan: metadata only
-- ----------------------------------------------------------------------------

drop function if exists public.admin_update_pricing_plan(
  uuid, text, text, boolean, numeric, numeric, numeric, numeric, numeric
);

create function public.admin_update_pricing_plan(
  p_plan_id uuid,
  p_name text,
  p_description text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_manage_pricing();

  if p_name is null or btrim(p_name) = '' then
    raise exception 'name is required' using errcode = '22004';
  end if;

  update public.pricing_plans
     set name = btrim(p_name),
         description = nullif(btrim(coalesce(p_description, '')), ''),
         is_active = coalesce(p_is_active, true)
   where id = p_plan_id;

  if not found then
    raise exception 'pricing plan % not found', p_plan_id using errcode = 'P0002';
  end if;
  return p_plan_id;
end;
$$;

comment on function public.admin_update_pricing_plan(uuid, text, text, boolean) is
  'Updates plan name, description and active flag. Rates change only through drafts.';

revoke all on function public.admin_update_pricing_plan(uuid, text, text, boolean) from public, anon;
grant execute on function public.admin_update_pricing_plan(uuid, text, text, boolean)
  to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- admin_create_pricing_draft
-- ----------------------------------------------------------------------------

create or replace function public.admin_create_pricing_draft(
  p_plan_id uuid,
  p_source_version_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source public.pricing_plan_versions%rowtype;
  v_existing integer;
  v_next integer;
  v_new uuid;
begin
  perform private.require_manage_pricing();

  -- Serialise drafting per plan.
  perform 1 from public.pricing_plans where id = p_plan_id for update;
  if not found then
    raise exception 'pricing plan % not found', p_plan_id using errcode = 'P0002';
  end if;

  select version_number into v_existing
  from public.pricing_plan_versions
  where pricing_plan_id = p_plan_id and published_at is null
  limit 1;
  if v_existing is not null then
    raise exception 'version % is already an open draft; edit, publish or discard it first',
      v_existing
      using errcode = '23505';
  end if;

  if p_source_version_id is not null then
    select * into v_source
    from public.pricing_plan_versions
    where id = p_source_version_id and pricing_plan_id = p_plan_id;
    if not found then
      raise exception 'source version does not belong to this plan' using errcode = '23514';
    end if;
  else
    select * into v_source
    from public.pricing_plan_versions
    where pricing_plan_id = p_plan_id and published_at is not null
    order by version_number desc
    limit 1;
    if not found then
      raise exception 'pricing plan % has no published version to copy', p_plan_id
        using errcode = 'P0002';
    end if;
  end if;

  select coalesce(max(version_number), 0) + 1 into v_next
  from public.pricing_plan_versions
  where pricing_plan_id = p_plan_id;

  insert into public.pricing_plan_versions (
    pricing_plan_id, version_number, currency_code, effective_from, regulated_tariff_id, notes
  ) values (
    p_plan_id, v_next, v_source.currency_code, now(), v_source.regulated_tariff_id,
    case
      when p_source_version_id is null then v_source.notes
      else format('Restored from version %s', v_source.version_number)
    end
  )
  returning id into v_new;

  perform private.copy_pricing_version_rows(v_source.id, v_new);
  return v_new;
end;
$$;

comment on function public.admin_create_pricing_draft(uuid, uuid) is
  'Opens a draft copied from the given version (rollback) or the latest published one. One draft per plan.';

revoke all on function public.admin_create_pricing_draft(uuid, uuid) from public, anon;
grant execute on function public.admin_create_pricing_draft(uuid, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- admin_save_pricing_draft
-- ----------------------------------------------------------------------------
--
-- p_draft shape (every array optional; omitted arrays are saved empty):
-- {
--   "notes": text, "regulated_tariff_id": uuid|null,
--   "base_rates": { base_fare, per_km_rate, per_min_rate, minimum_charge,
--                   loading_fee, unloading_fee, waiting_per_min_rate,
--                   waiting_free_minutes, multi_stop_fee, vat_rate },
--   "distance_tiers":   [{ min_km, max_km, per_km_rate }],
--   "weight_tiers":     [{ min_kg, max_kg, surcharge_type, surcharge_value }],
--   "volume_tiers":     [{ min_m3, max_m3, surcharge_type, surcharge_value }],
--   "cargo_surcharges": [{ cargo_type_id, surcharge_type, surcharge_value }],
--   "equipment_surcharges": [{ equipment_id, surcharge_type, surcharge_value }],
--   "time_multipliers": [{ name, days_of_week, start_time, end_time, timezone,
--                          multiplier, applies_to, priority, stacks }],
--   "zone_multipliers": [{ service_zone_id, multiplier, reason }],
--   "zones":            [{ service_zone_id, is_primary }],
--   "vehicle_type_ids": [uuid]
-- }
-- Table constraints and the overlap triggers validate the values; their
-- messages reach the console unchanged.

create or replace function public.admin_save_pricing_draft(p_version_id uuid, p_draft jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version public.pricing_plan_versions%rowtype;
  v_rates jsonb := coalesce(p_draft -> 'base_rates', '{}'::jsonb);
  v_currency char(3);
begin
  perform private.require_manage_pricing();
  v_version := private.lock_pricing_draft(p_version_id);
  v_currency := v_version.currency_code;

  if jsonb_typeof(p_draft) is distinct from 'object' then
    raise exception 'draft must be a JSON object' using errcode = '22023';
  end if;
  if jsonb_typeof(v_rates) is distinct from 'object'
     or not (v_rates ? 'base_fare' and v_rates ? 'per_km_rate' and v_rates ? 'per_min_rate') then
    raise exception 'base fare, per-km rate and per-minute rate are required' using errcode = '22004';
  end if;

  update public.pricing_plan_versions
     set notes = nullif(btrim(coalesce(p_draft ->> 'notes', '')), ''),
         regulated_tariff_id = nullif(p_draft ->> 'regulated_tariff_id', '')::uuid
   where id = p_version_id;

  perform private.clear_pricing_version_rows(p_version_id);

  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate,
    minimum_charge, loading_fee, unloading_fee, waiting_per_min_rate,
    waiting_free_minutes, multi_stop_fee, vat_rate
  ) values (
    p_version_id, v_currency,
    (v_rates ->> 'base_fare')::numeric,
    (v_rates ->> 'per_km_rate')::numeric,
    (v_rates ->> 'per_min_rate')::numeric,
    coalesce((v_rates ->> 'minimum_charge')::numeric, 0),
    coalesce((v_rates ->> 'loading_fee')::numeric, 0),
    coalesce((v_rates ->> 'unloading_fee')::numeric, 0),
    coalesce((v_rates ->> 'waiting_per_min_rate')::numeric, 0),
    coalesce((v_rates ->> 'waiting_free_minutes')::integer, 5),
    coalesce((v_rates ->> 'multi_stop_fee')::numeric, 0),
    coalesce((v_rates ->> 'vat_rate')::numeric, 0.18)
  );

  insert into public.pricing_distance_tiers (
    pricing_plan_version_id, currency_code, min_km, max_km, per_km_rate, display_order
  )
  select p_version_id, v_currency, t.min_km, t.max_km, t.per_km_rate, (e.ord - 1)::integer
  from jsonb_array_elements(coalesce(p_draft -> 'distance_tiers', '[]'::jsonb)) with ordinality e(value, ord)
  cross join lateral jsonb_to_record(e.value) as t(min_km numeric, max_km numeric, per_km_rate numeric);

  insert into public.pricing_weight_tiers (
    pricing_plan_version_id, currency_code, min_kg, max_kg, surcharge_type, surcharge_value, display_order
  )
  select p_version_id, v_currency, t.min_kg, t.max_kg, t.surcharge_type, t.surcharge_value, (e.ord - 1)::integer
  from jsonb_array_elements(coalesce(p_draft -> 'weight_tiers', '[]'::jsonb)) with ordinality e(value, ord)
  cross join lateral jsonb_to_record(e.value)
    as t(min_kg numeric, max_kg numeric, surcharge_type text, surcharge_value numeric);

  insert into public.pricing_volume_tiers (
    pricing_plan_version_id, currency_code, min_m3, max_m3, surcharge_type, surcharge_value, display_order
  )
  select p_version_id, v_currency, t.min_m3, t.max_m3, t.surcharge_type, t.surcharge_value, (e.ord - 1)::integer
  from jsonb_array_elements(coalesce(p_draft -> 'volume_tiers', '[]'::jsonb)) with ordinality e(value, ord)
  cross join lateral jsonb_to_record(e.value)
    as t(min_m3 numeric, max_m3 numeric, surcharge_type text, surcharge_value numeric);

  insert into public.pricing_cargo_surcharges (
    pricing_plan_version_id, cargo_type_id, currency_code, surcharge_type, surcharge_value
  )
  select p_version_id, t.cargo_type_id, v_currency, t.surcharge_type, t.surcharge_value
  from jsonb_to_recordset(coalesce(p_draft -> 'cargo_surcharges', '[]'::jsonb))
    as t(cargo_type_id uuid, surcharge_type text, surcharge_value numeric);

  insert into public.pricing_equipment_surcharges (
    pricing_plan_version_id, equipment_id, currency_code, surcharge_type, surcharge_value
  )
  select p_version_id, t.equipment_id, v_currency, t.surcharge_type, t.surcharge_value
  from jsonb_to_recordset(coalesce(p_draft -> 'equipment_surcharges', '[]'::jsonb))
    as t(equipment_id uuid, surcharge_type text, surcharge_value numeric);

  insert into public.pricing_time_multipliers (
    pricing_plan_version_id, name, days_of_week, start_time, end_time,
    timezone, multiplier, applies_to, priority, stacks
  )
  select p_version_id, t.name,
         array(select jsonb_array_elements_text(t.days_of_week)::smallint),
         t.start_time, t.end_time,
         coalesce(nullif(t.timezone, ''), 'Africa/Dar_es_Salaam'),
         t.multiplier,
         coalesce(nullif(t.applies_to, ''), 'subtotal'),
         coalesce(t.priority, 0),
         coalesce(t.stacks, false)
  from jsonb_to_recordset(coalesce(p_draft -> 'time_multipliers', '[]'::jsonb))
    as t(name text, days_of_week jsonb, start_time time, end_time time, timezone text,
         multiplier numeric, applies_to text, priority integer, stacks boolean);

  insert into public.pricing_zone_multipliers (pricing_plan_version_id, service_zone_id, multiplier, reason)
  select p_version_id, t.service_zone_id, t.multiplier, nullif(btrim(coalesce(t.reason, '')), '')
  from jsonb_to_recordset(coalesce(p_draft -> 'zone_multipliers', '[]'::jsonb))
    as t(service_zone_id uuid, multiplier numeric, reason text);

  insert into public.pricing_plan_zones (pricing_plan_version_id, service_zone_id, is_primary)
  select p_version_id, t.service_zone_id, coalesce(t.is_primary, false)
  from jsonb_to_recordset(coalesce(p_draft -> 'zones', '[]'::jsonb))
    as t(service_zone_id uuid, is_primary boolean);

  insert into public.pricing_plan_vehicle_types (pricing_plan_version_id, vehicle_type_id)
  select distinct p_version_id, v::uuid
  from jsonb_array_elements_text(coalesce(p_draft -> 'vehicle_type_ids', '[]'::jsonb)) v;

  return p_version_id;
end;
$$;

comment on function public.admin_save_pricing_draft(uuid, jsonb) is
  'Replaces every rate, tier, surcharge and multiplier of an unpublished draft atomically.';

revoke all on function public.admin_save_pricing_draft(uuid, jsonb) from public, anon;
grant execute on function public.admin_save_pricing_draft(uuid, jsonb) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- admin_discard_pricing_draft
-- ----------------------------------------------------------------------------

create or replace function public.admin_discard_pricing_draft(p_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_manage_pricing();
  perform private.lock_pricing_draft(p_version_id);
  perform private.clear_pricing_version_rows(p_version_id);
  delete from public.pricing_plan_versions where id = p_version_id;
end;
$$;

revoke all on function public.admin_discard_pricing_draft(uuid) from public, anon;
grant execute on function public.admin_discard_pricing_draft(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- admin_publish_pricing_draft
-- ----------------------------------------------------------------------------
--
-- Publishes immediately (p_effective_from null) or schedules the version. The
-- previous version stays in force until the new one starts, because publishing
-- sets its effective_to to the new effective_from.

create or replace function public.admin_publish_pricing_draft(
  p_version_id uuid,
  p_effective_from timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version public.pricing_plan_versions%rowtype;
  -- clock_timestamp, not now(): now() is frozen at transaction start.
  v_from timestamptz := coalesce(p_effective_from, clock_timestamp());
  v_latest timestamptz;
begin
  perform private.require_manage_pricing();
  v_version := private.lock_pricing_draft(p_version_id);

  -- Never rewrite history: quotes already priced must keep their version.
  if v_from < clock_timestamp() - interval '1 minute' then
    raise exception 'a version cannot start in the past' using errcode = '22023';
  end if;

  select max(effective_from) into v_latest
  from public.pricing_plan_versions
  where pricing_plan_id = v_version.pricing_plan_id
    and published_at is not null;
  if v_latest is not null and v_from <= v_latest then
    raise exception 'the start time must be after the latest published version (%)', v_latest
      using errcode = '22023';
  end if;

  update public.pricing_plan_versions set effective_from = v_from where id = p_version_id;

  return public.publish_pricing_plan_version(p_version_id);
end;
$$;

comment on function public.admin_publish_pricing_draft(uuid, timestamptz) is
  'Publishes a draft now or at a scheduled start time. Start times cannot be in the past.';

revoke all on function public.admin_publish_pricing_draft(uuid, timestamptz) from public, anon;
grant execute on function public.admin_publish_pricing_draft(uuid, timestamptz) to authenticated, service_role;
