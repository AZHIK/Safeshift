-- Delivery recipient.
--
-- Many moves are sent to someone other than the person booking. The
-- recipient needs the tracking link and the delivery code, not the customer.
--
-- 1. jobs.recipient_name / recipient_phone, set by the customer through
--    job_set_recipient until the goods are delivered.
-- 2. When the trip goes in transit (or the recipient is added while it is),
--    the server issues the delivery code and texts it to the recipient with
--    a tracking link. The code is only ever in plain text at issue time.
-- 3. job_issue_delivery_otp keeps its contract (returns the code to the
--    customer) and also texts the same new code to the recipient, so both
--    always hold the current code. A verified code is never re-issued.
-- 4. job_recipient lets the customer and the assigned driver read the
--    recipient's name and phone.

alter table public.jobs
  add column if not exists recipient_name text,
  add column if not exists recipient_phone text;

alter table public.jobs
  drop constraint if exists jobs_recipient_phone_check;
alter table public.jobs
  add constraint jobs_recipient_phone_check check (
    recipient_phone is null or recipient_phone ~ '^\+?[0-9]{7,15}$'
  );

alter table public.jobs
  drop constraint if exists jobs_recipient_name_check;
alter table public.jobs
  add constraint jobs_recipient_name_check check (
    recipient_name is null or length(btrim(recipient_name)) between 1 and 120
  );

comment on column public.jobs.recipient_phone is
  'Phone of the person receiving the goods when it is not the customer. Receives the tracking link and delivery code by SMS.';

-- ----------------------------------------------------------------------------
-- SMS through the sms-send Edge Function (best effort, like push)
-- ----------------------------------------------------------------------------
create or replace function private.invoke_sms_send(
  p_profile_id uuid,
  p_to text,
  p_body text,
  p_reference_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url    text;
  v_base   text;
  v_secret text;
begin
  if p_profile_id is null
     or p_to is null or btrim(p_to) = ''
     or p_body is null or btrim(p_body) = ''
  then
    return;
  end if;

  select nullif(btrim(cfg.url), '')
    into v_url
  from public.edge_function_config cfg
  where cfg.function_name = 'sms-send'
    and cfg.is_active;

  if v_url is null then
    v_base := nullif(btrim(coalesce(
      public.get_vault_secret('safeshift_project_url'),
      public.get_vault_secret('SUPABASE_URL')
    )), '');
    if v_base is not null then
      v_url := rtrim(v_base, '/') || '/functions/v1/sms-send';
    end if;
  end if;

  v_secret := nullif(btrim(public.get_vault_secret('INTERNAL_FUNCTION_SECRET')), '');
  if v_url is null or v_secret is null then
    return;
  end if;

  -- profile_id attributes the message to the booking customer in the
  -- notification log; `to` is the recipient's number.
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object(
      'profile_id', p_profile_id,
      'to', p_to,
      'body', p_body,
      'reference_type', 'job',
      'reference_id', p_reference_id
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-internal-secret', v_secret
    ),
    timeout_milliseconds := 5000
  );
exception
  when others then
    null;
end;
$$;

revoke all on function private.invoke_sms_send(uuid, text, text, uuid)
  from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Delivery code issuing
