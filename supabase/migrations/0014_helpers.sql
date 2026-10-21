-- ============================================================================
-- SafeShift — Phase 1 / Migration 0014
-- Helper functions: identity, RBAC, JWT claims, consent, audit triggers and
-- column-protection triggers.
--
-- Every SECURITY DEFINER function sets search_path = '' and fully qualifies
-- object names, so no caller can influence name resolution.
-- ============================================================================

-- ============================================================================
-- 1. Identity helpers
-- ============================================================================

create or replace function public.current_profile_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select auth.uid()::uuid;
$$;

comment on function public.current_profile_id() is
  'The authenticated profile id (auth.uid()).';

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.primary_role
    from public.profiles p
   where p.id = auth.uid();
$$;

comment on function public.current_user_role() is
  'Primary role of the authenticated profile, resolved with RLS bypassed.';

create or replace function public.current_country_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.default_country_id
    from public.profiles p
   where p.id = auth.uid();
$$;

comment on function public.current_country_id() is
  'Default country of the authenticated profile. Used for country-scoped RBAC.';

-- ============================================================================
-- 2. Administrative RBAC helpers
-- ============================================================================

create or replace function public.has_admin_role(role_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.admin_roles ar
     where ar.profile_id = auth.uid()
       and ar.role_name = has_admin_role.role_name
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
  );
$$;

comment on function public.has_admin_role(text) is
  'True when the caller holds the named active, unexpired, unrevoked admin role.';

create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.admin_roles ar
      join public.admin_role_permissions arp
        on arp.role_name = ar.role_name
     where ar.profile_id = auth.uid()
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
       and arp.permission_key = has_permission.permission_key
       -- Country scoping: a grant with country_id NULL applies everywhere,
       -- otherwise it must match the caller's country.
       and (
         ar.country_id is null
         or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
       )
  );
$$;

comment on function public.has_permission(text) is
  'True when any active admin role of the caller grants the permission, honouring country scope and expiry.';

-- City-scoped variant: used by server code that knows which city it is acting
-- on. A grant with city_id NULL applies to the whole country.
create or replace function public.has_permission(permission_key text, city_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.admin_roles ar
      join public.admin_role_permissions arp
        on arp.role_name = ar.role_name
     where ar.profile_id = auth.uid()
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
       and arp.permission_key = has_permission.permission_key
       and (
         ar.country_id is null
         or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
       )
       and (ar.city_id is null or ar.city_id = has_permission.city_id)
  );
$$;

comment on function public.has_permission(text, uuid) is
  'City-scoped permission check. Honours country and city scope plus expiry.';

-- ============================================================================
-- 3. Business membership helpers (avoid recursive RLS on business_members)
-- ============================================================================

create or replace function public.business_has_members(p_business_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.business_members bm
     where bm.business_account_id = p_business_account_id
  );
$$;

create or replace function public.is_business_member(p_business_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.business_members bm
     where bm.business_account_id = p_business_account_id
       and bm.profile_id = auth.uid()
       and bm.accepted_at is not null
  );
$$;

create or replace function public.is_business_admin(p_business_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.business_members bm
     where bm.business_account_id = p_business_account_id
       and bm.profile_id = auth.uid()
       and bm.role in ('owner', 'admin')
       and bm.accepted_at is not null
  );
$$;

create or replace function public.is_business_owner(p_business_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.business_members bm
     where bm.business_account_id = p_business_account_id
       and bm.profile_id = auth.uid()
       and bm.role = 'owner'
       and bm.accepted_at is not null
  );
$$;

comment on function public.is_business_member(uuid) is
  'Authenticated caller is an accepted member of the business account. SECURITY DEFINER to avoid recursive RLS.';

-- ============================================================================
-- 4. Custom JWT claims (Supabase Auth Hook)
-- ============================================================================

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id    uuid;
  v_role       public.user_role;
  v_country_id uuid;
  v_claims     jsonb;
begin
  v_user_id := nullif(event ->> 'user_id', '')::uuid;
  if v_user_id is null then
    return event;
  end if;

  select p.primary_role, p.default_country_id
    into v_role, v_country_id
    from public.profiles p
   where p.id = v_user_id;

  v_claims := coalesce(event -> 'claims', '{}'::jsonb);

  if v_role is not null then
    v_claims := jsonb_set(v_claims, '{user_role}', to_jsonb(v_role::text), true);
  end if;

  if v_country_id is not null then
    v_claims := jsonb_set(v_claims, '{country_id}', to_jsonb(v_country_id::text), true);
  end if;

  return jsonb_set(event, '{claims}', v_claims, true);
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Adds user_role and country_id custom claims to every issued access token.';

