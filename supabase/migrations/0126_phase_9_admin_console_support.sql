-- ============================================================================
-- SafeShift — Phase 9 / Migration 0126
-- Admin console support: fleet-owner role, dashboard views, audited
-- verification actions, profile search, and recent-activity feed.
--
-- All SECURITY DEFINER functions set an empty search_path and re-check the
-- caller's permission with public.has_permission(). No client role can call
-- them without an active admin_roles grant.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Extend admin role catalogue with fleet_owner
-- ----------------------------------------------------------------------------
alter table public.admin_roles
  drop constraint admin_roles_role_name_check;
alter table public.admin_roles
  add constraint admin_roles_role_name_check check (
    role_name in (
      'super_admin',
      'operations_admin',
      'verification_admin',
      'support_agent',
      'finance_admin',
      'analyst',
      'fleet_owner'
    )
  );

alter table public.admin_role_permissions
  drop constraint admin_role_permissions_role_name_check;
alter table public.admin_role_permissions
  add constraint admin_role_permissions_role_name_check check (
    role_name in (
      'super_admin',
      'operations_admin',
      'verification_admin',
      'support_agent',
      'finance_admin',
      'analyst',
      'fleet_owner'
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Permissions used by the Phase 9 console
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('view_verifications',       'View driver, vehicle, and business verification queues', 'trust_safety'),
  ('manage_verifications',     'Assign and process verification requests',                'trust_safety'),
  ('manage_business_verifications', 'Approve or reject business account verification',     'trust_safety'),
  ('view_fleet',               'View a fleet owned by the signed-in fleet owner',           'operations'),
  ('manage_fleet_vehicles',    'Add, edit, and retire fleet vehicles',                      'operations'),
  ('manage_fleet_drivers',     'Invite and remove fleet drivers',                           'operations'),
  ('view_fleet_earnings',      'View fleet earnings and billing events',                    'finance'),
  ('manage_tariffs',           'Manage regulated tariff frameworks',                        'pricing'),
  ('manage_promos',            'Manage promo codes and redemption rules',                   'operations'),
  ('view_support_tickets',     'View support tickets and messages',                         'support'),
  ('manage_support_tickets',   'Reply to, assign, and resolve support tickets',             'support'),
  ('view_payouts',             'View payout batches and payout items',                      'finance'),
  ('manage_payouts',           'Create and approve payout batches',                         'finance'),
  ('view_all_businesses',      'View all business account records',                         'support')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', permission_key
from public.admin_permissions_catalog
where permission_key in (
  'view_verifications', 'manage_verifications', 'manage_business_verifications',
  'view_fleet', 'manage_fleet_vehicles', 'manage_fleet_drivers', 'view_fleet_earnings',
  'manage_tariffs', 'manage_promos', 'view_support_tickets', 'manage_support_tickets',
  'view_payouts', 'manage_payouts', 'view_all_businesses'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('verification_admin', 'view_verifications'),
  ('verification_admin', 'manage_verifications'),
  ('verification_admin', 'manage_business_verifications'),
  ('operations_admin',   'view_verifications'),
  ('operations_admin',   'manage_verifications'),
  ('operations_admin',   'view_fleet'),
  ('operations_admin',   'manage_fleet_vehicles'),
  ('operations_admin',   'manage_fleet_drivers'),
  ('operations_admin',   'view_fleet_earnings'),
  ('operations_admin',   'manage_tariffs'),
  ('operations_admin',   'manage_promos'),
  ('operations_admin',   'view_all_businesses'),
  ('support_agent',      'view_support_tickets'),
  ('support_agent',      'manage_support_tickets'),
  ('support_agent',      'view_all_businesses'),
  ('finance_admin',      'view_payouts'),
  ('finance_admin',      'manage_payouts'),
  ('finance_admin',      'view_fleet_earnings'),
  ('analyst',            'view_support_tickets'),
  ('analyst',            'view_payouts'),
  -- Fleet owners are deliberately narrow: only their own fleet and drivers.
  ('fleet_owner',        'view_fleet'),
  ('fleet_owner',        'manage_fleet_vehicles'),
  ('fleet_owner',        'manage_fleet_drivers'),
  ('fleet_owner',        'view_fleet_earnings')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 3. Business self-registration returning
-- The owner membership is attached by an AFTER INSERT trigger, so the existing
-- member-based SELECT policy cannot see the row during RETURNING. Track the
-- creator explicitly and allow that creator to read the new account.
-- ----------------------------------------------------------------------------
alter table public.business_accounts
  add column if not exists created_by uuid references public.profiles (id) on delete set null;

alter table public.business_accounts
  alter column created_by set default auth.uid();

create index if not exists business_accounts_created_by_idx
  on public.business_accounts (created_by);

create policy business_accounts_select_creator
  on public.business_accounts for select to authenticated
  using (created_by = (select auth.uid()));

-- ----------------------------------------------------------------------------
-- 4. Dashboard view
-- security_invoker = true means the caller's RLS still applies. The view is
-- therefore safe to expose to every authenticated admin role.
-- ----------------------------------------------------------------------------
-- The profiles RLS policy logs PII reads. A dashboard GET runs in a
-- read-only PostgREST transaction, so counting profiles directly from a
-- security_invoker view would attempt a write and fail. This narrow,
-- permission-checked helper returns only an aggregate and never exposes rows.
create or replace function public.admin_active_user_count()
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (
    public.has_permission('view_all_users')
    or public.has_permission('view_analytics')
  ) then
    return 0;
  end if;
  return (select count(*) from public.profiles where is_active);
end;
$$;

comment on function public.admin_active_user_count() is
  'Aggregate active-user count for the admin dashboard. Returns 0 without view permission.';

revoke all on function public.admin_active_user_count() from public;
revoke all on function public.admin_active_user_count() from anon;
grant execute on function public.admin_active_user_count() to authenticated, service_role;

create or replace view public.admin_dashboard_metrics
with (security_invoker = true)
as
select
  (select count(*) from public.jobs
    where status in ('requested', 'quoted', 'matched', 'accepted', 'heading_to_pickup',
                     'arrived', 'loading', 'in_transit'))
    as active_jobs,
  (select count(*) from public.incidents where status in ('open', 'investigating'))
    as active_incidents,
  (select count(*) from public.trip_alerts where status = 'open')
    as open_sos_alerts,
  (select count(*) from public.support_tickets where status in ('open', 'in_progress', 'waiting_customer'))
    as open_tickets,
  (select count(*) from public.disputes where status in ('open', 'in_review', 'escalated'))
    as open_disputes,
  (select count(*) from public.verification_requests where status in ('pending', 'in_review'))
    as pending_verifications,
  public.admin_active_user_count()
    as active_users,
  (select count(*) from public.drivers where verification_status = 'verified')
    as verified_drivers,
  (select count(*) from public.jobs where created_at >= now() - interval '24 hours')
    as jobs_last_24h,
  (select coalesce(sum(gross_booking_value), 0) from public.daily_metrics
    where metric_date >= current_date - 6)
    as gbv_last_7d,
  now() as generated_at;

comment on view public.admin_dashboard_metrics is
  'Operational dashboard counters. security_invoker keeps underlying RLS in force.';

grant select on public.admin_dashboard_metrics to authenticated;

-- ----------------------------------------------------------------------------
-- 5. Profile search (support / operations / verification)
-- ----------------------------------------------------------------------------
create or replace function public.admin_search_profiles(
  p_query text,
  p_limit integer default 25
)
returns table (
  profile_id uuid,
  full_name text,
  display_name text,
  phone text,
  email text,
  primary_role public.user_role,
  is_active boolean,
  driver_status public.driver_verification_status,
  created_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_query text := btrim(coalesce(p_query, ''));
  v_limit integer := greatest(1, least(coalesce(p_limit, 25), 100));
  v_row record;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (
    public.has_permission('view_all_users')
    or public.has_permission('view_all_customers')
    or public.has_permission('view_all_drivers')
    or public.has_permission('view_all_businesses')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  if length(v_query) > 0 and length(v_query) < 2 then
    return;
  end if;

  for v_row in
    select p.id,
           p.full_name,
           p.display_name,
           p.phone,
           p.email,
           p.primary_role,
           p.is_active,
           d.verification_status,
           p.created_at
      from public.profiles p
      left join public.drivers d on d.id = p.id
     where v_query = ''
        or p.full_name ilike '%' || v_query || '%'
        or p.display_name ilike '%' || v_query || '%'
        or p.phone ilike '%' || v_query || '%'
        or p.email ilike '%' || v_query || '%'
     order by p.created_at desc
     limit v_limit
  loop
    perform public.log_pii_select(v_row.id, 'profiles', 'phone,email,full_name');
    profile_id := v_row.id;
    full_name := v_row.full_name;
    display_name := v_row.display_name;
    phone := v_row.phone;
    email := v_row.email;
    primary_role := v_row.primary_role;
    is_active := v_row.is_active;
    driver_status := v_row.verification_status;
    created_at := v_row.created_at;
    return next;
  end loop;
end;
$$;

comment on function public.admin_search_profiles(text, integer) is
  'Permission-checked profile search for the admin console. A blank query lists recent profiles. Writes a PDPC access-log row for each non-owner profile returned.';

-- Batch profile summaries for pages that otherwise join public.profiles.
-- Direct profile selects by staff trigger the Phase 6 PII-read logger, which
-- cannot run inside PostgREST's read-only GET transaction. This function
-- returns only the directory fields the console needs and writes the same
-- PDPC access-log rows explicitly.
create or replace function public.admin_profile_summaries(p_ids uuid[])
returns table (
  profile_id uuid,
  full_name text,
  display_name text,
  phone text,
  email text,
  primary_role public.user_role,
  is_active boolean
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (
    public.has_permission('view_all_users')
    or public.has_permission('view_all_customers')
    or public.has_permission('view_all_drivers')
    or public.has_permission('view_all_businesses')
    or public.has_permission('view_analytics')
    or public.has_permission('view_fleet')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  for v_row in
    select p.id, p.full_name, p.display_name, p.phone, p.email,
           p.primary_role, p.is_active
      from public.profiles p
     where p.id = any(coalesce(p_ids, array[]::uuid[]))
       and (
         public.has_permission('view_all_users')
         or public.has_permission('view_all_customers')
         or public.has_permission('view_all_drivers')
         or public.has_permission('view_all_businesses')
         or public.has_permission('view_analytics')
         or (
           public.has_permission('view_fleet')
           and exists (
             select 1
               from public.fleet_members fm
               join public.fleets f on f.id = fm.fleet_id
              where fm.driver_id = p.id
                and f.owner_profile_id = auth.uid()
           )
         )
       )
  loop
    perform public.log_pii_select(v_row.id, 'profiles', 'phone,email,full_name');
    profile_id := v_row.id;
    full_name := v_row.full_name;
    display_name := v_row.display_name;
    phone := v_row.phone;
    email := v_row.email;
    primary_role := v_row.primary_role;
    is_active := v_row.is_active;
    return next;
  end loop;
end;
$$;

comment on function public.admin_profile_summaries(uuid[]) is
  'Permission-checked batch profile directory for the admin console. Writes a PDPC access-log row for each non-owner profile returned.';

revoke all on function public.admin_profile_summaries(uuid[]) from public;
grant execute on function public.admin_profile_summaries(uuid[]) to authenticated, service_role;

revoke all on function public.admin_search_profiles(text, integer) from public;
grant execute on function public.admin_search_profiles(text, integer) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Recent activity feed
-- ----------------------------------------------------------------------------
create or replace function public.admin_recent_activity(p_limit integer default 50)
returns table (
  activity_id text,
  actor_id uuid,
  actor_name text,
  action text,
  entity_type text,
  entity_id uuid,
  created_at timestamptz,
  source text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not public.has_permission('view_audit') then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  return query
  select * from (
    select 'admin:' || a.id::text as activity_id,
           a.admin_profile_id as actor_id,
           coalesce(p.full_name, p.display_name, 'Admin') as actor_name,
           a.action,
           a.entity_type,
           a.entity_id,
           a.created_at,
           'admin_actions_log'::text as source
      from public.admin_actions_log a
      left join public.profiles p on p.id = a.admin_profile_id
    union all
    select 'audit:' || l.id::text as activity_id,
           l.actor_id,
           coalesce(p.full_name, p.display_name, 'System') as actor_name,
           l.action::text,
           l.entity_type,
           l.entity_id,
           l.created_at,
           'audit_log'::text as source
      from private.audit_log l
      left join public.profiles p on p.id = l.actor_id
  ) feed
  order by feed.created_at desc
  limit v_limit;
end;
$$;

comment on function public.admin_recent_activity(integer) is
  'Permission-checked combined admin/audit activity feed.';

revoke all on function public.admin_recent_activity(integer) from public;
grant execute on function public.admin_recent_activity(integer) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Admin console role helper (used by middleware)
-- ----------------------------------------------------------------------------
create or replace function public.admin_console_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select r.role_name
    from public.admin_roles r
   where r.profile_id = auth.uid()
     and r.is_active
     and (r.expires_at is null or r.expires_at > now())
     and r.revoked_at is null
   order by case r.role_name
     when 'super_admin' then 1
     when 'operations_admin' then 2
     when 'verification_admin' then 3
     when 'support_agent' then 4
     when 'finance_admin' then 5
     when 'analyst' then 6
     when 'fleet_owner' then 7
     else 8 end
   limit 1;
$$;

comment on function public.admin_console_role() is
  'Returns the highest-priority active admin role for the caller, or NULL.';

revoke all on function public.admin_console_role() from public;
grant execute on function public.admin_console_role() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. Audited verification decisions
-- ----------------------------------------------------------------------------
create or replace function public.admin_approve_verification(
  p_request_id uuid,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_req public.verification_requests%rowtype;
  v_permission text;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_req
    from public.verification_requests
   where id = p_request_id
   for update;

  if not found then
    raise exception 'verification request % not found', p_request_id using errcode = 'P0002';
  end if;

  v_permission := case v_req.request_type
    when 'driver_verification' then 'verify_driver'
    when 'vehicle_verification' then 'verify_vehicle'
    when 'business_verification' then 'manage_business_verifications'
    else 'manage_verifications'
  end;

  if not public.has_permission(v_permission) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  update public.verification_requests
     set status = 'approved',
         reviewed_at = now(),
         decided_at = now(),
         decision_notes = p_notes,
         assigned_to = coalesce(assigned_to, v_actor),
         assigned_at = coalesce(assigned_at, now())
   where id = p_request_id;

  if v_req.driver_id is not null then
    update public.drivers
       set verification_status = 'verified',
           verified_at = now(),
           verified_by = v_actor,
           re_verification_due_at = now() + interval '12 months'
     where id = v_req.driver_id;
  end if;

  if v_req.vehicle_id is not null then
    update public.vehicles
       set verification_status = 'verified',
           verified_at = now(),
           verified_by = v_actor
     where id = v_req.vehicle_id;
  end if;

  if v_req.business_account_id is not null then
    update public.business_accounts
       set verified_at = now()
     where id = v_req.business_account_id;
  end if;

  insert into public.verification_history (
    verification_request_id, driver_id, vehicle_id, business_account_id,
    action, actor_id, notes
  ) values (
    v_req.id, v_req.driver_id, v_req.vehicle_id, v_req.business_account_id,
    'approved', v_actor, p_notes
  );

  insert into public.admin_actions_log (
    admin_profile_id, admin_role, permission_used, action, entity_type, entity_id, new_value
  ) values (
    v_actor,
    coalesce(public.admin_console_role(), 'admin'),
    v_permission,
    'verification.approved',
    'verification_request',
    p_request_id,
    jsonb_build_object('notes', p_notes)
  );
end;
$$;

create or replace function public.admin_reject_verification(
  p_request_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_req public.verification_requests%rowtype;
  v_permission text;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 3 then
    raise exception 'a rejection reason is required' using errcode = '22023';
  end if;

  select * into v_req
    from public.verification_requests
   where id = p_request_id
   for update;

  if not found then
    raise exception 'verification request % not found', p_request_id using errcode = 'P0002';
  end if;

  v_permission := case v_req.request_type
    when 'driver_verification' then 'reject_driver'
    when 'vehicle_verification' then 'verify_vehicle'
    when 'business_verification' then 'manage_business_verifications'
    else 'manage_verifications'
  end;

  if not public.has_permission(v_permission) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  update public.verification_requests
     set status = 'rejected',
         reviewed_at = now(),
         decided_at = now(),
         decision_notes = p_reason,
         assigned_to = coalesce(assigned_to, v_actor),
         assigned_at = coalesce(assigned_at, now())
   where id = p_request_id;

  if v_req.driver_id is not null then
    update public.drivers
       set verification_status = 'rejected'
     where id = v_req.driver_id;
  end if;

  if v_req.vehicle_id is not null then
    update public.vehicles
       set verification_status = 'rejected'
     where id = v_req.vehicle_id;
  end if;

  insert into public.verification_history (
    verification_request_id, driver_id, vehicle_id, business_account_id,
    action, actor_id, notes
  ) values (
    v_req.id, v_req.driver_id, v_req.vehicle_id, v_req.business_account_id,
    'rejected', v_actor, p_reason
  );

  insert into public.admin_actions_log (
    admin_profile_id, admin_role, permission_used, action, entity_type, entity_id, new_value
  ) values (
    v_actor,
    coalesce(public.admin_console_role(), 'admin'),
    v_permission,
    'verification.rejected',
    'verification_request',
    p_request_id,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;

comment on function public.admin_approve_verification(uuid, text) is
  'Approves a verification request, updates the subject, and writes audit history.';
comment on function public.admin_reject_verification(uuid, text) is
  'Rejects a verification request with a mandatory reason and writes audit history.';

revoke all on function public.admin_approve_verification(uuid, text) from public;
revoke all on function public.admin_reject_verification(uuid, text) from public;
grant execute on function public.admin_approve_verification(uuid, text) to authenticated, service_role;
grant execute on function public.admin_reject_verification(uuid, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Driver self-service onboarding may create its own row, but a driver can
-- never bootstrap a verified/trusted state. Verification fields are writable
-- only by staff holding the relevant permission.
-- ----------------------------------------------------------------------------
create policy drivers_insert_self
  on public.drivers for insert to authenticated
  with check (
    id = (select auth.uid())
    and verification_status = 'pending'
    and verified_at is null
    and verified_by is null
    and risk_tier = 'standard'
  );

create or replace function private.protect_driver_trust_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    return new;
  end if;
  if v_actor = old.id
     and not public.has_permission('verify_driver')
     and (
       new.verification_status is distinct from old.verification_status
       or new.risk_tier is distinct from old.risk_tier
       or new.verified_at is distinct from old.verified_at
       or new.verified_by is distinct from old.verified_by
     )
  then
    raise exception 'driver trust fields can only be changed by verification staff'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_driver_trust_fields on public.drivers;
create trigger trg_protect_driver_trust_fields
  before update on public.drivers
  for each row execute function private.protect_driver_trust_fields();

comment on function private.protect_driver_trust_fields() is
  'Prevents a driver from self-approving verification_status, risk_tier, or verified_* fields.';
