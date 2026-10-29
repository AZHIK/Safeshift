-- ============================================================================
-- SafeShift — Phase 8 / Migration 0120
-- Client integration support functions.
--
-- Adds only new objects. Phase 1–7 migrations are untouched.
--
--   ensure_my_profile            idempotent profile bootstrap after OTP
--   customer_jobs                flattened history for the customer app
--   customer_job                 one job with driver/vehicle detail
--   driver_pending_offers        flattened offer inbox for the driver app
--   driver_active_job            assigned job in progress
--   driver_trips                 completed/cancelled driver history
--   driver_earnings_summary      today/week/month + last-7-days rollup
--   driver_documents_list        current driver documents
--   driver_vehicle_info          current vehicle
--   driver_ratings_list          ratings received by the driver
--   job_delivery_codes           hashed delivery OTP (new table)
--   job_issue_delivery_otp       customer issues a 6-digit delivery code
--   job_verify_delivery_otp      driver verifies and marks delivered
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Profile bootstrap
-- ----------------------------------------------------------------------------
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
  v_role  public.user_role;
  v_phone text := nullif(auth.jwt() ->> 'phone', '');
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_role not in ('customer', 'driver') then
    raise exception 'unsupported self-service role %', p_role using errcode = '22023';
  end if;
  v_role := p_role::public.user_role;

  update public.profiles
     set full_name = coalesce(
           nullif(btrim(p_full_name), ''),
           nullif(btrim(full_name), ''),
           nullif(split_part(coalesce(v_phone, ''), '@', 1), '')
         ),
         phone = coalesce(phone, v_phone),
         primary_role = case
           when primary_role = 'customer' and v_role = 'driver' then 'driver'::public.user_role
           else primary_role
         end
   where id = v_actor;

  if not found then
    insert into public.profiles (id, primary_role, full_name, phone)
    values (
      v_actor,
      v_role,
      nullif(btrim(p_full_name), ''),
      v_phone
    );
  end if;
end;
$$;

comment on function public.ensure_my_profile(text, text) is
  'Creates or completes the caller profile after OTP. Never grants admin/fleet/business roles.';

