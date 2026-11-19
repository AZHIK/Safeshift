-- ============================================================================
-- SafeShift — Migration 0140
-- Courier ordering flow fixes.
--
-- This migration closes the gaps between the single-screen booking flow and
-- the dispatch engine:
--
--   1. Parcel details (description, declared value, photos) are persisted on
--      the quote request instead of living only in the client.
--   2. The quote engine rejects loads that do not fit the chosen vehicle,
--      cargo/vehicle mismatches, missing declared values, and out-of-area
--      destinations with actionable messages.
--   3. Dispatch excludes drivers who are already on a job or whose GPS fix is
--      stale, and remembers how often a job has been dispatched.
--   4. A re-dispatch worker escalates the search radius, gives up after a
--      bounded number of attempts, and cancels jobs nobody could take without
--      charging the customer.
--   5. job_cancel() clears pending offers and frees the driver.
--   6. Driver/customer RPCs expose parcel, schedule and cancellation fields.
--   7. Push notifications are wired to job offers and job status changes.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Parcel details on quote requests
-- ----------------------------------------------------------------------------
alter table public.quote_requests
  add column if not exists cargo_description text,
  add column if not exists declared_value_tzs numeric(14,2),
  add column if not exists cargo_photo_paths text[] not null default '{}';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'quote_requests_declared_value_check'
      and conrelid = 'public.quote_requests'::regclass
  ) then
    alter table public.quote_requests
      add constraint quote_requests_declared_value_check
      check (declared_value_tzs is null or declared_value_tzs >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'quote_requests_cargo_description_check'
      and conrelid = 'public.quote_requests'::regclass
  ) then
    alter table public.quote_requests
      add constraint quote_requests_cargo_description_check
      check (cargo_description is null or length(cargo_description) <= 1000);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'quote_requests_cargo_photo_paths_check'
      and conrelid = 'public.quote_requests'::regclass
  ) then
    alter table public.quote_requests
      add constraint quote_requests_cargo_photo_paths_check
      check (array_position(cargo_photo_paths, null) is null);
  end if;
end;
$$;

comment on column public.quote_requests.cargo_description is
  'Customer description of the goods being moved. Shown to the assigned driver.';
comment on column public.quote_requests.declared_value_tzs is
  'Customer-declared approximate value of the goods, used for handling and claims.';
comment on column public.quote_requests.cargo_photo_paths is
  'Object paths inside the job-evidence bucket. Uploaded by the customer after the job is created.';

-- ----------------------------------------------------------------------------
-- 2. Dispatch bookkeeping on jobs
-- ----------------------------------------------------------------------------
alter table public.jobs
  add column if not exists dispatch_attempts smallint not null default 0,
  add column if not exists last_dispatched_at timestamptz;

comment on column public.jobs.dispatch_attempts is
  'How many times the dispatch worker has searched for a driver for this job.';
comment on column public.jobs.last_dispatched_at is
  'When the dispatch worker last searched for this job.';

create index if not exists idx_jobs_undispatched
  on public.jobs (created_at)
  where driver_id is null
    and status in ('requested', 'quoted', 'matched');