revoke all on function public.custom_access_token_hook(jsonb) from public;
revoke all on function public.custom_access_token_hook(jsonb) from anon;
revoke all on function public.custom_access_token_hook(jsonb) from authenticated;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;

grant usage on schema public to supabase_auth_admin;
grant select on table public.profiles to supabase_auth_admin;

-- ============================================================================
-- 5. Consent recording (PDPC compliance)
-- ============================================================================

create or replace function public.record_consent(
  profile_id uuid,
  consent_type text,
  consent_version text,
  granted boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_id      uuid := gen_random_uuid();
  v_headers jsonb;
  v_ip      inet;
  v_ua      text;
begin
  if v_actor is null then
    raise exception 'authentication required to record consent' using errcode = '28000';
  end if;

  if v_actor <> profile_id and not public.has_permission('view_consent') then
    raise exception 'not authorised to record consent for another profile' using errcode = '42501';
  end if;

  if consent_type not in (
    'terms_of_service', 'privacy_policy', 'marketing_email', 'marketing_sms', 'data_processing'
  ) then
    raise exception 'invalid consent_type: %', consent_type using errcode = '22023';
  end if;

  if consent_version is null or btrim(consent_version) = '' then
    raise exception 'consent_version is required' using errcode = '22004';
  end if;

  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := '{}'::jsonb;
  end;

  begin
    v_ip := nullif(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1), '')::inet;
  exception when others then
    v_ip := null;
  end;

  v_ua := v_headers ->> 'user-agent';

  insert into public.consent_records (
    id, profile_id, consent_type, consent_version, granted, ip_address, user_agent, granted_at, revoked_at
  )
  values (
    v_id,
    record_consent.profile_id,
    record_consent.consent_type,
    record_consent.consent_version,
    record_consent.granted,
    v_ip,
    v_ua,
    case when record_consent.granted then now() else null end,
    case when record_consent.granted then null else now() end
  );

  insert into private.audit_log (
    actor_id, actor_role, action, entity_type, entity_id, new_value, ip_address, user_agent, session_id
  )
  values (
    v_actor,
    public.current_user_role(),
    case when record_consent.granted then 'consent_granted'::public.audit_action else 'consent_revoked'::public.audit_action end,
    'consent_record',
    v_id,
    jsonb_build_object(
      'profile_id', record_consent.profile_id,
      'consent_type', record_consent.consent_type,
      'consent_version', record_consent.consent_version,
      'granted', record_consent.granted
    ),
    v_ip,
    v_ua,
    auth.jwt() ->> 'session_id'
  );

  return v_id;
end;
$$;

comment on function public.record_consent(uuid, text, text, boolean) is
  'Records a versioned consent decision for the caller (or, with view_consent, another profile) and writes an audit entry.';

-- ============================================================================
-- 6. User deactivation (requires suspend_user)
-- ============================================================================

create or replace function public.deactivate_user(profile_id uuid, reason text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor      uuid := auth.uid();
  v_target     uuid := deactivate_user.profile_id;
  v_old        jsonb;
  v_headers    jsonb;
  v_ip         inet;
begin
  if v_actor is null or not public.has_permission('suspend_user') then
    raise exception 'not authorised: suspend_user permission required' using errcode = '42501';
  end if;

  if v_target = v_actor then
    raise exception 'administrators cannot deactivate their own account' using errcode = '42501';
  end if;

  select to_jsonb(p) into v_old from public.profiles p where p.id = v_target;
  if v_old is null then
    raise exception 'profile % not found', v_target using errcode = '23503';
  end if;

  update public.profiles p
     set is_active = false,
         deactivated_at = now(),
         deactivation_reason = deactivate_user.reason
   where p.id = v_target;

  update public.user_sessions s
     set revoked_at = now(),
         revoked_reason = coalesce(deactivate_user.reason, 'account_deactivated')
   where s.profile_id = v_target
     and s.revoked_at is null;

  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := '{}'::jsonb;
  end;

  begin
    v_ip := nullif(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1), '')::inet;
  exception when others then
    v_ip := null;
  end;

  insert into private.audit_log (
    actor_id, actor_role, action, entity_type, entity_id, old_value, new_value, ip_address, user_agent, session_id
  )
  values (
    v_actor,
    public.current_user_role(),
    'user_suspended',
    'profile',
    v_target,
    v_old,
    jsonb_build_object('is_active', false, 'deactivation_reason', deactivate_user.reason),
    v_ip,
    v_headers ->> 'user-agent',
    auth.jwt() ->> 'session_id'
  );

  return true;
