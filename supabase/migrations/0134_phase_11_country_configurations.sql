-- ============================================================================
-- SafeShift — Phase 11 / Migration 0134
-- Country configurations as their own table.
--
-- Until now a country's configuration lived in a single jsonb column on
-- public.countries:
--
--   config jsonb not null default '{}'::jsonb
--
--   'Country-level configuration: payment providers, KYC rules, document
--    requirements, feature defaults.'
--
-- A JSON blob cannot be searched, cannot be constrained, cannot be indexed,
-- cannot be audited column by column, and cannot be granted to a different
-- operator than the country itself. It also gives the operator no way to
-- tell which key holds a payment provider list and which holds a KYC rule:
-- they are all entries in the same object.
--
-- This migration replaces the blob with a real table:
--
--   public.country_configurations
--     country_id  -- the country the configuration belongs to
--     config_key  -- the setting name, e.g. 'payment_providers'
--     config_value -- the value of that setting, as JSON
--
-- One row is one setting. The table is country-scoped the same way the
-- twenty-one configuration tables are: a row belongs to exactly one country,
-- and the key is unique inside that country.
--
-- The existing blob is migrated into the table, key by key, so no setting is
-- lost and the operator's data keeps working.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The table
-- ----------------------------------------------------------------------------
create table public.country_configurations (
  id           uuid primary key default gen_random_uuid(),
  country_id   uuid not null references public.countries (id) on delete cascade,
  config_key   text not null,
  config_value jsonb not null default '{}'::jsonb,
  description  text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- The key names the setting, so it is a code rather than free text.
  constraint country_configurations_key_format
    check (config_key ~ '^[a-z0-9_]+$'),

  -- One setting per key per country.
  constraint country_configurations_country_key_unique
    unique (country_id, config_key)
);

comment on table public.country_configurations is
  'The settings of one country, one row per setting. Replaces the jsonb blob that used to live on public.countries.';

comment on column public.country_configurations.config_key is
  'The name of the setting, e.g. payment_providers, kyc_rules, document_requirements, feature_defaults.';

comment on column public.country_configurations.config_value is
  'The value of the setting. Its shape depends on the key, so it is stored as JSON and validated by the console.';

-- ----------------------------------------------------------------------------
-- 2. Move the existing blob into rows
--
-- Each key of the old jsonb object becomes one row. A country whose blob
-- was empty or absent contributes no rows.
-- ----------------------------------------------------------------------------
insert into public.country_configurations (
  country_id, config_key, config_value, description, is_active
)
select
  c.id,
  entry.key,
  entry.value,
  'Migrated from the country configuration blob.',
  true
from public.countries c
cross join lateral jsonb_each(c.config) as entry(key, value)
where c.config <> '{}'::jsonb
on conflict (country_id, config_key) do nothing;

-- ----------------------------------------------------------------------------
-- 3. Drop the blob
--
-- Every setting now lives in its own row, so the column would only be a
-- second source of truth that could drift from the table.
-- ----------------------------------------------------------------------------
alter table public.countries drop column config;

comment on table public.countries is
  'Countries the platform operates in. Activating a country is a data change, not a code change. The settings of a country live in public.country_configurations.';

-- ----------------------------------------------------------------------------
-- 4. Audit trail and timestamps
-- ----------------------------------------------------------------------------
create trigger trg_country_configurations_audit
  after insert or update or delete on public.country_configurations
  for each row execute function private.audit_trigger();

create trigger trg_country_configurations_updated_at
  before update on public.country_configurations
  for each row execute function set_updated_at();

-- ----------------------------------------------------------------------------
-- 5. Privileges
--
-- The console writes a configuration row through the signed-in
-- administrator's session, so the table needs the write privileges its
-- policies use. DELETE is not granted: a setting is retired by clearing
-- is_active, never by removing the row.
-- ----------------------------------------------------------------------------
grant insert, update on public.country_configurations to authenticated;

-- ----------------------------------------------------------------------------
-- 6. Row-level security
--
-- The policies are gated on 'manage_countries', the same permission that
-- unlocks the Countries page, so an operator who may open a country may
-- manage its settings.
-- ----------------------------------------------------------------------------
alter table public.country_configurations enable row level security;

create policy country_configurations_select_authenticated
  on public.country_configurations for select to authenticated using (true);

create policy country_configurations_insert_manage_countries
  on public.country_configurations for insert to authenticated
  with check ((select public.has_permission('manage_countries')));

create policy country_configurations_update_manage_countries
  on public.country_configurations for update to authenticated
  using ((select public.has_permission('manage_countries')))
  with check ((select public.has_permission('manage_countries')));

-- ----------------------------------------------------------------------------
-- 7. Reference counts
--
-- A country with settings still attached is a country the operator has
-- configured, and the console counts those rows before it lets the country
-- be deactivated.
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
      'fleets',            (select count(*) from public.fleets where country_id = p_id and is_active),
      'configurations',    (select count(*) from public.country_configurations where country_id = p_id and is_active)
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
