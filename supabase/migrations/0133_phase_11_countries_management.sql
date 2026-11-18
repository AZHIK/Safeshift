-- ============================================================================
-- SafeShift — Phase 11 / Migration 0133
-- Country management in the operator configuration console.
--
-- The console can already read public.countries (every country-scoped
-- configuration row and every country dropdown reads it), but it cannot
-- write to it: the table is read-only for the authenticated role and the
-- catalogue of permissions has no key that unlocks it.
--
-- This migration adds the missing half:
--
--   1. the 'manage_countries' permission and the grants that unlock it,
--   2. the umbrella family entry, so 'manage_configuration' opens the page
--      the same way it opens the other twenty configuration pages,
--   3. the row-level security policies that let an administrator write a
--      country row, and the table privileges those policies need,
--   4. the reference counts that stop a country being deactivated while
--      live data still points at it.
--
-- Countries are the root of the scope hierarchy: twenty-eight tables carry
-- a country_id. Deactivating a country that cities, vehicles or pricing
-- plans still reference would hide a live market, so the deactivate guard
-- counts those rows before the console lets the row be hidden.
--
-- Nothing else about the permission model changes. The umbrella still does
-- not cover 'manage_admins', and the grants below are the same two roles
-- migration 0132 granted configuration domains to.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The permission
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_countries', 'Add the countries the platform operates in and retire the ones it does not', 'platform')
on conflict (permission_key) do nothing;

comment on column public.admin_permissions_catalog.description is
  'Grouping for admin UI: operations, finance, trust_safety, pricing, support, platform, compliance.';

-- ----------------------------------------------------------------------------
-- 2. Role grants
-- ----------------------------------------------------------------------------
-- super_admin receives every catalogue row ("select 'super_admin',
-- permission_key from public.admin_permissions_catalog"), so it holds this
-- one automatically once the catalogue row exists.
--
-- operations_admin is given the key explicitly: opening a market is an
-- operations duty, in the same way that adding a vehicle type for a new
-- city is.
-- ----------------------------------------------------------------------------
insert into public.admin_role_permissions (role_name, permission_key) values
  ('super_admin',      'manage_countries'),
  ('operations_admin', 'manage_countries')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 3. The umbrella family
-- ----------------------------------------------------------------------------
-- 'manage_configuration' opens the whole operator configuration section.
-- The countries page is part of that section, so the umbrella covers it.
--
-- The family list stays in sync with
-- apps/admin-console/lib/configuration/resources/index.ts, which mirrors it.
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
    'manage_ratings',
    'manage_countries'
  ];
$$;

comment on function public.config_permission_keys() is
  'Permissions that the umbrella ''manage_configuration'' expands to. Excludes ''manage_admins'' so the umbrella can never mint admin roles.';

revoke all on function public.config_permission_keys() from public, anon;
grant execute on function public.config_permission_keys() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Writing a country row
--
-- The console writes through the signed-in administrator's session, so the
-- database has to allow it. The policies are gated on 'manage_countries',
-- which the umbrella also satisfies.
--
-- DELETE is deliberately not granted: a country is retired by clearing
-- is_active, never by removing the row, because twenty-eight tables carry a
-- country_id and the history of a live market must not disappear.
-- ----------------------------------------------------------------------------
grant insert, update on public.countries to authenticated;

create policy countries_insert_manage_countries
  on public.countries for insert to authenticated
  with check ((select public.has_permission('manage_countries')));

create policy countries_update_manage_countries
  on public.countries for update to authenticated
  using ((select public.has_permission('manage_countries')))
  with check ((select public.has_permission('manage_countries')));

-- ----------------------------------------------------------------------------
-- 5. Reference counts
--
-- A country that cities, vehicles, drivers, pricing plans or tax rates
-- still point at is a live market. The console counts those rows before it
-- lets the country be deactivated, and refuses while any of them exist.
--
-- The counts are taken inside the database because the operational tables
-- carry row-level security policies that would otherwise hide live
-- references from an operator. The table and column pairs are fixed in the
-- function body, and only counts leave it.
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

  elsif p_resource = 'countries' then
    v_counts := jsonb_build_object(
      'cities',            (select count(*) from public.cities where country_id = p_id and is_active),
      'regions',           (select count(*) from public.regions where country_id = p_id and is_active),
      'vehicles',          (select count(*) from public.vehicles where country_id = p_id and is_active),
      'drivers',           (select count(*) from public.drivers where country_id = p_id),
      'pricing_plans',     (select count(*) from public.pricing_plans where country_id = p_id and is_active),
      'tax_rates',         (select count(*) from public.tax_rates where country_id = p_id and is_active),
      'payment_providers', (select count(*) from public.payment_providers where country_id = p_id and is_active),
      'business_accounts', (select count(*) from public.business_accounts where country_id = p_id and is_active),
      'fleets',            (select count(*) from public.fleets where country_id = p_id and is_active)
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
