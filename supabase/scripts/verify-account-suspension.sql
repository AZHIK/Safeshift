-- Verifies 0168_account_suspension.sql against real data, as a super admin,
-- inside a transaction that is always rolled back.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-account-suspension.sql

begin;

do $$
declare
  v_admin uuid;
  v_driver uuid;
  v_customer uuid;
  v_job uuid;
begin
  select profile_id into v_admin from public.admin_roles
  where role_name = 'super_admin' and is_active and revoked_at is null limit 1;
  select d.id into v_driver from public.drivers d
  where d.verification_status = 'verified' and private.driver_active_job_count(d.id) = 0 limit 1;
  select p.id into v_customer from public.profiles p
  where p.is_active and p.id <> '00000000-0000-4000-8000-000000000000'
    and not exists (select 1 from public.drivers d where d.id = p.id)
    and not exists (select 1 from public.admin_roles r where r.profile_id = p.id)
    and exists (select 1 from auth.users u where u.id = p.id)
  limit 1;
  select id into v_job from public.jobs where status = 'completed' limit 1;
  if v_admin is null or v_driver is null or v_customer is null or v_job is null then
    raise exception 'FIXTURE: need a super_admin, an idle verified driver, a customer and a completed job';
  end if;
  -- A session to prove suspension ends it.
  insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), v_customer, now(), now());
  perform set_config('t.admin', v_admin::text, true);
  perform set_config('t.driver', v_driver::text, true);
  perform set_config('t.customer', v_customer::text, true);
  perform set_config('t.job', v_job::text, true);
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'aal', 'aal2', 'role', 'authenticated')::text, true);

do $$
declare
  v_failed boolean;
  v_driver uuid := current_setting('t.driver')::uuid;
  v_customer uuid := current_setting('t.customer')::uuid;
begin
  -- Guards.
  v_failed := false;
  begin perform public.admin_suspend_account(current_setting('t.admin')::uuid, 'testing self');
  exception when insufficient_privilege then v_failed := sqlerrm like '%your own account%'; end;
  if not v_failed then raise exception 'CHECK 1: self-suspension must be refused'; end if;

  v_failed := false;
  begin perform public.admin_suspend_account('00000000-0000-4000-8000-000000000000', 'testing platform');
  exception when insufficient_privilege then v_failed := sqlerrm like '%platform account%'; end;
  if not v_failed then raise exception 'CHECK 1: the platform account must be protected'; end if;

  v_failed := false;
  begin perform public.admin_suspend_account(v_customer, ' ');
  exception when null_value_not_allowed then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 1: a reason must be required'; end if;

  -- Driver suspension and reinstatement.
  perform public.admin_suspend_driver(v_driver, 'Repeated customer complaints');
  v_failed := false;
  begin perform public.admin_suspend_driver(v_driver, 'again');
  exception when check_violation then v_failed := sqlerrm like '%already suspended%'; end;
  if not v_failed then raise exception 'CHECK 2: double suspension must be refused'; end if;
  perform public.admin_reinstate_driver(v_driver, 'Investigated, cleared');

  -- Account suspension and reactivation.
  perform public.admin_suspend_account(v_customer, 'Fraudulent chargebacks');
end $$;

reset role;

do $$
declare
  v_driver public.drivers%rowtype;
  v_profile public.profiles%rowtype;
begin
  select * into v_driver from public.drivers where id = current_setting('t.driver')::uuid;
  if v_driver.verification_status <> 'verified' or v_driver.suspension_reason is not null
     or v_driver.status_before_suspension is not null then
    raise exception 'CHECK 2: reinstated driver must be verified and clean (%)', row_to_json(v_driver);
  end if;

  select * into v_profile from public.profiles where id = current_setting('t.customer')::uuid;
  if v_profile.is_active or v_profile.deactivation_reason <> 'Fraudulent chargebacks' then
    raise exception 'CHECK 3: suspended profile not recorded';
  end if;
  if (select banned_until from auth.users where id = current_setting('t.customer')::uuid) < now() + interval '50 years' then
    raise exception 'CHECK 3: Supabase Auth must ban the suspended user';
  end if;
  if exists (select 1 from auth.sessions where user_id = current_setting('t.customer')::uuid) then
    raise exception 'CHECK 3: sessions of the suspended user must be ended';
  end if;

  -- A driver mid-job cannot be suspended: put the driver on a job.
  update public.jobs set driver_id = current_setting('t.driver')::uuid, status = 'in_transit'
   where id = current_setting('t.job')::uuid;
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'aal', 'aal2', 'role', 'authenticated')::text, true);

do $$
declare
  v_failed boolean := false;
  v_rows integer;
begin
  begin perform public.admin_suspend_driver(current_setting('t.driver')::uuid, 'mid-trip');
  exception when check_violation then v_failed := sqlerrm like '%in progress%'; end;
  if not v_failed then raise exception 'CHECK 4: a driver mid-job must not be suspended'; end if;

  perform public.admin_reactivate_account(current_setting('t.customer')::uuid, 'Chargebacks resolved');

  select count(*) into v_rows from public.admin_account_history(current_setting('t.customer')::uuid);
  if v_rows < 2 then raise exception 'CHECK 6: history must show suspension and reactivation, got %', v_rows; end if;
  select count(*) into v_rows from public.admin_account_history(current_setting('t.driver')::uuid);
  if v_rows < 2 then raise exception 'CHECK 6: driver history must show suspension and reinstatement, got %', v_rows; end if;
end $$;

reset role;

do $$
begin
  if not (select is_active from public.profiles where id = current_setting('t.customer')::uuid)
     or (select banned_until from auth.users where id = current_setting('t.customer')::uuid) is not null then
    raise exception 'CHECK 5: reactivation must restore the profile and lift the Auth ban';
  end if;
end $$;

select 'verify-account-suspension: all checks passed' as result;

rollback;
