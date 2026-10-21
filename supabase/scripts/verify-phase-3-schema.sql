-- ============================================================================
-- SafeShift — Phase 3 schema verification
--
-- Usage (local):
--   psql "$LOCAL_DB_URL" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-3-schema.sql
--
-- Run after migrations and after seed.sql + seed-phase-2.sql + seed-phase-3.sql.
--
-- The script is read-only against seeded rows. It creates a small set of
-- `verify-*` scratch plans/versions to exercise immutability, publishing,
-- resolution and overlap triggers, then removes them before the report.
-- Run it against a disposable local/test database.
-- ============================================================================

drop table if exists _phase3_verification;
create temporary table _phase3_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

-- ----------------------------------------------------------------------------
-- 0. Remove scratch fixtures left by a failed previous run.
-- ----------------------------------------------------------------------------
do $$
declare
  v_plans uuid[] := array[
    '3f000000-0000-4000-8000-000000000001'::uuid,
    '3f000000-0000-4000-8000-000000000011'::uuid,
    '3f000000-0000-4000-8000-000000000021'::uuid
  ];
  v_versions uuid[];
begin
  select coalesce(array_agg(id), '{}'::uuid[]) into v_versions
  from public.pricing_plan_versions
  where pricing_plan_id = any(v_plans);

  if cardinality(v_versions) > 0 then
    delete from public.pricing_distance_tiers where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_weight_tiers where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_volume_tiers where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_cargo_surcharges where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_equipment_surcharges where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_time_multipliers where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_zone_multipliers where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_plan_zones where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_plan_vehicle_types where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_plan_base_rates where pricing_plan_version_id = any(v_versions);
    delete from public.zone_pricing_override_resolution where pricing_plan_version_id = any(v_versions);
    delete from public.pricing_plan_versions where id = any(v_versions);
  end if;

  delete from public.pricing_plans where id = any(v_plans);
end $$;

-- ----------------------------------------------------------------------------
-- 1. Table inventory (18 Phase 3 tables).
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 1, 'Phase 3 table ' || x.name,
       case when to_regclass(x.name) is not null then 'PASS' else 'FAIL' end,
       coalesce(to_regclass(x.name)::text, 'missing')
from (values
  ('public.pricing_plans'),
  ('public.pricing_plan_versions'),
  ('public.pricing_plan_zones'),
  ('public.pricing_plan_vehicle_types'),
  ('public.pricing_plan_base_rates'),
  ('public.pricing_distance_tiers'),
  ('public.pricing_weight_tiers'),
  ('public.pricing_volume_tiers'),
  ('public.pricing_cargo_surcharges'),
  ('public.pricing_equipment_surcharges'),
  ('public.pricing_time_multipliers'),
  ('public.pricing_zone_multipliers'),
  ('public.zone_pricing_override_resolution'),
  ('public.regulated_tariffs'),
  ('public.regulated_tariff_bands'),
  ('public.promo_codes'),
  ('public.promo_redemptions'),
  ('public.promo_code_eligibility_rules')
) x(name);

insert into _phase3_verification
select 1, 'Phase 3 table count is 18',
       case when count(*) = 18 then 'PASS' else 'FAIL' end,
       count(*) || ' of 18 present'
from (values
  ('public.pricing_plans'), ('public.pricing_plan_versions'), ('public.pricing_plan_zones'),
  ('public.pricing_plan_vehicle_types'), ('public.pricing_plan_base_rates'),
  ('public.pricing_distance_tiers'), ('public.pricing_weight_tiers'),
  ('public.pricing_volume_tiers'), ('public.pricing_cargo_surcharges'),
  ('public.pricing_equipment_surcharges'), ('public.pricing_time_multipliers'),
  ('public.pricing_zone_multipliers'), ('public.zone_pricing_override_resolution'),
  ('public.regulated_tariffs'), ('public.regulated_tariff_bands'),
  ('public.promo_codes'), ('public.promo_redemptions'),
  ('public.promo_code_eligibility_rules')
) x(name)
where to_regclass(x.name) is not null;

-- ----------------------------------------------------------------------------
-- 2. Foreign keys.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 2, 'All public foreign keys validated',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*) || ' unvalidated'
from pg_constraint
where contype = 'f'
  and connamespace = 'public'::regnamespace
  and not convalidated;

insert into _phase3_verification
select 2, 'zone_pricing_overrides.pricing_plan_id -> pricing_plan_versions',
       case when exists (
         select 1
         from pg_constraint
         where conrelid = 'public.zone_pricing_overrides'::regclass
           and conname = 'zone_pricing_overrides_pricing_plan_id_fkey'
           and contype = 'f'
           and confrelid = 'public.pricing_plan_versions'::regclass
           and confdeltype = 'r'
       ) then 'PASS' else 'FAIL' end,
       'ON DELETE RESTRICT';

