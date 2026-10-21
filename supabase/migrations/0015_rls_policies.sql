-- ============================================================================
-- SafeShift — Phase 1 / Migration 0015
-- Row Level Security.
--
-- Every public table has RLS enabled. Policies deny by default and use
-- (select auth.uid()) so the planner evaluates it once per statement.
--
-- Write paths that must never come from a client have NO policy at all; the
-- service role (Edge Functions only) bypasses RLS and is the only writer.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Enable RLS on every public table
-- ----------------------------------------------------------------------------
alter table public.currencies                  enable row level security;
alter table public.languages                   enable row level security;
alter table public.countries                   enable row level security;
alter table public.regions                     enable row level security;
alter table public.cities                      enable row level security;
alter table public.service_zones               enable row level security;
alter table public.neighborhoods               enable row level security;
alter table public.addresses                   enable row level security;
alter table public.zone_pricing_overrides      enable row level security;
alter table public.profiles                    enable row level security;
alter table public.user_devices                enable row level security;
alter table public.user_sessions               enable row level security;
alter table public.customers                   enable row level security;
alter table public.business_accounts           enable row level security;
alter table public.business_members            enable row level security;
alter table public.drivers                     enable row level security;
alter table public.driver_status_history       enable row level security;
alter table public.driver_operating_zones      enable row level security;
alter table public.driver_service_hours        enable row level security;
alter table public.user_referrals              enable row level security;
alter table public.saved_addresses             enable row level security;
alter table public.admin_roles                 enable row level security;
alter table public.admin_permissions_catalog   enable row level security;
alter table public.admin_role_permissions      enable row level security;
alter table public.admin_actions_log           enable row level security;
alter table public.exchange_rates              enable row level security;
alter table public.localization_strings        enable row level security;
alter table public.feature_flags               enable row level security;
alter table public.consent_records             enable row level security;

-- The partitioned audit log is server-only: RLS on, zero policies, grants revoked.
alter table private.audit_log                  enable row level security;

-- ============================================================================
-- Reference data: read-only for authenticated clients
-- ============================================================================
create policy currencies_select_authenticated
  on public.currencies for select to authenticated using (true);

create policy languages_select_authenticated
  on public.languages for select to authenticated using (true);

create policy countries_select_authenticated
  on public.countries for select to authenticated using (true);

create policy regions_select_authenticated
  on public.regions for select to authenticated using (true);

create policy cities_select_authenticated
  on public.cities for select to authenticated using (true);

create policy neighborhoods_select_authenticated
  on public.neighborhoods for select to authenticated using (true);

create policy admin_permissions_catalog_select_authenticated
  on public.admin_permissions_catalog for select to authenticated using (true);

create policy admin_role_permissions_select_authenticated
  on public.admin_role_permissions for select to authenticated using (true);

-- ============================================================================
-- Geography / configuration tables
-- ============================================================================
-- service_zones: everyone reads; zone changes require manage_zones.
create policy service_zones_select_authenticated
  on public.service_zones for select to authenticated using (true);

create policy service_zones_insert_manage_zones
  on public.service_zones for insert to authenticated
  with check ((select public.has_permission('manage_zones')));

create policy service_zones_update_manage_zones
  on public.service_zones for update to authenticated
  using ((select public.has_permission('manage_zones')))
  with check ((select public.has_permission('manage_zones')));

create policy service_zones_delete_manage_zones
  on public.service_zones for delete to authenticated
  using ((select public.has_permission('manage_zones')));

-- addresses: owner-only reads, unless the caller can view all addresses.
create policy addresses_select_own_or_view_all
  on public.addresses for select to authenticated
  using (
    created_by = (select auth.uid())
    or (select public.has_permission('view_all_addresses'))
  );

create policy addresses_insert_authenticated
  on public.addresses for insert to authenticated
  with check (created_by = (select auth.uid()));

create policy addresses_update_creator
  on public.addresses for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()));

-- zone_pricing_overrides: everyone reads; changes require adjust_pricing.
create policy zone_pricing_overrides_select_authenticated
  on public.zone_pricing_overrides for select to authenticated using (true);

create policy zone_pricing_overrides_insert_adjust_pricing
  on public.zone_pricing_overrides for insert to authenticated
  with check ((select public.has_permission('adjust_pricing')));

create policy zone_pricing_overrides_update_adjust_pricing
  on public.zone_pricing_overrides for update to authenticated
  using ((select public.has_permission('adjust_pricing')))
  with check ((select public.has_permission('adjust_pricing')));

create policy zone_pricing_overrides_delete_adjust_pricing
  on public.zone_pricing_overrides for delete to authenticated
  using ((select public.has_permission('adjust_pricing')));

-- ============================================================================
-- Identity
-- ============================================================================
-- profiles: own row, or admins with view_all_users. No INSERT policy (the auth
-- trigger creates profiles). No DELETE policy (service role only).
create policy profiles_select_own_or_view_all
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or (select public.has_permission('view_all_users'))
  );