-- ----------------------------------------------------------------------------
-- 3. Authoritative quote function (parcel-aware)
-- ----------------------------------------------------------------------------
-- The old 16-argument signature is replaced so the parcel fields can be
-- persisted with the quote. The first sixteen arguments keep their names and
-- order, so positional callers and the quote-calculate Edge Function continue
-- to work.
drop function if exists public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric
);

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
  p_duration_min numeric default null,
  p_cargo_description text default null,
  p_declared_value_tzs numeric default null,
  p_cargo_photo_paths text[] default '{}'::text[]
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
  v_photo_paths        text[] := coalesce(p_cargo_photo_paths, '{}'::text[]);
  v_match_count        integer;
  v_vehicle            public.vehicle_types%rowtype;
  v_cargo              public.cargo_types%rowtype;
  v_has_cargo          boolean := false;
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

  if p_declared_value_tzs is not null and p_declared_value_tzs < 0 then
    raise exception 'declared_value_tzs must be >= 0' using errcode = '22023';
  end if;

  if p_cargo_description is not null
     and length(btrim(p_cargo_description)) > 1000
  then
    raise exception 'cargo_description must be 1000 characters or fewer'
      using errcode = '22023';
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

  if p_distance_km is not null and p_distance_km > 1000 then
    raise exception 'route distance is too long for a single move'
      using errcode = '22023';
  end if;

  if p_scheduled_at is not null and p_scheduled_at < v_now - interval '15 minutes' then
    raise exception 'scheduled time is in the past' using errcode = '22023';
  end if;

  if p_scheduled_at is not null and p_scheduled_at > v_now + interval '60 days' then
    raise exception 'moves can be scheduled at most 60 days ahead'
      using errcode = '22023';
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

  if not exists (
    select 1 from public.cities c
    where c.is_active
      and c.boundary is not null
      and extensions.ST_Covers(c.boundary, p_destination_location)
  ) then
    raise exception 'destination point is outside every active service city'
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

  select * into v_vehicle
  from public.vehicle_types vt
  where vt.id = p_vehicle_type_id;

  if p_cargo_type_id is not null then
    select * into v_cargo
    from public.cargo_types ct
    where ct.id = p_cargo_type_id
      and ct.is_active
      and (ct.country_id is null or ct.country_id = v_city.country_id);

    if not found then
      raise exception 'cargo type % is not available in %', p_cargo_type_id, v_city.name
        using errcode = 'P0002';
    end if;
    v_has_cargo := true;
  end if;

  -- 3. Load must fit the vehicle that was quoted.
  if p_cargo_weight_kg is not null and p_cargo_weight_kg > v_vehicle.capacity_kg_max then
    raise exception 'This load weighs % kg but a % carries at most % kg. Choose a larger vehicle.',
      round(p_cargo_weight_kg, 1), v_vehicle.name, round(v_vehicle.capacity_kg_max, 0)
      using errcode = '22023';
  end if;

  if p_cargo_volume_m3 is not null
     and v_vehicle.capacity_m3_max is not null
     and p_cargo_volume_m3 > v_vehicle.capacity_m3_max
  then
    raise exception 'This load is % m3 but a % carries at most % m3. Choose a larger vehicle.',
      round(p_cargo_volume_m3, 1), v_vehicle.name, round(v_vehicle.capacity_m3_max, 1)
      using errcode = '22023';
  end if;

  if v_has_cargo then
    if cardinality(v_cargo.allowed_vehicle_type_codes) > 0
       and not (v_vehicle.code = any(v_cargo.allowed_vehicle_type_codes))
    then
      raise exception 'Cargo type "%" cannot travel in a %. Choose an allowed vehicle.',
        v_cargo.name, v_vehicle.name
        using errcode = '22023';
    end if;

    if cardinality(v_cargo.prohibited_vehicle_type_codes) > 0
       and v_vehicle.code = any(v_cargo.prohibited_vehicle_type_codes)
    then
      raise exception 'Cargo type "%" cannot travel in a %. Choose another vehicle.',
        v_cargo.name, v_vehicle.name
        using errcode = '22023';
    end if;

    if v_cargo.requires_declared_value
       and (p_declared_value_tzs is null or p_declared_value_tzs <= 0)
    then
      raise exception 'Add an approximate value for % so the driver can handle it correctly.',
        v_cargo.name
        using errcode = '22023';
    end if;

    if p_declared_value_tzs is not null
       and v_cargo.max_value_tzs is not null
       and p_declared_value_tzs > v_cargo.max_value_tzs
    then
      raise exception 'Declared value exceeds the % limit for %. Split the load or contact support.',
        round(v_cargo.max_value_tzs, 0), v_cargo.name
        using errcode = '22023';
    end if;
  end if;

  -- 4. Distance and duration.
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

  -- 5. Resolve the active plan, then its published version for now().
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

  -- 6. Fare core (scheduled time drives time-of-day multipliers).
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

  -- 7. Highest matching active surge, if any (Decision F).
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

  -- 8. Promotion validation and one-promo discount (Decision C).
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

  -- 9. One transaction: request, quote, immutable snapshot.
  begin
    v_session_id := auth.jwt() ->> 'session_id';
  exception when others then
    v_session_id := null;
  end;

  insert into public.quote_requests (
    id, country_id, city_id, customer_id,
    pickup_location, pickup_address, destination_location, destination_address,
    vehicle_type_id, cargo_type_id, cargo_weight_kg, cargo_volume_m3,
    cargo_description, declared_value_tzs, cargo_photo_paths,
    scheduled_at, stop_count, waiting_minutes, requested_at, session_id, metadata
  ) values (
    v_request_id, v_city.country_id, v_city.id, p_customer_id,
    p_pickup_location, p_pickup_address, p_destination_location, p_destination_address,
    p_vehicle_type_id, p_cargo_type_id, p_cargo_weight_kg, p_cargo_volume_m3,
    nullif(btrim(coalesce(p_cargo_description, '')), ''),
    p_declared_value_tzs, v_photo_paths,
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
      'cargo_description', nullif(btrim(coalesce(p_cargo_description, '')), ''),
      'declared_value_tzs', p_declared_value_tzs,
      'cargo_photo_paths', to_jsonb(v_photo_paths),
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

comment on function public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric, text, numeric, text[]
) is
  'Authoritative Phase 4 quote function. Validates the caller and the load/vehicle fit, resolves the plan, applies surge/promo/LATRA cap, persists the parcel details, and returns the quote id.';

revoke all on function public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric, text, numeric, text[]
) from public;
revoke all on function public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric, text, numeric, text[]
) from anon;
grant execute on function public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric, text, numeric, text[]
) to authenticated, service_role;
-- ----------------------------------------------------------------------------
-- 4. Attach parcel photos to a freshly created job
-- ----------------------------------------------------------------------------
-- Photos are uploaded to the private job-evidence bucket after the job row
-- exists (the bucket policies are path-scoped to the job), but before
-- dispatch, so the first driver already sees them.
create or replace function public.job_attach_parcel_photos(
  p_job_id uuid,
  p_photo_paths text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_paths text[] := coalesce(p_photo_paths, '{}'::text[]);
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or (v_actor is not null and v_actor = v_job.customer_id)
  ) then
    raise exception 'not authorised to attach parcel photos to job %', p_job_id
      using errcode = '42501';
  end if;

  if v_job.status not in ('requested', 'quoted', 'matched') then
    raise exception 'parcel photos can only be changed before a driver accepts'
      using errcode = '23514';
  end if;

  if cardinality(v_paths) > 8 then
    raise exception 'at most 8 parcel photos are allowed' using errcode = '22023';
  end if;

  if array_position(v_paths, null) is not null then
    raise exception 'parcel photo paths cannot contain nulls' using errcode = '22023';
  end if;

  update public.quote_requests qr
     set cargo_photo_paths = v_paths,
         updated_at = now()
    from public.quotes q
   where q.id = v_job.quote_id
     and qr.id = q.quote_request_id;
end;
$$;

comment on function public.job_attach_parcel_photos(uuid, text[]) is
  'Stores parcel photo object paths on the job quote request. Only the customer may call it before a driver accepts.';

revoke all on function public.job_attach_parcel_photos(uuid, text[]) from public;
revoke all on function public.job_attach_parcel_photos(uuid, text[]) from anon;
grant execute on function public.job_attach_parcel_photos(uuid, text[]) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Job inserts keep the customer's payment choice
-- ----------------------------------------------------------------------------
create or replace function private.prepare_job_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quote   public.quotes%rowtype;
  v_request public.quote_requests%rowtype;
  v_service boolean := private.is_service_context();