-- ----------------------------------------------------------------------------
-- 3. RLS enabled and at least one policy on every Phase 3 table.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 3, 'RLS enabled on ' || x.name,
       case when c.relrowsecurity then 'PASS' else 'FAIL' end,
       c.relname
from (values
  ('pricing_plans'), ('pricing_plan_versions'), ('pricing_plan_zones'),
  ('pricing_plan_vehicle_types'), ('pricing_plan_base_rates'),
  ('pricing_distance_tiers'), ('pricing_weight_tiers'), ('pricing_volume_tiers'),
  ('pricing_cargo_surcharges'), ('pricing_equipment_surcharges'),
  ('pricing_time_multipliers'), ('pricing_zone_multipliers'),
  ('zone_pricing_override_resolution'), ('regulated_tariffs'),
  ('regulated_tariff_bands'), ('promo_codes'), ('promo_redemptions'),
  ('promo_code_eligibility_rules')
) x(name)
join pg_class c on c.oid = format('public.%I', x.name)::regclass
order by x.name;

insert into _phase3_verification
select 3, 'Policy on ' || x.name,
       case when (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = x.name) > 0
            then 'PASS' else 'FAIL' end,
       (select count(*)::text || ' policies' from pg_policies p where p.schemaname = 'public' and p.tablename = x.name)
from (values
  ('pricing_plans'), ('pricing_plan_versions'), ('pricing_plan_zones'),
  ('pricing_plan_vehicle_types'), ('pricing_plan_base_rates'),
  ('pricing_distance_tiers'), ('pricing_weight_tiers'), ('pricing_volume_tiers'),
  ('pricing_cargo_surcharges'), ('pricing_equipment_surcharges'),
  ('pricing_time_multipliers'), ('pricing_zone_multipliers'),
  ('zone_pricing_override_resolution'), ('regulated_tariffs'),
  ('regulated_tariff_bands'), ('promo_codes'), ('promo_redemptions'),
  ('promo_code_eligibility_rules')
) x(name)
order by x.name;

-- ----------------------------------------------------------------------------
-- 4. Indexes (named quote-path and back-office indexes).
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 4, 'Index ' || x.name,
       case when exists (
         select 1 from pg_indexes
         where schemaname = 'public' and indexname = x.name
       ) then 'PASS' else 'FAIL' end,
       x.name
from (values
  ('idx_pricing_plans_active_scope'),
  ('idx_pricing_plans_code_key'),
  ('idx_pricing_plans_active_city'),
  ('idx_pricing_plan_versions_plan_effective'),
  ('idx_pricing_plan_versions_draft'),
  ('idx_pricing_plan_versions_regulated'),
  ('idx_pricing_plan_zones_zone'),
  ('idx_pricing_plan_vehicle_types_type'),
  ('idx_pricing_distance_tiers_version_min'),
  ('idx_pricing_weight_tiers_version_min'),
  ('idx_pricing_volume_tiers_version_min'),
  ('idx_pricing_cargo_surcharges_cargo'),
  ('idx_pricing_equipment_surcharges_equipment'),
  ('idx_pricing_time_multipliers_version'),
  ('idx_pricing_zone_multipliers_zone'),
  ('idx_regulated_tariffs_active_country'),
  ('idx_regulated_tariffs_vehicle_type'),
  ('idx_regulated_tariffs_effective'),
  ('idx_regulated_tariff_bands_lookup'),
  ('idx_promo_codes_active_country'),
  ('idx_promo_codes_active_window'),
  ('idx_promo_redemptions_code_profile'),
  ('idx_promo_redemptions_profile_redeemed'),
  ('idx_promo_redemptions_redeemed'),
  ('idx_promo_code_eligibility_rules_code'),
  ('idx_zone_pricing_override_resolution_version'),
  ('pricing_plans_scope_code_key'),
  ('pricing_plan_versions_plan_number_key'),
  ('pricing_plan_zones_version_zone_key'),
  ('pricing_plan_vehicle_types_version_type_key'),
  ('pricing_plan_base_rates_version_key'),
  ('pricing_cargo_surcharges_version_cargo_key'),
  ('pricing_equipment_surcharges_version_equipment_key'),
  ('pricing_zone_multipliers_version_zone_key')
) x(name)
order by x.name;

-- ----------------------------------------------------------------------------
-- 5. Helper functions exist, are SECURITY DEFINER and pin search_path.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 5, 'Function ' || x.signature,
       case when p.oid is not null and p.prosecdef then 'PASS' else 'FAIL' end,
       case when p.oid is null then 'missing'
            when not p.prosecdef then 'not security definer'
            else 'security definer' end
