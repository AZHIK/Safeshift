-- Account suspension and reinstatement for the admin console.
--
-- Account (any user):
--   admin_suspend_account      profiles inactive + Supabase Auth ban + all
--                              sessions ended, so sign-in and token refresh
--                              stop (deactivate_user only marked the profile,
--                              so a suspended user could keep signing in)
--   admin_reactivate_account   lifts all of it
--
-- Driver (operational, account stays usable):
--   admin_suspend_driver       verification_status 'suspended', offline;
--                              dispatch only offers jobs to 'verified' drivers
--   admin_reinstate_driver     back to the status held before suspension
--
-- Fleet:
--   admin_set_fleet_active     suspend / reactivate with a reason
--
-- Every change is written to private.audit_log; admin_account_history reads
-- it back for the console.

-- Audit actions for the new events (accounts reuse user_suspended and
-- user_reactivated). Added values are only used by functions at run time.
alter type public.audit_action add value if not exists 'driver_suspended';
alter type public.audit_action add value if not exists 'driver_reinstated';
alter type public.audit_action add value if not exists 'fleet_suspended';
alter type public.audit_action add value if not exists 'fleet_reactivated';

alter table public.drivers
  add column if not exists suspension_reason text,
  add column if not exists suspended_at timestamptz,
  add column if not exists suspended_by uuid references public.profiles (id) on delete set null,
  add column if not exists status_before_suspension public.driver_verification_status;

alter table public.fleets
  add column if not exists deactivation_reason text,
  add column if not exists deactivated_at timestamptz;

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

