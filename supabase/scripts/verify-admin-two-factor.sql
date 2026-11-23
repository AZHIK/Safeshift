-- Verifies the email second factor from 0179_admin_two_factor_options.sql,
-- inside a transaction that is always rolled back.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-admin-two-factor.sql

begin;

do $$
declare
  v_admin uuid;
  v_session uuid := gen_random_uuid();
  v_other_session uuid := gen_random_uuid();
  v_issued record;
begin
  select r.profile_id into v_admin from public.admin_roles r
  join auth.users u on u.id = r.profile_id and nullif(u.email, '') is not null
  where r.role_name = 'super_admin' and r.is_active and r.revoked_at is null limit 1;
  if v_admin is null then raise exception 'FIXTURE: need a super_admin with an email'; end if;
  insert into auth.sessions (id, user_id, created_at, updated_at) values
    (v_session, v_admin, now(), now()), (v_other_session, v_admin, now(), now());

  -- Issued by the service role (here: the owner connection).
  select * into v_issued from public.admin_issue_email_challenge(v_admin, v_session);
  if v_issued.code !~ '^\d{6}$' or v_issued.email is null then
    raise exception 'CHECK 1: a 6-digit code and the admin email must be returned';
  end if;
  if exists (select 1 from private.admin_email_challenges where code_hash = v_issued.code) then
    raise exception 'CHECK 1: the code must not be stored in plain text';
  end if;

  begin
    perform public.admin_issue_email_challenge(v_admin, v_session);
    raise exception 'CHECK 2: a second code within a minute must be refused';
  exception when configuration_limit_exceeded then null;
  end;

  perform set_config('t.admin', v_admin::text, true);
  perform set_config('t.session', v_session::text, true);
  perform set_config('t.other', v_other_session::text, true);
  perform set_config('t.code', v_issued.code, true);
end $$;

-- Signed in with a password only (aal1).
set local role authenticated;
select null from set_config('request.jwt.claims', json_build_object(
  'sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal1',
  'session_id', current_setting('t.session'))::text, true);

do $$
declare
  v_wrong text := lpad(((current_setting('t.code')::int + 1) % 1000000)::text, 6, '0');
begin
  -- Check 3 uses has_admin_role, which has no configuration shortcut.
  if public.has_permission('manage_admins') or public.has_admin_role('super_admin') then
    raise exception 'CHECK 3: without a second factor, staff permissions must be denied';
  end if;
  if public.admin_verify_email_challenge(v_wrong) then
    raise exception 'CHECK 4: a wrong code must not verify';
  end if;
  if not public.admin_verify_email_challenge(current_setting('t.code')) then
    raise exception 'CHECK 5: the emailed code must verify';
  end if;
  if not public.has_permission('manage_admins') or not public.has_admin_role('super_admin') then
    raise exception 'CHECK 5: a verified session must hold its permissions';
  end if;
  if not (public.admin_second_factor_status() ->> 'verified')::boolean
     or public.admin_second_factor_status() ->> 'method' <> 'email' then
    raise exception 'CHECK 5: status must report an email-verified session';
  end if;
  -- A used code cannot be replayed.
  begin
    perform public.admin_verify_email_challenge(current_setting('t.code'));
    raise exception 'CHECK 6: a used code must not verify again';
  exception when invalid_parameter_value then null;
  end;
end $$;

-- The same admin in a different session is still unverified.
select null from set_config('request.jwt.claims', json_build_object(
  'sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal1',
  'session_id', current_setting('t.other'))::text, true);
do $$ begin
  if public.has_permission('manage_admins') then
    raise exception 'CHECK 7: verification must be bound to the session that verified';
  end if;
end $$;

-- Authenticator and SMS factors still work through aal2.
select null from set_config('request.jwt.claims', json_build_object(
  'sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal2',
  'session_id', current_setting('t.other'))::text, true);
do $$ begin
  if not public.has_permission('manage_admins') then
    raise exception 'CHECK 8: an aal2 session must keep its permissions';
  end if;
end $$;

reset role;

-- Five wrong attempts lock the code.
do $$
declare v_issued record; v_session uuid := gen_random_uuid();
begin
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_session, current_setting('t.admin')::uuid, now(), now());
  select * into v_issued from public.admin_issue_email_challenge(current_setting('t.admin')::uuid, v_session);
  update private.admin_email_challenges set attempts = 5 where session_id = v_session;
  perform set_config('t.locked', v_session::text, true);
  perform set_config('t.locked_code', v_issued.code, true);
end $$;
set local role authenticated;
select null from set_config('request.jwt.claims', json_build_object(
  'sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal1',
  'session_id', current_setting('t.locked'))::text, true);
do $$ begin
  begin
    perform public.admin_verify_email_challenge(current_setting('t.locked_code'));
    raise exception 'CHECK 9: a locked code must not verify, even when correct';
  exception when configuration_limit_exceeded then null;
  end;
end $$;
reset role;


-- SMS channel: issue to the admin's phone, verify, method recorded as sms.
do $$
declare v_issued record; v_session uuid := gen_random_uuid();
begin
  update public.profiles set phone = coalesce(phone, '+255700000099') where id = current_setting('t.admin')::uuid;
  insert into auth.sessions (id, user_id, created_at, updated_at) values (v_session, current_setting('t.admin')::uuid, now(), now());
  select * into v_issued from public.admin_issue_second_factor_challenge(current_setting('t.admin')::uuid, v_session, 'sms');
  if v_issued.code !~ '^\d{6}$' or v_issued.destination !~ '^\+?\d{9,15}$' then
    raise exception 'CHECK 10: an SMS code must go to the admin phone (%)', v_issued.destination;
  end if;
  perform set_config('t.sms_session', v_session::text, true);
  perform set_config('t.sms_code', v_issued.code, true);
end $$;
set local role authenticated;
select null from set_config('request.jwt.claims', json_build_object(
  'sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal1',
  'session_id', current_setting('t.sms_session'))::text, true);
do $$ begin
  if not public.admin_verify_second_factor(current_setting('t.sms_code')) then
    raise exception 'CHECK 10: the SMS code must verify';
  end if;
  if public.admin_second_factor_status() ->> 'method' <> 'sms' or not public.has_permission('manage_admins') then
    raise exception 'CHECK 10: an SMS-verified session must hold its permissions';
  end if;
end $$;
reset role;

select 'verify-admin-two-factor: all checks passed' as result;

rollback;
