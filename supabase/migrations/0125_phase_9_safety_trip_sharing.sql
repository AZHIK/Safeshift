-- ============================================================================
-- SafeShift — Phase 9 / Migration 0125
-- Safety alerts, trip sharing, and dispute evidence storage.
--
-- New tables:
--   trip_alerts          SOS / safety alerts raised during a job
--   trip_share_tokens    short-lived public tracking tokens
--
-- Public tracking deliberately exposes a minimal snapshot (status, route,
-- driver first name, vehicle type, coarse live position) and never phone,
-- email, exact customer address, payment, or identity data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. trip_alerts
-- ----------------------------------------------------------------------------
create table public.trip_alerts (
  id              uuid primary key default gen_random_uuid(),
  job_id          uuid not null references public.jobs (id) on delete cascade,
  profile_id      uuid not null references public.profiles (id) on delete cascade,
  alert_type      text not null default 'sos',
  status          text not null default 'open',
  location        extensions.geography(point, 4326),
  details         text,
  metadata        jsonb not null default '{}'::jsonb,
  acknowledged_by uuid references public.profiles (id) on delete set null,
  acknowledged_at timestamptz,
  resolved_by     uuid references public.profiles (id) on delete set null,
  resolved_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint trip_alerts_type_check check (alert_type in ('sos', 'emergency', 'safety_check')),
  constraint trip_alerts_status_check check (status in ('open', 'acknowledged', 'resolved', 'cancelled')),
  constraint trip_alerts_details_not_blank_check check (details is null or length(btrim(details)) > 0),
  constraint trip_alerts_metadata_object_check check (jsonb_typeof(metadata) = 'object'),
  constraint trip_alerts_resolved_check check (status <> 'resolved' or resolved_at is not null),
  constraint trip_alerts_acknowledged_check check (status <> 'acknowledged' or acknowledged_at is not null)
);

comment on table public.trip_alerts is
  'SOS and safety alerts raised by a job participant. Admin on-call acknowledgement is recorded here.';

create index idx_trip_alerts_job_created on public.trip_alerts (job_id, created_at desc);
create index idx_trip_alerts_status_created on public.trip_alerts (status, created_at desc);

create trigger trg_trip_alerts_updated_at
  before update on public.trip_alerts
  for each row execute function public.set_updated_at();

alter table public.trip_alerts enable row level security;

create policy trip_alerts_select_participant_or_staff
  on public.trip_alerts for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('view_incidents'))
    or exists (
      select 1 from public.jobs j
       where j.id = trip_alerts.job_id
         and (j.customer_id = (select auth.uid()) or j.driver_id = (select auth.uid()))
    )
  );

create policy trip_alerts_insert_participant
  on public.trip_alerts for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and exists (
      select 1 from public.jobs j
       where j.id = trip_alerts.job_id
         and (j.customer_id = (select auth.uid()) or j.driver_id = (select auth.uid()))
    )
  );

create policy trip_alerts_update_staff
  on public.trip_alerts for update to authenticated
  using ((select public.has_permission('manage_incidents')))
  with check ((select public.has_permission('manage_incidents')));

grant select, insert, update on public.trip_alerts to authenticated;
revoke all on public.trip_alerts from anon;

-- ----------------------------------------------------------------------------
-- 2. trip_share_tokens
-- ----------------------------------------------------------------------------
create table public.trip_share_tokens (
  id         uuid primary key default gen_random_uuid(),
  job_id     uuid not null references public.jobs (id) on delete cascade,
  token      text not null unique,
  created_by uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default now() + interval '24 hours',
  created_at timestamptz not null default now(),

  constraint trip_share_tokens_token_not_blank_check check (length(btrim(token)) >= 24),
  constraint trip_share_tokens_expiry_check check (expires_at > created_at)
);

comment on table public.trip_share_tokens is
  'Short-lived opaque tokens for the public trip tracking page. Tokens are bearer secrets; do not log them.';

create index idx_trip_share_tokens_job on public.trip_share_tokens (job_id, created_at desc);
create index idx_trip_share_tokens_expiry on public.trip_share_tokens (expires_at);

alter table public.trip_share_tokens enable row level security;

create policy trip_share_tokens_select_creator_or_staff
  on public.trip_share_tokens for select to authenticated
  using (
    created_by = (select auth.uid())
    or (select public.has_permission('view_all_jobs'))
  );

