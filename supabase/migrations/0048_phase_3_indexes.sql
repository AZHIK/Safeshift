-- ============================================================================
-- SafeShift — Phase 3 / Migration 0048
-- Quote-time and back-office indexes.
--
-- Quote resolution reads: active plan for (city, zone, vehicle type) ->
-- active version at time -> base rates + tiers. The indexes below follow that
-- access path. Partial indexes keep drafts and historic rows out of the hot
-- path where appropriate.
-- ============================================================================

-- pricing_plans -----------------------------------------------------------------
create index if not exists idx_pricing_plans_active_scope
  on public.pricing_plans (country_id, city_id, service_zone_id, vehicle_type_id)
  where is_active;
create unique index if not exists idx_pricing_plans_code_key
  on public.pricing_plans (code);
create index if not exists idx_pricing_plans_active_city
  on public.pricing_plans (city_id)
  where is_active;

-- pricing_plan_versions ---------------------------------------------------------
create index if not exists idx_pricing_plan_versions_plan_effective
  on public.pricing_plan_versions (pricing_plan_id, effective_from desc);
create index if not exists idx_pricing_plan_versions_draft
  on public.pricing_plan_versions (pricing_plan_id)
  where published_at is null;
create index if not exists idx_pricing_plan_versions_regulated
  on public.pricing_plan_versions (regulated_tariff_id)
  where regulated_tariff_id is not null;

-- version applicability ---------------------------------------------------------
create index if not exists idx_pricing_plan_zones_zone
  on public.pricing_plan_zones (service_zone_id);
create index if not exists idx_pricing_plan_vehicle_types_type
  on public.pricing_plan_vehicle_types (vehicle_type_id);

-- tiers -------------------------------------------------------------------------
create index if not exists idx_pricing_distance_tiers_version_min
  on public.pricing_distance_tiers (pricing_plan_version_id, min_km);
create index if not exists idx_pricing_weight_tiers_version_min
  on public.pricing_weight_tiers (pricing_plan_version_id, min_kg);
create index if not exists idx_pricing_volume_tiers_version_min
  on public.pricing_volume_tiers (pricing_plan_version_id, min_m3);

-- surcharges --------------------------------------------------------------------
create index if not exists idx_pricing_cargo_surcharges_cargo
  on public.pricing_cargo_surcharges (cargo_type_id);
create index if not exists idx_pricing_equipment_surcharges_equipment
  on public.pricing_equipment_surcharges (equipment_id);
create index if not exists idx_pricing_time_multipliers_version
  on public.pricing_time_multipliers (pricing_plan_version_id);
create index if not exists idx_pricing_zone_multipliers_zone
  on public.pricing_zone_multipliers (service_zone_id);

-- regulated tariffs -------------------------------------------------------------
create index if not exists idx_regulated_tariffs_active_country
  on public.regulated_tariffs (country_id, regulatory_body)
  where is_active;
create index if not exists idx_regulated_tariffs_vehicle_type
  on public.regulated_tariffs (vehicle_type_id);
create index if not exists idx_regulated_tariffs_effective
  on public.regulated_tariffs (effective_from desc);
create index if not exists idx_regulated_tariff_bands_lookup
  on public.regulated_tariff_bands (regulated_tariff_id, band_type, min_value);

-- promotions --------------------------------------------------------------------
create index if not exists idx_promo_codes_active_country
  on public.promo_codes (country_id)
  where is_active;
create index if not exists idx_promo_codes_active_window
  on public.promo_codes (valid_from, valid_to)
  where is_active;
create index if not exists idx_promo_redemptions_code_profile
  on public.promo_redemptions (promo_code_id, profile_id);
create index if not exists idx_promo_redemptions_profile_redeemed
  on public.promo_redemptions (profile_id, redeemed_at desc);
create index if not exists idx_promo_redemptions_redeemed
  on public.promo_redemptions (redeemed_at desc);
create index if not exists idx_promo_code_eligibility_rules_code
  on public.promo_code_eligibility_rules (promo_code_id);

-- override resolution -----------------------------------------------------------
create index if not exists idx_zone_pricing_override_resolution_version
  on public.zone_pricing_override_resolution (pricing_plan_version_id);