revoke all on function public.ensure_my_profile(text, text) from public;
revoke all on function public.ensure_my_profile(text, text) from anon;
grant execute on function public.ensure_my_profile(text, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Customer read models
-- ----------------------------------------------------------------------------
create or replace function public.customer_jobs(p_limit integer default 50)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  completed_at timestamptz,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  vehicle_type text,
  cargo_type text,
  payment_method public.payment_method
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    j.id,
    j.status,
    qr.pickup_address,
    qr.destination_address,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.completed_at,
    j.driver_id,
    coalesce(dp.full_name, dp.display_name),
    dp.phone,
    d.rating,
    vt.name,
    ct.name,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.customer_id = auth.uid()
  order by j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

comment on function public.customer_jobs(integer) is
  'Flattened customer job history for the mobile app. Caller sees only their own jobs.';

revoke all on function public.customer_jobs(integer) from public;
revoke all on function public.customer_jobs(integer) from anon;
grant execute on function public.customer_jobs(integer) to authenticated, service_role;

create or replace function public.customer_job(p_job_id uuid)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  completed_at timestamptz,
  driver_id uuid,
  driver_name text,
  driver_phone text,
  driver_rating numeric,
  driver_verified boolean,
  driver_lat double precision,
  driver_lng double precision,
  vehicle_type text,
  cargo_type text,
  payment_method public.payment_method
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    j.id,
    j.status,
    qr.pickup_address,
    qr.destination_address,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.completed_at,
    j.driver_id,
    coalesce(dp.full_name, dp.display_name),
    dp.phone,
    d.rating,
    d.verification_status = 'verified',
    case when d.current_location is null then null
         else extensions.ST_Y(d.current_location::extensions.geometry) end,
    case when d.current_location is null then null
         else extensions.ST_X(d.current_location::extensions.geometry) end,
    vt.name,
    ct.name,
    j.payment_method
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.id = p_job_id
    and (
      j.customer_id = auth.uid()
      or j.driver_id = auth.uid()
      or public.has_permission('view_all_jobs')
    );
$$;

comment on function public.customer_job(uuid) is
  'Single flattened job for customer tracking/deep links. Participants and staff only.';

revoke all on function public.customer_job(uuid) from public;
revoke all on function public.customer_job(uuid) from anon;
grant execute on function public.customer_job(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Driver read models
-- ----------------------------------------------------------------------------
create or replace function public.driver_pending_offers()
returns table (
  offer_id uuid,
  job_id uuid,
  expires_at timestamptz,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  cargo_type text,
  customer_name text,
  customer_phone text,
  vehicle_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.id,
    o.job_id,
    o.expires_at,
    o.distance_to_pickup_km,
    o.eta_minutes,
    qr.pickup_address,
    qr.destination_address,
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    ct.name,
    coalesce(cp.full_name, cp.display_name),
    cp.phone,
    vt.name
  from public.job_offers o
  join public.jobs j on j.id = o.job_id
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where o.driver_id = auth.uid()
    and o.response = 'pending'
    and o.expires_at > now()
    and j.status in ('requested', 'quoted', 'matched')
  order by o.offered_at;
$$;

comment on function public.driver_pending_offers() is
  'Flattened pending offer inbox for the authenticated driver.';

revoke all on function public.driver_pending_offers() from public;
revoke all on function public.driver_pending_offers() from anon;
grant execute on function public.driver_pending_offers() to authenticated, service_role;

create or replace function public.driver_active_job()
returns table (
  offer_id uuid,
  job_id uuid,
  status public.job_status,
  expires_at timestamptz,
  distance_to_pickup_km numeric,
  eta_minutes integer,
  pickup_address text,
  destination_address text,
  distance_km numeric,
  estimated_fare numeric,
  currency_code char(3),
  cargo_type text,
  customer_name text,
  customer_phone text,
  vehicle_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    null::uuid,
    j.id,
    j.status,
    null::timestamptz,
    null::numeric,
    null::integer,
    qr.pickup_address,
    qr.destination_address,
    j.distance_km,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    ct.name,
    coalesce(cp.full_name, cp.display_name),
    cp.phone,
    vt.name
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.driver_id = auth.uid()
    and j.status in (
      'accepted', 'heading_to_pickup', 'arrived', 'loading', 'in_transit', 'delivered'
    )
  order by j.accepted_at desc nulls last
  limit 1;
$$;

comment on function public.driver_active_job() is
  'The authenticated driver''s current assigned job, if any.';

revoke all on function public.driver_active_job() from public;
revoke all on function public.driver_active_job() from anon;
grant execute on function public.driver_active_job() to authenticated, service_role;

create or replace function public.driver_trips(p_limit integer default 100)
returns table (
  job_id uuid,
  status public.job_status,
  pickup_address text,
  destination_address text,
  final_amount numeric,
  currency_code char(3),
  distance_km numeric,
  created_at timestamptz,
  completed_at timestamptz,
  customer_name text,
  cargo_type text,
  vehicle_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    j.id,
    j.status,
    qr.pickup_address,
    qr.destination_address,
    coalesce(j.final_amount, q.total),
    coalesce(j.final_currency_code, q.currency_code),
    j.distance_km,
    j.created_at,
    j.completed_at,
    coalesce(cp.full_name, cp.display_name),
    ct.name,
    vt.name
  from public.jobs j
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  join public.profiles cp on cp.id = j.customer_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  left join public.cargo_types ct on ct.id = qr.cargo_type_id
  where j.driver_id = auth.uid()
    and j.status in ('completed', 'cancelled', 'delivered')
  order by j.completed_at desc nulls last, j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
$$;

comment on function public.driver_trips(integer) is
  'Flattened completed/cancelled trips for the authenticated driver.';

revoke all on function public.driver_trips(integer) from public;
revoke all on function public.driver_trips(integer) from anon;
grant execute on function public.driver_trips(integer) to authenticated, service_role;

create or replace function public.driver_earnings_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select
      coalesce(j.final_amount, 0) as amount,
      j.completed_at
    from public.jobs j
    where j.driver_id = auth.uid()
      and j.status = 'completed'
  ), days as (
    select generate_series(
      current_date - 6,
      current_date,
      interval '1 day'
    )::date as day
  ), daily as (
    select
      d.day,
      coalesce(sum(m.amount) filter (
        where (m.completed_at at time zone 'Africa/Dar_es_Salaam')::date = d.day
      ), 0) as amount
    from days d
    left join mine m on true
    group by d.day
  )
  select jsonb_build_object(
    'today_amount', coalesce((
      select sum(amount) from mine
      where (completed_at at time zone 'Africa/Dar_es_Salaam')::date = current_date
    ), 0),
    'today_trips', (
      select count(*) from mine
      where (completed_at at time zone 'Africa/Dar_es_Salaam')::date = current_date
    ),
    'week_amount', coalesce((
      select sum(amount) from mine where completed_at >= date_trunc('week', now())
    ), 0),
    'week_trips', (
      select count(*) from mine where completed_at >= date_trunc('week', now())
    ),
    'month_amount', coalesce((
      select sum(amount) from mine where completed_at >= date_trunc('month', now())
    ), 0),
    'month_trips', (
      select count(*) from mine where completed_at >= date_trunc('month', now())
    ),
    'last_7_days', coalesce((
      select jsonb_agg(jsonb_build_object(
        'day', to_char(d.day, 'Dy'),
        'date', d.day,
        'amount', d.amount
      ) order by d.day)
      from daily d
    ), '[]'::jsonb)
  );
$$;

comment on function public.driver_earnings_summary() is
  'Driver earnings rollup used by the mobile earnings tab.';

revoke all on function public.driver_earnings_summary() from public;
revoke all on function public.driver_earnings_summary() from anon;
grant execute on function public.driver_earnings_summary() to authenticated, service_role;

create or replace function public.driver_documents_list()
returns table (
  document_id uuid,
  document_type_id uuid,
  title text,
  status public.driver_verification_status,
  expires_at date,
  file_path text,
  rejection_reason text,
  uploaded_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    dd.id,
    dd.document_type_id,
    dt.name,
    dd.verification_status,
    dd.expires_at,
    dd.file_path,
    dd.rejection_reason,
    dd.created_at
  from public.driver_documents dd
  join public.document_types dt on dt.id = dd.document_type_id
  where dd.driver_id = auth.uid()
    and dd.is_current
  order by dt.name;
$$;

comment on function public.driver_documents_list() is
  'Current documents for the authenticated driver.';

revoke all on function public.driver_documents_list() from public;
revoke all on function public.driver_documents_list() from anon;
grant execute on function public.driver_documents_list() to authenticated, service_role;

create or replace function public.driver_vehicle_info()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', v.id,
    'registration_number', v.registration_number,
    'vehicle_type', vt.name,
    'make', vm.name,
    'model', vmo.name,
    'year', v.year,
    'color', v.color,
    'capacity_kg', v.capacity_kg,
    'capacity_m3', v.capacity_m3,
    'verification_status', v.verification_status,
    'is_active', v.is_active,
    'photo_urls', v.photo_urls
  )
  from public.drivers d
  join public.vehicles v on v.id = d.current_vehicle_id
  join public.vehicle_types vt on vt.id = v.vehicle_type_id
  left join public.vehicle_makes vm on vm.id = v.make_id
  left join public.vehicle_models vmo on vmo.id = v.model_id
  where d.id = auth.uid();
$$;

comment on function public.driver_vehicle_info() is
  'Current vehicle for the authenticated driver.';

revoke all on function public.driver_vehicle_info() from public;
revoke all on function public.driver_vehicle_info() from anon;
grant execute on function public.driver_vehicle_info() to authenticated, service_role;

create or replace function public.driver_ratings_list(p_limit integer default 50)
returns table (
  rating_id uuid,
  score smallint,
  comment text,
  created_at timestamptz,
  rater_name text,
  job_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.score,
    r.comment,
    r.created_at,
    case when r.is_anonymous then 'Anonymous' else coalesce(p.full_name, p.display_name) end,
    r.job_id
  from public.ratings r
  left join public.profiles p on p.id = r.rater_profile_id
  where r.rated_profile_id = auth.uid()
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

comment on function public.driver_ratings_list(integer) is
  'Ratings received by the authenticated driver.';

revoke all on function public.driver_ratings_list(integer) from public;
revoke all on function public.driver_ratings_list(integer) from anon;
grant execute on function public.driver_ratings_list(integer) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Delivery OTP
-- ----------------------------------------------------------------------------
create table if not exists public.job_delivery_codes (
  job_id      uuid primary key references public.jobs (id) on delete cascade,
  code_hash   text not null,
  issued_by   uuid references public.profiles (id) on delete set null,
  issued_at   timestamptz not null default now(),
  expires_at  timestamptz not null,
  attempts    integer not null default 0,
  verified_at timestamptz,
  constraint job_delivery_codes_expiry_check check (expires_at > issued_at),
  constraint job_delivery_codes_attempts_check check (attempts >= 0)
);

comment on table public.job_delivery_codes is
  'Hashed delivery OTP for a job. Direct client access is blocked; only the SECURITY DEFINER issue/verify functions may read or write it.';

alter table public.job_delivery_codes enable row level security;
revoke all on table public.job_delivery_codes from public;
revoke all on table public.job_delivery_codes from anon, authenticated;

-- Explicit deny-all policy. Table privileges are already revoked, and the
-- SECURITY DEFINER issue/verify functions are the only supported access path.
-- The policy keeps the Phase 1 "every table has a policy" gate meaningful
-- without granting clients any read or write capability.
create policy job_delivery_codes_client_denied
  on public.job_delivery_codes
  as restrictive
  for all
  to authenticated
  using (false)
  with check (false);

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

  if not (private.is_service_context() or v_actor = v_job.customer_id) then
    raise exception 'only the job customer may issue a delivery code'
      using errcode = '42501';
  end if;

  if v_job.status not in ('accepted', 'heading_to_pickup', 'arrived', 'loading', 'in_transit') then
    raise exception 'job % cannot issue a delivery code in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');

  insert into public.job_delivery_codes (
    job_id, code_hash, issued_by, issued_at, expires_at, attempts, verified_at
  ) values (
    p_job_id,
    extensions.crypt(v_code, extensions.gen_salt('bf')),
    v_actor,
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

comment on function public.job_issue_delivery_otp(uuid) is
  'Issues a fresh 6-digit delivery code to the job customer and stores only its bcrypt hash.';

revoke all on function public.job_issue_delivery_otp(uuid) from public;
revoke all on function public.job_issue_delivery_otp(uuid) from anon;
grant execute on function public.job_issue_delivery_otp(uuid) to authenticated, service_role;

create or replace function public.job_verify_delivery_otp(
  p_job_id uuid,
  p_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_code  public.job_delivery_codes%rowtype;
begin
  if p_code is null or p_code !~ '^[0-9]{6}$' then
    return false;
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or v_actor = v_job.driver_id) then
    raise exception 'only the assigned driver may verify the delivery code'
      using errcode = '42501';
  end if;

  select * into v_code
  from public.job_delivery_codes
  where job_id = p_job_id
  for update;

  if not found then
    raise exception 'no delivery code has been issued for this job'
      using errcode = 'P0002';
  end if;
  if v_code.verified_at is not null then
    return true;
  end if;
  if v_code.expires_at <= now() then
    raise exception 'the delivery code has expired' using errcode = '22023';
  end if;
  if v_code.attempts >= 5 then
    raise exception 'too many delivery code attempts' using errcode = '22023';
  end if;

  if extensions.crypt(p_code, v_code.code_hash) = v_code.code_hash then
    update public.job_delivery_codes
       set verified_at = now()
     where job_id = p_job_id;

    if v_job.status = 'in_transit' then
      perform public.job_advance_status(
        p_job_id,
        'delivered'::public.job_status,
        'Delivery OTP verified'
      );
    end if;
    return true;
  end if;

  update public.job_delivery_codes
     set attempts = attempts + 1
   where job_id = p_job_id;
  return false;
end;
$$;

comment on function public.job_verify_delivery_otp(uuid, text) is
  'Verifies the driver-entered delivery code, rate-limits attempts, and moves an in-transit job to delivered.';

revoke all on function public.job_verify_delivery_otp(uuid, text) from public;
revoke all on function public.job_verify_delivery_otp(uuid, text) from anon;
grant execute on function public.job_verify_delivery_otp(uuid, text) to authenticated, service_role;
