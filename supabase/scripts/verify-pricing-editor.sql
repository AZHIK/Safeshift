-- Verifies the pricing editor functions from 0164_admin_pricing_editor.sql.
--
-- Runs as a real super admin (impersonated through request.jwt.claims) inside
-- a transaction that is always rolled back, so it is safe on any database that
-- has one active super_admin, a city and a vehicle type. Any failed check
-- raises, which aborts the script with the failing message.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-pricing-editor.sql

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as the owner)
-- ---------------------------------------------------------------------------
do $$
declare
  v_admin uuid;
  v_city record;
  v_vehicle uuid;
begin
  select profile_id into v_admin
  from public.admin_roles
  where role_name = 'super_admin' and is_active and revoked_at is null
    and (expires_at is null or expires_at > now())
  limit 1;
  if v_admin is null then raise exception 'FIXTURE: no active super_admin'; end if;

  select c.id, c.country_id into v_city from public.cities c where c.is_active limit 1;
  if v_city.id is null then raise exception 'FIXTURE: no active city'; end if;

  select id into v_vehicle from public.vehicle_types
  where is_active and (country_id is null or country_id = v_city.country_id) limit 1;
  if v_vehicle is null then raise exception 'FIXTURE: no vehicle type'; end if;

  perform set_config('test.admin', v_admin::text, true);
  perform set_config('test.country', v_city.country_id::text, true);
  perform set_config('test.city', v_city.id::text, true);
  perform set_config('test.vehicle', v_vehicle::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- Admin flow (as the authenticated super admin)
-- ---------------------------------------------------------------------------
set local role authenticated;
select null from set_config(
  'request.jwt.claims',
  json_build_object('sub', current_setting('test.admin'), 'aal', 'aal2', 'role', 'authenticated')::text,
  true
);

do $$
declare
  v_plan uuid;
  v_v1 uuid;
  v_v2 uuid;
  v_v3 uuid;
  v_failed boolean;
begin
  v_plan := public.admin_create_pricing_plan(
    current_setting('test.country')::uuid, current_setting('test.city')::uuid,
    current_setting('test.vehicle')::uuid,
    'test-editor-' || substr(md5(random()::text), 1, 8), 'Editor test plan', null, null, 'TZS',
    1000, 500, 50, 3000, 0.18
  );
  perform set_config('test.plan', v_plan::text, true);

  -- 1. A published version cannot be edited in place.
  v_failed := false;
  begin
    perform public.admin_save_pricing_draft(
      (select id from public.pricing_plan_versions where pricing_plan_id = v_plan and version_number = 1),
      '{"base_rates": {"base_fare": 1, "per_km_rate": 1, "per_min_rate": 1}}'
    );
  exception when others then
    v_failed := sqlerrm like '%is published%';
  end;
  if not v_failed then raise exception 'CHECK 1: saving a published version must fail'; end if;

  -- 2. Open a draft; a second draft is refused.
  v_v2 := public.admin_create_pricing_draft(v_plan);
  perform set_config('test.v2', v_v2::text, true);
  v_failed := false;
  begin
    perform public.admin_create_pricing_draft(v_plan);
  exception when unique_violation then v_failed := true;
  end;
  if not v_failed then raise exception 'CHECK 2: a second open draft must be refused'; end if;

  -- 3. Save a full draft.
  perform public.admin_save_pricing_draft(v_v2, jsonb_build_object(
    'notes', 'Night surcharge',
    'base_rates', jsonb_build_object(
      'base_fare', 2000, 'per_km_rate', 600, 'per_min_rate', 40, 'minimum_charge', 5000,
      'loading_fee', 1500, 'unloading_fee', 1500, 'waiting_per_min_rate', 100,
      'waiting_free_minutes', 10, 'multi_stop_fee', 2500, 'vat_rate', 0.18),
    'distance_tiers', jsonb_build_array(
      jsonb_build_object('min_km', 0, 'max_km', 10, 'per_km_rate', 700),
      jsonb_build_object('min_km', 10, 'max_km', null, 'per_km_rate', 500)),
    'weight_tiers', jsonb_build_array(
      jsonb_build_object('min_kg', 500, 'max_kg', null, 'surcharge_type', 'flat_fee', 'surcharge_value', 5000)),
    'time_multipliers', jsonb_build_array(
      jsonb_build_object('name', 'Night', 'days_of_week', jsonb_build_array(0,1,2,3,4,5,6),
        'start_time', '22:00', 'end_time', '05:00', 'multiplier', 1.25))
  ));

  -- 4. Overlapping tiers are rejected and the saved draft is untouched.
  v_failed := false;
  begin
    perform public.admin_save_pricing_draft(v_v2, jsonb_build_object(
      'base_rates', jsonb_build_object('base_fare', 1, 'per_km_rate', 1, 'per_min_rate', 1),
      'distance_tiers', jsonb_build_array(
        jsonb_build_object('min_km', 0, 'max_km', 10, 'per_km_rate', 700),
        jsonb_build_object('min_km', 5, 'max_km', 20, 'per_km_rate', 500))
    ));
  exception when others then v_failed := sqlerrm like '%overlapping distance tier%';
  end;
  if not v_failed then raise exception 'CHECK 4: overlapping distance tiers must be rejected'; end if;

  -- 5. Publishing in the past is refused.
  v_failed := false;
  begin
    perform public.admin_publish_pricing_draft(v_v2, now() - interval '1 day');
  exception when others then v_failed := sqlerrm like '%cannot start in the past%';
  end;
  if not v_failed then raise exception 'CHECK 5: backdated publish must be refused'; end if;

  -- 6. Publish now.
  perform public.admin_publish_pricing_draft(v_v2);

  -- 7. Metadata update creates no version.
  perform public.admin_update_pricing_plan(v_plan, 'Renamed plan', 'desc', true);

  -- 8. Roll back: draft from version 1, then schedule it for tomorrow.
  v_v1 := (select id from public.pricing_plan_versions where pricing_plan_id = v_plan and version_number = 1);
  v_v3 := public.admin_create_pricing_draft(v_plan, v_v1);
  perform set_config('test.v3', v_v3::text, true);
  perform public.admin_publish_pricing_draft(v_v3, now() + interval '1 day');

  -- 9. Discard: open and discard a draft.
  perform set_config('test.discarded', public.admin_create_pricing_draft(v_plan)::text, true);
  perform public.admin_discard_pricing_draft(current_setting('test.discarded')::uuid);
end $$;

-- 10. A user without manage_pricing is refused.
select null from set_config(
  'request.jwt.claims',
  json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text,
  true
);
-- The functions allow has_permission('manage_pricing') OR
-- private.is_pricing_service(). The latter is true whenever the login user
-- (session_user) is postgres, which is the case for this script's connection
-- even after `set role`. Real API traffic logs in as `authenticator`, so there
-- has_permission is the only gate; assert that gate directly.
do $$
begin
  if public.has_permission('manage_pricing') then
    raise exception 'CHECK 10: a user without an admin role must not hold manage_pricing';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Assertions on stored data (as the owner, bypassing RLS)
-- ---------------------------------------------------------------------------
reset role;

do $$
declare
  v_plan uuid := current_setting('test.plan')::uuid;
  v_v2 uuid := current_setting('test.v2')::uuid;
  v_v3 uuid := current_setting('test.v3')::uuid;
  v_rates record;
  v_n integer;
begin
  -- Check 3: everything saved, including the fees the old update dropped.
  select * into v_rates from public.pricing_plan_base_rates where pricing_plan_version_id = v_v2;
  if v_rates.base_fare <> 2000 or v_rates.loading_fee <> 1500 or v_rates.multi_stop_fee <> 2500
     or v_rates.waiting_free_minutes <> 10 then
    raise exception 'CHECK 3: base rates not saved (%)', row_to_json(v_rates);
  end if;
  select count(*) into v_n from public.pricing_distance_tiers where pricing_plan_version_id = v_v2;
  if v_n <> 2 then raise exception 'CHECK 3/4: expected 2 distance tiers, got %', v_n; end if;
  select count(*) into v_n from public.pricing_time_multipliers where pricing_plan_version_id = v_v2;
  if v_n <> 1 then raise exception 'CHECK 3: expected 1 time multiplier, got %', v_n; end if;

  -- Check 6: v2 published and supersedes v1.
  if (select published_at from public.pricing_plan_versions where id = v_v2) is null then
    raise exception 'CHECK 6: version 2 not published';
  end if;
  if (select superseded_by_version_id from public.pricing_plan_versions
      where pricing_plan_id = v_plan and version_number = 1) is distinct from v_v2 then
    raise exception 'CHECK 6: version 1 not superseded by version 2';
  end if;

  -- Check 7: renaming did not add a version (v1, v2, v3 only; discarded one gone).
  select count(*) into v_n from public.pricing_plan_versions where pricing_plan_id = v_plan;
  if v_n <> 3 then raise exception 'CHECK 7/9: expected 3 versions, got %', v_n; end if;
  if (select name from public.pricing_plans where id = v_plan) <> 'Renamed plan' then
    raise exception 'CHECK 7: plan not renamed';
  end if;

  -- Check 8: v3 copies v1 rates and only takes over tomorrow.
  if (select base_fare from public.pricing_plan_base_rates where pricing_plan_version_id = v_v3) <> 1000 then
    raise exception 'CHECK 8: rollback draft did not copy version 1 rates';
  end if;
  if public.active_pricing_plan_version(v_plan, clock_timestamp()) <> v_v2 then
    raise exception 'CHECK 8: version 2 must stay active until the scheduled start';
  end if;
  if public.active_pricing_plan_version(v_plan, now() + interval '2 days') <> v_v3 then
    raise exception 'CHECK 8: version 3 must be active after its start';
  end if;

  -- Check 9: the discarded draft is gone with its rows.
  if exists (select 1 from public.pricing_plan_versions where id = current_setting('test.discarded')::uuid)
     or exists (select 1 from public.pricing_plan_base_rates
                where pricing_plan_version_id = current_setting('test.discarded')::uuid) then
    raise exception 'CHECK 9: discarded draft still exists';
  end if;

  raise notice 'verify-pricing-editor: all checks passed';
end $$;

select 'verify-pricing-editor: all checks passed' as result;

rollback;
