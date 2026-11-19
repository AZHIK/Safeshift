-- Google OAuth users may have an email but no phone. Preserve that contact
-- when completing a profile so profiles_contact_present_check is satisfied.
create or replace function public.ensure_my_profile(
  p_role text default 'customer',
  p_full_name text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.user_role;
  v_phone text;
  v_email text;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_role not in ('customer', 'driver') then
    raise exception 'unsupported self-service role %', p_role using errcode = '22023';
  end if;
  v_role := p_role::public.user_role;

  select nullif(btrim(u.phone), ''), nullif(btrim(u.email), '')
    into v_phone, v_email
    from auth.users u
   where u.id = v_actor;

  update public.profiles
     set full_name = coalesce(nullif(btrim(p_full_name), ''), nullif(btrim(full_name), '')),
         phone = coalesce(phone, v_phone),
         email = coalesce(email, v_email),
         primary_role = case
           when primary_role = 'customer' and v_role = 'driver' then 'driver'::public.user_role
           else primary_role
         end
   where id = v_actor;

  if not found then
    insert into public.profiles (id, primary_role, full_name, phone, email)
    values (v_actor, v_role, nullif(btrim(p_full_name), ''), v_phone, v_email);
  end if;
end;
$$;

comment on function public.ensure_my_profile(text, text) is
  'Creates or completes the caller profile after phone OTP or OAuth. Never grants admin/fleet/business roles.';

revoke all on function public.ensure_my_profile(text, text) from public, anon;
grant execute on function public.ensure_my_profile(text, text) to authenticated, service_role;
