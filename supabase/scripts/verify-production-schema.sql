-- Post-Phase-9 release checks for the current courier and configuration schema.
-- Fails with a SQL exception when a security-critical contract is missing.
do $$
declare
  v_quote oid;
begin
  select p.oid into v_quote
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'quote_calculate_and_persist'
    and p.pronargs = 19;

  if v_quote is null then
    raise exception 'the parcel-aware quote function is missing';
  end if;
  if has_function_privilege('authenticated', v_quote, 'EXECUTE')
     or has_function_privilege('anon', v_quote, 'EXECUTE') then
    raise exception 'a client can call the trusted pricing RPC directly';
  end if;
  if not has_function_privilege('service_role', v_quote, 'EXECUTE') then
    raise exception 'the quote Edge Function cannot call the pricing RPC';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'quote_calculate_and_persist') <> 1 then
    raise exception 'an old quote function overload is still exposed';
  end if;

  if to_regclass('public.country_configurations') is null
     or not (select relrowsecurity from pg_class
             where oid = 'public.country_configurations'::regclass) then
    raise exception 'country configurations or their RLS are missing';
  end if;
  if to_regprocedure('public.dispatch_tick(integer)') is null
     or to_regprocedure('public.job_attach_parcel_photos(uuid,text[])') is null then
    raise exception 'courier dispatch or parcel functions are missing';
  end if;
  if to_regprocedure('public.driver_trip_detail(uuid)') is null then
    raise exception 'the driver trip-detail lookup is missing';
  end if;
  if not exists (select 1 from cron.job where jobname = 'safeshift_dispatch_tick') then
    raise exception 'the redispatch scheduler is missing';
  end if;
  raise notice 'PRODUCTION SCHEMA VERIFICATION: PASS';
end;
$$;
