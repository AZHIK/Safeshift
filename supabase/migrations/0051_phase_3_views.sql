-- ============================================================================
-- SafeShift — Phase 3 / Migration 0051
-- Security-invoker reporting views.
--
-- security_invoker = true means each view runs with the caller's own
-- privileges and RLS. No view elevates access.
-- ============================================================================

create or replace view public.pricing_plan_summary
with (security_invoker = true, security_barrier = true) as
select
  p.id                       as plan_id,
  p.code                     as plan_code,
  p.name                     as plan_name,
  c.name                     as city_name,
  z.name                     as zone_name,
  vt.name                    as vehicle_type_name,
  v.version_number           as current_version_number,
  v.effective_from           as current_effective_from,
  br.base_fare,
  br.per_km_rate,
  br.per_min_rate,
  br.minimum_charge,
  (v.regulated_tariff_id is not null) as is_regulated,
  br.currency_code
from public.pricing_plans p
join public.cities c on c.id = p.city_id
left join public.service_zones z on z.id = p.service_zone_id
join public.vehicle_types vt on vt.id = p.vehicle_type_id
join lateral (
  select pv.*
  from public.pricing_plan_versions pv
  where pv.pricing_plan_id = p.id
    and pv.published_at is not null
    and pv.effective_from <= now()
    and (pv.effective_to is null or pv.effective_to > now())
  order by pv.version_number desc
  limit 1
) v on true
join public.pricing_plan_base_rates br on br.pricing_plan_version_id = v.id
where p.is_active;

comment on view public.pricing_plan_summary is
  'One row per active plan with its currently effective published version and core rates.';

create or replace view public.promo_code_active
with (security_invoker = true, security_barrier = true) as
select
  pc.id,
  pc.code,
  pc.name,
  pc.description,
  pc.discount_type,
  pc.discount_value,
  pc.max_discount_amount,
  pc.min_purchase_amount,
  pc.currency_code,
  pc.valid_from,
  pc.valid_to,
  pc.total_redemption_limit,
  pc.per_user_redemption_limit,
  pc.new_users_only,
  (select count(*) from public.promo_redemptions r where r.promo_code_id = pc.id) as redemption_count,
  case
    when pc.total_redemption_limit is null then null
    else greatest(
      pc.total_redemption_limit
        - (select count(*) from public.promo_redemptions r where r.promo_code_id = pc.id),
      0
    )
  end as remaining_capacity
from public.promo_codes pc
where pc.is_active
  and now() >= pc.valid_from
  and now() < pc.valid_to;

comment on view public.promo_code_active is
  'Currently valid promo codes with redemption counts. security_invoker: non-managers only count redemptions visible to them.';

create or replace view public.regulated_tariff_bands_summary
with (security_invoker = true, security_barrier = true) as
select
  rt.id             as tariff_id,
  rt.name           as tariff_name,
  rt.regulatory_body,
  b.band_type,
  b.min_value,
  b.max_value,
  b.value_unit,
  b.min_fare,
  b.max_fare
from public.regulated_tariffs rt
join public.regulated_tariff_bands b on b.regulated_tariff_id = rt.id
where rt.is_active;

comment on view public.regulated_tariff_bands_summary is
  'Readable projection of active regulated tariffs and their legal bands.';

revoke all on public.pricing_plan_summary, public.promo_code_active, public.regulated_tariff_bands_summary from public, anon;
grant select on public.pricing_plan_summary, public.promo_code_active, public.regulated_tariff_bands_summary to authenticated, service_role;