end;
$$;

comment on function public.deactivate_user(uuid, text) is
  'Deactivates a profile and revokes its sessions. Requires the suspend_user permission.';

-- ============================================================================
-- 7. Generic audit trigger
-- ============================================================================

create or replace function private.try_uuid(p_value text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_value is null then
    return null;
  end if;
  return p_value::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

create or replace function private.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old        jsonb;
  v_new        jsonb;
  v_action     public.audit_action;
  v_actor      uuid;
  v_actor_role public.user_role;
  v_entity_id  uuid;
  v_headers    jsonb;
  v_ip         inet;
  v_ua         text;
  v_session_id text;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_action := 'insert';
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_action := 'update';
  elsif tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_action := 'delete';
  else
    return null;
  end if;

  begin
    v_actor := auth.uid();
  exception when others then
    v_actor := null;
  end;

  -- Keep the actor FK valid; service-role and seed writes have no profile.
  if v_actor is not null
     and not exists (select 1 from public.profiles p where p.id = v_actor)
  then
    v_actor := null;
  end if;

  if v_actor is not null then
    select p.primary_role into v_actor_role
      from public.profiles p where p.id = v_actor;
  end if;

  v_entity_id := private.try_uuid(coalesce(v_new ->> 'id', v_old ->> 'id'));

  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := '{}'::jsonb;
  end;

  begin
    v_ip := nullif(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1), '')::inet;
  exception when others then
    v_ip := null;
  end;

  v_ua := v_headers ->> 'user-agent';

  begin
    v_session_id := auth.jwt() ->> 'session_id';
  exception when others then
    v_session_id := null;
  end;

  insert into private.audit_log (
    actor_id, actor_role, action, entity_type, entity_id,
    old_value, new_value, ip_address, user_agent, session_id
  )
  values (
    v_actor, v_actor_role, v_action, tg_table_name, v_entity_id,
    v_old, v_new, v_ip, v_ua, v_session_id
  );

  return null;
end;
$$;

comment on function private.audit_trigger() is
  'Generic AFTER INSERT/UPDATE/DELETE audit writer into private.audit_log.';

