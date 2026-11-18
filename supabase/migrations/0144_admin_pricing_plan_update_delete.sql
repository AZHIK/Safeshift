-- Admin update/delete helpers for pricing plans.
--
-- Update never edits a published version in place: it creates the next draft
-- version from the latest one, applies the new base rates, and publishes it.
-- Delete is only allowed when no quote references any version of the plan.
create or replace function public.admin_update_pricing_plan(
  p_plan_id uuid,
  p_name text,
  p_description text default null,
  p_is_active boolean default true,
  p_base_fare numeric default 0,
  p_per_km_rate numeric default 0,
  p_per_min_rate numeric default 0,
  p_minimum_charge numeric default 0,
  p_vat_rate numeric default 0.18
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_plan public.pricing_plans%rowtype;
  v_source uuid;
  v_new uuid;
  v_next integer;
  v_currency char(3);
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;

  select * into v_plan from public.pricing_plans where id = p_plan_id for update;
  if not found then
    raise exception 'pricing plan % not found', p_plan_id using errcode = 'P0002';
  end if;

  update public.pricing_plans
     set name = p_name,
         description = p_description,
         is_active = p_is_active
   where id = p_plan_id;

  select id, currency_code into v_source, v_currency
  from public.pricing_plan_versions
  where pricing_plan_id = p_plan_id
  order by (published_at is not null) desc, version_number desc
  limit 1;

  if v_source is null then
    raise exception 'pricing plan % has no version to update', p_plan_id using errcode = 'P0002';
  end if;

  select coalesce(max(version_number), 0) + 1 into v_next
  from public.pricing_plan_versions
  where pricing_plan_id = p_plan_id;

  insert into public.pricing_plan_versions (
    pricing_plan_id, version_number, currency_code, effective_from,
    published_at, published_by
  ) values (
    p_plan_id, v_next, v_currency, now(), now(), v_actor
  )
  returning id into v_new;

  insert into public.pricing_plan_base_rates (
    pricing_plan_version_id, currency_code, base_fare, per_km_rate, per_min_rate,
    minimum_charge, vat_rate
  ) values (
    v_new, v_currency, p_base_fare, p_per_km_rate, p_per_min_rate,
    p_minimum_charge, p_vat_rate
  );

  return v_new;
end;
$$;

create or replace function public.admin_delete_pricing_plan(p_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('manage_pricing') or private.is_pricing_service()) then
    raise exception 'manage_pricing permission required' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.quotes q
    join public.pricing_plan_versions v on v.id = q.pricing_plan_version_id
    where v.pricing_plan_id = p_plan_id
  ) then
    raise exception 'pricing plan % has been used in quotes and cannot be deleted', p_plan_id
      using errcode = '23503';
  end if;

  delete from public.pricing_zone_multipliers
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_time_multipliers
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_equipment_surcharges
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_cargo_surcharges
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_volume_tiers
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_weight_tiers
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_distance_tiers
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_plan_zones
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_plan_vehicle_types
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.pricing_plan_base_rates
    where pricing_plan_version_id in (select id from public.pricing_plan_versions where pricing_plan_id = p_plan_id);
  delete from public.zone_pricing_overrides
    where pricing_plan_id in (select id from public.pricing_plans where id = p_plan_id);
  delete from public.pricing_plan_versions where pricing_plan_id = p_plan_id;
  delete from public.pricing_plans where id = p_plan_id;
end;
$$;

revoke all on function public.admin_update_pricing_plan(uuid, text, text, boolean, numeric, numeric, numeric, numeric, numeric) from public;
revoke all on function public.admin_update_pricing_plan(uuid, text, text, boolean, numeric, numeric, numeric, numeric, numeric) from anon;
grant execute on function public.admin_update_pricing_plan(uuid, text, text, boolean, numeric, numeric, numeric, numeric, numeric) to authenticated, service_role;

revoke all on function public.admin_delete_pricing_plan(uuid) from public;
revoke all on function public.admin_delete_pricing_plan(uuid) from anon;
grant execute on function public.admin_delete_pricing_plan(uuid) to authenticated, service_role;
