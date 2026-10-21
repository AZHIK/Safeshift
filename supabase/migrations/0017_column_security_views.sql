-- ============================================================================
-- SafeShift — Phase 1 / Migration 0017
-- Column-level security views.
--
-- 1. public.driver_public_profile — column-limited, security_invoker view over
--    a whitelisting SECURITY DEFINER function. It never exposes phone, email,
--    licence number or exact coordinates.
--
-- 2. public.audit_log_view — security_invoker view over the SECURITY DEFINER
--    function public.get_audit_log(). The function owns the privileged read of
--    private.audit_log and the view_audit permission gate; the view itself
--    elevates no privileges (avoids the security_definer_view lint finding).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.driver_public_profile
-- ----------------------------------------------------------------------------
-- security_invoker = true means the view runs with the caller's privileges.
-- The underlying function is the whitelist: it returns only safe columns and
-- only for verified, active drivers.
create or replace view public.driver_public_profile
with (security_invoker = true)
as
select
  g.id,
  g.full_name,
  g.display_name,
  g.avatar_url,
  g.rating,
  g.total_trips,
  g.verification_status,
  g.home_city_id,
  g.current_vehicle_id
from public.get_public_driver_profile(null) as g;

comment on view public.driver_public_profile is
  'Customer/investor-safe driver projection. Excludes phone, email, licence and exact location. Read-only.';

-- ----------------------------------------------------------------------------
-- public.get_audit_log()
-- ----------------------------------------------------------------------------
-- The privileged read of private.audit_log lives in this SECURITY DEFINER
-- function. The WHERE clause is the authorisation gate: without the view_audit
-- permission the function returns zero rows. search_path is empty and all
-- object names are schema-qualified, so no caller can influence name
-- resolution.
create or replace function public.get_audit_log(
  p_limit       integer default null,
  p_entity_type text    default null,
  p_entity_id   uuid    default null
)
returns table (
  id          bigint,
  actor_id    uuid,
  actor_role  public.user_role,
  action      public.audit_action,
  entity_type text,
  entity_id   uuid,
  old_value   jsonb,
  new_value   jsonb,
  ip_address  inet,
  user_agent  text,
  session_id  text,
  created_at  timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    a.id,
    a.actor_id,
    a.actor_role,
    a.action,
    a.entity_type,
    a.entity_id,
    a.old_value,
    a.new_value,
    a.ip_address,
    a.user_agent,
    a.session_id,
    a.created_at
  from private.audit_log a
  where (select public.has_permission('view_audit'))
    and (p_entity_type is null or a.entity_type = p_entity_type)
    and (p_entity_id   is null or a.entity_id   = p_entity_id)
  order by a.created_at desc
  limit case
          when p_limit is null then null            -- NULL limit = all rows
          else least(greatest(p_limit, 1), 1000)
        end;
$$;

comment on function public.get_audit_log(integer, text, uuid) is
  'Permission-gated read of private.audit_log. Returns zero rows unless the caller holds the view_audit permission. p_limit NULL (the default) returns all rows.';

revoke all on function public.get_audit_log(integer, text, uuid) from public, anon;
grant execute on function public.get_audit_log(integer, text, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- public.audit_log_view
-- ----------------------------------------------------------------------------
-- security_invoker = true: the view runs with the caller's privileges and
-- elevates nothing. The privileged read is delegated to public.get_audit_log(),
-- which is SECURITY DEFINER and applies the view_audit gate.
create or replace view public.audit_log_view
with (security_invoker = true, security_barrier = true)
as
select * from public.get_audit_log();

comment on view public.audit_log_view is
  'Audit trail projection for administrators holding the view_audit permission. Returns zero rows otherwise. Security-invoker view over public.get_audit_log().';

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------
revoke all on public.driver_public_profile from public, anon;
revoke all on public.audit_log_view from public, anon;

grant select on public.driver_public_profile to authenticated, service_role;
grant select on public.audit_log_view to authenticated, service_role;