create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- user_devices: full CRUD on your own devices.
create policy user_devices_select_own
  on public.user_devices for select to authenticated
  using (profile_id = (select auth.uid()));

create policy user_devices_insert_own
  on public.user_devices for insert to authenticated
  with check (profile_id = (select auth.uid()));

create policy user_devices_update_own
  on public.user_devices for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy user_devices_delete_own
  on public.user_devices for delete to authenticated
  using (profile_id = (select auth.uid()));

-- user_sessions: own reads, or admins with view_sessions. Writes are server-only.
create policy user_sessions_select_own_or_view_sessions
  on public.user_sessions for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('view_sessions'))
  );

-- customers: own row, or admins with view_all_customers.
create policy customers_select_own_or_view_all
  on public.customers for select to authenticated
  using (
    id = (select auth.uid())
    or (select public.has_permission('view_all_customers'))
  );

create policy customers_update_own
  on public.customers for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- business_accounts: members read; any authenticated user may create; only
-- owners/admins may modify.
create policy business_accounts_select_member_or_view_all
  on public.business_accounts for select to authenticated
  using (
    (select public.is_business_member(id))
    or (select public.has_permission('view_business_accounts'))
  );

create policy business_accounts_insert_authenticated
  on public.business_accounts for insert to authenticated
  with check ((select auth.uid()) is not null);

create policy business_accounts_update_admin
  on public.business_accounts for update to authenticated
  using ((select public.is_business_admin(id)))
  with check ((select public.is_business_admin(id)));

-- business_members: members read; owners (or the bootstrapping first owner)
-- write.
create policy business_members_select_member_or_view_all
  on public.business_members for select to authenticated
  using (
    (select public.is_business_member(business_account_id))
    or (select public.has_permission('view_business_accounts'))
  );

create policy business_members_insert_owner_or_bootstrap
  on public.business_members for insert to authenticated
  with check (
    (select public.is_business_owner(business_account_id))
    or (
      profile_id = (select auth.uid())
      and business_members.role = 'owner'
      and not (select public.business_has_members(business_account_id))
    )
  );

create policy business_members_update_owner
  on public.business_members for update to authenticated
  using ((select public.is_business_owner(business_account_id)))
  with check ((select public.is_business_owner(business_account_id)));

create policy business_members_delete_owner
  on public.business_members for delete to authenticated
  using ((select public.is_business_owner(business_account_id)));

-- drivers: own row, or admins with view_all_drivers. The Phase 4 "customer on
-- active job" branch is intentionally a placeholder that grants nothing yet.
create policy drivers_select_own_or_view_all
  on public.drivers for select to authenticated
  using (
    id = (select auth.uid())
    or (select public.has_permission('view_all_drivers'))
    or false -- Phase 4: customer on an active job with this driver
  );

create policy drivers_update_own
  on public.drivers for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- driver_status_history: own history, or admins. Writes come from the trigger.
create policy driver_status_history_select_own_or_view_all
  on public.driver_status_history for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_drivers'))
  );

-- driver operating zones / service hours: full CRUD on your own rows.
create policy driver_operating_zones_select_own_or_view_all
  on public.driver_operating_zones for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_drivers'))
  );

create policy driver_operating_zones_insert_own
  on public.driver_operating_zones for insert to authenticated
  with check (driver_id = (select auth.uid()));

create policy driver_operating_zones_update_own
  on public.driver_operating_zones for update to authenticated
  using (driver_id = (select auth.uid()))
  with check (driver_id = (select auth.uid()));

create policy driver_operating_zones_delete_own
  on public.driver_operating_zones for delete to authenticated
  using (driver_id = (select auth.uid()));

create policy driver_service_hours_select_own_or_view_all
  on public.driver_service_hours for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_drivers'))
  );

create policy driver_service_hours_insert_own
  on public.driver_service_hours for insert to authenticated
  with check (driver_id = (select auth.uid()));

create policy driver_service_hours_update_own
  on public.driver_service_hours for update to authenticated
  using (driver_id = (select auth.uid()))
  with check (driver_id = (select auth.uid()));

create policy driver_service_hours_delete_own
  on public.driver_service_hours for delete to authenticated
  using (driver_id = (select auth.uid()));

-- user_referrals: visible to referrer and referred; created by the referrer.
create policy user_referrals_select_involved
  on public.user_referrals for select to authenticated
  using (
    referrer_profile_id = (select auth.uid())
    or referred_profile_id = (select auth.uid())
  );

create policy user_referrals_insert_referrer
  on public.user_referrals for insert to authenticated
  with check (referrer_profile_id = (select auth.uid()));

-- saved_addresses: full CRUD on your own rows.
create policy saved_addresses_select_own
  on public.saved_addresses for select to authenticated
  using (profile_id = (select auth.uid()));

create policy saved_addresses_insert_own
  on public.saved_addresses for insert to authenticated
  with check (profile_id = (select auth.uid()));