from (values
  ('public.publish_pricing_plan_version(uuid)'),
  ('public.draft_pricing_plan_version(uuid)'),
  ('public.active_pricing_plan_version(uuid,timestamp with time zone)'),
  ('public.active_pricing_plan_for(uuid,uuid,uuid,timestamp with time zone)'),
  ('public.zone_pricing_override_plan_version(uuid)'),
  ('public.regulated_max_fare(uuid,numeric,numeric)'),
  ('public.promo_code_valid(uuid,uuid,timestamp with time zone)'),
  ('public.quote_preview(uuid,numeric,numeric,numeric,numeric,uuid,uuid[],uuid,timestamp with time zone)')
) x(signature)
left join pg_proc p on p.oid = to_regprocedure(x.signature)
order by x.signature;

insert into _phase3_verification
select 5, 'All Phase 3 SECURITY DEFINER functions pin search_path',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(p.proname, ', '), 'all pinned')
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and p.proname in (
    'publish_pricing_plan_version', 'draft_pricing_plan_version',
    'active_pricing_plan_version', 'active_pricing_plan_for',
    'zone_pricing_override_plan_version', 'regulated_max_fare',
    'promo_code_valid', 'quote_preview'
  )
  and not ('search_path=""' = any(coalesce(p.proconfig, '{}'::text[])));

-- ----------------------------------------------------------------------------
-- 6. Views exist with security_invoker = true.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 6, 'View ' || x.name,
       case when c.oid is not null
                  and coalesce(c.reloptions, '{}'::text[]) @> array['security_invoker=true']
            then 'PASS' else 'FAIL' end,
       coalesce(array_to_string(c.reloptions, ','), 'missing')
from (values
  ('public.pricing_plan_summary'),
  ('public.promo_code_active'),
  ('public.regulated_tariff_bands_summary')
) x(name)
left join pg_class c on c.oid = to_regclass(x.name)
order by x.name;

