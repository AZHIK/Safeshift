-- Verifies 0182_admin_records.sql as a super admin, rolled back.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-admin-records.sql

begin;

do $$
declare
  v_fresh uuid := gen_random_uuid();
  v_customer uuid;
begin
  perform set_config('t.admin', (select profile_id::text from public.admin_roles
    where role_name = 'super_admin' and is_active and revoked_at is null and country_id is null limit 1), true);
  -- A brand-new user with no history.
  insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token)
  values ('00000000-0000-0000-0000-000000000000', v_fresh, 'authenticated', 'authenticated',
    'fresh-' || substr(v_fresh::text, 1, 8) || '@example.test', now(), now(), '', '', '', '', '', '', '', '');
  insert into public.profiles (id, primary_role, full_name, email) values (v_fresh, 'customer', 'Fresh User', 'fresh-' || substr(v_fresh::text, 1, 8) || '@example.test')
  on conflict (id) do nothing;
  -- A customer with jobs.
  select customer_id into v_customer from public.jobs where status = 'completed' limit 1;
  perform set_config('t.fresh', v_fresh::text, true);
  perform set_config('t.customer', v_customer::text, true);
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal2')::text, true);

do $$
declare
  v_row jsonb;
  v_failed boolean;
  v_lang uuid;
  v_key jsonb;
begin
  -- 1. Create, read, edit, delete a currency row (a simple reference table).
  v_row := public.admin_record_insert('currencies',
    jsonb_build_object('code', 'ZZZ', 'name', 'Test Dollar', 'symbol', 'Z$', 'decimal_places', 2));
  if v_row ->> 'name' <> 'Test Dollar' or v_row ->> 'id' is null then
    raise exception 'CHECK 1: insert must return the row with its generated id';
  end if;
  v_key := jsonb_build_object('id', v_row ->> 'id');
  v_row := public.admin_record_update('currencies', v_key,
    jsonb_build_object('name', 'Renamed Dollar', 'id', gen_random_uuid()));
  if v_row ->> 'name' <> 'Renamed Dollar' or v_row ->> 'id' <> v_key ->> 'id' then
    raise exception 'CHECK 1: update must change values but never the key (%)', v_row;
  end if;
  if public.admin_record_get('currencies', v_key) ->> 'symbol' <> 'Z$' then
    raise exception 'CHECK 1: get failed';
  end if;
  if (public.admin_record_list('currencies', 'Renamed Dollar', null, true, 10, 0) ->> 'total')::int <> 1 then
    raise exception 'CHECK 1: search must find the edited row';
  end if;
  perform public.admin_record_delete('currencies', v_key);

  -- 2. Money tables refuse raw writes.
  v_failed := false;
  begin perform public.admin_record_insert('payments', '{"amount": 1}');
  exception when insufficient_privilege then v_failed := sqlerrm like '%append-only%'; end;
  if not v_failed then raise exception 'CHECK 2: payments must refuse raw writes'; end if;

  -- 3. Unknown tables and SQL in names are refused.
  v_failed := false;
  begin perform public.admin_record_list('cities; drop table x', null, null, true, 5, 0);
  exception when undefined_table then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 3: unknown table must be refused'; end if;

  -- 4. A referenced row cannot be deleted; the message says why.
  select id into v_lang from public.countries limit 1;
  v_failed := false;
  begin perform public.admin_record_delete('countries', jsonb_build_object('id', v_lang));
  exception when foreign_key_violation then v_failed := sqlerrm like '%other records still use this one%'; end;
  if not v_failed then raise exception 'CHECK 4: a referenced country must not be deleted'; end if;

  -- 5. People are deleted through the account action.
  v_failed := false;
  begin perform public.admin_record_delete('profiles', jsonb_build_object('id', current_setting('t.fresh')));
  exception when insufficient_privilege then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 5: raw profile deletes must be refused'; end if;

  if public.admin_delete_account(current_setting('t.fresh')::uuid, 'Duplicate sign-up') <> 'deleted' then
    raise exception 'CHECK 6: a user without history must be deleted';
  end if;
  if current_setting('t.customer', true) <> '' and
     public.admin_delete_account(current_setting('t.customer')::uuid, 'Customer asked to be forgotten') <> 'anonymized' then
    raise exception 'CHECK 7: a customer with jobs must be anonymized';
  end if;

  v_failed := false;
  begin perform public.admin_delete_account(current_setting('t.admin')::uuid, 'self');
  exception when insufficient_privilege then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 8: self-deletion must be refused'; end if;
