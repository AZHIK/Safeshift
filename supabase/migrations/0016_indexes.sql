-- ============================================================================
-- SafeShift — Phase 1 / Migration 0016
-- Indexes.
--
-- Unique constraints declared inline in earlier migrations already create their
-- own indexes; this migration adds the remaining access-path and partial
-- indexes. All statements are idempotent.
--
-- Partitioning thresholds (documented, not enforced here):
--   * private.audit_log     — partitioned monthly from day one (migration 0012)
--   * public.user_sessions  — partition by RANGE(created_at) above ~50M rows
--   * public.admin_actions_log — partition by RANGE(created_at) above ~100M rows
--   * public.user_devices   — no partitioning expected for pilot scale
-- ============================================================================

-- ----------------------------------------------------------------------------
-- profiles
-- ----------------------------------------------------------------------------
create unique index if not exists profiles_email_key
  on public.profiles (email)
  where email is not null;

create index if not exists profiles_primary_role_idx
  on public.profiles (primary_role);

create index if not exists profiles_default_country_idx
  on public.profiles (default_country_id);

create index if not exists profiles_is_active_idx
  on public.profiles (is_active);

-- ----------------------------------------------------------------------------
-- user_devices / user_sessions
-- ----------------------------------------------------------------------------
create index if not exists user_devices_push_token_idx
  on public.user_devices (push_token)
  where push_token is not null;

create index if not exists user_sessions_profile_id_idx
  on public.user_sessions (profile_id);

create index if not exists user_sessions_active_expires_idx
  on public.user_sessions (expires_at)
  where revoked_at is null;

-- ----------------------------------------------------------------------------
-- customers / business
-- ----------------------------------------------------------------------------
create index if not exists business_accounts_country_idx
  on public.business_accounts (country_id);

create index if not exists business_accounts_registration_number_idx
  on public.business_accounts (registration_number);

create index if not exists business_members_profile_idx
  on public.business_members (profile_id);

-- ----------------------------------------------------------------------------
-- drivers
-- ----------------------------------------------------------------------------
create index if not exists drivers_country_idx
  on public.drivers (country_id);

create index if not exists drivers_verification_status_idx
  on public.drivers (verification_status);

create index if not exists drivers_available_idx
  on public.drivers (is_available)
  where is_available = true;

create index if not exists drivers_current_location_gist
  on public.drivers using gist (current_location);

create index if not exists drivers_home_city_idx
  on public.drivers (home_city_id);

create index if not exists driver_operating_zones_driver_idx
  on public.driver_operating_zones (driver_id);

create index if not exists driver_operating_zones_service_zone_idx
  on public.driver_operating_zones (service_zone_id);

-- ----------------------------------------------------------------------------
-- referrals / saved addresses
-- ----------------------------------------------------------------------------
create index if not exists user_referrals_referrer_idx
  on public.user_referrals (referrer_profile_id);

create index if not exists user_referrals_referred_idx
  on public.user_referrals (referred_profile_id);

create index if not exists saved_addresses_profile_idx
  on public.saved_addresses (profile_id);

-- ----------------------------------------------------------------------------
-- administration
-- ----------------------------------------------------------------------------
create index if not exists admin_roles_active_idx
  on public.admin_roles (profile_id, is_active)
  where is_active = true;

create index if not exists admin_roles_role_name_idx
  on public.admin_roles (role_name);

create index if not exists admin_actions_log_admin_idx
  on public.admin_actions_log (admin_profile_id, created_at desc);

create index if not exists admin_actions_log_action_idx
  on public.admin_actions_log (action, created_at desc);

-- ----------------------------------------------------------------------------
-- geography
-- ----------------------------------------------------------------------------
create index if not exists regions_country_idx
  on public.regions (country_id);

create index if not exists cities_country_idx
  on public.cities (country_id);

create index if not exists cities_active_idx
  on public.cities (is_active)
  where is_active = true;

create index if not exists cities_boundary_gist
  on public.cities using gist (boundary);

create index if not exists service_zones_city_idx
  on public.service_zones (city_id);

create index if not exists service_zones_zone_type_idx
  on public.service_zones (zone_type);

create index if not exists service_zones_boundary_gist
  on public.service_zones using gist (boundary);

create index if not exists service_zones_centroid_gist
  on public.service_zones using gist (centroid);

create index if not exists neighborhoods_city_idx
  on public.neighborhoods (city_id);

create index if not exists neighborhoods_centroid_gist
  on public.neighborhoods using gist (centroid);

create index if not exists addresses_country_idx
  on public.addresses (country_id);

create index if not exists addresses_city_idx
  on public.addresses (city_id);

create index if not exists addresses_location_gist
  on public.addresses using gist (location);

create index if not exists addresses_created_by_idx
  on public.addresses (created_by);

create index if not exists zone_pricing_overrides_service_zone_idx
  on public.zone_pricing_overrides (service_zone_id);

create index if not exists zone_pricing_overrides_pricing_plan_idx
  on public.zone_pricing_overrides (pricing_plan_id)
  where pricing_plan_id is not null;

-- ----------------------------------------------------------------------------
-- localization / configuration
-- ----------------------------------------------------------------------------
create index if not exists feature_flags_flag_key_idx
  on public.feature_flags (flag_key);

create index if not exists feature_flags_scope_idx
  on public.feature_flags (country_id, city_id);

create index if not exists exchange_rates_pair_idx
  on public.exchange_rates (from_currency_id, to_currency_id, effective_from desc);

-- ----------------------------------------------------------------------------
-- consent
-- ----------------------------------------------------------------------------
create index if not exists consent_records_profile_type_idx
  on public.consent_records (profile_id, consent_type);

create index if not exists consent_records_granted_at_idx
  on public.consent_records (granted_at);

-- ----------------------------------------------------------------------------
-- audit log (partitioned parent; indexes cascade to every partition)
-- ----------------------------------------------------------------------------
create index if not exists audit_log_created_at_idx
  on private.audit_log (created_at desc);

create index if not exists audit_log_actor_idx
  on private.audit_log (actor_id, created_at desc);

create index if not exists audit_log_entity_idx
  on private.audit_log (entity_type, entity_id);

create index if not exists audit_log_action_idx
  on private.audit_log (action, created_at desc);