begin
  if new.quote_id is null then
    raise exception 'jobs.quote_id is required' using errcode = '23502';
  end if;

  select * into v_quote
  from public.quotes
  where id = new.quote_id;

  if not found then
    raise exception 'quote % not found', new.quote_id using errcode = 'P0002';
  end if;

  select * into v_request
  from public.quote_requests
  where id = v_quote.quote_request_id;

  if not found then
    raise exception 'quote request for quote % not found', new.quote_id using errcode = 'P0002';
  end if;

  if new.customer_id is null then
    new.customer_id := v_request.customer_id;
  end if;

  if new.customer_id <> v_request.customer_id then
    raise exception 'job customer does not match the quote customer'
      using errcode = '23514';
  end if;

  if new.city_id is null then
    new.city_id := v_request.city_id;
  end if;

  if new.city_id <> v_request.city_id then
    raise exception 'job city does not match the quote city'
      using errcode = '23514';
  end if;

  new.distance_km := v_quote.distance_km;
  new.final_amount := v_quote.total;
  new.final_currency_code := v_quote.currency_code;
  new.scheduled_at := coalesce(new.scheduled_at, v_request.scheduled_at, now());

  -- A promo is redeemed when the priced quote becomes a job. The ledger is
  -- append-only and client-inaccessible; service/seed inserts still pass
  -- through this SECURITY DEFINER trigger.
  if v_quote.promo_code_id is not null
     and not exists (
       select 1 from public.promo_redemptions pr where pr.job_id = new.id
     )
  then
    insert into public.promo_redemptions (
      promo_code_id, profile_id, job_id, discount_amount, currency_code,
      redeemed_at, created_at
    ) values (
      v_quote.promo_code_id, v_request.customer_id, new.id,
      v_quote.promo_discount, v_quote.currency_code, now(), now()
    );
  end if;

  if not v_service then
    if v_quote.expires_at <= now() then
      raise exception 'quote % has expired', v_quote.id using errcode = '22023';
    end if;

    if exists (select 1 from public.jobs j where j.quote_id = new.quote_id) then
      raise exception 'quote % has already been used to create a job', v_quote.id
        using errcode = '23505';
    end if;

    -- A client may only create the untouched initial state. Every later change
    -- goes through job_advance_status(), job_assign_driver() or job_cancel().
    -- payment_method is intentionally kept: it is the customer's choice and
    -- does not move money on its own.
    new.status := 'requested';
    new.driver_id := null;
    new.vehicle_id := null;
    new.accepted_at := null;
    new.started_at := null;
    new.completed_at := null;
    new.cancelled_at := null;
    new.payment_status := 'pending';
    new.cancellation_policy_applied := null;
    new.cancellation_fee := 0;
    new.actual_duration_min := null;
    new.actual_distance_km := null;
    new.dispatch_attempts := 0;
    new.last_dispatched_at := null;
  end if;

  return new;
end;
$$;

comment on function private.prepare_job_insert() is
  'Derives customer/city/distance/amount from the persisted quote, keeps the customer payment choice, and prevents clients from creating a job in a non-initial state.';

-- ----------------------------------------------------------------------------
-- 6. Driver availability follows the job lifecycle
-- ----------------------------------------------------------------------------
create or replace function private.sync_driver_availability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.driver_id is not null then
      update public.drivers
         set is_available = false
       where id = new.driver_id;
    end if;
    return new;
  end if;

  -- A new assignment (or a reassignment) makes the driver busy.
  if new.driver_id is not null
     and new.driver_id is distinct from old.driver_id
     and new.status not in ('completed', 'cancelled')
  then
    update public.drivers
       set is_available = false
     where id = new.driver_id;
  end if;

  -- Reaching a terminal state releases the driver.
  if new.status in ('completed', 'cancelled')
     and old.status not in ('completed', 'cancelled')
  then
    if new.driver_id is not null then
      update public.drivers
         set is_available = true
       where id = new.driver_id;
    end if;
  end if;

  return new;
end;
$$;

comment on function private.sync_driver_availability() is
  'Keeps drivers.is_available in step with job assignment and completion so dispatched drivers stop receiving offers.';

drop trigger if exists trg_jobs_sync_driver_availability on public.jobs;
create trigger trg_jobs_sync_driver_availability
  after insert or update of driver_id, status on public.jobs
  for each row execute function private.sync_driver_availability();
