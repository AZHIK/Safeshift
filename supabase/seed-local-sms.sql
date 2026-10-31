-- Local development only: capture auth SMS OTPs instead of sending them.
--
-- This file is loaded by [db.seed] in supabase/config.toml and is paired with
-- the local-only [auth.hook.send_sms] config. It must never be applied to a
-- hosted project. The hook writes every OTP to public.local_sms_outbox so the
-- developer can read it with `pnpm db:watch-otp` (or a direct SQL query).

-- GoTrue stores phone numbers without the leading +. Align the seeded auth
-- users so local phone sign-in resolves to the existing seeded profiles instead
-- of creating duplicate users.
update auth.users
set phone = regexp_replace(phone, '^\+', '')
where phone like '+%';

create table if not exists public.local_sms_outbox (
  id bigint generated always as identity primary key,
  phone text not null,
  otp text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.local_sms_outbox enable row level security;

-- The hook runs as the function owner (postgres), so the auth role only needs
-- execute permission on the function. Keep the table private from app roles.
revoke all on table public.local_sms_outbox from anon, authenticated;

drop function if exists public.send_sms_hook(jsonb);

create function public.send_sms_hook(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := event->'user'->>'phone';
  v_otp text := event->'sms'->>'otp';
begin
  insert into public.local_sms_outbox (phone, otp, payload)
  values (coalesce(v_phone, ''), coalesce(v_otp, ''), event);

  raise notice 'SafeShift local OTP for %: %', v_phone, v_otp;
  return '{}'::jsonb;
end;
$$;

revoke all on function public.send_sms_hook(jsonb) from public, anon, authenticated;
grant execute on function public.send_sms_hook(jsonb) to supabase_auth_admin;