-- ----------------------------------------------------------------------------
create or replace function private.issue_delivery_code(
  p_job_id uuid,
  p_issued_by uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if exists (
    select 1 from public.job_delivery_codes
    where job_id = p_job_id and verified_at is not null
  ) then
    raise exception 'the delivery code was already used' using errcode = '23514';
  end if;

  v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');

  insert into public.job_delivery_codes (
    job_id, code_hash, issued_by, issued_at, expires_at, attempts, verified_at
  ) values (
    p_job_id,
    extensions.crypt(v_code, extensions.gen_salt('bf')),
    p_issued_by,
    now(),
    now() + interval '24 hours',
    0,
    null
  )
  on conflict (job_id) do update
    set code_hash = excluded.code_hash,
        issued_by = excluded.issued_by,
        issued_at = excluded.issued_at,
        expires_at = excluded.expires_at,
        attempts = 0,
        verified_at = null;

  return v_code;
end;
$$;

revoke all on function private.issue_delivery_code(uuid, uuid) from public, anon, authenticated;

-- Public tracking link for the recipient, or null when not configured.
create or replace function private.recipient_tracking_url(p_job_id uuid, p_created_by uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base  text := nullif(btrim(public.get_vault_secret('safeshift_tracking_base_url')), '');
  v_token text;
begin
  if v_base is null then
    return null;
  end if;
  v_token := replace(replace(encode(extensions.gen_random_bytes(24), 'base64'), '/', '_'), '+', '-');
  insert into public.trip_share_tokens (job_id, token, created_by, expires_at)
  values (p_job_id, v_token, p_created_by, now() + interval '24 hours');
  return rtrim(v_base, '/') || '/' || v_token;
exception
  when others then
    return null;
end;
$$;

revoke all on function private.recipient_tracking_url(uuid, uuid) from public, anon, authenticated;

-- Texts the recipient a fresh code (and a tracking link on the first send).
create or replace function private.send_code_to_recipient(
  p_job_id uuid,
  p_code text,
  p_with_link boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job      public.jobs%rowtype;
  v_sender   text;
  v_driver   text;
  v_link     text;
  v_body     text;
begin
  select * into v_job from public.jobs where id = p_job_id;
  if v_job.recipient_phone is null then
    return;
  end if;

  select nullif(split_part(coalesce(p.full_name, p.display_name, ''), ' ', 1), '')
    into v_sender from public.profiles p where p.id = v_job.customer_id;
  select nullif(split_part(coalesce(p.full_name, p.display_name, ''), ' ', 1), '')
    into v_driver from public.profiles p where p.id = v_job.driver_id;

  if p_with_link then
    v_link := private.recipient_tracking_url(p_job_id, v_job.customer_id);
  end if;

  v_body := format(
    'SafeShift: %s is delivering goods to you from %s. Your delivery code is %s. '
    || 'Give it to the driver only when you have received the goods.',
    coalesce(v_driver, 'Your driver'),
    coalesce(v_sender, 'a SafeShift customer'),
    p_code
  );
  if v_link is not null then
    v_body := v_body || ' Track: ' || v_link;
  end if;

  perform private.invoke_sms_send(
    v_job.customer_id, v_job.recipient_phone, v_body, p_job_id
  );
end;
$$;

revoke all on function private.send_code_to_recipient(uuid, text, boolean)
  from public, anon, authenticated;

create or replace function public.job_issue_delivery_otp(p_job_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_code  text;
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or (v_actor is not null and v_actor = v_job.customer_id)) then
    raise exception 'only the job customer may issue a delivery code'
      using errcode = '42501';
  end if;

  if v_job.status not in ('accepted', 'heading_to_pickup', 'arrived', 'cargo_verified', 'loading', 'in_transit', 'arrived_destination') then
    raise exception 'job % cannot issue a delivery code in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  v_code := private.issue_delivery_code(p_job_id, v_actor);
  perform private.send_code_to_recipient(p_job_id, v_code, false);
  return v_code;
end;
$$;

-- ----------------------------------------------------------------------------
-- Automatic send when the goods leave the pickup
-- ----------------------------------------------------------------------------
create or replace function private.notify_recipient_in_transit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if new.recipient_phone is null then
    return new;
  end if;

  -- Goods just left the pickup, or the recipient was added mid-trip.
  if (new.status = 'in_transit' and old.status is distinct from 'in_transit')
     or (new.status in ('in_transit', 'arrived_destination')
         and new.recipient_phone is distinct from old.recipient_phone)
  then
    begin
      v_code := private.issue_delivery_code(new.id, new.customer_id);
      perform private.send_code_to_recipient(new.id, v_code, true);
    exception when others then
      -- Never block the status change; the customer can resend the code.
      null;
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_jobs_notify_recipient on public.jobs;
create trigger trg_jobs_notify_recipient
  after update of status, recipient_phone on public.jobs
  for each row execute function private.notify_recipient_in_transit();

-- ----------------------------------------------------------------------------
-- Customer sets the recipient; customer and driver read it
-- ----------------------------------------------------------------------------
create or replace function public.job_set_recipient(
  p_job_id uuid,
  p_name text,
  p_phone text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[\s()-]', '', 'g'), '');
  v_name  text := nullif(btrim(coalesce(p_name, '')), '');
begin
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (v_actor is not null and v_actor = v_job.customer_id) then
    raise exception 'only the job customer may set the recipient' using errcode = '42501';
  end if;

  if v_job.status in ('delivered', 'completed', 'cancelled', 'disputed') then
    raise exception 'the recipient can no longer be changed' using errcode = '23514';
  end if;

  if v_phone is not null and v_phone !~ '^\+?[0-9]{7,15}$' then
    raise exception 'enter a valid recipient phone number' using errcode = '22023';
  end if;

  if (v_phone is null) <> (v_name is null) then
    raise exception 'enter both the recipient name and phone, or neither'
      using errcode = '22023';
  end if;

  update public.jobs
     set recipient_name = left(v_name, 120),
         recipient_phone = v_phone
   where id = p_job_id;
end;
$$;

revoke all on function public.job_set_recipient(uuid, text, text) from public, anon;
grant execute on function public.job_set_recipient(uuid, text, text) to authenticated, service_role;

create or replace function public.job_recipient(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
begin
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('view_all_jobs')
    or v_actor = v_job.customer_id
    or v_actor = v_job.driver_id
  ) then
    raise exception 'not authorised to view job %', p_job_id using errcode = '42501';
  end if;

  return jsonb_build_object(
    'name', v_job.recipient_name,
    'phone', v_job.recipient_phone,
    'code_issued', v_job.recipient_phone is not null and exists (
      select 1 from public.job_delivery_codes c
      where c.job_id = p_job_id and c.verified_at is null and c.expires_at > now()
    )
  );
end;
$$;

revoke all on function public.job_recipient(uuid) from public, anon;
grant execute on function public.job_recipient(uuid) to authenticated, service_role;
