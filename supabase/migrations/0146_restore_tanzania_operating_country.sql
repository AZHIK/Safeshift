-- The configuration seed accidentally left every country inactive. The
-- driver registration form only offers countries that are operating.
update public.countries
   set is_active = true,
       launched_at = coalesce(launched_at, now())
 where iso_code = 'TZ'
   and is_active = false;
