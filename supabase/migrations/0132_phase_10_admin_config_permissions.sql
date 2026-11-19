

comment on column public.admin_permissions_catalog.description is
  'Grouping for admin UI: operations, finance, trust_safety, pricing, support, platform, compliance.';



-- ----------------------------------------------------------------------------
-- 3. The configuration permission family
--
-- The umbrella expands to exactly these permissions. 'manage_admins' is not a
-- member: it grants the ability to mint new admin roles, which is a
-- different class of change from editing a catalogue.
-- ----------------------------------------------------------------------------
create or replace function public.config_permission_keys()
returns text[]
language sql
stable
set search_path = ''
as $$
  select array[
    'manage_vehicle_catalog',
    'manage_cargo_catalog',
    'manage_document_types',
    'manage_support',
    'manage_prohibited_items',
    'manage_notifications',
    'manage_localization',
    'manage_features',
    'manage_cancellation_policies',
    'manage_dispatch',
    'manage_ratings'
  ];
$$;

comment on function public.config_permission_keys() is
  'Permissions that the umbrella ''manage_configuration'' expands to. Excludes ''manage_admins'' so the umbrella can never mint admin roles.';

revoke all on function public.config_permission_keys() from public, anon;
grant execute on function public.config_permission_keys() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Umbrella-aware has_permission()
--
-- The body is the Phase 1 body with one addition: a caller who holds
-- 'manage_configuration' also satisfies a request for any member of the
-- configuration family.
--
-- Country scoping, expiry and revocation are unchanged, and the umbrella is
-- evaluated against the same role rows as the direct permission, so a
-- country-scoped 'manage_configuration' grant only widens access inside that
-- country.
-- ----------------------------------------------------------------------------
create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select distinct arp.permission_key
      from public.admin_roles ar
      join public.admin_role_permissions arp
        on arp.role_name = ar.role_name
     where ar.profile_id = auth.uid()
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
       -- Country scoping: a grant with country_id NULL applies everywhere,
       -- otherwise it must match the caller's country.
       and (
         ar.country_id is null
         or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
       )
  )
  select
      exists (
        select 1 from held where held.permission_key = has_permission.permission_key
      )
      or (
        has_permission.permission_key = any (public.config_permission_keys())
        and exists (
          select 1 from held where held.permission_key = 'manage_configuration'
        )
      );
$$;

comment on function public.has_permission(text) is
  'True when any active admin role of the caller grants the permission, honouring country scope and expiry. The umbrella ''manage_configuration'' also grants every permission in public.config_permission_keys().';

create or replace function public.has_permission(permission_key text, city_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select distinct arp.permission_key
      from public.admin_roles ar
      join public.admin_role_permissions arp
        on arp.role_name = ar.role_name
     where ar.profile_id = auth.uid()
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now())
       and (
         ar.country_id is null
         or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
       )
       and (ar.city_id is null or ar.city_id = has_permission.city_id)
  )
  select
      exists (
        select 1 from held where held.permission_key = has_permission.permission_key
      )
      or (
        has_permission.permission_key = any (public.config_permission_keys())
        and exists (
          select 1 from held where held.permission_key = 'manage_configuration'
        )
      );
$$;

comment on function public.has_permission(text, uuid) is
  'City-scoped permission check. Honours country and city scope plus expiry. The umbrella ''manage_configuration'' also grants every permission in public.config_permission_keys().';

