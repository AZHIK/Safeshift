-- A dated override replaces the version's usual zone multiplier. The most
-- specific live override wins, then the one with the latest start.
create function private.zone_fare_multiplier(p_version uuid,p_zone uuid,p_at timestamptz)
returns numeric language sql stable set search_path='' as $$
 select coalesce(
 (select o.multiplier from public.zone_pricing_overrides o
  where o.service_zone_id=p_zone and (o.pricing_plan_id=p_version or o.pricing_plan_id is null)
  and o.effective_from<=p_at and (o.effective_to is null or o.effective_to>p_at)
  order by (o.pricing_plan_id is not null) desc,o.effective_from desc,o.id limit 1),
 (select z.multiplier from public.pricing_zone_multipliers z where z.pricing_plan_version_id=p_version and z.service_zone_id=p_zone),1);
$$;
revoke all on function private.zone_fare_multiplier(uuid,uuid,timestamptz) from public,anon,authenticated;
-- Both pricing routines use the identical original lookup. Preserve all other
-- calculations and assert that the expected baseline is present before changing it.
do $$
declare
 f regprocedure;
 definition text;
 old_lookup text := $old$    select zm.multiplier into v_zone_multiplier
    from public.pricing_zone_multipliers zm
    where zm.pricing_plan_version_id = p_pricing_plan_version_id
      and zm.service_zone_id = p_zone_id;

    if not found then
      v_zone_multiplier := 1;
    end if;$old$;
begin
 foreach f in array array[
 'public.quote_preview(uuid,numeric,numeric,numeric,numeric,uuid,uuid[],uuid,timestamptz)'::regprocedure,
 'private.quote_calculate_core(uuid,numeric,numeric,numeric,numeric,uuid,uuid[],uuid,integer,integer,timestamptz)'::regprocedure
 ] loop
  definition:=pg_get_functiondef(f);
  if strpos(definition,old_lookup)=0 then raise exception 'Unexpected pricing implementation: %',f; end if;
  execute replace(definition,old_lookup,'    v_zone_multiplier := private.zone_fare_multiplier(p_pricing_plan_version_id,p_zone_id,p_at_time);');
 end loop;
end $$;
