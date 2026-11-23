-- Verifies the promo functions from 0165_admin_promo_management.sql.
--
-- Runs as a real super admin inside a transaction that is always rolled back.
-- Needs one active super_admin, one service zone and one non-admin profile.
-- Permission refusal for non-admins is covered by the console integration
-- tests, which sign in through the API (this script connects as postgres).
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-promo-management.sql

begin;

do $$
declare
  v_admin uuid;
  v_zone uuid;
  v_customer uuid;
begin
  select profile_id into v_admin from public.admin_roles
  where role_name = 'super_admin' and is_active and revoked_at is null limit 1;
  select id into v_zone from public.service_zones limit 1;
  select p.id into v_customer from public.profiles p
  where not exists (select 1 from public.admin_roles r where r.profile_id = p.id) limit 1;
  if v_admin is null or v_zone is null or v_customer is null then
    raise exception 'FIXTURE: need a super_admin, a service zone and a non-admin profile';
  end if;
  perform set_config('test.admin', v_admin::text, true);
  perform set_config('test.zone', v_zone::text, true);
  perform set_config('test.customer', v_customer::text, true);
  perform set_config('test.code', 'TEST' || upper(substr(md5(random()::text), 1, 6)), true);
end $$;

set local role authenticated;
select null from set_config(
  'request.jwt.claims',
  json_build_object('sub', current_setting('test.admin'), 'aal', 'aal2', 'role', 'authenticated')::text,
  true
);

do $$
declare
  v_a uuid;
  v_b uuid;
  v_failed boolean;
  v_code text := current_setting('test.code');
begin
  -- 1. Create with all four rule kinds; the code is upper-cased.
  v_a := public.admin_save_promo(null, jsonb_build_object(
    'code', lower(v_code), 'name', 'Launch week', 'discount_type', 'capped_percentage',
    'discount_value', 20, 'max_discount_amount', 5000, 'currency_code', 'TZS',
    'valid_from', now(), 'valid_to', now() + interval '7 days',
    'total_redemption_limit', 100, 'per_user_redemption_limit', 1
  ), jsonb_build_array(
    jsonb_build_object('rule_type', 'first_job'),
    jsonb_build_object('rule_type', 'min_account_age_days', 'rule_value', jsonb_build_object('min_days', 2)),
    jsonb_build_object('rule_type', 'specific_zone', 'rule_value', jsonb_build_object('service_zone_id', current_setting('test.zone'))),
    jsonb_build_object('rule_type', 'specific_day_of_week', 'rule_value', jsonb_build_object('day_of_week', 5))
  ));
  perform set_config('test.a', v_a::text, true);

  -- 2. An invalid rule rejects the whole save; nothing changes.
  v_failed := false;
  begin
    perform public.admin_save_promo(v_a, jsonb_build_object(
      'code', v_code, 'name', 'Changed name', 'discount_type', 'capped_percentage',
      'discount_value', 20, 'max_discount_amount', 5000,
      'valid_from', now(), 'valid_to', now() + interval '7 days'
    ), jsonb_build_array(jsonb_build_object('rule_type', 'specific_day_of_week', 'rule_value', jsonb_build_object('day_of_week', 9))));
  exception when others then v_failed := sqlerrm like '%day of week must be 0%';
  end;
  if not v_failed then raise exception 'CHECK 2: invalid day of week must be rejected'; end if;

  -- 3. Duplicate code gives a clear message.
  v_failed := false;
  begin
    perform public.admin_save_promo(null, jsonb_build_object(
      'code', v_code, 'name', 'Dup', 'discount_type', 'flat_amount', 'discount_value', 1000,
      'valid_from', now(), 'valid_to', now() + interval '1 day'));
  exception when unique_violation then v_failed := sqlerrm like '%already exists%';
  end;
  if not v_failed then raise exception 'CHECK 3: duplicate code must be rejected'; end if;

  -- 4. A free ride stores value 100 whatever was sent.
  v_b := public.admin_save_promo(null, jsonb_build_object(
    'code', v_code || 'F', 'name', 'Free ride', 'discount_type', 'free_ride', 'discount_value', 7,
    'valid_from', now(), 'valid_to', now() + interval '1 day'));
  perform set_config('test.b', v_b::text, true);
end $$;

-- Redemptions can only be written by the platform; add one as the owner.
reset role;
insert into public.promo_redemptions (promo_code_id, profile_id, discount_amount, currency_code)
values (current_setting('test.a')::uuid, current_setting('test.customer')::uuid, 4000, 'TZS');

set local role authenticated;
select null from set_config(
  'request.jwt.claims',
  json_build_object('sub', current_setting('test.admin'), 'aal', 'aal2', 'role', 'authenticated')::text,
  true
);