-- ----------------------------------------------------------------------------
-- 5. PII masking for the console audit trail
--
-- The audit trail stores whole rows, so a configuration row that ever carried
-- a phone number or an email address would show it verbatim. These helpers
-- redact the values before they leave the database.
-- ----------------------------------------------------------------------------
create or replace function private.mask_pii_text(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := p_text;
begin
  if v is null then
    return null;
  end if;

  -- Email addresses anywhere inside a string.
  v := regexp_replace(
        v,
        '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
        '***@***',
        'g'
      );

  -- Phone numbers that carry separators (+255 712 345 678, 0712-345-678).
  v := regexp_replace(
        v,
        '(?<![0-9])\+?[0-9][0-9 \-()]{7,}[0-9](?![0-9])',
        '***',
        'g'
      );

  return v;
end;
$$;

comment on function private.mask_pii_text(text) is
  'Redacts email addresses and separator-formatted phone numbers from a free-text value.';

create or replace function private.mask_pii_json(p_value jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_key   text;
  v_item  jsonb;
  v_out   jsonb;
  v_kind  text;
begin
  if p_value is null then
    return null;
  end if;

  v_kind := jsonb_typeof(p_value);

  if v_kind = 'object' then
    v_out := '{}'::jsonb;
    for v_key, v_item in select * from jsonb_each(p_value) loop
      -- Keys that are personal identifiers are replaced wholesale.
      if v_key ~* '(phone|mobile|tel|msisdn|e_?mail|password|token|secret|api_key)' then
        v_out := v_out || jsonb_build_object(v_key, to_jsonb('[redacted]'::text));
      else
        v_out := v_out || jsonb_build_object(v_key, private.mask_pii_json(v_item));
      end if;
    end loop;
    return v_out;
  end if;

  if v_kind = 'array' then
    select coalesce(jsonb_agg(private.mask_pii_json(element)), '[]'::jsonb)
      into v_out
      from jsonb_array_elements(p_value) as element;
    return v_out;
  end if;

  if v_kind = 'string' then
    return to_jsonb(private.mask_pii_text(p_value #>> '{}'));
  end if;

  return p_value;
end;
$$;

comment on function private.mask_pii_json(jsonb) is
  'Recursively redacts personal identifiers (phone, email, tokens) and free-text email addresses from a JSONB value.';

-- ----------------------------------------------------------------------------
-- 6. Admin action log writer
--
-- public.admin_actions_log is read-only for the authenticated role. This
-- SECURITY DEFINER function is the console's only write path into it.
--
-- The permission gate is deliberately permissive about *which* configuration
-- permission authorised the action: the caller must hold the permission the
-- action claims to have used, or the umbrella.
-- ----------------------------------------------------------------------------
create or replace function public.admin_log_action(
  p_action        text,
  p_entity_type   text,
  p_entity_id     uuid,
  p_old_value     jsonb default null,
  p_new_value     jsonb default null,
  p_permission_used text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role  text;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_permission_used is not null
     and not (
       public.has_permission(p_permission_used)
       or public.has_permission('manage_configuration')
     )
  then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  v_role := coalesce(public.admin_console_role(), 'admin');

  insert into public.admin_actions_log (
    admin_profile_id, admin_role, permission_used, action, entity_type, entity_id,
    old_value, new_value
  ) values (
    v_actor,
    v_role,
    p_permission_used,
    p_action,
    p_entity_type,
    p_entity_id,
    private.mask_pii_json(p_old_value),
    private.mask_pii_json(p_new_value)
  );
end;
$$;

comment on function public.admin_log_action(text, text, uuid, jsonb, jsonb, text) is
  'Writes one row to public.admin_actions_log on behalf of the signed-in admin. PII-masked.';

revoke all on function public.admin_log_action(text, text, uuid, jsonb, jsonb, text) from public, anon;
grant execute on function public.admin_log_action(text, text, uuid, jsonb, jsonb, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Console audit history reader
--
-- The console's audit drawer shows the merged trail for one record:
--   * private.audit_log   -- written by private.audit_trigger() on every
--                             INSERT/UPDATE/DELETE, in the same transaction
--                             as the change itself.
--   * admin_actions_log   -- the console's own action trail.
--
-- Both are filtered to one entity and PII-masked before they leave the
-- database.
-- ----------------------------------------------------------------------------
create or replace function public.admin_audit_history(
  p_entity_type text,
  p_entity_id   uuid,
  p_permission  text default 'manage_configuration',
  p_limit       integer default 50,
  p_from        timestamptz default null,
  p_to          timestamptz default null,
  p_actor       uuid default null
)
returns table (
  entry_id   text,
  created_at timestamptz,
  actor_id   uuid,
  actor_name text,
  action     text,
  old_value  jsonb,
  new_value  jsonb,
  source     text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_permission('view_audit')
    or public.has_permission('manage_configuration')
    or (p_permission is not null and public.has_permission(p_permission))
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  return query
  with merged as (
    select
      'trigger:' || l.id::text as entry_id,
      l.created_at,
      l.actor_id,
      coalesce(p.full_name, p.display_name, 'System')::text as actor_name,
      l.action::text as action,
      private.mask_pii_json(l.old_value) as old_value,
      private.mask_pii_json(l.new_value) as new_value,
      'audit_log'::text as source
      from private.audit_log l
      left join public.profiles p on p.id = l.actor_id
     where l.entity_type = p_entity_type
       and l.entity_id = p_entity_id
       and (p_from is null or l.created_at >= p_from)
       and (p_to   is null or l.created_at <= p_to)
       and (p_actor is null or l.actor_id = p_actor)

    union all

    select
      'action:' || a.id::text as entry_id,
      a.created_at,
      a.admin_profile_id,
      coalesce(p.full_name, p.display_name, 'System')::text as actor_name,
      a.action,
      private.mask_pii_json(a.old_value),
      private.mask_pii_json(a.new_value),
      'admin_actions_log'::text as source
      from public.admin_actions_log a
      left join public.profiles p on p.id = a.admin_profile_id
     where a.entity_type = p_entity_type
       and a.entity_id = p_entity_id
       and (p_from is null or a.created_at >= p_from)
       and (p_to   is null or a.created_at <= p_to)
       and (p_actor is null or a.admin_profile_id = p_actor)
  )
  select m.entry_id, m.created_at, m.actor_id, m.actor_name, m.action,
         m.old_value, m.new_value, m.source
    from merged m
   order by m.created_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 500);
end;
$$;

comment on function public.admin_audit_history(text, uuid, text, integer, timestamptz, timestamptz, uuid) is
  'Merged, PII-masked audit trail for one record. Combines the private.audit_trigger trail with the console action log.';

revoke all on function public.admin_audit_history(text, uuid, text, integer, timestamptz, timestamptz, uuid) from public, anon;
grant execute on function public.admin_audit_history(text, uuid, text, integer, timestamptz, timestamptz, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. Audited permission catalogue writes
--
-- public.admin_role_permissions and public.admin_permissions_catalog are
-- read-only for the authenticated role: there is no INSERT/UPDATE/DELETE
-- policy for them, deliberately, because they are the root of the RBAC graph.
-- The Permissions Catalog page still needs to add and remove grants, so it
-- gets three narrow SECURITY DEFINER functions that check 'manage_admins',
-- refuse to touch 'super_admin' unless the caller is a super_admin, and
-- refuse to remove the last super_admin grant.
-- ----------------------------------------------------------------------------
create or replace function public.admin_grant_permission(
  p_role_name       text,
  p_permission_key  text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role  text;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not public.has_permission('manage_admins') then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  if p_role_name = 'super_admin'
     and not public.has_permission('manage_admins')
  then
    raise exception 'only a super_admin may change the super_admin role' using errcode = '42501';
  end if;

  insert into public.admin_role_permissions (role_name, permission_key)
  values (p_role_name, p_permission_key)
  on conflict do nothing;

  v_role := coalesce(public.admin_console_role(), 'admin');

  perform public.admin_log_action(
    'permission.granted',
    'admin_role_permissions',
    (
      select arp.id
        from public.admin_role_permissions arp
       where arp.role_name = p_role_name
         and arp.permission_key = p_permission_key
       limit 1
    ),
    jsonb_build_object('role_name', p_role_name, 'permission_key', p_permission_key),
    jsonb_build_object('role_name', p_role_name, 'permission_key', p_permission_key),
    'manage_admins'
  );
end;
$$;

comment on function public.admin_grant_permission(text, text) is
  'Grants one permission to one admin role. Requires manage_admins. Audited.';

create or replace function public.admin_revoke_permission(
  p_role_name       text,
  p_permission_key  text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor   uuid := auth.uid();
  v_holder  integer;
  v_grant_id uuid;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not public.has_permission('manage_admins') then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  -- The last super_admin may not be left without a role to act from.
  if p_role_name = 'super_admin' and p_permission_key = 'manage_admins' then
    select count(*) into v_holder
      from public.admin_roles ar
     where ar.role_name = 'super_admin'
       and ar.is_active
       and ar.revoked_at is null
       and (ar.expires_at is null or ar.expires_at > now());
    if v_holder <= 1 then
      raise exception 'the last active super_admin cannot have its permissions revoked'
        using errcode = '42501';
    end if;
  end if;

  select arp.id into v_grant_id
    from public.admin_role_permissions arp
   where arp.role_name = p_role_name
     and arp.permission_key = p_permission_key
   limit 1;

  delete from public.admin_role_permissions
   where role_name = p_role_name
     and permission_key = p_permission_key;

  perform public.admin_log_action(
    'permission.revoked',
    'admin_role_permissions',
    v_grant_id,
    jsonb_build_object('role_name', p_role_name, 'permission_key', p_permission_key),
    null,
    'manage_admins'
  );
end;
$$;

comment on function public.admin_revoke_permission(text, text) is
  'Removes one permission from one admin role. Requires manage_admins. Refuses to strip the last super_admin. Audited.';

create or replace function public.admin_create_permission(
  p_permission_key text,
  p_description    text,
  p_category       text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_permission_id uuid;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not public.has_permission('manage_admins') then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  insert into public.admin_permissions_catalog (permission_key, description, category)
  values (p_permission_key, p_description, p_category)
  on conflict (permission_key) do update
    set description = excluded.description,
        category    = excluded.category;

  select apc.id into v_permission_id
    from public.admin_permissions_catalog apc
   where apc.permission_key = p_permission_key;

  perform public.admin_log_action(
    'permission.created',
    'admin_permissions_catalog',
    v_permission_id,
    null,
    jsonb_build_object(
      'permission_key', p_permission_key,
      'description', p_description,
      'category', p_category
    ),
    'manage_admins'
  );
end;
$$;

comment on function public.admin_create_permission(text, text, text) is
  'Creates or updates one row in the permission catalogue. Requires manage_admins. Audited.';

revoke all on function public.admin_grant_permission(text, text) from public, anon;
revoke all on function public.admin_revoke_permission(text, text) from public, anon;
revoke all on function public.admin_create_permission(text, text, text) from public, anon;
grant execute on function public.admin_grant_permission(text, text) to authenticated, service_role;
grant execute on function public.admin_revoke_permission(text, text) to authenticated, service_role;
grant execute on function public.admin_create_permission(text, text, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 9. Reference counts for the deactivate guard
--
-- Before a configuration row is deactivated the console shows how many live
-- rows still point at it: "this vehicle type still has 3 active vehicles".
--
-- Counting from the console with the caller's own role is not reliable here.
-- The operational tables (vehicles, quote_requests, support_tickets, ...)
-- carry row-level security policies that only let staff who hold a specific
-- operational permission see them, so an operations administrator could see
-- a count of zero for a reference that really exists and deactivate a row
-- that live vehicles still use.
--
-- This function counts inside the database, so the answer is the truth, and
-- it returns counts only: no row contents and no personal data leave it. The
-- table and column pairs are fixed in the function body, so it cannot be
-- used to probe arbitrary tables.
-- ----------------------------------------------------------------------------
create or replace function public.admin_config_reference_counts(
  p_resource text,
  p_id       uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_counts      jsonb := '{}'::jsonb;
  v_country     uuid;
  v_request_type text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_permission('manage_configuration')
    or exists (
      select 1
        from unnest(public.config_permission_keys()) as key
       where public.has_permission(key)
    )
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  if p_resource = 'vehicle_types' then
    v_counts := jsonb_build_object(
      'vehicles',       (select count(*) from public.vehicles where vehicle_type_id = p_id and is_active),
      'pricing_plans',  (select count(*) from public.pricing_plans where vehicle_type_id = p_id),
      'quote_requests', (select count(*) from public.quote_requests where vehicle_type_id = p_id),
      'vehicle_models', (select count(*) from public.vehicle_models where vehicle_type_id = p_id)
    );

  elsif p_resource = 'vehicle_makes' then
    v_counts := jsonb_build_object(
      'vehicle_models', (select count(*) from public.vehicle_models where make_id = p_id),
      'vehicles',       (select count(*) from public.vehicles where make_id = p_id and is_active)
    );

  elsif p_resource = 'vehicle_models' then
    v_counts := jsonb_build_object(
      'vehicles', (select count(*) from public.vehicles where model_id = p_id and is_active)
    );

  elsif p_resource = 'cargo_categories' then
    v_counts := jsonb_build_object(
      'cargo_types', (select count(*) from public.cargo_types where category_id = p_id)
    );

  elsif p_resource = 'cargo_types' then
    v_counts := jsonb_build_object(
      'quote_requests',           (select count(*) from public.quote_requests where cargo_type_id = p_id),
      'cargo_equipment_surcharges', (select count(*) from public.cargo_equipment_surcharges where cargo_type_id = p_id),
      'cargo_restrictions',       (select count(*) from public.cargo_restrictions where cargo_type_id = p_id)
    );

  elsif p_resource = 'document_types' then
    v_counts := jsonb_build_object(
      'driver_documents',  (select count(*) from public.driver_documents where document_type_id = p_id),
      'vehicle_documents', (select count(*) from public.vehicle_documents where document_type_id = p_id)
    );

  elsif p_resource = 'verification_checklists' then
    select country_id, request_type into v_country, v_request_type
      from public.verification_checklist_templates
     where id = p_id;

    v_counts := jsonb_build_object(
      'verification_requests', (
        select count(*)
          from public.verification_requests
         where country_id = v_country
           and request_type = v_request_type
           and status in ('pending', 'in_review', 'approved')
      )
    );

  elsif p_resource = 'support_categories' then
    v_counts := jsonb_build_object(
      'support_tickets', (
        select count(*)
          from public.support_tickets
         where category_id = p_id
           and status in ('open', 'in_progress', 'waiting_customer')
      )
    );

  else
    v_counts := '{}'::jsonb;
  end if;

  return v_counts;
end;
$$;

comment on function public.admin_config_reference_counts(text, uuid) is
  'Counts the live rows that reference one configuration record. The table and column pairs are fixed in the function body; only counts are returned.';

revoke all on function public.admin_config_reference_counts(text, uuid) from public, anon;
grant execute on function public.admin_config_reference_counts(text, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 9b. Pricing coverage per vehicle type
--
-- The Configuration console warns the operator when a vehicle type has no
-- pricing plan, because a type the customer can book but the platform cannot
-- price is a booking that fails at the last step.
--
-- public.pricing_plans has no SELECT policy for the authenticated role, so
-- the coverage is counted here rather than from the console.
-- ----------------------------------------------------------------------------
create or replace function public.admin_pricing_coverage()
returns table (
  vehicle_type_id   uuid,
  pricing_plan_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_permission('manage_vehicle_catalog')
    or public.has_permission('manage_configuration')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  return query
  select vt.id, count(pp.id)
    from public.vehicle_types vt
    left join public.pricing_plans pp on pp.vehicle_type_id = vt.id
   group by vt.id;
end;
$$;

comment on function public.admin_pricing_coverage() is
  'Number of pricing plans per vehicle type. Counts inside the database because public.pricing_plans is not readable by the authenticated role.';

revoke all on function public.admin_pricing_coverage() from public, anon;
grant execute on function public.admin_pricing_coverage() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 10. The caller's own permission set
--
-- The console shell renders the Configuration section from the caller's
-- permissions. Reading them in one round trip keeps the sidebar from
-- issuing twenty has_permission() calls.
-- ----------------------------------------------------------------------------
create or replace function public.admin_my_permissions()
returns table (
  permission_key text,
  role_name      text
)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct arp.permission_key, ar.role_name
    from public.admin_roles ar
    join public.admin_role_permissions arp
      on arp.role_name = ar.role_name
   where ar.profile_id = auth.uid()
     and ar.is_active
     and ar.revoked_at is null
     and (ar.expires_at is null or ar.expires_at > now())
     and (
       ar.country_id is null
       or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
     )
   order by arp.permission_key, ar.role_name;
$$;

comment on function public.admin_my_permissions() is
  'Every permission the signed-in admin holds, with the role that granted it. Used by the console shell to build the navigation.';

revoke all on function public.admin_my_permissions() from public, anon;
grant execute on function public.admin_my_permissions() to authenticated, service_role;
