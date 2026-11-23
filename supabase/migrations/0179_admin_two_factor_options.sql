-- Two-factor options for console staff: authenticator app, text message or
-- email.
--
-- Authenticator (TOTP) and text message (phone factor, delivered through the
-- send_sms hook and Meseji) are native Supabase factors and raise the session
-- to aal2. Supabase has no email factor, so a verified email code is recorded
-- against the exact Auth session (session_id claim) for 12 hours instead.
-- Every permission check that required aal2 now calls
-- private.second_factor_verified(), which accepts either.
--
-- Email codes: 6 digits from a CSPRNG, stored only as a salted SHA-256 hash,
-- valid 10 minutes, 5 attempts, at most one new code per minute. They are
-- issued only to the service role (the admin-email-otp function), so a client
-- can never read a code without receiving the email.

create table if not exists private.admin_email_challenges (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  session_id  uuid not null,
  code_hash   text not null,
  attempts    integer not null default 0,
  expires_at  timestamptz not null,
  consumed_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists idx_admin_email_challenges_session
  on private.admin_email_challenges (session_id, created_at desc);

create table if not exists private.admin_verified_sessions (
  session_id  uuid primary key,
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  method      text not null check (method in ('email')),
  verified_at timestamptz not null default now(),
  expires_at  timestamptz not null
);

revoke all on private.admin_email_challenges, private.admin_verified_sessions from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- The single second-factor gate
-- ----------------------------------------------------------------------------

create or replace function private.second_factor_verified()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or exists (
        select 1
        from private.admin_verified_sessions s
        where s.session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid
          and s.profile_id = auth.uid()
          and s.expires_at > now()
      );
$$;

revoke all on function private.second_factor_verified() from public, anon;
grant execute on function private.second_factor_verified() to authenticated, service_role;

-- Rewrite every live function that compared the aal claim directly.
do $$
declare
  v_fn record;
  v_def text;
  v_new text;
begin
  for v_fn in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prokind = 'f'
      and p.proname <> 'second_factor_verified'
      and p.prosrc ~ '''aal'''
  loop
    v_def := pg_get_functiondef(v_fn.oid);
    v_new := regexp_replace(
      v_def,
      '\(\s*select\s+auth\.jwt\(\)\s*->>\s*''aal''\s*\)\s*=\s*''aal2''',
      'private.second_factor_verified()', 'gi');
    v_new := regexp_replace(
      v_new,
      '\(\s*auth\.jwt\(\)\s*->>\s*''aal''\s*\)\s*=\s*''aal2''',
      'private.second_factor_verified()', 'gi');
    if v_new = v_def then
      raise exception 'unrecognised aal check in %', v_fn.oid::regprocedure;
    end if;
    execute v_new;
  end loop;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prokind = 'f'
      and p.proname <> 'second_factor_verified' and p.prosrc ~ '''aal'''
  ) then
    raise exception 'a function still checks the aal claim directly';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- Email codes
-- ----------------------------------------------------------------------------

create or replace function private.email_code_hash(p_code text, p_challenge uuid)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(p_code || ':' || p_challenge::text, 'sha256'), 'hex');
$$;

revoke all on function private.email_code_hash(text, uuid) from public, anon, authenticated;

-- Service role only: returns the code so the function can email it.
create or replace function public.admin_issue_email_challenge(p_profile_id uuid, p_session_id uuid)
returns table (code text, email text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_id uuid := gen_random_uuid();
  v_bytes bytea := extensions.gen_random_bytes(4);
  v_code text;
begin
  if not (coalesce(auth.role(), '') = 'service_role' or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.admin_roles r
    where r.profile_id = p_profile_id and r.is_active and r.revoked_at is null
      and (r.expires_at is null or r.expires_at > now())
  ) then
    raise exception 'email verification is only for console staff' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.sessions s where s.id = p_session_id and s.user_id = p_profile_id) then
    raise exception 'sign in again before requesting a code' using errcode = '42501';
  end if;

  select nullif(btrim(u.email), '') into v_email from auth.users u where u.id = p_profile_id;
  if v_email is null then
    raise exception 'this account has no email address' using errcode = '22023';
  end if;

  if exists (
    select 1 from private.admin_email_challenges c
    where c.session_id = p_session_id and c.created_at > now() - interval '60 seconds'
  ) then
    raise exception 'a code was sent less than a minute ago; check your inbox or wait' using errcode = '53400';
  end if;

  -- Older codes for this session stop working.
  update private.admin_email_challenges set consumed_at = now()
   where session_id = p_session_id and consumed_at is null;

  v_code := lpad(((((get_byte(v_bytes, 0)::bigint << 24) | (get_byte(v_bytes, 1) << 16)
                    | (get_byte(v_bytes, 2) << 8) | get_byte(v_bytes, 3)) % 1000000))::text, 6, '0');

  insert into private.admin_email_challenges (id, profile_id, session_id, code_hash, expires_at)
  values (v_id, p_profile_id, p_session_id, private.email_code_hash(v_code, v_id), now() + interval '10 minutes');

  return query select v_code, v_email;
end;
$$;

revoke all on function public.admin_issue_email_challenge(uuid, uuid) from public, anon, authenticated;
grant execute on function public.admin_issue_email_challenge(uuid, uuid) to service_role;

-- Called by the signed-in admin with the code from the email.
create or replace function public.admin_verify_email_challenge(p_code text)
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
  values (v_session, auth.uid(), 'email', now() + interval '12 hours')
  on conflict (session_id) do update
    set verified_at = now(), expires_at = excluded.expires_at, method = excluded.method;
  return true;
end;
$$;

revoke all on function public.admin_verify_email_challenge(text) from public, anon;
grant execute on function public.admin_verify_email_challenge(text) to authenticated;

-- What the console needs to route a signed-in admin.
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
      when coalesce(auth.jwt() ->> 'aal', '') = 'aal2' then 'factor'
      when private.second_factor_verified() then 'email'
    end,
    'email', (select u.email from auth.users u where u.id = auth.uid())
  );
$$;

revoke all on function public.admin_second_factor_status() from public, anon;
grant execute on function public.admin_second_factor_status() to authenticated;

-- The email could not be sent: forget the code so the admin can retry at once.
create or replace function public.admin_discard_email_challenge(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (coalesce(auth.role(), '') = 'service_role' or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'service role required' using errcode = '42501';
  end if;
  delete from private.admin_email_challenges
   where session_id = p_session_id and consumed_at is null;
end;
$$;

revoke all on function public.admin_discard_email_challenge(uuid) from public, anon, authenticated;
grant execute on function public.admin_discard_email_challenge(uuid) to service_role;
