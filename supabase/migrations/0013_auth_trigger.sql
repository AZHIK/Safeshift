-- ============================================================================
-- SafeShift — Phase 1 / Migration 0013
-- Auth trigger: create a public.profiles row for every new auth.users row.
--
-- The trigger runs as the table owner (SECURITY DEFINER) so it works before the
-- new user has any RLS identity.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_country_id    uuid;
  v_language_id   uuid;
  v_currency_id   uuid;
  v_country_code  text;
  v_full_name     text;
  v_phone         text;
begin
  -- Country is optional and always resolved from data, never hardcoded.
  v_country_code := upper(nullif(btrim(new.raw_user_meta_data ->> 'country_code'), ''));
  if v_country_code is not null then
    select c.id, c.default_language_id, c.default_currency_id
      into v_country_id, v_language_id, v_currency_id
      from public.countries c
     where btrim(c.iso_code) = v_country_code
     limit 1;
  end if;

  v_full_name := nullif(btrim(new.raw_user_meta_data ->> 'full_name'), '');
  v_phone := coalesce(
    nullif(btrim(new.phone), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'phone'), '')
  );

  insert into public.profiles (
    id,
    primary_role,
    full_name,
    display_name,
    phone,
    email,
    phone_verified,
    email_verified,
    preferred_language_id,
    preferred_currency_id,
    default_country_id
  )
  values (
    new.id,
    -- Role is never taken from client-controlled metadata for privileged
    -- values; elevated roles are granted server-side after creation.
    'customer',
    v_full_name,
    v_full_name,
    v_phone,
    new.email,
    new.phone_confirmed_at is not null,
    new.email_confirmed_at is not null,
    v_language_id,
    v_currency_id,
    v_country_id
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Creates a customer profile when a new auth.users row is inserted. Country/language/currency are resolved from public.countries.';

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon;
revoke all on function public.handle_new_user() from authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