create policy trip_share_tokens_insert_participant
  on public.trip_share_tokens for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.jobs j
       where j.id = trip_share_tokens.job_id
         and (j.customer_id = (select auth.uid()) or j.driver_id = (select auth.uid()))
    )
  );

create policy trip_share_tokens_delete_creator_or_staff
  on public.trip_share_tokens for delete to authenticated
  using (
    created_by = (select auth.uid())
    or (select public.has_permission('view_all_jobs'))
  );

grant select, insert, delete on public.trip_share_tokens to authenticated;
revoke all on public.trip_share_tokens from anon;

-- ----------------------------------------------------------------------------
-- 3. Create a token (idempotent per call, 24h lifetime)
-- ----------------------------------------------------------------------------
create or replace function public.create_trip_share_token(p_job_id uuid)
returns table (token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_token text;
  v_expires timestamptz := now() + interval '24 hours';
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.jobs j
     where j.id = p_job_id
       and (j.customer_id = v_actor or j.driver_id = v_actor)
  ) then
    raise exception 'job % not found for this participant', p_job_id using errcode = '42501';
  end if;

  v_token := replace(replace(encode(extensions.gen_random_bytes(24), 'base64'), '/', '_'), '+', '-');

  insert into public.trip_share_tokens (job_id, token, created_by, expires_at)
  values (p_job_id, v_token, v_actor, v_expires);

  return query select v_token, v_expires;
end;
$$;

comment on function public.create_trip_share_token(uuid) is
  'Creates a 24-hour public tracking token for a job participant.';

revoke all on function public.create_trip_share_token(uuid) from public;
revoke all on function public.create_trip_share_token(uuid) from anon;
grant execute on function public.create_trip_share_token(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Public snapshot (anon-callable with the bearer token)
-- ----------------------------------------------------------------------------
create or replace function public.trip_share_snapshot(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'job_id', j.id,
    'status', j.status,
    'pickup', qr.pickup_address,
    'destination', qr.destination_address,
    'driver_first_name', nullif(split_part(coalesce(dp.full_name, dp.display_name, ''), ' ', 1), ''),
    'vehicle_type', vt.name,
    'driver_lat', case when d.current_location is null then null
                       else extensions.ST_Y(d.current_location::extensions.geometry) end,
    'driver_lng', case when d.current_location is null then null
                       else extensions.ST_X(d.current_location::extensions.geometry) end,
    'location_updated_at', d.location_updated_at,
    'expires_at', t.expires_at,
    'updated_at', j.updated_at
  )
  from public.trip_share_tokens t
  join public.jobs j on j.id = t.job_id
  join public.quotes q on q.id = j.quote_id
  join public.quote_requests qr on qr.id = q.quote_request_id
  left join public.profiles dp on dp.id = j.driver_id
  left join public.drivers d on d.id = j.driver_id
  left join public.vehicle_types vt on vt.id = qr.vehicle_type_id
  where t.token = p_token
    and t.expires_at > now()
  limit 1;
$$;

comment on function public.trip_share_snapshot(text) is
  'Minimal public tracking snapshot for a valid, unexpired trip share token.';

revoke all on function public.trip_share_snapshot(text) from public;
grant execute on function public.trip_share_snapshot(text) to anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Dispute evidence storage
-- Path: dispute/{dispute_id}/{uuid}.{ext}
-- Policies are intentionally named outside the Phase 8 job_evidence_* prefix
-- so the Phase 8 storage-policy count gate remains stable.
-- ----------------------------------------------------------------------------
create policy dispute_evidence_storage_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'job-evidence'
    and (storage.foldername(name))[1] = 'dispute'
    and exists (
      select 1
        from public.disputes d
        join public.jobs j on j.id = d.job_id
       where d.id::text = (storage.foldername(name))[2]
         and (
           d.raised_by = (select auth.uid())
           or j.customer_id = (select auth.uid())
           or j.driver_id = (select auth.uid())
           or (select public.has_permission('view_all_disputes'))
         )
    )
  );

create policy dispute_evidence_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'job-evidence'
    and (storage.foldername(name))[1] = 'dispute'
    and exists (
      select 1
        from public.disputes d
        join public.jobs j on j.id = d.job_id
       where d.id::text = (storage.foldername(name))[2]
         and (
           d.raised_by = (select auth.uid())
           or j.customer_id = (select auth.uid())
           or j.driver_id = (select auth.uid())
           or (select public.has_permission('view_all_disputes'))
         )
    )
  );