create policy saved_addresses_update_own
  on public.saved_addresses for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy saved_addresses_delete_own
  on public.saved_addresses for delete to authenticated
  using (profile_id = (select auth.uid()));

-- ============================================================================
-- Administration
-- ============================================================================
create policy admin_roles_select_own_or_manage
  on public.admin_roles for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('manage_admins'))
  );

create policy admin_roles_insert_manage_admins
  on public.admin_roles for insert to authenticated
  with check ((select public.has_permission('manage_admins')));

create policy admin_roles_update_manage_admins
  on public.admin_roles for update to authenticated
  using ((select public.has_permission('manage_admins')))
  with check ((select public.has_permission('manage_admins')));

create policy admin_roles_delete_manage_admins
  on public.admin_roles for delete to authenticated
  using ((select public.has_permission('manage_admins')));

-- admin_actions_log: readable with view_audit. Writes are service-role only.
create policy admin_actions_log_select_view_audit
  on public.admin_actions_log for select to authenticated
  using ((select public.has_permission('view_audit')));

-- ============================================================================
-- Localization / configuration
-- ============================================================================
create policy exchange_rates_select_authenticated
  on public.exchange_rates for select to authenticated using (true);

create policy exchange_rates_insert_manage_currency
  on public.exchange_rates for insert to authenticated
  with check ((select public.has_permission('manage_currency')));

create policy exchange_rates_update_manage_currency
  on public.exchange_rates for update to authenticated
  using ((select public.has_permission('manage_currency')))
  with check ((select public.has_permission('manage_currency')));

create policy exchange_rates_delete_manage_currency
  on public.exchange_rates for delete to authenticated
  using ((select public.has_permission('manage_currency')));

create policy localization_strings_select_authenticated
  on public.localization_strings for select to authenticated using (true);

create policy localization_strings_insert_manage_localization
  on public.localization_strings for insert to authenticated
  with check ((select public.has_permission('manage_localization')));

create policy localization_strings_update_manage_localization
  on public.localization_strings for update to authenticated
  using ((select public.has_permission('manage_localization')))
  with check ((select public.has_permission('manage_localization')));

create policy localization_strings_delete_manage_localization
  on public.localization_strings for delete to authenticated
  using ((select public.has_permission('manage_localization')));

create policy feature_flags_select_authenticated
  on public.feature_flags for select to authenticated using (true);

create policy feature_flags_insert_manage_features
  on public.feature_flags for insert to authenticated
  with check ((select public.has_permission('manage_features')));

create policy feature_flags_update_manage_features
  on public.feature_flags for update to authenticated
  using ((select public.has_permission('manage_features')))
  with check ((select public.has_permission('manage_features')));

create policy feature_flags_delete_manage_features
  on public.feature_flags for delete to authenticated
  using ((select public.has_permission('manage_features')));

-- ============================================================================
-- Consent (append-only)
-- ============================================================================
create policy consent_records_select_own_or_view_consent
  on public.consent_records for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('view_consent'))
  );

-- ============================================================================
-- Privileges
-- ============================================================================
-- No anonymous access anywhere in v1.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- Authenticated clients can read anything RLS allows.
grant select on all tables in schema public to authenticated;

-- The audit log is server-only.
revoke all on all tables in schema private from anon;
revoke all on all tables in schema private from authenticated;
revoke all on all sequences in schema private from anon;
revoke all on all sequences in schema private from authenticated;

-- profiles: clients may not change role or account status. Restrict UPDATE to
-- the safe, self-service columns. Governed further by trg_profiles_protect_privileged.
revoke update on public.profiles from authenticated;
grant update (
  full_name,
  display_name,
  phone,
  email,
  avatar_url,
  preferred_language_id,
  preferred_currency_id,
  default_country_id,
  marketing_opt_in,
  terms_accepted_at,
  privacy_accepted_at,
  last_login_at,
  last_login_ip
) on public.profiles to authenticated;

-- Consent is append-only through public.record_consent.
revoke update, delete on public.consent_records from authenticated;

-- Admin action log is written only by the service role.
revoke insert, update, delete on public.admin_actions_log from authenticated;

-- Countries, regions, cities, neighborhoods, currencies, languages, catalogues
-- and zone overrides are read-only where no client write policy exists.
revoke insert, update, delete on public.countries from authenticated;
revoke insert, update, delete on public.regions from authenticated;
revoke insert, update, delete on public.cities from authenticated;
revoke insert, update, delete on public.neighborhoods from authenticated;
revoke insert, update, delete on public.currencies from authenticated;
revoke insert, update, delete on public.languages from authenticated;
revoke insert, update, delete on public.admin_permissions_catalog from authenticated;
revoke insert, update, delete on public.admin_role_permissions from authenticated;
revoke insert, update, delete on public.driver_status_history from authenticated;

-- Sequences (identity columns) need usage for inserts by authenticated callers.
grant usage, select on all sequences in schema public to authenticated;
