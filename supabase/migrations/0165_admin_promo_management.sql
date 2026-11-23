-- Promo code management for the admin console.
--
--   admin_save_promo              create or update a promo and replace its
--                                 eligibility rules in one transaction
--   admin_delete_promo            delete a promo that was never redeemed
--   admin_promo_summaries         redemption totals per promo
--   admin_promo_redemptions       paged redemption history of one promo
--
-- Eligibility rule values are free-form JSON in the table. The quote engine
-- (quote_calculate_and_persist) reads these keys, so they are validated here:
--   first_job              {}
--   min_jobs_completed     {"min_jobs": int >= 1}
--   min_account_age_days   {"min_days": int >= 1}
--   specific_zone          {"zone_id": uuid of a service zone}
--   specific_day_of_week   {"day_of_week": 0..6, 0 = Sunday}

create or replace function private.require_permission(p_permission text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_permission(p_permission) then
    raise exception '% permission required', p_permission using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.require_permission(text) from public, anon, authenticated;

-- Validates one eligibility rule and returns its canonical value.
create or replace function private.normalize_promo_rule(p_type text, p_value jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value jsonb := coalesce(p_value, '{}'::jsonb);
  v_int integer;
  v_zone uuid;
begin
  if jsonb_typeof(v_value) <> 'object' then
    raise exception 'rule % must have an object value', p_type using errcode = '22023';
  end if;

  case p_type
    when 'first_job' then
      return '{}'::jsonb;
    when 'min_jobs_completed' then
      v_int := (v_value ->> 'min_jobs')::integer;
      if v_int is null or v_int < 1 then
        raise exception 'minimum completed jobs must be 1 or more' using errcode = '22023';
      end if;
      return jsonb_build_object('min_jobs', v_int);
    when 'min_account_age_days' then
      v_int := (v_value ->> 'min_days')::integer;
      if v_int is null or v_int < 1 then
        raise exception 'minimum account age must be 1 day or more' using errcode = '22023';
      end if;
      return jsonb_build_object('min_days', v_int);
    when 'specific_zone' then
      v_zone := coalesce(v_value ->> 'zone_id', v_value ->> 'service_zone_id')::uuid;
      if v_zone is null or not exists (select 1 from public.service_zones where id = v_zone) then
        raise exception 'choose an existing service zone' using errcode = '22023';
      end if;
      return jsonb_build_object('zone_id', v_zone);
    when 'specific_day_of_week' then
      v_int := (v_value ->> 'day_of_week')::integer;
      if v_int is null or v_int not between 0 and 6 then
        raise exception 'day of week must be 0 (Sunday) to 6 (Saturday)' using errcode = '22023';
      end if;
      return jsonb_build_object('day_of_week', v_int);
    else
      raise exception 'unsupported eligibility rule %', p_type using errcode = '22023';
  end case;
end;
$$;

revoke all on function private.normalize_promo_rule(text, jsonb) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- admin_save_promo
-- ----------------------------------------------------------------------------
--
-- p_promo keys: code, name, description, country_id, discount_type,
-- discount_value, max_discount_amount, min_purchase_amount, currency_code,
-- valid_from, valid_to, total_redemption_limit, per_user_redemption_limit,
-- new_users_only, applicable_vehicle_type_ids, applicable_city_ids,
-- applicable_cargo_type_ids, is_active.
-- p_rules: [{ rule_type, rule_value, description }]

create or replace function public.admin_save_promo(
  p_promo_id uuid,
  p_promo jsonb,
  p_rules jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_promo_id;
  v_code text := upper(btrim(coalesce(p_promo ->> 'code', '')));
  v_type text := p_promo ->> 'discount_type';
  v_value numeric := (p_promo ->> 'discount_value')::numeric;
  v_existing public.promo_codes%rowtype;
  v_redeemed bigint := 0;
  v_rule jsonb;
  v_ids_vehicle uuid[];
  v_ids_city uuid[];
  v_ids_cargo uuid[];
begin
  perform private.require_permission('manage_promotions');

  if jsonb_typeof(p_promo) is distinct from 'object' then
    raise exception 'promo must be a JSON object' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_rules, '[]'::jsonb)) <> 'array' then
    raise exception 'rules must be a JSON array' using errcode = '22023';
  end if;
  if btrim(coalesce(p_promo ->> 'name', '')) = '' then
    raise exception 'name is required' using errcode = '22004';
  end if;

  -- A free ride always discounts the whole subtotal; the value is not used.
  if v_type = 'free_ride' then
    v_value := 100;
  end if;

  v_ids_vehicle := array(select jsonb_array_elements_text(coalesce(p_promo -> 'applicable_vehicle_type_ids', '[]'))::uuid);
  v_ids_city := array(select jsonb_array_elements_text(coalesce(p_promo -> 'applicable_city_ids', '[]'))::uuid);
  v_ids_cargo := array(select jsonb_array_elements_text(coalesce(p_promo -> 'applicable_cargo_type_ids', '[]'))::uuid);

  if v_id is not null then
    select * into v_existing from public.promo_codes where id = v_id for update;
    if not found then
      raise exception 'promo % not found', v_id using errcode = 'P0002';
    end if;
    select count(*) into v_redeemed from public.promo_redemptions where promo_code_id = v_id;
    -- Customers have used the old code; changing it would strand receipts
    -- and support conversations that quote it.
    if v_redeemed > 0 and v_code <> v_existing.code then
      raise exception 'the code cannot change after it has been redeemed (% times)', v_redeemed
        using errcode = '23514';
    end if;

    update public.promo_codes set
      code = v_code,
      name = btrim(p_promo ->> 'name'),
      description = nullif(btrim(coalesce(p_promo ->> 'description', '')), ''),
      country_id = nullif(p_promo ->> 'country_id', '')::uuid,
      discount_type = v_type,
      discount_value = v_value,
      max_discount_amount = nullif(p_promo ->> 'max_discount_amount', '')::numeric,
      min_purchase_amount = coalesce(nullif(p_promo ->> 'min_purchase_amount', '')::numeric, 0),
      currency_code = nullif(btrim(coalesce(p_promo ->> 'currency_code', '')), ''),
      valid_from = (p_promo ->> 'valid_from')::timestamptz,
      valid_to = (p_promo ->> 'valid_to')::timestamptz,
      total_redemption_limit = nullif(p_promo ->> 'total_redemption_limit', '')::integer,
      per_user_redemption_limit = coalesce(nullif(p_promo ->> 'per_user_redemption_limit', '')::integer, 1),
      new_users_only = coalesce((p_promo ->> 'new_users_only')::boolean, false),
      applicable_vehicle_type_ids = v_ids_vehicle,
      applicable_city_ids = v_ids_city,
      applicable_cargo_type_ids = v_ids_cargo,
      is_active = coalesce((p_promo ->> 'is_active')::boolean, true)
    where id = v_id;
  else
    insert into public.promo_codes (
      code, name, description, country_id, discount_type, discount_value,
      max_discount_amount, min_purchase_amount, currency_code, valid_from, valid_to,
      total_redemption_limit, per_user_redemption_limit, new_users_only,
      applicable_vehicle_type_ids, applicable_city_ids, applicable_cargo_type_ids,
      is_active, created_by
    ) values (
      v_code,
      btrim(p_promo ->> 'name'),
      nullif(btrim(coalesce(p_promo ->> 'description', '')), ''),
      nullif(p_promo ->> 'country_id', '')::uuid,
      v_type,
      v_value,
      nullif(p_promo ->> 'max_discount_amount', '')::numeric,
      coalesce(nullif(p_promo ->> 'min_purchase_amount', '')::numeric, 0),
      nullif(btrim(coalesce(p_promo ->> 'currency_code', '')), ''),
      (p_promo ->> 'valid_from')::timestamptz,
      (p_promo ->> 'valid_to')::timestamptz,
      nullif(p_promo ->> 'total_redemption_limit', '')::integer,
      coalesce(nullif(p_promo ->> 'per_user_redemption_limit', '')::integer, 1),
      coalesce((p_promo ->> 'new_users_only')::boolean, false),
      v_ids_vehicle, v_ids_city, v_ids_cargo,
      coalesce((p_promo ->> 'is_active')::boolean, true),
      auth.uid()
    )
    returning id into v_id;
  end if;

  delete from public.promo_code_eligibility_rules where promo_code_id = v_id;
  for v_rule in select * from jsonb_array_elements(coalesce(p_rules, '[]'::jsonb)) loop
    insert into public.promo_code_eligibility_rules (promo_code_id, rule_type, rule_value, description)
    values (
      v_id,
      v_rule ->> 'rule_type',
      private.normalize_promo_rule(v_rule ->> 'rule_type', v_rule -> 'rule_value'),
      nullif(btrim(coalesce(v_rule ->> 'description', '')), '')
    );
  end loop;

  return v_id;
exception
  when unique_violation then
    raise exception 'promo code % already exists', v_code using errcode = '23505';
end;
$$;

comment on function public.admin_save_promo(uuid, jsonb, jsonb) is
  'Creates (p_promo_id null) or updates a promo and replaces its eligibility rules atomically.';

revoke all on function public.admin_save_promo(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.admin_save_promo(uuid, jsonb, jsonb) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- admin_delete_promo
-- ----------------------------------------------------------------------------

create or replace function public.admin_delete_promo(p_promo_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_redeemed bigint;
begin
  perform private.require_permission('manage_promotions');
  select count(*) into v_redeemed from public.promo_redemptions where promo_code_id = p_promo_id;
  if v_redeemed > 0 then
    raise exception 'this promo was redeemed % times and is kept for the record; deactivate it instead',
      v_redeemed
      using errcode = '23503';
  end if;
  delete from public.promo_codes where id = p_promo_id;
  if not found then
    raise exception 'promo % not found', p_promo_id using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.admin_delete_promo(uuid) from public, anon;
grant execute on function public.admin_delete_promo(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Reporting
-- ----------------------------------------------------------------------------

create or replace function public.admin_promo_summaries()
returns table (
  promo_code_id uuid,
  redemptions bigint,
  unique_customers bigint,
  total_discount numeric,
  last_redeemed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission('view_promotions');
  return query
    select r.promo_code_id,
           count(*)::bigint,
           count(distinct r.profile_id)::bigint,
           coalesce(sum(r.discount_amount), 0)::numeric,
           max(r.redeemed_at)
    from public.promo_redemptions r
    group by r.promo_code_id;
end;
$$;

revoke all on function public.admin_promo_summaries() from public, anon;
grant execute on function public.admin_promo_summaries() to authenticated, service_role;

create or replace function public.admin_promo_redemptions(
  p_promo_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  redeemed_at timestamptz,
  discount_amount numeric,
  currency_code char(3),
  job_id uuid,
  customer_id uuid,
  customer_name text,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission('view_promotions');
  return query
    select r.id, r.redeemed_at, r.discount_amount, r.currency_code, r.job_id, r.profile_id,
           coalesce(nullif(btrim(p.full_name), ''), p.display_name, 'Customer'),
           count(*) over ()
    from public.promo_redemptions r
    left join public.profiles p on p.id = r.profile_id
    where r.promo_code_id = p_promo_id
    order by r.redeemed_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200)
    offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.admin_promo_redemptions(uuid, integer, integer) from public, anon;
grant execute on function public.admin_promo_redemptions(uuid, integer, integer) to authenticated, service_role;
