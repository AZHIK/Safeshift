begin;
do $$
declare version_id uuid; zone uuid; t timestamptz:=now()+interval '20 years'; preview jsonb; core jsonb;
begin
 select id into strict version_id from public.pricing_plan_versions where published_at is not null limit 1;
 select id into strict zone from public.service_zones limit 1;
 insert into public.zone_pricing_overrides(service_zone_id,multiplier,effective_from,effective_to)
 values(zone,1.50,t,t+interval '1 day');
 insert into public.zone_pricing_overrides(service_zone_id,pricing_plan_id,multiplier,effective_from,effective_to)
 values(zone,version_id,1.75,t,t+interval '1 hour');
 preview:=public.quote_preview(version_id,1,1,0,0,null,'{}',zone,t);
 core:=private.quote_calculate_core(version_id,1,1,0,0,null,'{}',zone,0,2,t);
 if (core->>'zone_multiplier')::numeric is distinct from 1.75 or (preview->>'zone_multiplier')::numeric is distinct from 1.75 then raise exception 'Price override failed';end if;
 if private.zone_fare_multiplier(version_id,zone,t+interval '1 hour')<>1.5 then raise exception 'Expired override applied';end if;
end $$;
rollback;
