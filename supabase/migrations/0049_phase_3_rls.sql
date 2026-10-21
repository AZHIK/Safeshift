-- ============================================================================
-- SafeShift — Phase 3 / Migration 0049
-- RLS, permission catalogue and privileges for every Phase 3 table.
--
-- Permission rows live in the migration (not only in seed data) so a
-- migration-only production deployment is fully operable.
--
-- Every policy uses the cached form (select auth.uid()) and every write is
-- gated by an admin permission. promo_redemptions is server-write only.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Permissions
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_pricing',            'Create pricing plans and publish plan versions',        'pricing'),
  ('manage_regulated_tariffs',  'Manage regulated tariff frameworks and legal bands',    'compliance'),
  ('view_promotions',           'View all promo codes and redemption records',           'operations')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'manage_pricing', 'manage_regulated_tariffs', 'view_promotions'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('finance_admin',   'manage_pricing'),
  ('finance_admin',   'manage_regulated_tariffs'),
  ('finance_admin',   'view_promotions'),
  ('operations_admin','view_promotions'),
  ('support_agent',   'view_promotions'),
  ('analyst',         'view_promotions')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 2. RLS enablement
-- ----------------------------------------------------------------------------
alter table public.pricing_plans enable row level security;
alter table public.pricing_plan_versions enable row level security;
alter table public.pricing_plan_zones enable row level security;
alter table public.pricing_plan_vehicle_types enable row level security;
alter table public.pricing_plan_base_rates enable row level security;
alter table public.pricing_distance_tiers enable row level security;
alter table public.pricing_weight_tiers enable row level security;
alter table public.pricing_volume_tiers enable row level security;
alter table public.pricing_cargo_surcharges enable row level security;
alter table public.pricing_equipment_surcharges enable row level security;
alter table public.pricing_time_multipliers enable row level security;
alter table public.pricing_zone_multipliers enable row level security;
alter table public.zone_pricing_override_resolution enable row level security;
alter table public.regulated_tariffs enable row level security;
alter table public.regulated_tariff_bands enable row level security;
alter table public.promo_codes enable row level security;
alter table public.promo_redemptions enable row level security;
alter table public.promo_code_eligibility_rules enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Pricing policies
-- ----------------------------------------------------------------------------
create policy pricing_plans_select_authenticated on public.pricing_plans
  for select to authenticated using (true);
create policy pricing_plans_manage on public.pricing_plans
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_plan_versions_select_authenticated on public.pricing_plan_versions
  for select to authenticated using (true);
create policy pricing_plan_versions_manage on public.pricing_plan_versions
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_plan_zones_select_authenticated on public.pricing_plan_zones
  for select to authenticated using (true);
create policy pricing_plan_zones_manage on public.pricing_plan_zones
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_plan_vehicle_types_select_authenticated on public.pricing_plan_vehicle_types
  for select to authenticated using (true);
create policy pricing_plan_vehicle_types_manage on public.pricing_plan_vehicle_types
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_plan_base_rates_select_authenticated on public.pricing_plan_base_rates
  for select to authenticated using (true);
create policy pricing_plan_base_rates_manage on public.pricing_plan_base_rates
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_distance_tiers_select_authenticated on public.pricing_distance_tiers
  for select to authenticated using (true);
create policy pricing_distance_tiers_manage on public.pricing_distance_tiers
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_weight_tiers_select_authenticated on public.pricing_weight_tiers
  for select to authenticated using (true);
create policy pricing_weight_tiers_manage on public.pricing_weight_tiers
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_volume_tiers_select_authenticated on public.pricing_volume_tiers
  for select to authenticated using (true);
create policy pricing_volume_tiers_manage on public.pricing_volume_tiers
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_cargo_surcharges_select_authenticated on public.pricing_cargo_surcharges
  for select to authenticated using (true);
create policy pricing_cargo_surcharges_manage on public.pricing_cargo_surcharges
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_equipment_surcharges_select_authenticated on public.pricing_equipment_surcharges
  for select to authenticated using (true);
create policy pricing_equipment_surcharges_manage on public.pricing_equipment_surcharges
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_time_multipliers_select_authenticated on public.pricing_time_multipliers
  for select to authenticated using (true);
