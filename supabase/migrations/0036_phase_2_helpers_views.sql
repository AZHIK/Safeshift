-- ============================================================================
-- SafeShift — Phase 2 / Migration 0036
-- Verification/capacity helpers, safe views, audit integration and protections.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Assignment and verification helpers
-- ----------------------------------------------------------------------------
create or replace function public.vehicle_current_driver(p_vehicle_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select va.driver_id
  from public.vehicle_assignments va
  where va.vehicle_id = p_vehicle_id
    and va.is_active
  order by va.assigned_at desc
  limit 1;
$$;

comment on function public.vehicle_current_driver(uuid) is
  'Driver currently assigned to the vehicle, resolved from vehicle_assignments.';

create or replace function public.driver_current_vehicle(p_driver_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select va.vehicle_id
  from public.vehicle_assignments va
  where va.driver_id = p_driver_id
    and va.is_active
  order by va.assigned_at desc
  limit 1;
$$;

comment on function public.driver_current_vehicle(uuid) is
  'Vehicle currently assigned to the driver, resolved from vehicle_assignments.';

-- Fail closed: a country with no active checklist template requires
-- verification rather than silently treating the driver as cleared.
create or replace function public.driver_requires_verification(p_driver_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  with driver_country as (
    select d.country_id
    from public.drivers d
    where d.id = p_driver_id
  ), active_template as (
    select vct.required_document_codes
    from public.verification_checklist_templates vct
    join driver_country dc on dc.country_id = vct.country_id
    where vct.request_type = 'driver_verification'
      and vct.is_active
  ), required_codes as (
    select distinct unnest(at.required_document_codes) as code
    from active_template at
  )
  select
    not exists (select 1 from active_template)
    or exists (
      select 1
      from required_codes rc
      left join lateral (
        select dd.*
        from public.driver_documents dd
        join public.document_types dt on dt.id = dd.document_type_id
        where dd.driver_id = p_driver_id
          and dd.is_current
          and dt.is_active
          and dt.code = rc.code
          and (dt.country_id is null or dt.country_id = (select country_id from driver_country))
        order by (dt.country_id is not null) desc, dd.created_at desc
        limit 1
      ) dd on true
      where dd.id is null
         or dd.verification_status <> 'verified'
         or (dd.expires_at is not null and dd.expires_at < current_date)
    );
$$;

comment on function public.driver_requires_verification(uuid) is
  'True when a required driver document is missing, expired or not verified. Fails closed when the country has no active checklist.';

create or replace function public.vehicle_requires_verification(p_vehicle_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  with vehicle_country as (
    select v.country_id
    from public.vehicles v
    where v.id = p_vehicle_id
  ), active_template as (
    select vct.required_document_codes
    from public.verification_checklist_templates vct
    join vehicle_country vc on vc.country_id = vct.country_id
    where vct.request_type = 'vehicle_verification'
      and vct.is_active
  ), required_codes as (
    select distinct unnest(at.required_document_codes) as code
    from active_template at
  )
  select
    not exists (select 1 from active_template)
    or exists (
      select 1
      from required_codes rc
      left join lateral (
        select vd.*
        from public.vehicle_documents vd
        join public.document_types dt on dt.id = vd.document_type_id
        where vd.vehicle_id = p_vehicle_id
          and vd.is_current
          and dt.is_active
          and dt.code = rc.code
          and (dt.country_id is null or dt.country_id = (select country_id from vehicle_country))
        order by (dt.country_id is not null) desc, vd.created_at desc
        limit 1
      ) vd on true
      where vd.id is null
         or vd.verification_status <> 'verified'
         or (vd.expires_at is not null and vd.expires_at < current_date)
    );
$$;

comment on function public.vehicle_requires_verification(uuid) is
  'True when a required vehicle document is missing, expired or not verified. Fails closed when the country has no active checklist.';

create or replace function public.can_carry_cargo(p_vehicle_id uuid, p_cargo_type_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.vehicles v
    join public.vehicle_types vt on vt.id = v.vehicle_type_id
    join public.cargo_types ct on ct.id = p_cargo_type_id
    where v.id = p_vehicle_id
      and v.is_active
      and vt.is_active
      and ct.is_active
      and (ct.country_id is null or ct.country_id = v.country_id)
      and (cardinality(ct.allowed_vehicle_type_codes) = 0 or vt.code = any(ct.allowed_vehicle_type_codes))
      and not (vt.code = any(ct.prohibited_vehicle_type_codes))
  );
$$;

comment on function public.can_carry_cargo(uuid, uuid) is
  'Capability check: active vehicle type is permitted and not prohibited for the country-scoped cargo type.';

create or replace function public.pending_verifications_for_admin(p_admin_profile_id uuid)
returns setof public.verification_requests
language sql stable security definer set search_path = '' as $$
  select vr.*
  from public.verification_requests vr
  left join public.drivers d on d.id = vr.driver_id
  left join public.vehicles v on v.id = vr.vehicle_id
  left join public.business_accounts ba on ba.id = vr.business_account_id
  where (
      p_admin_profile_id = auth.uid()
      or coalesce(auth.role(), '') = 'service_role'
    )
    and vr.status in ('pending', 'in_review')
    and (vr.assigned_to is null or vr.assigned_to = p_admin_profile_id)
    and exists (
      select 1
      from public.admin_roles ar
      join public.admin_role_permissions arp on arp.role_name = ar.role_name
      where ar.profile_id = p_admin_profile_id
        and ar.is_active
        and ar.revoked_at is null
        and (ar.expires_at is null or ar.expires_at > now())
        and (
          (vr.driver_id is not null and arp.permission_key = 'verify_driver')
          or (vr.vehicle_id is not null and arp.permission_key = 'verify_vehicle')
          or (vr.business_account_id is not null and arp.permission_key in ('verify_driver', 'verify_vehicle'))
        )
        and (ar.country_id is null or ar.country_id = coalesce(d.country_id, v.country_id, ba.country_id))
        and (ar.city_id is null or ar.city_id = coalesce(d.home_city_id, v.home_city_id, ba.city_id))
    );
$$;

comment on function public.pending_verifications_for_admin(uuid) is
  'Pending/in-review verification requests visible to the supplied admin, scoped by that admin country/city grants and request type. The caller must be that admin or the service role.';

-- ----------------------------------------------------------------------------
-- Client-side column protections. RLS controls rows; this controls state fields.
-- ----------------------------------------------------------------------------
create or replace function private.protect_vehicle_verification_fields()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if new.verification_status is distinct from old.verification_status
     or new.verified_at is distinct from old.verified_at
     or new.verified_by is distinct from old.verified_by
     or new.rejection_reason is distinct from old.rejection_reason then
    if not public.has_permission('verify_vehicle') then
      raise exception 'vehicle verification fields are server/admin controlled' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_vehicles_protect_verification
  before update on public.vehicles for each row execute function private.protect_vehicle_verification_fields();

-- ----------------------------------------------------------------------------
-- Audit integration. The generic Phase 1 trigger writes private.audit_log.
-- ----------------------------------------------------------------------------
-- Vehicle audit is deliberately narrower than "every column": trust, status
-- and ownership changes matter, routine telemetry updates do not.
create trigger trg_vehicles_audit
  after insert or delete or update of verification_status, is_active, owner_type,
    owner_profile_id, owner_business_account_id, owner_fleet_id
  on public.vehicles
  for each row execute function private.audit_trigger();

create trigger trg_driver_documents_audit
  after update of verification_status on public.driver_documents
  for each row execute function private.audit_trigger();

create trigger trg_vehicle_documents_audit
  after update of verification_status on public.vehicle_documents
  for each row execute function private.audit_trigger();

create trigger trg_fleets_audit
  after insert or delete or update of owner_profile_id, is_active, verified_at, verified_by
  on public.fleets
  for each row execute function private.audit_trigger();

create trigger trg_verification_requests_audit
  after insert or update or delete on public.verification_requests
  for each row execute function private.audit_trigger();

-- On a decision, write both trails:
--   * verification_history — operational business narrative
--   * admin_actions_log    — queryable admin action record
-- private.audit_log is written independently by trg_verification_requests_audit.
create or replace function private.log_verification_decision()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_actor          uuid := auth.uid();
  v_role           text;
  v_permission     text;
  v_history_action text;
begin
  v_history_action := case
    when new.status = 'approved' then 'approved'
    when new.status = 'rejected' then 'rejected'
    when new.status = 'expired' then 'expired'
    when new.status = 'pending' and old.status in ('rejected', 'expired') then 'reopened'
    else null
  end;

  if v_history_action is null or new.status is not distinct from old.status then
    return new;
  end if;

  insert into public.verification_history (
    verification_request_id, driver_id, vehicle_id, business_account_id,
    action, actor_id, notes
  ) values (
    new.id, new.driver_id, new.vehicle_id, new.business_account_id,
    v_history_action, v_actor, new.decision_notes
  );

  if v_history_action in ('approved', 'rejected') and v_actor is not null then
    select ar.role_name into v_role
    from public.admin_roles ar
    where ar.profile_id = v_actor
      and ar.is_active
      and ar.revoked_at is null
      and (ar.expires_at is null or ar.expires_at > now())
    order by (ar.role_name = 'super_admin') desc, ar.granted_at desc
    limit 1;

    if v_role is not null then
      v_permission := case
        when new.vehicle_id is not null then 'verify_vehicle'
        else 'verify_driver'
      end;

      insert into public.admin_actions_log (
        admin_profile_id, admin_role, permission_used, action, entity_type,
        entity_id, old_value, new_value
      ) values (
        v_actor, v_role, v_permission, 'verification_' || new.status,
        'verification_request', new.id,
        jsonb_build_object('status', old.status),
        jsonb_build_object('status', new.status)
      );
    end if;
  end if;

  return new;
end;
$$;

comment on function private.log_verification_decision() is
  'Writes verification_history for status transitions and admin_actions_log for approve/reject decisions.';

create trigger trg_verification_requests_admin_action
  after update of status on public.verification_requests
  for each row execute function private.log_verification_decision();

-- verification_history is an append-only business ledger. Even the service
-- role must not rewrite a past decision; corrections are new history rows.
-- The only permitted UPDATE is the system-driven ON DELETE SET NULL of a
-- subject FK, which leaves the recorded decision itself untouched.
create or replace function private.prevent_verification_history_mutation()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'verification_history is append-only' using errcode = '42501';
  end if;

  if new.id = old.id
     and new.action = old.action
     and new.notes is not distinct from old.notes
     and new.actor_id is not distinct from old.actor_id
     and new.created_at = old.created_at
     and (new.verification_request_id is null or new.verification_request_id = old.verification_request_id)
     and (new.driver_id is null or new.driver_id = old.driver_id)
     and (new.vehicle_id is null or new.vehicle_id = old.vehicle_id)
     and (new.business_account_id is null or new.business_account_id = old.business_account_id)
     and (new.driver_document_id is null or new.driver_document_id = old.driver_document_id)
     and (new.vehicle_document_id is null or new.vehicle_document_id = old.vehicle_document_id)
  then
    return new;
  end if;

  raise exception 'verification_history is append-only' using errcode = '42501';
end;
$$;

comment on function private.prevent_verification_history_mutation() is
  'Blocks DELETE and content UPDATE on verification_history; permits only ON DELETE SET NULL of subject FKs.';

create trigger trg_verification_history_immutable
  before update or delete on public.verification_history
  for each row execute function private.prevent_verification_history_mutation();

-- ----------------------------------------------------------------------------
-- Security-invoker projections. They expose no registration, chassis or owner data.
-- ----------------------------------------------------------------------------
create or replace view public.vehicle_public_view
with (security_invoker = true, security_barrier = true) as
select v.id, vt.name as vehicle_type_name, v.capacity_kg, v.photo_urls,
       (v.verification_status = 'verified') as verification_status_bool,
       c.name as home_city_name
from public.vehicles v
join public.vehicle_types vt on vt.id = v.vehicle_type_id
left join public.cities c on c.id = v.home_city_id;

create or replace view public.driver_verification_summary
with (security_invoker = true, security_barrier = true) as
select d.id as driver_id,
       coalesce(x.total_required, 0)::bigint as total_documents_required,
       coalesce(x.total_submitted, 0)::bigint as total_documents_submitted,
       coalesce(x.total_verified, 0)::bigint as total_verified,
       coalesce(x.total_expired, 0)::bigint as total_expired,
       coalesce(x.total_required, 0) > 0
         and coalesce(x.total_required, 0) = coalesce(x.total_verified, 0)
         and coalesce(x.total_expired, 0) = 0 as is_fully_verified,
       x.next_expiry_date
from public.drivers d
left join lateral (
  with required_codes as (
    select distinct unnest(vct.required_document_codes) code
    from public.verification_checklist_templates vct
    where vct.country_id = d.country_id and vct.request_type = 'driver_verification' and vct.is_active
  ), docs as (
    select dd.*, dt.code
    from public.driver_documents dd
    join public.document_types dt on dt.id = dd.document_type_id
    where dd.driver_id = d.id
      and dd.is_current
      and dt.is_active
  )
  select (select count(*) from required_codes) total_required,
         count(distinct docs.code) filter (where docs.code in (select code from required_codes)) total_submitted,
         count(distinct docs.code) filter (where docs.code in (select code from required_codes) and docs.verification_status = 'verified' and (docs.expires_at is null or docs.expires_at >= current_date)) total_verified,
         count(distinct docs.code) filter (where docs.code in (select code from required_codes) and docs.expires_at < current_date) total_expired,
         min(docs.expires_at) filter (where docs.code in (select code from required_codes) and docs.expires_at >= current_date) next_expiry_date
  from docs
) x on true;

create or replace view public.vehicle_verification_summary
with (security_invoker = true, security_barrier = true) as
select v.id as vehicle_id,
       coalesce(x.total_required, 0)::bigint as total_documents_required,
       coalesce(x.total_submitted, 0)::bigint as total_documents_submitted,
       coalesce(x.total_verified, 0)::bigint as total_verified,
       coalesce(x.total_expired, 0)::bigint as total_expired,
       coalesce(x.total_required, 0) > 0
         and coalesce(x.total_required, 0) = coalesce(x.total_verified, 0)
         and coalesce(x.total_expired, 0) = 0 as is_fully_verified,
       x.next_expiry_date
from public.vehicles v
left join lateral (
  with required_codes as (
    select distinct unnest(vct.required_document_codes) code
    from public.verification_checklist_templates vct
    where vct.country_id = v.country_id and vct.request_type = 'vehicle_verification' and vct.is_active
  ), docs as (
    select vd.*, dt.code
    from public.vehicle_documents vd
    join public.document_types dt on dt.id = vd.document_type_id
    where vd.vehicle_id = v.id
      and vd.is_current
      and dt.is_active
  )
  select (select count(*) from required_codes) total_required,
         count(distinct docs.code) filter (where docs.code in (select code from required_codes)) total_submitted,
         count(distinct docs.code) filter (where docs.code in (select code from required_codes) and docs.verification_status = 'verified' and (docs.expires_at is null or docs.expires_at >= current_date)) total_verified,
         count(distinct docs.code) filter (where docs.code in (select code from required_codes) and docs.expires_at < current_date) total_expired,
         min(docs.expires_at) filter (where docs.code in (select code from required_codes) and docs.expires_at >= current_date) next_expiry_date
  from docs
) x on true;

create or replace view public.active_fleet_roster
with (security_invoker = true, security_barrier = true) as
select f.id as fleet_id, f.name as fleet_name,
       coalesce((select array_agg(fm.driver_id order by fm.driver_id) from public.fleet_members fm where fm.fleet_id = f.id and fm.is_active), '{}'::uuid[]) as active_drivers,
       coalesce((select array_agg(fv.vehicle_id order by fv.vehicle_id) from public.fleet_vehicles fv where fv.fleet_id = f.id and fv.is_active), '{}'::uuid[]) as active_vehicles,
       0::bigint as active_jobs_count
from public.fleets f where f.is_active;

comment on view public.vehicle_public_view is
  'Customer-safe vehicle projection. Excludes registration, chassis, engine and owner data. security_invoker, so vehicle RLS still applies.';
comment on view public.driver_verification_summary is
  'Per-driver checklist coverage. total_* counts current documents whose type code is required by the active country template.';
comment on view public.vehicle_verification_summary is
  'Per-vehicle checklist coverage. total_* counts current documents whose type code is required by the active country template.';
comment on view public.active_fleet_roster is
  'Active fleet roster. active_jobs_count is a Phase 4 placeholder and is always 0 in Phase 2.';

revoke all on function public.vehicle_current_driver(uuid), public.driver_current_vehicle(uuid), public.driver_requires_verification(uuid), public.vehicle_requires_verification(uuid), public.can_carry_cargo(uuid, uuid), public.pending_verifications_for_admin(uuid) from public, anon;
grant execute on function public.vehicle_current_driver(uuid), public.driver_current_vehicle(uuid), public.driver_requires_verification(uuid), public.vehicle_requires_verification(uuid), public.can_carry_cargo(uuid, uuid), public.pending_verifications_for_admin(uuid) to authenticated, service_role;
revoke all on public.vehicle_public_view, public.driver_verification_summary, public.vehicle_verification_summary, public.active_fleet_roster from public, anon;
grant select on public.vehicle_public_view, public.driver_verification_summary, public.vehicle_verification_summary, public.active_fleet_roster to authenticated, service_role;