-- ----------------------------------------------------------------------------
-- 7. Dispatch: exclude busy and stale drivers, remember attempts
-- ----------------------------------------------------------------------------
create or replace function public.match_dispatch(
  p_job_id uuid,
  p_radius_km numeric default 10,
  p_limit integer default 5,
  p_timeout_seconds integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor            uuid := auth.uid();
  v_job              public.jobs%rowtype;
  v_vehicle_type_id  uuid;
  v_pickup           extensions.geography;
  v_scheduled_at     timestamptz;
  v_driver           record;
  v_sequence         integer;
  v_offers           jsonb := '[]'::jsonb;
  v_offer_id         uuid;
  v_radius_m         numeric;
  v_timeout          integer := greatest(5, least(coalesce(p_timeout_seconds, 30), 300));
  v_limit            integer := greatest(1, least(coalesce(p_limit, 5), 20));
  v_verified         integer := 0;
  v_located          integer := 0;
  v_vehicled         integer := 0;
  v_typed            integer := 0;
  v_in_radius        integer := 0;
  v_busy             integer := 0;
begin
  if p_job_id is null then
    raise exception 'job id is required' using errcode = '22004';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or v_actor = v_job.customer_id
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to dispatch job %', p_job_id
      using errcode = '42501';
  end if;

  if v_job.driver_id is not null
     or v_job.status not in ('requested', 'quoted', 'matched')
  then
    return jsonb_build_object(
      'job_id', p_job_id,
      'offers', '[]'::jsonb,
      'count', 0,
      'reason', 'job is no longer dispatchable'
    );
  end if;

  select qr.vehicle_type_id, qr.pickup_location, qr.scheduled_at
    into v_vehicle_type_id, v_pickup, v_scheduled_at
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  if v_pickup is null or v_vehicle_type_id is null then
    raise exception 'job % has no pickup or vehicle type', p_job_id
      using errcode = '23514';
  end if;

  -- Scheduled moves are not offered hours in advance. The dispatch worker
  -- starts the search 45 minutes before the requested time.
  if v_scheduled_at is not null
     and v_scheduled_at > now() + interval '45 minutes'
  then
    return jsonb_build_object(
      'job_id', p_job_id,
      'offers', '[]'::jsonb,
      'count', 0,
      'reason', 'job is scheduled for later',
      'scheduled_at', v_scheduled_at
    );
  end if;

  -- The customer app retries dispatch as a fallback for a missing pg_cron.
  -- A job that already has a live offer must never fan out to more drivers,
  -- and the retry must not consume a dispatch attempt.
  if exists (
    select 1 from public.job_offers o
    where o.job_id = p_job_id
      and o.response = 'pending'
      and o.expires_at > now()
  ) then
    return jsonb_build_object(
      'job_id', p_job_id,
      'offers', '[]'::jsonb,
      'count', 0,
      'reason', 'waiting for a driver to respond'
    );
  end if;

  if p_radius_km is null or p_radius_km <= 0 then
    raise exception 'radius_km must be > 0' using errcode = '22023';
  end if;
  v_radius_m := p_radius_km * 1000;

  -- Count the drivers surviving each filter, in the same order the selection
  -- below applies them. Used only to explain an empty result.
  select count(*) into v_verified
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
   where d.verification_status = 'verified'
     and d.is_available;

  select count(*) into v_located
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes';

  select count(*) into v_vehicled
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified';

  select count(*) into v_typed
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and v.vehicle_type_id = v_vehicle_type_id;

  select count(*) into v_busy
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and v.vehicle_type_id = v_vehicle_type_id
     and not exists (
       select 1 from public.jobs aj
       where aj.driver_id = d.id
         and aj.status in (
           'accepted', 'heading_to_pickup', 'arrived', 'loading',
           'in_transit', 'delivered'
         )
     );

  select count(*) into v_in_radius
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
   where d.verification_status = 'verified'
     and d.is_available
     and d.current_location is not null
     and d.location_updated_at > now() - interval '10 minutes'
     and v.is_active
     and v.verification_status = 'verified'
     and v.vehicle_type_id = v_vehicle_type_id
     and not exists (
       select 1 from public.jobs aj
       where aj.driver_id = d.id
         and aj.status in (
           'accepted', 'heading_to_pickup', 'arrived', 'loading',
           'in_transit', 'delivered'
         )
     )
     and extensions.ST_DWithin(d.current_location, v_pickup, v_radius_m);

  for v_driver in
    select
      d.id,
      round((extensions.ST_Distance(d.current_location, v_pickup) / 1000.0)::numeric, 2) as distance_km,
      greatest(
        1,
        ceil(
          extensions.ST_Distance(d.current_location, v_pickup) / 1000.0 / 20.0 * 60.0
        )::integer
      ) as eta_minutes
    from public.drivers d
    join public.profiles p on p.id = d.id and p.is_active
    join public.vehicles v on v.id = d.current_vehicle_id
    where d.verification_status = 'verified'
      and d.is_available
      and d.current_location is not null
      and d.location_updated_at > now() - interval '10 minutes'
      and v.is_active
      and v.verification_status = 'verified'
      and v.vehicle_type_id = v_vehicle_type_id
      and not exists (
        select 1 from public.jobs aj
        where aj.driver_id = d.id
          and aj.status in (
            'accepted', 'heading_to_pickup', 'arrived', 'loading',
            'in_transit', 'delivered'
          )
      )
      and extensions.ST_DWithin(d.current_location, v_pickup, v_radius_m)
      and not exists (
        select 1 from public.job_offers o
        where o.job_id = p_job_id
          and o.driver_id = d.id
          and (
            o.response in ('pending', 'declined')
            or (o.response = 'expired' and o.responded_at > now() - interval '5 minutes')
          )
      )
    order by
      extensions.ST_Distance(d.current_location, v_pickup),
      d.rating desc,
      d.id
    limit v_limit
  loop
    select coalesce(max(o.offer_sequence), 0) + 1
      into v_sequence
    from public.job_offers o
    where o.job_id = p_job_id;

    insert into public.job_offers (
      job_id, driver_id, offer_sequence, offered_at, expires_at,
      distance_to_pickup_km, eta_minutes, payout_estimate, currency_code
    ) values (
      p_job_id, v_driver.id, v_sequence, clock_timestamp(),
      clock_timestamp() + make_interval(secs => v_timeout),
      v_driver.distance_km, v_driver.eta_minutes, null,
      v_job.final_currency_code
    )
    returning id into v_offer_id;

    v_offers := v_offers || jsonb_build_object(
      'offer_id', v_offer_id,
      'driver_id', v_driver.id,
      'distance_km', v_driver.distance_km,
      'eta_minutes', v_driver.eta_minutes,
      'expires_at', clock_timestamp() + make_interval(secs => v_timeout)
    );
  end loop;

  update public.jobs
     set dispatch_attempts = dispatch_attempts + 1,
         last_dispatched_at = now()
   where id = p_job_id;

  return jsonb_build_object(
    'job_id', p_job_id,
    'offers', v_offers,
    'count', jsonb_array_length(v_offers),
    'reason', case
      when jsonb_array_length(v_offers) > 0 then null
      when v_verified = 0 then 'no verified drivers are available right now'
      when v_located = 0 then 'drivers are online but have not shared a recent location'
      when v_vehicled = 0 then 'drivers have no verified vehicle attached'
      when v_typed = 0 then 'no online driver has a vehicle of the requested class'
      when v_busy = 0 then 'every matching driver is already on a job'
      when v_in_radius = 0 then 'no matching driver is within the search radius'
      else 'no matching driver is free right now'
    end,
    'diagnostics', jsonb_build_object(
      'verified_and_available', v_verified,
      'with_fresh_location', v_located,
      'with_verified_vehicle', v_vehicled,
      'with_requested_vehicle_type', v_typed,
      'free_for_a_new_job', v_busy,
      'within_radius', v_in_radius,
      'attempts', v_job.dispatch_attempts + 1
    )
  );
end;
$$;

comment on function public.match_dispatch(uuid, numeric, integer, integer) is
  'Phase 8 dispatch entry point. Selects eligible nearby verified drivers, excludes busy drivers and stale GPS fixes, creates time-bounded offers, and records the attempt. Returns a reason and diagnostics when no driver matched.';
-- ----------------------------------------------------------------------------
-- 8. Cancellation: clear pending offers and waive fees before a match
-- ----------------------------------------------------------------------------
create or replace function public.job_cancel(
  p_job_id uuid,
  p_cancelled_by uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor          uuid := auth.uid();
  v_job            public.jobs%rowtype;
  v_quote          public.quotes%rowtype;
  v_policy         public.cancellation_policies%rowtype;
  v_policy_found   boolean := false;
  v_policy_name    text;
  v_role           public.user_role;
  v_country_id     uuid;
  v_minutes_before integer;
  v_fee            numeric(14,2) := 0;
  v_refund         numeric(14,2) := 0;
  v_currency       char(3);
  v_refund_status  text;
  v_tier           record;
  v_never_matched  boolean := false;
begin
  if p_job_id is null or p_cancelled_by is null then
    raise exception 'job and cancelling profile are required' using errcode = '22004';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a cancellation reason is required' using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or (v_actor is not null and p_cancelled_by = v_actor)
    or public.has_permission('assign_drivers')
  ) then
    raise exception 'not authorised to cancel this job' using errcode = '42501';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_job.status in ('completed', 'cancelled', 'disputed') then
    raise exception 'job % cannot be cancelled in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  if p_cancelled_by = v_job.customer_id then
    v_role := 'customer';
  elsif p_cancelled_by = v_job.driver_id then
    v_role := 'driver';
  elsif private.is_service_context() or public.has_permission('assign_drivers') then
    v_role := 'admin';
  else
    raise exception 'profile % is not a party to job %', p_cancelled_by, p_job_id
      using errcode = '42501';
  end if;

  -- A job nobody ever accepted cannot have incurred a cancellation fee.
  v_never_matched := v_job.driver_id is null and v_job.accepted_at is null;

  select * into v_quote
  from public.quotes
  where id = v_job.quote_id;

  select c.country_id into v_country_id
  from public.cities c
  where c.id = v_job.city_id;

  v_minutes_before := floor(
    extract(epoch from (coalesce(v_job.scheduled_at, now()) - now())) / 60.0
  )::integer;

  if not v_never_matched and v_role in ('customer', 'driver') then
    select * into v_policy
    from public.cancellation_policies cp
    where cp.country_id = v_country_id
      and cp.applies_to_role = v_role
      and cp.is_active
    order by cp.created_at desc, cp.id
    limit 1;

    v_policy_found := found;
  end if;

  if v_policy_found then
    v_policy_name := v_policy.name;

    if v_minutes_before < v_policy.free_cancellation_window_minutes then
      if v_policy.fee_type = 'flat' then
        v_fee := v_policy.fee_value;
      elsif v_policy.fee_type = 'percentage_of_quote' then
        v_fee := round(
          coalesce(v_job.final_amount, v_quote.total, 0) * v_policy.fee_value / 100.0,
          2
        );
      elsif v_policy.fee_type = 'tiered' then
        select (tier ->> 'fee')::numeric into v_fee
        from jsonb_array_elements(v_policy.fee_tiers) tier
        where (tier ->> 'minutes_before_pickup')::numeric <= v_minutes_before
        order by (tier ->> 'minutes_before_pickup')::numeric desc
        limit 1;

        if not found then
          v_fee := 0;
        end if;
      end if;
    end if;
  end if;

  if v_never_matched then
    v_fee := 0;
    v_policy_name := null;
  end if;

  v_fee := round(
    least(
      greatest(coalesce(v_fee, 0), 0),
      coalesce(v_job.final_amount, v_quote.total, 0)
    ),
    2
  );

  v_currency := coalesce(v_job.final_currency_code, v_quote.currency_code);

  if v_job.payment_status in ('paid', 'partially_refunded') then
    v_refund := round(
      greatest(coalesce(v_job.final_amount, v_quote.total, 0) - v_fee, 0),
      2
    );
    v_refund_status := 'pending';
  else
    v_refund := 0;
    v_refund_status := 'not_applicable';
  end if;

  update public.jobs
     set status = 'cancelled',
         cancelled_at = now(),
         cancellation_policy_applied = v_policy_name,
         cancellation_fee = v_fee
   where id = p_job_id;

  -- Any offer still open is dead the moment the job is cancelled. Without
  -- this, drivers keep seeing a request they can no longer win.
  update public.job_offers
     set response = 'auto_reassigned',
         responded_at = now(),
         decline_reason = 'Job cancelled before a driver accepted'
   where job_id = p_job_id
     and response = 'pending';

  insert into public.job_cancellations (
    job_id, cancelled_by, canceller_role, reason, cancellation_policy_id,
    fee_applied, refund_amount, currency_code, refund_status, notes
  ) values (
    p_job_id, p_cancelled_by, v_role, p_reason,
    case when v_policy_found then v_policy.id else null end,
    v_fee, v_refund, v_currency, v_refund_status, p_reason
  );

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, v_job.status, 'cancelled', p_cancelled_by, p_reason
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id,
    'cancelled',
    p_cancelled_by,
    jsonb_build_object(
      'canceller_role', v_role,
      'policy_id', case when v_policy_found then v_policy.id else null end,
      'fee_applied', v_fee,
      'refund_amount', v_refund,
      'refund_status', v_refund_status,
      'currency_code', v_currency,
      'never_matched', v_never_matched,
      'reason', p_reason
    )
  );