end $$;

reset role;

do $$
declare v_p public.profiles%rowtype;
begin
  if exists (select 1 from auth.users where id = current_setting('t.fresh')::uuid)
     or exists (select 1 from public.profiles where id = current_setting('t.fresh')::uuid) then
    raise exception 'CHECK 6: the fresh user must be gone';
  end if;
  if current_setting('t.customer', true) <> '' then
    select * into v_p from public.profiles where id = current_setting('t.customer')::uuid;
    if v_p.full_name <> 'Deleted user' or v_p.phone is not null or v_p.email not like 'deleted+%@deleted.invalid' or v_p.is_active then
      raise exception 'CHECK 7: personal data must be erased (%)', row_to_json(v_p);
    end if;
    if (select banned_until from auth.users where id = current_setting('t.customer')::uuid) < now() + interval '50 years' then
      raise exception 'CHECK 7: the anonymized login must be blocked';
    end if;
    if not exists (select 1 from public.jobs where customer_id = current_setting('t.customer')::uuid) then
      raise exception 'CHECK 7: business records must be kept';
    end if;
  end if;
  if exists (select 1 from public.currencies where code = 'ZZZ') then
    raise exception 'CHECK 1: the test currency must be deleted';
  end if;
end $$;


-- 9. A finance admin (no manage_records) manages tariffs, nothing else.
reset role;
do $$
declare v_fin uuid := gen_random_uuid();
begin
  insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token)
  values ('00000000-0000-0000-0000-000000000000', v_fin, 'authenticated', 'authenticated',
    'fin-' || substr(v_fin::text, 1, 8) || '@example.test', now(), now(), '', '', '', '', '', '', '', '');
  insert into public.profiles (id, primary_role, full_name, email)
  values (v_fin, 'customer', 'Finance Test', 'fin-' || substr(v_fin::text, 1, 8) || '@example.test')
  on conflict (id) do nothing;
  insert into public.admin_roles (profile_id, role_name) values (v_fin, 'finance_admin');
  perform set_config('t.fin', v_fin::text, true);
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.fin'), 'role', 'authenticated', 'aal', 'aal2')::text, true);

do $$
declare
  v_row jsonb;
  v_failed boolean;
begin
  if public.has_permission('manage_records') then
    raise exception 'CHECK 9: finance admin must not hold manage_records';
  end if;
  if (select enum_values from public.admin_record_columns('regulated_tariffs') where column_name = 'tariff_structure')
     is distinct from array['distance_band', 'weight_band', 'distance_and_weight_band', 'percentage_of_market', 'flat'] then
    raise exception 'CHECK 10: allowed values from a CHECK constraint must be listed';
  end if;
  v_row := public.admin_record_insert('regulated_tariffs', jsonb_build_object(
    'country_id', (select id from public.countries limit 1), 'regulatory_body', 'LATRA',
    'name', 'Verify tariff', 'approval_reference', 'TEST/1', 'approval_date', current_date,
    'effective_from', now(), 'tariff_structure', 'distance_band', 'currency_code', 'TZS'));
  v_row := public.admin_record_update('regulated_tariffs', jsonb_build_object('id', v_row ->> 'id'),
    '{"is_active": false, "notes": "edited"}');
  if (v_row ->> 'is_active')::boolean or v_row ->> 'notes' <> 'edited' then
    raise exception 'CHECK 9: tariff edit failed (%)', v_row;
  end if;
  perform public.admin_record_delete('regulated_tariffs', jsonb_build_object('id', v_row ->> 'id'));

  v_failed := false;
  begin perform public.admin_record_list('countries', null, null, true, 5, 0);
  exception when insufficient_privilege then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 9: finance admin must not browse other tables'; end if;
end $$;

reset role;

select 'verify-admin-records: all checks passed' as result;

rollback;
