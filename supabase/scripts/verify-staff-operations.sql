-- Verifies 0178_staff_operations.sql against real data as a super admin,
-- inside a transaction that is always rolled back.
--
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/scripts/verify-staff-operations.sql

begin;

do $$
declare
  v_admin uuid;
  v_customer uuid;
  v_city uuid;
begin
  select profile_id into v_admin from public.admin_roles
  where role_name = 'super_admin' and is_active and revoked_at is null and country_id is null limit 1;
  select c.id into v_city from public.cities c where c.is_active limit 1;
  select p.id into v_customer from public.profiles p
  where p.is_active and p.id <> '00000000-0000-4000-8000-000000000000'
    and not exists (select 1 from public.admin_roles r where r.profile_id = p.id)
    and p.default_country_id = (select country_id from public.cities where id = v_city)
    and exists (select 1 from auth.users u where u.id = p.id)
  limit 1;
  if v_admin is null or v_customer is null or v_city is null then
    raise exception 'FIXTURE: need an all-country super_admin, an active city and a customer in its country';
  end if;
  insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), v_customer, now(), now());
  perform set_config('t.admin', v_admin::text, true);
  perform set_config('t.customer', v_customer::text, true);
  perform set_config('t.city', v_city::text, true);
  perform set_config('t.fleet', gen_random_uuid()::text, true);
end $$;

set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal2')::text, true);

do $$
declare
  v_failed boolean;
  v_customer uuid := current_setting('t.customer')::uuid;
  v_fleet uuid := current_setting('t.fleet')::uuid;
  v_id uuid;
begin
  -- Accounts.
  perform public.admin_update_account(v_customer, 'edit_profile', 'Customer asked for a name fix', 'Verified Name', 'VN');
  perform public.admin_update_account(v_customer, 'end_sessions', 'Lost phone reported');

  v_failed := false;
  begin perform public.admin_update_account(current_setting('t.admin')::uuid, 'end_sessions', 'self check');
  exception when insufficient_privilege then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 1: an admin must not operate on their own account'; end if;

  v_failed := false;
  begin perform public.admin_update_account('00000000-0000-4000-8000-000000000000', 'end_sessions', 'platform check');
  exception when insufficient_privilege then v_failed := true; end;
  if not v_failed then raise exception 'CHECK 1: the platform account must be protected'; end if;

  v_failed := false;
  begin perform public.admin_update_account(v_customer, 'end_sessions', ' ');
  exception when others then v_failed := sqlerrm like '%reason%'; end;
  if not v_failed then raise exception 'CHECK 1: a reason must be required'; end if;

  -- Fleets: onboarding is idempotent per id.
  v_id := public.admin_onboard_fleet(v_fleet, current_setting('t.city')::uuid, 'Verify Fleet Ltd', v_customer, 'REG-VERIFY-1');
  v_id := public.admin_onboard_fleet(v_fleet, current_setting('t.city')::uuid, 'Verify Fleet Ltd', v_customer, 'REG-VERIFY-1');
  if v_id <> v_fleet then raise exception 'CHECK 2: onboarding must return the fleet id'; end if;

  perform public.admin_review_fleet(v_fleet, 'verify', 'Business licence checked');
  perform public.admin_review_fleet(v_fleet, 'commission', 'Negotiated rate', 10.5);

  v_failed := false;
  begin perform public.admin_review_fleet(v_fleet, 'commission', 'too high', 150);
  exception when others then v_failed := sqlerrm like '%commission percentage%'; end;
  if not v_failed then raise exception 'CHECK 3: an out-of-range commission must be refused'; end if;
end $$;

reset role;

do $$
declare
  v_profile public.profiles%rowtype;
  v_fleet public.fleets%rowtype;
begin
  select * into v_profile from public.profiles where id = current_setting('t.customer')::uuid;
  if v_profile.full_name <> 'Verified Name' or v_profile.display_name <> 'VN' then
    raise exception 'CHECK 1: profile edit not saved';
  end if;
  if exists (select 1 from auth.sessions where user_id = current_setting('t.customer')::uuid) then
    raise exception 'CHECK 1: sessions must be ended';
  end if;
  select * into v_fleet from public.fleets where id = current_setting('t.fleet')::uuid;
  if v_fleet.verified_at is null or v_fleet.commission_rate_override <> 10.5
     or v_fleet.owner_profile_id <> current_setting('t.customer')::uuid then
    raise exception 'CHECK 2/3: fleet not onboarded, verified and priced (%)', row_to_json(v_fleet);
  end if;
  if (select count(*) from public.fleets where registration_number = 'REG-VERIFY-1') <> 1 then
    raise exception 'CHECK 2: a repeated onboarding must not duplicate the fleet';
  end if;
end $$;

-- Tickets and incidents, when the database has any.
set local role authenticated;
select null from set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.admin'), 'role', 'authenticated', 'aal', 'aal2')::text, true);

do $$
declare
  v_ticket uuid;
  v_incident uuid;
  v_agent uuid;
begin
  select id into v_ticket from public.support_tickets limit 1;
  if v_ticket is not null then
    select a.id into v_agent from public.admin_ticket_agents(v_ticket) a limit 1;
    perform public.admin_triage_ticket(v_ticket, 'in_progress', 'high', v_agent, now() + interval '4 hours');
    perform set_config('t.ticket', v_ticket::text, true);
  end if;
  select id into v_incident from public.incidents limit 1;
  if v_incident is not null then
    perform public.admin_incident_action(v_incident, 'Called the driver; customer safe');
    perform set_config('t.incident', v_incident::text, true);
  end if;
end $$;

reset role;

do $$
declare
  v_ticket text := coalesce(current_setting('t.ticket', true), '');
  v_incident text := coalesce(current_setting('t.incident', true), '');
begin
  -- Nested ifs: PL/pgSQL does not guarantee that "and" short-circuits.
  if v_ticket <> '' then
    if (select priority from public.support_tickets where id = v_ticket::uuid) <> 'high' then
      raise exception 'CHECK 4: ticket triage not saved';
    end if;
  end if;
  if v_incident <> '' then
    if not exists (select 1 from public.incident_actions
                   where incident_id = v_incident::uuid and notes = 'Called the driver; customer safe') then
      raise exception 'CHECK 5: incident action not recorded';
    end if;
  end if;
end $$;

select 'verify-staff-operations: all checks passed' as result,
       coalesce(current_setting('t.ticket', true), '') <> '' as ticket_checked,
       coalesce(current_setting('t.incident', true), '') <> '' as incident_checked;

rollback;