end;
$$;

comment on function public.job_cancel(uuid, uuid, text) is
  'Cancels a job, closes pending offers, waives fees for jobs that were never matched, resolves the country/role policy, records the refund placeholder, and writes immutable history/events.';

revoke all on function public.job_cancel(uuid, uuid, text) from public;
revoke all on function public.job_cancel(uuid, uuid, text) from anon;
grant execute on function public.job_cancel(uuid, uuid, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 9. Re-dispatch worker
-- ----------------------------------------------------------------------------
create or replace function public.dispatch_tick(p_max_jobs integer default 25)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job        record;
  v_radius     numeric;
  v_processed  integer := 0;
  v_max        integer := greatest(1, least(coalesce(p_max_jobs, 25), 200));
begin
  if not (
    private.is_service_context()
    or public.has_permission('assign_drivers')
    or public.has_permission('manage_dispatch')
  ) then
    raise exception 'not authorised to run the dispatch worker' using errcode = '42501';
  end if;

  -- Close expired offers first so their drivers become eligible again.
  update public.job_offers
     set response = 'expired',
         responded_at = now(),
         decline_reason = 'Offer expired before a response'
   where response = 'pending'
     and expires_at <= now();

  for v_job in
    select
      j.id,
      j.customer_id,
      j.dispatch_attempts,
      qr.scheduled_at,
      (
        select count(*) from public.job_offers o
        where o.job_id = j.id
          and o.response = 'pending'
          and o.expires_at > now()
      ) as pending_offers
    from public.jobs j
    join public.quotes q on q.id = j.quote_id
    join public.quote_requests qr on qr.id = q.quote_request_id
    where j.driver_id is null
      and j.status in ('requested', 'quoted', 'matched')
      and j.scheduled_at > now() - interval '2 hours'
      and (j.last_dispatched_at is null
           or j.last_dispatched_at < now() - interval '35 seconds')
      and (qr.scheduled_at is null
           or qr.scheduled_at <= now() + interval '45 minutes')
    order by j.created_at
    limit v_max
    for update of j skip locked
  loop
    -- Somebody already has a live offer; do not waste another round.
    if v_job.pending_offers > 0 then
      continue;
    end if;

    -- Six escalating rounds is roughly six minutes of searching.
    if v_job.dispatch_attempts >= 6 then
      begin
        perform public.job_cancel(
          v_job.id,
          v_job.customer_id,
          'No driver was available for this move'
        );
      exception when others then
        -- Another worker may have moved the job on; leave it for the next run.
        null;
      end;
      continue;
    end if;

    v_radius := case v_job.dispatch_attempts
      when 0 then 5
      when 1 then 10
      when 2 then 15
      when 3 then 20
      else 25
    end;

    begin
      perform public.match_dispatch(v_job.id, v_radius, 5, 45);
      v_processed := v_processed + 1;
    exception when others then
      -- Never let a broken job block the worker forever: count the round so
      -- the attempt cap eventually retires it.
      update public.jobs
         set dispatch_attempts = dispatch_attempts + 1,
             last_dispatched_at = now()
       where id = v_job.id;
    end;
  end loop;

  return v_processed;
end;
$$;

comment on function public.dispatch_tick(integer) is
  'Re-dispatches jobs that still have no driver, escalating the radius, and cancels jobs nobody could take after six attempts. Intended for pg_cron.';

revoke all on function public.dispatch_tick(integer) from public;
revoke all on function public.dispatch_tick(integer) from anon;
revoke all on function public.dispatch_tick(integer) from authenticated;
grant execute on function public.dispatch_tick(integer) to service_role;




-- ----------------------------------------------------------------------------
-- 10. Read RPCs expose parcel, schedule and cancellation details
-- ----------------------------------------------------------------------------
-- The app needs these to show the driver what is being moved (and the customer
-- why a job ended). The row shapes change, so the functions are dropped and
-- recreated; no database object depends on them.
drop function if exists public.customer_jobs(integer);
drop function if exists public.customer_job(uuid);
drop function if exists public.driver_pending_offers();
drop function if exists public.driver_active_job();
drop function if exists public.driver_trips(integer);

create function public.customer_jobs(p_limit integer default 50)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_lat double precision,
  destination_lng double precision,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  scheduled_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
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
  cargo_description text,
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
    extensions.ST_Y(qr.pickup_location::extensions.geometry),
    extensions.ST_X(qr.pickup_location::extensions.geometry),
    extensions.ST_Y(qr.destination_location::extensions.geometry),
    extensions.ST_X(qr.destination_location::extensions.geometry),
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.scheduled_at,
    j.completed_at,
    j.cancelled_at,
    jc.reason,
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
    qr.cargo_description,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  left join lateral (
    select c.reason
    from public.job_cancellations c
    where c.job_id = j.id
    order by c.created_at desc
    limit 1
  ) jc on true
  where j.customer_id = auth.uid()
  order by j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

comment on function public.customer_jobs(integer) is
  'Flattened customer job history for the mobile app. Caller sees only their own jobs. Includes pickup/destination coordinates, parcel, schedule, cancellation and catalogue details.';

revoke all on function public.customer_jobs(integer) from public;
revoke all on function public.customer_jobs(integer) from anon;
grant execute on function public.customer_jobs(integer) to authenticated, service_role;

create function public.customer_job(p_job_id uuid)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  pickup_lat double precision,
  pickup_lng double precision,
  destination_lat double precision,
  destination_lng double precision,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  scheduled_at timestamptz,
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  cancellation_fee numeric,
  dispatch_attempts smallint,
  last_dispatched_at timestamptz,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  driver_verified boolean,
  driver_lat double precision,
  driver_lng double precision,
  driver_location_updated_at timestamptz,
  driver_location_fresh boolean,
  vehicle_type text,
  vehicle_type_id uuid,
  vehicle_type_icon_url text,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  cargo_weight_kg numeric,
  declared_value_tzs numeric,
  cargo_photo_paths text[],
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
    extensions.ST_Y(qr.pickup_location::extensions.geometry),
    extensions.ST_X(qr.pickup_location::extensions.geometry),
    extensions.ST_Y(qr.destination_location::extensions.geometry),
    extensions.ST_X(qr.destination_location::extensions.geometry),
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.scheduled_at,
    j.accepted_at,
    j.completed_at,
    j.cancelled_at,
    jc.reason,
    j.cancellation_fee,
    j.dispatch_attempts,
    j.last_dispatched_at,
    j.driver_id,
    coalesce(dp.full_name, dp.display_name),
    dp.phone,
    d.rating,
    d.verification_status = 'verified',
    case when d.current_location is null then null
         else extensions.ST_Y(d.current_location::extensions.geometry) end,
    case when d.current_location is null then null
         else extensions.ST_X(d.current_location::extensions.geometry) end,
    d.location_updated_at,
    d.location_updated_at > now() - interval '5 minutes',
    vt.name,
    vt.id,
    vt.icon_url,
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    qr.cargo_weight_kg,
    qr.declared_value_tzs,
    qr.cargo_photo_paths,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  left join lateral (
    select c.reason
    from public.job_cancellations c
    where c.job_id = j.id
    order by c.created_at desc
    limit 1
  ) jc on true
  where j.id = p_job_id
    and (
      j.customer_id = auth.uid()
      or j.driver_id = auth.uid()
      or public.has_permission('view_all_jobs')
    );
$$;

comment on function public.customer_job(uuid) is
  'Single flattened job for customer tracking/deep links. Participants and staff only. Includes pickup/destination coordinates, parcel, schedule, cancellation and fresh-driver-location details.';

revoke all on function public.customer_job(uuid) from public;
revoke all on function public.customer_job(uuid) from anon;
grant execute on function public.customer_job(uuid) to authenticated, service_role;

create function public.driver_pending_offers()
returns table (
  offer_id uuid,
  job_id uuid,
  offered_at timestamptz,
  expires_at timestamptz,
  offer_ttl_seconds integer,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  scheduled_at timestamptz,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  cargo_weight_kg numeric,
  declared_value_tzs numeric,
  cargo_photo_paths text[],
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
    o.offered_at,
    o.expires_at,
    greatest(0, floor(extract(epoch from (o.expires_at - now())))::integer),
    o.distance_to_pickup_km,
    o.eta_minutes,
    qr.pickup_address,
    qr.destination_address,
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    qr.scheduled_at,
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    qr.cargo_weight_kg,
    qr.declared_value_tzs,
    qr.cargo_photo_paths,
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
  'Flattened pending offer inbox for the authenticated driver, including the live offer TTL, parcel details and schedule.';

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
  scheduled_at timestamptz,
  accepted_at timestamptz,
  cargo_type text,
  cargo_type_id uuid,
  cargo_type_icon_url text,
  cargo_description text,
  cargo_weight_kg numeric,
  declared_value_tzs numeric,
  cargo_photo_paths text[],
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
    qr.scheduled_at,
    j.accepted_at,
    ct.name,
    ct.id,
    ct.icon_url,
    qr.cargo_description,
    qr.cargo_weight_kg,
    qr.declared_value_tzs,
    qr.cargo_photo_paths,
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
  'The authenticated driver''s current assigned job, if any. Includes the parcel details and schedule.';

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
  where j.driver_id = auth.uid()
    and j.status in ('completed', 'cancelled', 'delivered')
  order by j.completed_at desc nulls last, j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
$$;

comment on function public.driver_trips(integer) is
  'Flattened completed/cancelled trips for the authenticated driver, including parcel details.';

revoke all on function public.driver_trips(integer) from public;
revoke all on function public.driver_trips(integer) from anon;
grant execute on function public.driver_trips(integer) to authenticated, service_role;


create or replace function private.invoke_push_send(
  p_profile_id uuid,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb,
  p_deep_link text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url     text;
  v_base    text;
  v_secret  text;
  v_payload jsonb;
begin
  if p_profile_id is null
     or p_title is null or btrim(p_title) = ''
     or p_body is null or btrim(p_body) = ''
  then
    return;
  end if;

  select nullif(btrim(cfg.url), '')
    into v_url
  from public.edge_function_config cfg
  where cfg.function_name = 'push-send'
    and cfg.is_active;

  if v_url is null then
    v_url := nullif(btrim(public.get_vault_secret('safeshift_push_send_url')), '');
  end if;

  if v_url is null then
    v_base := nullif(btrim(coalesce(
      public.get_vault_secret('safeshift_project_url'),
      public.get_vault_secret('SUPABASE_URL')
    )), '');
    if v_base is not null then
      v_url := rtrim(v_base, '/') || '/functions/v1/push-send';
    end if;
  end if;

  v_secret := nullif(btrim(public.get_vault_secret('INTERNAL_FUNCTION_SECRET')), '');

  if v_url is null or v_secret is null then
    return;
  end if;

  v_payload := jsonb_build_object(
    'profile_id', p_profile_id,
    'title', p_title,
    'body', p_body,
    'data', coalesce(p_data, '{}'::jsonb)
  );

  if p_deep_link is not null and btrim(p_deep_link) <> '' then
    v_payload := v_payload || jsonb_build_object('deep_link', p_deep_link);
  end if;

  perform net.http_post(
    url := v_url,
    body := v_payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-internal-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
exception
  when others then
    -- Notifications are best-effort. Never break the business transaction.
    null;
end;
$$;

comment on function private.invoke_push_send(uuid, text, text, jsonb, text) is
  'Enqueues a push-send Edge Function call through pg_net. Quietly does nothing when push is not configured.';

revoke all on function private.invoke_push_send(uuid, text, text, jsonb, text) from public;
revoke all on function private.invoke_push_send(uuid, text, text, jsonb, text) from anon;
revoke all on function private.invoke_push_send(uuid, text, text, jsonb, text) from authenticated;

-- Push the moment an offer is created, so a driver does not have to be
-- staring at the app to see the request.
create or replace function private.notify_new_offer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job     public.jobs%rowtype;
  v_request public.quote_requests%rowtype;
  v_amount  text;
  v_body    text;
begin
  select * into v_job
  from public.jobs
  where id = new.job_id;

  if not found then
    return new;
  end if;

  select qr.* into v_request
  from public.quotes q
  join public.quote_requests qr on qr.id = q.quote_request_id
  where q.id = v_job.quote_id;

  if not found then
    return new;
  end if;

  v_amount := to_char(coalesce(v_job.final_amount, 0), 'FM999,999,999,990');

  v_body := format(
    '%s → %s · TZS %s · %s km away',
    v_request.pickup_address,
    v_request.destination_address,
    v_amount,
    to_char(coalesce(new.distance_to_pickup_km, 0), 'FM990.0')
  );

  perform private.invoke_push_send(
    new.driver_id,
    'New move near you',
    v_body,
    jsonb_build_object(
      'type', 'job_offer',
      'job_id', new.job_id::text,
      'offer_id', new.id::text,
      'expires_at', new.expires_at::text
    ),
    'safeshift://home'
  );

  return new;
end;
$$;

comment on function private.notify_new_offer() is
  'Pushes a new move request to the offered driver.';

drop trigger if exists trg_job_offers_notify_driver on public.job_offers;
create trigger trg_job_offers_notify_driver
  after insert on public.job_offers
  for each row execute function private.notify_new_offer();

-- Keep both parties informed as the job moves. The message is chosen from the
-- new status; the customer is notified about their own job and the driver is
-- notified when the job is cancelled after assignment.
create or replace function private.notify_job_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_name text;
  v_title       text;
  v_body        text;
  v_link        text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status
     and new.driver_id is not distinct from old.driver_id
  then
    return new;
  end if;

  select coalesce(p.full_name, p.display_name)
    into v_driver_name
  from public.profiles p
  where p.id = new.driver_id;

  -- Newly assigned: reassure the customer.
  if new.driver_id is not null
     and (tg_op = 'INSERT' or new.driver_id is distinct from old.driver_id)
  then
    perform private.invoke_push_send(
      new.customer_id,
      'Driver on the way',
      format(
        '%s accepted your move and is heading to the pickup point.',
        coalesce(v_driver_name, 'Your driver')
      ),
      jsonb_build_object('type', 'job_status', 'job_id', new.id::text, 'status', new.status::text),
      'safeshift://tracking/' || new.id::text
    );
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    v_title := null;
    v_body := null;

    case new.status
      when 'heading_to_pickup' then
        v_title := 'Driver on the way';
        v_body := format('%s is heading to the pickup point.', coalesce(v_driver_name, 'Your driver'));
      when 'arrived' then
        v_title := 'Driver has arrived';
        v_body := 'Your driver is at the pickup point.';
      when 'loading' then
        v_title := 'Loading started';
        v_body := 'Your goods are being loaded.';
      when 'in_transit' then
        v_title := 'Your move is on the way';
        v_body := 'Your goods are on the road now.';
      when 'delivered' then
        v_title := 'Delivered';
        v_body := 'Your goods have arrived. Please confirm and complete payment.';
      when 'completed' then
        v_title := 'Move complete';
        v_body := 'Thanks for using SafeShift.';
      when 'cancelled' then
        v_title := 'Move cancelled';
        v_body := 'This move was cancelled.';
      else
        v_title := null;
    end case;

    if v_title is not null then
      perform private.invoke_push_send(
        new.customer_id,
        v_title,
        v_body,
        jsonb_build_object('type', 'job_status', 'job_id', new.id::text, 'status', new.status::text),
        'safeshift://tracking/' || new.id::text
      );
    end if;

    -- A driver who already accepted needs to know the customer cancelled.
    if new.status = 'cancelled' and new.driver_id is not null then
      perform private.invoke_push_send(
        new.driver_id,
        'Move cancelled',
        'The customer cancelled this move. You are free for new requests.',
        jsonb_build_object('type', 'job_status', 'job_id', new.id::text, 'status', new.status::text),
        'safeshift://home'
      );
    end if;
  end if;

  return new;
end;
$$;

comment on function private.notify_job_status() is
  'Pushes assignment, progress and cancellation updates to the customer and, on cancellation, the driver.';

drop trigger if exists trg_jobs_notify_status on public.jobs;
create trigger trg_jobs_notify_status
  after insert or update of status, driver_id on public.jobs
  for each row execute function private.notify_job_status();



-- The dispatch selection filters on availability plus a fresh GPS fix, so this
-- partial index keeps the worker cheap when many drivers are offline.
create index if not exists idx_drivers_dispatchable
  on public.drivers (current_vehicle_id)
  where is_available
    and verification_status = 'verified'
    and current_location is not null;