-- ----------------------------------------------------------------------------
-- 7. Immutability and overlap triggers exist.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 7, 'Immutability trigger on ' || x.name,
       case when exists (
         select 1 from pg_trigger t
         where t.tgrelid = format('public.%I', x.name)::regclass
           and t.tgname = 'trg_' || x.name || '_immutable'
           and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end,
       'trg_' || x.name || '_immutable'
from (values
  ('pricing_plan_versions'), ('pricing_plan_zones'), ('pricing_plan_vehicle_types'),
  ('pricing_plan_base_rates'), ('pricing_distance_tiers'), ('pricing_weight_tiers'),
  ('pricing_volume_tiers'), ('pricing_cargo_surcharges'),
  ('pricing_equipment_surcharges'), ('pricing_time_multipliers'),
  ('pricing_zone_multipliers')
) x(name)
order by x.name;

insert into _phase3_verification
select 7, 'Overlap trigger ' || x.name,
       case when exists (
         select 1 from pg_trigger t
         where t.tgrelid = format('public.%I', x.table_name)::regclass
           and t.tgname = x.name
           and not t.tgisinternal
       ) then 'PASS' else 'FAIL' end,
       x.name
from (values
  ('trg_regulated_tariff_bands_no_overlap', 'regulated_tariff_bands'),
  ('trg_pricing_distance_tiers_no_overlap', 'pricing_distance_tiers'),
  ('trg_pricing_weight_tiers_no_overlap', 'pricing_weight_tiers'),
  ('trg_pricing_volume_tiers_no_overlap', 'pricing_volume_tiers'),
  ('trg_pricing_time_multipliers_no_overlap', 'pricing_time_multipliers')
) x(name, table_name)
order by x.name;

-- ----------------------------------------------------------------------------
-- 8. Scratch fixtures for immutability/publish/resolution tests.
-- ----------------------------------------------------------------------------
do $$
begin
  insert into public.pricing_plans (
    id, country_id, city_id, service_zone_id, vehicle_type_id, code, name, is_active
  ) values (
    '3f000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    null,
    '22000000-0000-4000-8000-000000000002',
    'verify-immutability', 'Verification immutability fixture', true
  );

  insert into public.pricing_plan_versions (
    id, pricing_plan_id, version_number, currency_code, effective_from,
    published_at, published_by
  ) values
    ('3f000000-0000-4000-8000-000000000002', '3f000000-0000-4000-8000-000000000001',
     1, 'TZS', now() - interval '2 days', now() - interval '2 days',
     'a0000000-0000-4000-8000-000000000001'),
    -- Published version with no children: isolates the DELETE trigger from FKs.
    ('3f000000-0000-4000-8000-000000000004', '3f000000-0000-4000-8000-000000000001',
     2, 'TZS', now() - interval '1 day', now() - interval '1 day',
     'a0000000-0000-4000-8000-000000000001'),
    -- Draft version for the editable-draft test.
    ('3f000000-0000-4000-8000-000000000005', '3f000000-0000-4000-8000-000000000001',
     3, 'TZS', now() + interval '1 day', null, null);

  insert into public.pricing_plan_base_rates (
    id, pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate
  ) values (
    '3f000000-0000-4000-8000-000000000003',
    '3f000000-0000-4000-8000-000000000002',
    'TZS', 1000.00, 100.00, 10.00
  );

  insert into public.pricing_distance_tiers (
    pricing_plan_version_id, currency_code, min_km, max_km, per_km_rate
  ) values (
    '3f000000-0000-4000-8000-000000000002', 'TZS', 0, 10, 100.00
  );

  insert into public.pricing_weight_tiers (
    pricing_plan_version_id, currency_code, min_kg, max_kg, surcharge_type, surcharge_value
  ) values (
    '3f000000-0000-4000-8000-000000000002', 'TZS', 0, 100, 'flat_fee', 0
  );

  insert into public.pricing_volume_tiers (
    pricing_plan_version_id, currency_code, min_m3, max_m3, surcharge_type, surcharge_value
  ) values (
    '3f000000-0000-4000-8000-000000000002', 'TZS', 0, 5, 'flat_fee', 0
  );

  insert into public.pricing_time_multipliers (
    pricing_plan_version_id, name, days_of_week, start_time, end_time, multiplier
  ) values (
    '3f000000-0000-4000-8000-000000000002', 'Scratch peak',
    '{1,2,3,4,5}'::smallint[], '07:00', '09:00', 1.25
  );
end $$;

-- ----------------------------------------------------------------------------
-- 9. Published versions and rate rows are immutable to non-service callers.
-- ----------------------------------------------------------------------------
do $$
declare
  v_blocked boolean := false;
  v_error   text;
  v_ok      boolean;
begin
  perform set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    update public.pricing_plan_versions
       set notes = 'immutability probe'
     where id = '3f000000-0000-4000-8000-000000000002';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase3_verification
  values (9, 'UPDATE on published version fails',
          case when v_blocked and v_error ilike '%immutable%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'update unexpectedly succeeded'));
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  perform set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    update public.pricing_plan_base_rates
       set base_fare = 1.00
     where id = '3f000000-0000-4000-8000-000000000003';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase3_verification
  values (9, 'UPDATE on rate row of published version fails',
          case when v_blocked and v_error ilike '%immutable%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'update unexpectedly succeeded'));
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  perform set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    delete from public.pricing_plan_versions
     where id = '3f000000-0000-4000-8000-000000000004';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase3_verification
  values (9, 'DELETE on published version fails',
          case when v_blocked
                     and (v_error ilike '%immutable%' or v_error ilike '%cannot be deleted%')
               then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'delete unexpectedly succeeded'));
end $$;

do $$
declare
  v_ok boolean := false;
begin
  update public.pricing_plan_versions
     set notes = 'draft probe'
   where id = '3f000000-0000-4000-8000-000000000005'
     and published_at is null;

  if found then
    v_ok := true;
  end if;

  insert into _phase3_verification
  values (9, 'UPDATE on draft version succeeds',
          case when v_ok then 'PASS' else 'FAIL' end,
          'draft version remains editable');
end $$;

-- ----------------------------------------------------------------------------
-- 10. Overlap-prevention triggers reject overlapping rows.
-- ----------------------------------------------------------------------------
do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  begin
    insert into public.regulated_tariff_bands (
      regulated_tariff_id, band_type, min_value, max_value, value_unit, min_fare, max_fare
    ) values (
      '30000000-0000-4000-8000-000000000001', 'distance', 3, 8, 'km', 10000, 50000
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase3_verification
  values (10, 'Overlapping regulated tariff band rejected',
          case when v_blocked and v_error ilike '%overlapping%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'insert unexpectedly succeeded'));
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  begin
    insert into public.pricing_distance_tiers (
      pricing_plan_version_id, currency_code, min_km, max_km, per_km_rate
    ) values (
      '3f000000-0000-4000-8000-000000000002', 'TZS', 5, 15, 100
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase3_verification
  values (10, 'Overlapping distance tier rejected',
          case when v_blocked and v_error ilike '%overlapping distance%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'insert unexpectedly succeeded'));
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  begin
    insert into public.pricing_weight_tiers (
      pricing_plan_version_id, currency_code, min_kg, max_kg, surcharge_type, surcharge_value
    ) values (
      '3f000000-0000-4000-8000-000000000002', 'TZS', 50, 200, 'flat_fee', 100
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase3_verification
  values (10, 'Overlapping weight tier rejected',
          case when v_blocked and v_error ilike '%overlapping weight%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'insert unexpectedly succeeded'));
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  begin
    insert into public.pricing_volume_tiers (
      pricing_plan_version_id, currency_code, min_m3, max_m3, surcharge_type, surcharge_value
    ) values (
      '3f000000-0000-4000-8000-000000000002', 'TZS', 2, 8, 'flat_fee', 100
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase3_verification
  values (10, 'Overlapping volume tier rejected',
          case when v_blocked and v_error ilike '%overlapping volume%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'insert unexpectedly succeeded'));
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  begin
    insert into public.pricing_time_multipliers (
      pricing_plan_version_id, name, days_of_week, start_time, end_time, multiplier
    ) values (
      '3f000000-0000-4000-8000-000000000002', 'Overlapping peak',
      '{1,2,3,4,5}'::smallint[], '08:00', '10:00', 1.10
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase3_verification
  values (10, 'Overlapping non-stacking time window rejected',
          case when v_blocked and v_error ilike '%overlapping non-stacking%' then 'PASS' else 'FAIL' end,
          coalesce(v_error, 'insert unexpectedly succeeded'));
end $$;

-- ----------------------------------------------------------------------------
-- 11. Publish workflow: v2 atomically closes and supersedes v1.
-- ----------------------------------------------------------------------------
do $$
declare
  v_plan uuid := '3f000000-0000-4000-8000-000000000011';
  v_v1   uuid := '3f000000-0000-4000-8000-000000000012';
  v_v2   uuid := '3f000000-0000-4000-8000-000000000013';
  v_ok   boolean;
  v_detail text;
begin
  insert into public.pricing_plans (
    id, country_id, city_id, service_zone_id, vehicle_type_id, code, name, display_order
  ) values (
    v_plan, '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001', null,
    '22000000-0000-4000-8000-000000000001',
    'verify-publish-plan', 'Verification publish fixture', 999
  );

  insert into public.pricing_plan_versions (
    id, pricing_plan_id, version_number, currency_code, effective_from
  ) values (
    v_v1, v_plan, 1, 'TZS', '2026-01-01 00:00:00+03'
  );
  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate
  ) values (v_v1, 'TZS', 1000, 100, 10);

  perform public.publish_pricing_plan_version(v_v1);

  insert into public.pricing_plan_versions (
    id, pricing_plan_id, version_number, currency_code, effective_from
  ) values (
    v_v2, v_plan, 2, 'TZS', '2026-06-01 00:00:00+03'
  );
  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate
  ) values (v_v2, 'TZS', 1100, 100, 10);

  perform public.publish_pricing_plan_version(v_v2);

  select (v1.effective_to = v2.effective_from
          and v1.superseded_by_version_id = v2.id
          and v1.published_at is not null),
         'v1 effective_to=' || coalesce(v1.effective_to::text, 'null')
           || ', superseded_by=' || coalesce(v1.superseded_by_version_id::text, 'null')
    into v_ok, v_detail
  from public.pricing_plan_versions v1
  join public.pricing_plan_versions v2 on v2.id = v_v2
  where v1.id = v_v1;

  insert into _phase3_verification
  values (11, 'publish_pricing_plan_version() supersedes previous version',
          case when v_ok then 'PASS' else 'FAIL' end, v_detail);
end $$;

-- ----------------------------------------------------------------------------
-- 12. Active version resolution.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 12, 'active_pricing_plan_version() returns v1 in March',
       case when (
         select version_number
         from public.pricing_plan_versions
         where id = public.active_pricing_plan_version(
           (select id from public.pricing_plans where code = 'dar-van-standard'),
           '2026-03-01 12:00:00+03'::timestamptz
         )
       ) = 1 then 'PASS' else 'FAIL' end,
       'March 2026';

insert into _phase3_verification
select 12, 'active_pricing_plan_version() returns v2 in October',
       case when (
         select version_number
         from public.pricing_plan_versions
         where id = public.active_pricing_plan_version(
           (select id from public.pricing_plans where code = 'dar-van-standard'),
           '2026-10-05 08:00:00+03'::timestamptz
         )
       ) = 2 then 'PASS' else 'FAIL' end,
       'October 2026';

insert into _phase3_verification
select 12, 'zone_pricing_override_plan_version() resolves the active version',
       case when public.zone_pricing_override_plan_version(
                    '0c000000-0000-4000-8000-000000000001'
                  ) = public.active_pricing_plan_version(
                    (select id from public.pricing_plans where code = 'dar-van-standard'),
                    now()
                  )
            then 'PASS' else 'FAIL' end,
       coalesce(public.zone_pricing_override_plan_version(
                  '0c000000-0000-4000-8000-000000000001'
                )::text, 'null');

-- ----------------------------------------------------------------------------
-- 13. Zone-specific plan wins over the city-wide plan.
-- ----------------------------------------------------------------------------
do $$
declare
  v_plan uuid := '3f000000-0000-4000-8000-000000000021';
  v_ver  uuid := '3f000000-0000-4000-8000-000000000022';
  v_zone uuid := '66666666-0000-4000-8000-000000000001';
  v_city uuid := '55555555-0000-4000-8000-000000000001';
  v_vt   uuid := '22000000-0000-4000-8000-000000000001';
  v_zone_plan uuid;
  v_city_plan uuid;
  v_expected_city uuid;
begin
  insert into public.pricing_plans (
    id, country_id, city_id, service_zone_id, vehicle_type_id, code, name
  ) values (
    v_plan, '33333333-0000-4000-8000-000000000001', v_city, v_zone, v_vt,
    'verify-zone-plan', 'Verification zone fixture'
  );

  insert into public.pricing_plan_versions (
    id, pricing_plan_id, version_number, currency_code, effective_from, published_at
  ) values (
    v_ver, v_plan, 1, 'TZS', now() - interval '1 day', now() - interval '1 day'
  );

  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate
  ) values (v_ver, 'TZS', 1000, 100, 10);

  v_zone_plan := public.active_pricing_plan_for(v_city, v_zone, v_vt, now());
  v_city_plan := public.active_pricing_plan_for(v_city, null, v_vt, now());
  select id into v_expected_city from public.pricing_plans where code = 'dar-van-standard';

  insert into _phase3_verification
  values (13, 'Zone-specific plan wins over city-wide plan',
          case when v_zone_plan = v_plan and v_city_plan = v_expected_city then 'PASS' else 'FAIL' end,
          'zone=' || coalesce(v_zone_plan::text, 'null')
            || ', expected_zone=' || v_plan::text
            || ', city=' || coalesce(v_city_plan::text, 'null')
            || ', expected_city=' || coalesce(v_expected_city::text, 'null'));
end $$;

-- ----------------------------------------------------------------------------
-- 14. quote_preview() returns a complete breakdown.
-- ----------------------------------------------------------------------------
do $$
declare
  v_version uuid;
  v_cargo uuid;
  v_q jsonb;
  v_required text[] := array[
    'base_fare','distance_charge','time_charge','weight_surcharge','volume_surcharge',
    'cargo_surcharge','equipment_surcharge','zone_multiplier','time_multiplier',
    'waiting_charge','multi_stop_charge','subtotal','vat','total','currency_code',
    'regulated_max_fare','is_capped','breakdown_details'
  ];
  v_missing text[];
  v_ok boolean;
begin
  select public.active_pricing_plan_version(p.id, '2026-10-05 08:00:00+03')
    into v_version
  from public.pricing_plans p where p.code = 'dar-van-standard';

  select id into v_cargo from public.cargo_types where code = 'appliances';

  v_q := public.quote_preview(
    v_version, 8, 20, 300, null, v_cargo, null,
    '66666666-0000-4000-8000-000000000001', '2026-10-05 08:00:00+03'
  );

  select coalesce(array_agg(k), '{}'::text[]) into v_missing
  from unnest(v_required) k
  where not (v_q ? k);

  v_ok := cardinality(v_missing) = 0
          and (v_q ->> 'time_multiplier')::numeric = 1.3
          and (v_q ->> 'cargo_surcharge')::numeric = 5000
          and (v_q ->> 'total')::numeric = round(
                ((v_q ->> 'subtotal')::numeric + (v_q ->> 'vat')::numeric), 2);

  insert into _phase3_verification
  values (14, 'quote_preview() returns full vanilla breakdown',
          case when v_ok then 'PASS' else 'FAIL' end,
          'missing=' || coalesce(array_to_string(v_missing, ','), 'none')
            || ', total=' || coalesce(v_q ->> 'total', 'null'));
end $$;

-- ----------------------------------------------------------------------------
-- 15–16. Regulated cap is applied and never exceeded.
-- ----------------------------------------------------------------------------
do $$
declare
  v_version uuid;
  v_cargo uuid;
  v_q jsonb;
  v_cap numeric;
  v_ok boolean;
begin
  select public.active_pricing_plan_version(p.id, '2026-10-05 08:00:00+03')
    into v_version
  from public.pricing_plans p where p.code = 'dar-refrigerated-standard';

  select id into v_cargo from public.cargo_types where code = 'appliances';

  v_q := public.quote_preview(
    v_version, 15, 20, 1000, null, v_cargo, null, null, '2026-10-05 08:00:00+03'
  );

  select public.regulated_max_fare(regulated_tariff_id, 15, 1000)
    into v_cap
  from public.pricing_plan_versions where id = v_version;

  v_ok := (v_q ->> 'is_capped')::boolean
          and v_cap is not null
          and (v_q ->> 'total')::numeric = v_cap
          and (v_q ->> 'total')::numeric <= v_cap
          and (v_q -> 'breakdown_details' ->> 'pre_regulated_total')::numeric > v_cap;

  insert into _phase3_verification
  values (15, 'quote_preview() applies the regulated cap',
          case when v_ok then 'PASS' else 'FAIL' end,
          'cap=' || coalesce(v_cap::text, 'null')
            || ', total=' || coalesce(v_q ->> 'total', 'null')
            || ', pre=' || coalesce(v_q -> 'breakdown_details' ->> 'pre_regulated_total', 'null'));
end $$;

-- ----------------------------------------------------------------------------
-- 17. promo_code_valid() rejects expired and non-new-user codes.
-- ----------------------------------------------------------------------------
do $$
declare
  v_customer uuid := 'c0000000-0000-4000-8000-000000000001';
  v_expired uuid;
  v_welcome uuid;
  v_dar50 uuid;
  v_valid boolean;
  v_ok boolean;
  v_original_created timestamptz;
  v_new_user_rejected boolean;
begin
  select id into v_expired from public.promo_codes where code = 'EXPIRED2025';
  select id into v_welcome from public.promo_codes where code = 'WELCOME10';
  select id into v_dar50 from public.promo_codes where code = 'DAR50';

  select created_at into v_original_created from public.profiles where id = v_customer;

  update public.profiles set created_at = now() - interval '90 days' where id = v_customer;
  v_new_user_rejected := not public.promo_code_valid(v_welcome, v_customer);
  update public.profiles set created_at = v_original_created where id = v_customer;

  v_valid := public.promo_code_valid(v_welcome, v_customer);

  v_ok := not public.promo_code_valid(v_expired, v_customer)
          and v_valid
          and public.promo_code_valid(v_dar50, v_customer)
          and v_new_user_rejected;

  insert into _phase3_verification
  values (17, 'promo_code_valid() rejects expired and non-new-user codes',
          case when v_ok then 'PASS' else 'FAIL' end,
          'expired_rejected=' || (not public.promo_code_valid(v_expired, v_customer))::text
            || ', new_user_rejected=' || v_new_user_rejected::text);
end $$;

-- ----------------------------------------------------------------------------
-- 18. Seed data counts.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 18, 'Seed: 1 LATRA tariff',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       count(*) || ' tariff(s)'
from public.regulated_tariffs
where country_id = '33333333-0000-4000-8000-000000000001'
  and regulatory_body = 'LATRA';

insert into _phase3_verification
select 18, 'Seed: 10 regulated bands',
       case when count(*) = 10 then 'PASS' else 'FAIL' end,
       count(*) || ' band(s)'
from public.regulated_tariff_bands
where regulated_tariff_id = '30000000-0000-4000-8000-000000000001';

insert into _phase3_verification
select 18, 'Seed: 6 Dar pricing plans',
       case when count(*) = 6 then 'PASS' else 'FAIL' end,
       count(*) || ' plan(s)'
from public.pricing_plans where code like 'dar-%';

insert into _phase3_verification
select 18, 'Seed: 7 published versions (6 v1 + van v2)',
       case when count(*) = 7 then 'PASS' else 'FAIL' end,
       count(*) || ' version(s)'
from public.pricing_plan_versions v
join public.pricing_plans p on p.id = v.pricing_plan_id
where p.code like 'dar-%' and v.published_at is not null;

insert into _phase3_verification
select 18, 'Seed: 5 promo codes',
       case when count(*) = 5 then 'PASS' else 'FAIL' end,
       count(*) || ' promo(s)'
from public.promo_codes;

insert into _phase3_verification
select 18, 'Seed: 3 promo eligibility rules',
       case when count(*) = 3 then 'PASS' else 'FAIL' end,
       count(*) || ' rule(s)'
from public.promo_code_eligibility_rules;

insert into _phase3_verification
select 18, 'Seed: zone override resolved to a plan version',
       case when count(*) >= 1 then 'PASS' else 'FAIL' end,
       count(*) || ' resolution(s)'
from public.zone_pricing_override_resolution
where zone_pricing_override_id = '0c000000-0000-4000-8000-000000000001';

insert into _phase3_verification
select 18, 'Seed: pricing_changed audit rows exist',
       case when count(*) >= 7 then 'PASS' else 'FAIL' end,
       count(*) || ' row(s)'
from private.audit_log
where action = 'pricing_changed';

-- ----------------------------------------------------------------------------
-- 19. Permissions, privileges and scope boundaries.
-- ----------------------------------------------------------------------------
insert into _phase3_verification
select 19, 'Phase 3 permissions installed',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       string_agg(permission_key, ', ' order by permission_key)
from public.admin_permissions_catalog
where permission_key in ('manage_pricing', 'manage_regulated_tariffs', 'manage_promotions', 'view_promotions');

insert into _phase3_verification
select 19, 'anon has no Phase 3 table privilege',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(t, ', '), 'no anon access')
from unnest(array[
  'pricing_plans','pricing_plan_versions','pricing_plan_zones','pricing_plan_vehicle_types',
  'pricing_plan_base_rates','pricing_distance_tiers','pricing_weight_tiers',
  'pricing_volume_tiers','pricing_cargo_surcharges','pricing_equipment_surcharges',
  'pricing_time_multipliers','pricing_zone_multipliers',
  'zone_pricing_override_resolution','regulated_tariffs','regulated_tariff_bands',
  'promo_codes','promo_redemptions','promo_code_eligibility_rules'
]) t
where has_table_privilege('anon', format('public.%I', t), 'SELECT')
   or has_table_privilege('anon', format('public.%I', t), 'INSERT')
   or has_table_privilege('anon', format('public.%I', t), 'UPDATE')
   or has_table_privilege('anon', format('public.%I', t), 'DELETE');

insert into _phase3_verification
select 19, 'promo_redemptions is service-write only',
       case when not has_table_privilege('authenticated', 'public.promo_redemptions', 'INSERT')
                 and not has_table_privilege('authenticated', 'public.promo_redemptions', 'UPDATE')
                 and not has_table_privilege('authenticated', 'public.promo_redemptions', 'DELETE')
            then 'PASS' else 'FAIL' end,
       'no client write grant';

insert into _phase3_verification
select 19, 'No Phase 4+ tables created',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(tablename, ', '), 'no quote_history/jobs/commission_rules/payouts')
from pg_tables
where schemaname = 'public'
  and tablename in ('quote_history', 'jobs', 'job_evidence', 'commission_rules', 'payouts', 'payments');

insert into _phase3_verification
select 19, 'No Phase 3 enums introduced',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(typname, ', '), 'TEXT + CHECK only')
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
  and t.typtype = 'e'
  and (t.typname like 'pricing%' or t.typname like 'promo%' or t.typname like 'regulated%');

insert into _phase3_verification
select 19, 'Phase 1 and Phase 2 core tables retained',
       case when count(*) = 6 then 'PASS' else 'FAIL' end,
       count(*) || ' of 6'
from (values
  ('public.profiles'), ('public.vehicles'), ('public.fleets'),
  ('public.vehicle_types'), ('public.cargo_types'), ('public.service_zones')
) x(name)
where to_regclass(x.name) is not null;

-- ----------------------------------------------------------------------------
-- 20. Remove scratch fixtures.
-- ----------------------------------------------------------------------------
do $$
declare
  v_plans uuid[] := array[
    '3f000000-0000-4000-8000-000000000001'::uuid,
    '3f000000-0000-4000-8000-000000000011'::uuid,
    '3f000000-0000-4000-8000-000000000021'::uuid
  ];
  v_versions uuid[];
begin
  select coalesce(array_agg(id), '{}'::uuid[]) into v_versions
  from public.pricing_plan_versions
  where pricing_plan_id = any(v_plans);

  delete from public.pricing_distance_tiers where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_weight_tiers where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_volume_tiers where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_cargo_surcharges where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_equipment_surcharges where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_time_multipliers where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_zone_multipliers where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_plan_zones where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_plan_vehicle_types where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_plan_base_rates where pricing_plan_version_id = any(v_versions);
  delete from public.zone_pricing_override_resolution where pricing_plan_version_id = any(v_versions);
  delete from public.pricing_plan_versions where id = any(v_versions);
  delete from public.pricing_plans where id = any(v_plans);
end $$;

-- ----------------------------------------------------------------------------
-- Report
-- ----------------------------------------------------------------------------
select check_no, check_name, status, details
from _phase3_verification
order by check_no, check_name;

select format(
  'PHASE 3 SCHEMA VERIFICATION: %s PASS, %s FAIL',
  count(*) filter (where status = 'PASS'),
  count(*) filter (where status = 'FAIL')
) as result
from _phase3_verification;

select check_no, check_name, details
from _phase3_verification
where status = 'FAIL'
order by check_no, check_name;