do $$
declare
  v_a uuid := current_setting('test.a')::uuid;
  v_failed boolean;
  v_summary record;
  v_rows integer;
begin
  -- 5. A redeemed code cannot be renamed, but other fields can change.
  v_failed := false;
  begin
    perform public.admin_save_promo(v_a, jsonb_build_object(
      'code', 'RENAMED1', 'name', 'Launch week', 'discount_type', 'capped_percentage',
      'discount_value', 20, 'max_discount_amount', 5000,
      'valid_from', now(), 'valid_to', now() + interval '7 days'));
  exception when others then v_failed := sqlerrm like '%cannot change after it has been redeemed%';
  end;
  if not v_failed then raise exception 'CHECK 5: renaming a redeemed code must fail'; end if;

  perform public.admin_save_promo(v_a, jsonb_build_object(
    'code', current_setting('test.code'), 'name', 'Launch week (extended)', 'discount_type', 'capped_percentage',
    'discount_value', 15, 'max_discount_amount', 4000,
    'valid_from', now(), 'valid_to', now() + interval '14 days', 'is_active', false),
    jsonb_build_array(jsonb_build_object('rule_type', 'min_jobs_completed', 'rule_value', jsonb_build_object('min_jobs', 3))));

  -- 6. A redeemed promo cannot be deleted.
  v_failed := false;
  begin
    perform public.admin_delete_promo(v_a);
  exception when foreign_key_violation then v_failed := sqlerrm like '%deactivate it instead%';
  end;
  if not v_failed then raise exception 'CHECK 6: deleting a redeemed promo must fail'; end if;

  -- 7. Summaries and history.
  select * into v_summary from public.admin_promo_summaries() s where s.promo_code_id = v_a;
  if v_summary.redemptions <> 1 or v_summary.total_discount <> 4000 or v_summary.unique_customers <> 1 then
    raise exception 'CHECK 7: wrong summary %', row_to_json(v_summary);
  end if;
  select count(*) into v_rows from public.admin_promo_redemptions(v_a) h where h.total_count = 1;
  if v_rows <> 1 then raise exception 'CHECK 7: expected 1 redemption row, got %', v_rows; end if;

  -- 8. An unredeemed promo can be deleted.
  perform public.admin_delete_promo(current_setting('test.b')::uuid);
end $$;

reset role;

do $$
declare
  v_a uuid := current_setting('test.a')::uuid;
  v_promo public.promo_codes%rowtype;
  v_rule record;
begin
  select * into v_promo from public.promo_codes where id = v_a;
  if v_promo.code <> current_setting('test.code') then
    raise exception 'CHECK 1: code not upper-cased (%)', v_promo.code;
  end if;
  if v_promo.created_by is distinct from current_setting('test.admin')::uuid then
    raise exception 'CHECK 1: created_by not recorded';
  end if;
  if v_promo.name <> 'Launch week (extended)' or v_promo.discount_value <> 15 or v_promo.is_active then
    raise exception 'CHECK 5: allowed update not saved (%)', row_to_json(v_promo);
  end if;
  -- Rules were replaced by the single min_jobs rule, with the canonical key.
  select count(*) as n, max(rule_value ->> 'min_jobs') as min_jobs into v_rule
  from public.promo_code_eligibility_rules where promo_code_id = v_a;
  if v_rule.n <> 1 or v_rule.min_jobs <> '3' then
    raise exception 'CHECK 5: rules not replaced (%)', row_to_json(v_rule);
  end if;
  if (select discount_value from public.promo_codes where code = current_setting('test.code') || 'F') is not null then
    raise exception 'CHECK 8: free ride promo still exists';
  end if;
end $$;

-- Check 4 ran before the delete; verify its stored value through the audit
-- trail is not possible here, so re-create and inspect directly.
set local role authenticated;
select null from set_config(
  'request.jwt.claims',
  json_build_object('sub', current_setting('test.admin'), 'aal', 'aal2', 'role', 'authenticated')::text,
  true
);
do $$
declare v_id uuid;
begin
  v_id := public.admin_save_promo(null, jsonb_build_object(
    'code', current_setting('test.code') || 'G', 'name', 'Free ride 2', 'discount_type', 'free_ride',
    'discount_value', 3, 'valid_from', now(), 'valid_to', now() + interval '1 day'));
  if (select discount_value from public.promo_codes where id = v_id) <> 100 then
    raise exception 'CHECK 4: free ride value must be stored as 100';
  end if;
end $$;
reset role;

select 'verify-promo-management: all checks passed' as result;

rollback;
