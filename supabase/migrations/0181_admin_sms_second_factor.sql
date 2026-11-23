-- Text-message second factor for console staff.
--
-- Supabase's native phone factor needs the paid "Advanced MFA - Phone"
-- add-on, so SMS codes use the same session-bound mechanism as email
-- (0179): a CSPRNG code stored only as a hash, delivered through Meseji by
-- the admin-otp function, verified against the exact Auth session.

alter table private.admin_email_challenges
  add column if not exists channel text not null default 'email';
alter table private.admin_email_challenges
  drop constraint if exists admin_email_challenges_channel_check;
alter table private.admin_email_challenges
  add constraint admin_email_challenges_channel_check check (channel in ('email', 'sms'));

alter table private.admin_verified_sessions
  drop constraint if exists admin_verified_sessions_method_check;
alter table private.admin_verified_sessions
  add constraint admin_verified_sessions_method_check check (method in ('email', 'sms'));

-- Shared issuing logic; returns the code and where it goes.
create or replace function private.issue_second_factor_challenge(
  p_profile_id uuid,
  p_session_id uuid,
  p_channel text
)
returns table (code text, destination text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_destination text;
  v_id uuid := gen_random_uuid();
  v_bytes bytea := extensions.gen_random_bytes(4);
  v_code text;
begin
  if p_channel not in ('email', 'sms') then
    raise exception 'unknown channel %', p_channel using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.admin_roles r
    where r.profile_id = p_profile_id and r.is_active and r.revoked_at is null
      and (r.expires_at is null or r.expires_at > now())
  ) then
    raise exception 'sign-in codes are only for console staff' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.sessions s where s.id = p_session_id and s.user_id = p_profile_id) then
    raise exception 'sign in again before requesting a code' using errcode = '42501';
  end if;

  if p_channel = 'email' then
    select nullif(btrim(u.email), '') into v_destination from auth.users u where u.id = p_profile_id;
    if v_destination is null then
      raise exception 'this account has no email address' using errcode = '22023';
    end if;
  else
    select coalesce(nullif(btrim(p.phone), ''), nullif(btrim(u.phone), '')) into v_destination
    from public.profiles p left join auth.users u on u.id = p.id
    where p.id = p_profile_id;
    if v_destination is null then
      raise exception 'this account has no phone number' using errcode = '22023';
    end if;
  end if;

  -- One new code per session per minute, whichever channel.
  if exists (
    select 1 from private.admin_email_challenges c
    where c.session_id = p_session_id and c.created_at > now() - interval '60 seconds'
  ) then
    raise exception 'a code was sent less than a minute ago; check your messages or wait' using errcode = '53400';
  end if;

  update private.admin_email_challenges set consumed_at = now()
   where session_id = p_session_id and consumed_at is null;

  v_code := lpad(((((get_byte(v_bytes, 0)::bigint << 24) | (get_byte(v_bytes, 1) << 16)
                    | (get_byte(v_bytes, 2) << 8) | get_byte(v_bytes, 3)) % 1000000))::text, 6, '0');

  insert into private.admin_email_challenges (id, profile_id, session_id, code_hash, expires_at, channel)
  values (v_id, p_profile_id, p_session_id, private.email_code_hash(v_code, v_id), now() + interval '10 minutes', p_channel);

  return query select v_code, v_destination;
end;
$$;

revoke all on function private.issue_second_factor_challenge(uuid, uuid, text) from public, anon, authenticated;

-- Service role only (the admin-otp function).
create or replace function public.admin_issue_second_factor_challenge(
  p_profile_id uuid,
  p_session_id uuid,
  p_channel text
)
returns table (code text, destination text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (coalesce(auth.role(), '') = 'service_role' or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'service role required' using errcode = '42501';
  end if;
  return query select * from private.issue_second_factor_challenge(p_profile_id, p_session_id, p_channel);
end;
$$;

revoke all on function public.admin_issue_second_factor_challenge(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.admin_issue_second_factor_challenge(uuid, uuid, text) to service_role;

-- The email-only entry point from 0179 now delegates.
create or replace function public.admin_issue_email_challenge(p_profile_id uuid, p_session_id uuid)
returns table (code text, email text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (coalesce(auth.role(), '') = 'service_role' or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'service role required' using errcode = '42501';
  end if;
  return query select * from private.issue_second_factor_challenge(p_profile_id, p_session_id, 'email');
end;
$$;

-- Verification works for either channel and records which one was used.
create or replace function public.admin_verify_second_factor(p_code text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_challenge private.admin_email_challenges%rowtype;
  v_code text := regexp_replace(coalesce(p_code, ''), '\D', '', 'g');
begin
  if auth.uid() is null or v_session is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;

  select * into v_challenge
  from private.admin_email_challenges c
  where c.session_id = v_session and c.profile_id = auth.uid() and c.consumed_at is null
  order by c.created_at desc
  limit 1
  for update;

  if not found or v_challenge.expires_at <= now() then
    raise exception 'this code has expired; request a new one' using errcode = '22023';
  end if;
  if v_challenge.attempts >= 5 then
    raise exception 'too many attempts; request a new code' using errcode = '53400';
  end if;

  if private.email_code_hash(v_code, v_challenge.id) <> v_challenge.code_hash then
    update private.admin_email_challenges set attempts = attempts + 1 where id = v_challenge.id;
    return false;
  end if;

  update private.admin_email_challenges set consumed_at = now() where id = v_challenge.id;
  insert into private.admin_verified_sessions (session_id, profile_id, method, expires_at)
  values (v_session, auth.uid(), v_challenge.channel, now() + interval '12 hours')
  on conflict (session_id) do update
    set verified_at = now(), expires_at = excluded.expires_at, method = excluded.method;
  return true;
end;
$$;

revoke all on function public.admin_verify_second_factor(text) from public, anon;
grant execute on function public.admin_verify_second_factor(text) to authenticated;

-- Kept for callers of the 0179 name.
create or replace function public.admin_verify_email_challenge(p_code text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select public.admin_verify_second_factor(p_code);
$$;

-- Status now reports the channel and whether a phone is on file.
create or replace function public.admin_second_factor_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'verified', private.second_factor_verified(),
    'method', case
      when coalesce(auth.jwt() ->> 'aal', '') = 'aal2' then 'authenticator'
      else (
        select s.method from private.admin_verified_sessions s
        where s.session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid
          and s.profile_id = auth.uid() and s.expires_at > now()
      )
    end,
    'email', (select u.email from auth.users u where u.id = auth.uid()),
    'phone', (
      select coalesce(nullif(btrim(p.phone), ''), nullif(btrim(u.phone), ''))
      from public.profiles p left join auth.users u on u.id = p.id
      where p.id = auth.uid()
    )
  );
$$;