-- Attach the generic audit trigger to every sensitive Phase 1 table.
do $$
declare
  v_table text;
  v_tables text[] := array[
    'public.profiles',
    'public.user_devices',
    'public.customers',
    'public.business_accounts',
    'public.business_members',
    'public.drivers',
    'public.driver_operating_zones',
    'public.driver_service_hours',
    'public.user_referrals',
    'public.saved_addresses',
    'public.admin_roles',
    'public.admin_permissions_catalog',
    'public.admin_role_permissions',
    'public.exchange_rates',
    'public.localization_strings',
    'public.feature_flags',
    'public.consent_records',
    'public.countries',
    'public.regions',
    'public.cities',
    'public.service_zones',
    'public.neighborhoods',
    'public.addresses',
    'public.zone_pricing_overrides',
    'public.currencies',
    'public.languages'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists %I on %s',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
    execute format(
      'create trigger %I after insert or update or delete on %s for each row execute function private.audit_trigger()',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
  end loop;
end $$;

-- ============================================================================
-- 8. Column-protection triggers
-- ============================================================================
-- RLS decides which rows a client may touch. These triggers decide which
-- columns. The service role and superuser always pass.

-- profiles: primary_role and account status are server-controlled.
create or replace function private.protect_profile_privileged_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
begin
  if v_service then
    return new;
  end if;

  if new.primary_role is distinct from old.primary_role then
    raise exception 'primary_role can only be changed by the service role'
      using errcode = '42501';
  end if;

  if new.is_active is distinct from old.is_active
     or new.deactivated_at is distinct from old.deactivated_at
     or new.deactivation_reason is distinct from old.deactivation_reason
  then
    if not public.has_permission('suspend_user') then
      raise exception 'account status changes require the suspend_user permission'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_profiles_protect_privileged
  before update on public.profiles
  for each row execute function private.protect_profile_privileged_fields();

-- drivers: trust, reputation and assignment fields are server-controlled.
create or replace function private.protect_driver_privileged_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
begin
  if v_service then
    return new;
  end if;

  if new.verification_status is distinct from old.verification_status
     or new.risk_tier is distinct from old.risk_tier
     or new.verified_at is distinct from old.verified_at
     or new.verified_by is distinct from old.verified_by
     or new.re_verification_due_at is distinct from old.re_verification_due_at
     or new.rating is distinct from old.rating
     or new.total_trips is distinct from old.total_trips
     or new.total_earnings is distinct from old.total_earnings
     or new.country_id is distinct from old.country_id
     or new.current_vehicle_id is distinct from old.current_vehicle_id
     or new.current_fleet_id is distinct from old.current_fleet_id
  then
    if not public.has_permission('verify_driver') then
      raise exception 'protected driver fields require the verify_driver permission'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_drivers_protect_privileged
  before update on public.drivers
  for each row execute function private.protect_driver_privileged_fields();

-- customers: aggregate/trust fields are server-controlled.
create or replace function private.protect_customer_privileged_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
begin
  if v_service then
    return new;
  end if;

  if new.total_jobs is distinct from old.total_jobs
     or new.total_spent is distinct from old.total_spent
     or new.rating is distinct from old.rating
     or new.is_flagged is distinct from old.is_flagged
     or new.flagged_reason is distinct from old.flagged_reason
  then
    if not public.has_permission('manage_customers') then
      raise exception 'protected customer fields require the manage_customers permission'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_customers_protect_privileged
  before update on public.customers
  for each row execute function private.protect_customer_privileged_fields();

-- business accounts: credit, balance and verification are server-controlled.
create or replace function private.protect_business_privileged_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
begin
  if v_service then
    return new;
  end if;

  if new.credit_limit is distinct from old.credit_limit
     or new.current_balance is distinct from old.current_balance
     or new.verified_at is distinct from old.verified_at
  then
    if not public.has_permission('manage_business_accounts') then
      raise exception 'protected business fields require the manage_business_accounts permission'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_business_accounts_protect_privileged
  before update on public.business_accounts
  for each row execute function private.protect_business_privileged_fields();

-- ============================================================================
-- 9. Public driver profile source (used by the column-limited view)
-- ============================================================================

create or replace function public.get_public_driver_profile(p_driver_id uuid default null)
returns table (
  id                  uuid,
  full_name           text,
  display_name        text,
  avatar_url          text,
  rating              numeric(3, 2),
  total_trips         integer,
  verification_status public.driver_verification_status,
  home_city_id        uuid,
  current_vehicle_id  uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.full_name,
    p.display_name,
    p.avatar_url,
    d.rating,
    d.total_trips,
    d.verification_status,
    d.home_city_id,
    d.current_vehicle_id
  from public.drivers d
  join public.profiles p on p.id = d.id
  where p.is_active
    and d.verification_status = 'verified'
    and (p_driver_id is null or d.id = p_driver_id);
$$;

comment on function public.get_public_driver_profile(uuid) is
  'Whitelisted, column-limited driver data. Never exposes phone, email, licence number, or exact location.';

-- ============================================================================
-- 10. Grants for API roles
-- ============================================================================

grant execute on function public.current_profile_id() to authenticated, service_role;
grant execute on function public.current_user_role() to authenticated, service_role;
grant execute on function public.current_country_id() to authenticated, service_role;
grant execute on function public.has_admin_role(text) to authenticated, service_role;
grant execute on function public.has_permission(text) to authenticated, service_role;
grant execute on function public.has_permission(text, uuid) to authenticated, service_role;
grant execute on function public.business_has_members(uuid) to authenticated, service_role;
grant execute on function public.is_business_member(uuid) to authenticated, service_role;
grant execute on function public.is_business_admin(uuid) to authenticated, service_role;
grant execute on function public.is_business_owner(uuid) to authenticated, service_role;
grant execute on function public.record_consent(uuid, text, text, boolean) to authenticated, service_role;
grant execute on function public.deactivate_user(uuid, text) to authenticated, service_role;
grant execute on function public.get_public_driver_profile(uuid) to authenticated, service_role;

revoke all on function public.current_profile_id() from public, anon;
revoke all on function public.current_user_role() from public, anon;
revoke all on function public.current_country_id() from public, anon;
revoke all on function public.has_admin_role(text) from public, anon;
revoke all on function public.has_permission(text) from public, anon;
revoke all on function public.has_permission(text, uuid) from public, anon;
revoke all on function public.business_has_members(uuid) from public, anon;
revoke all on function public.is_business_member(uuid) from public, anon;
revoke all on function public.is_business_admin(uuid) from public, anon;
revoke all on function public.is_business_owner(uuid) from public, anon;
revoke all on function public.record_consent(uuid, text, text, boolean) from public, anon;
revoke all on function public.deactivate_user(uuid, text) from public, anon;
revoke all on function public.get_public_driver_profile(uuid) from public, anon;
