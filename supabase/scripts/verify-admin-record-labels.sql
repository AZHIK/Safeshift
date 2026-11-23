-- Verifies 0184_admin_record_labels.sql and 0185_admin_entity_names.sql as a super admin, rolled back.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-admin-record-labels.sql

begin;

select null from set_config('t.admin', (select profile_id::text from public.admin_roles
  where role_name = 'super_admin' and is_active and revoked_at is null and country_id is null limit 1), true);

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal2')::text, true);

do $$
declare
  v_opts jsonb;
  v_job record;
  v_labels jsonb;
  v_failed boolean := false;
begin
  -- 1. City choices for a pricing plan are city names, not ids.
  v_opts := public.admin_record_options('pricing_plans', 'city_id');
  if jsonb_array_length(v_opts -> 'options') = 0 then raise exception 'no city options'; end if;
  if (v_opts -> 'options' -> 0 ->> 'label') ~ '^[0-9a-f]{8}-' then raise exception 'city label is an id: %', v_opts; end if;

  -- 2. Search narrows the choices.
  v_opts := public.admin_record_options('cities', 'country_id', 'tanz');
  if exists (select 1 from jsonb_array_elements(v_opts -> 'options') e where e ->> 'label' not ilike '%tanz%') then
    raise exception 'search returned non-matching countries: %', v_opts;
  end if;

  -- 3. A job's customer and driver resolve to names.
  select customer_id, driver_id into v_job from public.jobs where driver_id is not null limit 1;
  if found then
    v_labels := public.admin_record_labels('jobs', jsonb_build_object(
      'customer_id', jsonb_build_array(v_job.customer_id), 'driver_id', jsonb_build_array(v_job.driver_id)));
    if v_labels -> 'customer_id' ->> v_job.customer_id::text is null then raise exception 'no customer name: %', v_labels; end if;
    if v_labels -> 'driver_id' ->> v_job.driver_id::text is null then raise exception 'no driver name: %', v_labels; end if;
  end if;

  -- 4. Own-row names.
  v_labels := public.admin_record_display('countries', array(select id::text from public.countries limit 3));
  if (select count(*) from jsonb_object_keys(v_labels)) = 0 then raise exception 'no country names'; end if;

  -- 5. A column that is not a reference is refused.
  begin
    perform public.admin_record_options('cities', 'name');
  exception when others then v_failed := true;
  end;
  if not v_failed then raise exception 'non-reference column accepted'; end if;

  -- 6. Console screens can name jobs and people.
  v_labels := public.admin_entity_names('profiles', array[current_setting('t.admin')]);
  if v_labels ->> current_setting('t.admin') is null then raise exception 'no admin name: %', v_labels; end if;
end $$;

-- 7. A user without console access is refused.
select null from set_config('request.jwt.claims',
  json_build_object('sub', (select id from public.profiles where primary_role = 'customer' limit 1), 'role', 'authenticated')::text, true);
do $$ begin
  perform public.admin_record_options('pricing_plans', 'city_id');
  raise exception 'customer read reference options';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.admin_entity_names('profiles', array[auth.uid()::text]);
  raise exception 'customer read entity names';
exception when insufficient_privilege then null;
end $$;

select 'all checks passed' as result;
rollback;