create policy pricing_time_multipliers_manage on public.pricing_time_multipliers
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy pricing_zone_multipliers_select_authenticated on public.pricing_zone_multipliers
  for select to authenticated using (true);
create policy pricing_zone_multipliers_manage on public.pricing_zone_multipliers
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

create policy zone_override_resolution_select_authenticated on public.zone_pricing_override_resolution
  for select to authenticated using (true);
create policy zone_override_resolution_manage on public.zone_pricing_override_resolution
  for all to authenticated
  using ((select public.has_permission('manage_pricing')))
  with check ((select public.has_permission('manage_pricing')));

-- ----------------------------------------------------------------------------
-- 4. Regulated tariffs
-- ----------------------------------------------------------------------------
create policy regulated_tariffs_select_authenticated on public.regulated_tariffs
  for select to authenticated using (true);
create policy regulated_tariffs_manage on public.regulated_tariffs
  for all to authenticated
  using ((select public.has_permission('manage_regulated_tariffs')))
  with check ((select public.has_permission('manage_regulated_tariffs')));

create policy regulated_tariff_bands_select_authenticated on public.regulated_tariff_bands
  for select to authenticated using (true);
create policy regulated_tariff_bands_manage on public.regulated_tariff_bands
  for all to authenticated
  using ((select public.has_permission('manage_regulated_tariffs')))
  with check ((select public.has_permission('manage_regulated_tariffs')));

-- ----------------------------------------------------------------------------
-- 5. Promotions
-- ----------------------------------------------------------------------------
-- Active promos are readable by any authenticated user (customers need to see
-- what they can apply). Promo managers can see and manage all rows, including
-- inactive and expired codes.
create policy promo_codes_select_active on public.promo_codes
  for select to authenticated using (is_active = true);
create policy promo_codes_manage on public.promo_codes
  for all to authenticated
  using ((select public.has_permission('manage_promotions')))
  with check ((select public.has_permission('manage_promotions')));

create policy promo_redemptions_select_own_or_manager on public.promo_redemptions
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('view_promotions'))
  );
-- Redemptions are written by the Phase 4 quote engine (service role only).

create policy promo_eligibility_select_authenticated on public.promo_code_eligibility_rules
  for select to authenticated using (true);
create policy promo_eligibility_manage on public.promo_code_eligibility_rules
  for all to authenticated
  using ((select public.has_permission('manage_promotions')))
  with check ((select public.has_permission('manage_promotions')));

-- ----------------------------------------------------------------------------
-- 6. Privileges
-- ----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

revoke all on
  public.pricing_plans,
  public.pricing_plan_versions,
  public.pricing_plan_zones,
  public.pricing_plan_vehicle_types,
  public.pricing_plan_base_rates,
  public.pricing_distance_tiers,
  public.pricing_weight_tiers,
  public.pricing_volume_tiers,
  public.pricing_cargo_surcharges,
  public.pricing_equipment_surcharges,
  public.pricing_time_multipliers,
  public.pricing_zone_multipliers,
  public.zone_pricing_override_resolution,
  public.regulated_tariffs,
  public.regulated_tariff_bands,
  public.promo_codes,
  public.promo_redemptions,
  public.promo_code_eligibility_rules
from authenticated;

grant select on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Admin-managed tables. RLS still decides which rows and which admin may
-- write; TRUNCATE stays revoked.
grant insert, update, delete on
  public.pricing_plans,
  public.pricing_plan_versions,
  public.pricing_plan_zones,
  public.pricing_plan_vehicle_types,
  public.pricing_plan_base_rates,
  public.pricing_distance_tiers,
  public.pricing_weight_tiers,
  public.pricing_volume_tiers,
  public.pricing_cargo_surcharges,
  public.pricing_equipment_surcharges,
  public.pricing_time_multipliers,
  public.pricing_zone_multipliers,
  public.zone_pricing_override_resolution,
  public.regulated_tariffs,
  public.regulated_tariff_bands,
  public.promo_codes,
  public.promo_code_eligibility_rules
to authenticated;

-- promo_redemptions deliberately receives no client write grant.