create or replace function private.audit_admin_change(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_old jsonb,
  p_new jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_headers jsonb;
begin
  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := '{}'::jsonb;
  end;
  insert into private.audit_log (
    actor_id, actor_role, action, entity_type, entity_id, old_value, new_value, user_agent, session_id
  ) values (
    auth.uid(), public.current_user_role(), p_action::public.audit_action, p_entity_type, p_entity_id,
    p_old, p_new, v_headers ->> 'user-agent', auth.jwt() ->> 'session_id'
  );
end;
$$;

revoke all on function private.audit_admin_change(text, text, uuid, jsonb, jsonb) from public, anon, authenticated;

-- Jobs a driver is responsible for right now.
create or replace function private.driver_active_job_count(p_driver_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.jobs
  where driver_id = p_driver_id
    and status::text in (
      'matched', 'accepted', 'heading_to_pickup', 'arrived', 'cargo_verified',
      'loading', 'in_transit', 'arrived_destination', 'delivered'
    );
$$;

revoke all on function private.driver_active_job_count(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Account
-- ----------------------------------------------------------------------------

create or replace function public.admin_suspend_account(p_profile_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.profiles%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_active_jobs integer;
begin
  if not public.has_permission('suspend_user') then
    raise exception 'suspend_user permission required' using errcode = '42501';
  end if;
  if length(v_reason) < 3 then
    raise exception 'a reason is required to suspend an account' using errcode = '22004';
  end if;
  if p_profile_id = auth.uid() then
    raise exception 'you cannot suspend your own account' using errcode = '42501';
  end if;
  if p_profile_id = '00000000-0000-4000-8000-000000000000' then
    raise exception 'the platform account cannot be suspended' using errcode = '42501';
  end if;

  select * into v_old from public.profiles where id = p_profile_id for update;
  if not found then
    raise exception 'account % not found', p_profile_id using errcode = 'P0002';
  end if;

  -- Suspending an administrator is an admin-management decision.
  if exists (
    select 1 from public.admin_roles
    where profile_id = p_profile_id and is_active and revoked_at is null
  ) and not public.has_permission('manage_admins') then
    raise exception 'manage_admins permission required to suspend an administrator' using errcode = '42501';
  end if;

  v_active_jobs := private.driver_active_job_count(p_profile_id);
  if v_active_jobs > 0 then
    raise exception 'this driver has % job(s) in progress; release or reassign them first', v_active_jobs
      using errcode = '23514';
  end if;

  update public.profiles
     set is_active = false, deactivated_at = now(), deactivation_reason = v_reason
   where id = p_profile_id;

  update public.drivers set is_available = false where id = p_profile_id and is_available;

  update public.user_sessions
     set revoked_at = now(), revoked_reason = 'account_suspended'
   where profile_id = p_profile_id and revoked_at is null;

  -- Stop Supabase Auth itself: no new sign-ins, no token refresh. Access
  -- tokens already issued expire within the JWT lifetime (auth.jwt_expiry).
  update auth.users set banned_until = now() + interval '100 years' where id = p_profile_id;
  delete from auth.sessions where user_id = p_profile_id;

  perform private.audit_admin_change(
    'user_suspended', 'profile', p_profile_id,
    jsonb_build_object('is_active', v_old.is_active),
    jsonb_build_object('is_active', false, 'reason', v_reason)
  );
end;
$$;

create or replace function public.admin_reactivate_account(p_profile_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.profiles%rowtype;
begin
  if not public.has_permission('reactivate_user') then
    raise exception 'reactivate_user permission required' using errcode = '42501';
  end if;
  select * into v_old from public.profiles where id = p_profile_id for update;
  if not found then
    raise exception 'account % not found', p_profile_id using errcode = 'P0002';
  end if;
  if v_old.is_active then
    raise exception 'this account is already active' using errcode = '23514';
  end if;

  update public.profiles
     set is_active = true, deactivated_at = null, deactivation_reason = null
   where id = p_profile_id;
  update auth.users set banned_until = null where id = p_profile_id;

  perform private.audit_admin_change(
    'user_reactivated', 'profile', p_profile_id,
    jsonb_build_object('is_active', false, 'reason', v_old.deactivation_reason),
    jsonb_build_object('is_active', true, 'note', nullif(btrim(coalesce(p_note, '')), ''))
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Driver
-- ----------------------------------------------------------------------------

create or replace function public.admin_suspend_driver(p_driver_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.drivers%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_active_jobs integer;
begin
  if not public.has_permission('suspend_driver') then
    raise exception 'suspend_driver permission required' using errcode = '42501';
  end if;
  if length(v_reason) < 3 then
    raise exception 'a reason is required to suspend a driver' using errcode = '22004';
  end if;
  select * into v_old from public.drivers where id = p_driver_id for update;
  if not found then
    raise exception 'driver % not found', p_driver_id using errcode = 'P0002';
  end if;
  if v_old.verification_status = 'suspended' then
    raise exception 'this driver is already suspended' using errcode = '23514';
  end if;
  v_active_jobs := private.driver_active_job_count(p_driver_id);
  if v_active_jobs > 0 then
    raise exception 'this driver has % job(s) in progress; release or reassign them first', v_active_jobs
      using errcode = '23514';
  end if;

  update public.drivers
     set verification_status = 'suspended',
         status_before_suspension = v_old.verification_status,
         is_available = false,
         suspension_reason = v_reason,
         suspended_at = now(),
         suspended_by = auth.uid()
   where id = p_driver_id;

  perform private.audit_admin_change(
    'driver_suspended', 'driver', p_driver_id,
    jsonb_build_object('verification_status', v_old.verification_status),
    jsonb_build_object('verification_status', 'suspended', 'reason', v_reason)
  );
end;
$$;

create or replace function public.admin_reinstate_driver(p_driver_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.drivers%rowtype;
  v_back public.driver_verification_status;
begin
  if not public.has_permission('suspend_driver') then
    raise exception 'suspend_driver permission required' using errcode = '42501';
  end if;
  select * into v_old from public.drivers where id = p_driver_id for update;
  if not found then
    raise exception 'driver % not found', p_driver_id using errcode = 'P0002';
  end if;
  if v_old.verification_status <> 'suspended' then
    raise exception 'this driver is not suspended' using errcode = '23514';
  end if;
  -- Back to where they were; an unknown prior status means re-verification.
  v_back := coalesce(v_old.status_before_suspension, 're_verification_due');

  update public.drivers
     set verification_status = v_back,
         status_before_suspension = null,
         suspension_reason = null,
         suspended_at = null,
         suspended_by = null
   where id = p_driver_id;

  perform private.audit_admin_change(
    'driver_reinstated', 'driver', p_driver_id,
    jsonb_build_object('verification_status', 'suspended', 'reason', v_old.suspension_reason),
    jsonb_build_object('verification_status', v_back, 'note', nullif(btrim(coalesce(p_note, '')), ''))
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Fleet
-- ----------------------------------------------------------------------------

create or replace function public.admin_set_fleet_active(p_fleet_id uuid, p_active boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.fleets%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if not public.has_permission('manage_fleets') then
    raise exception 'manage_fleets permission required' using errcode = '42501';
  end if;
  select * into v_old from public.fleets where id = p_fleet_id for update;
  if not found then
    raise exception 'fleet % not found', p_fleet_id using errcode = 'P0002';
  end if;
  if v_old.is_active = p_active then
    raise exception 'this fleet is already %', case when p_active then 'active' else 'suspended' end
      using errcode = '23514';
  end if;
  if not p_active and length(v_reason) < 3 then
    raise exception 'a reason is required to suspend a fleet' using errcode = '22004';
  end if;

  update public.fleets
     set is_active = p_active,
         deactivation_reason = case when p_active then null else v_reason end,
         deactivated_at = case when p_active then null else now() end
   where id = p_fleet_id;

  perform private.audit_admin_change(
    case when p_active then 'fleet_reactivated' else 'fleet_suspended' end, 'fleet', p_fleet_id,
    jsonb_build_object('is_active', v_old.is_active),
    jsonb_build_object('is_active', p_active, 'reason', nullif(v_reason, ''))
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- History
-- ----------------------------------------------------------------------------

create or replace function public.admin_account_history(p_entity_id uuid, p_limit integer default 50)
returns table (
  occurred_at timestamptz,
  action text,
  actor_name text,
  old_value jsonb,
  new_value jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('view_all_users') or public.has_permission('view_all_drivers')
          or public.has_permission('view_all_fleets')) then
    raise exception 'view_all_users permission required' using errcode = '42501';
  end if;
  return query
    select a.created_at, a.action::text,
           coalesce(nullif(btrim(p.full_name), ''), p.display_name, 'System'),
           a.old_value, a.new_value
    from private.audit_log a
    left join public.profiles p on p.id = a.actor_id
    where a.entity_id = p_entity_id
      and a.action::text in ('user_suspended', 'user_reactivated',
                             'driver_suspended', 'driver_reinstated', 'fleet_suspended', 'fleet_reactivated')
    order by a.created_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

revoke all on function public.admin_suspend_account(uuid, text) from public, anon;
revoke all on function public.admin_reactivate_account(uuid, text) from public, anon;
revoke all on function public.admin_suspend_driver(uuid, text) from public, anon;
revoke all on function public.admin_reinstate_driver(uuid, text) from public, anon;
revoke all on function public.admin_set_fleet_active(uuid, boolean, text) from public, anon;
revoke all on function public.admin_account_history(uuid, integer) from public, anon;
grant execute on function public.admin_suspend_account(uuid, text) to authenticated, service_role;
grant execute on function public.admin_reactivate_account(uuid, text) to authenticated, service_role;
grant execute on function public.admin_suspend_driver(uuid, text) to authenticated, service_role;
grant execute on function public.admin_reinstate_driver(uuid, text) to authenticated, service_role;
grant execute on function public.admin_set_fleet_active(uuid, boolean, text) to authenticated, service_role;
grant execute on function public.admin_account_history(uuid, integer) to authenticated, service_role;
