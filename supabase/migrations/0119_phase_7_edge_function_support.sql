-- ============================================================================
-- 0119 — Phase 7: Edge Function support
-- ============================================================================
-- Adds idempotency, provider caches, dead-letter storage, Vault access, the
-- payment initiation/completion RPCs, storage bucket policies, and the
-- idempotency cleanup schedule.
--
-- Phase 5's job_pay() captures a charge in one call. Phase 7 splits the flow:
--   job_payment_initiate() creates a pending payment before the provider call.
--   job_pay_complete() finalizes it from a verified webhook.
-- The Phase 5 function remains untouched and its verification gate still runs.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Idempotency keys
-- ----------------------------------------------------------------------------
create table public.idempotency_keys (
  id           uuid primary key default gen_random_uuid(),
  key          text not null,
  scope        text not null,
  request_hash text,
  response     jsonb,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default now() + interval '24 hours',

  constraint idempotency_keys_key_scope_key unique (key, scope),
  constraint idempotency_keys_key_not_blank_check check (length(btrim(key)) > 0),
  constraint idempotency_keys_scope_not_blank_check check (length(btrim(scope)) > 0)
);

comment on table public.idempotency_keys is
  'Phase 7 idempotency cache. The database UNIQUE(key, scope) is the source of truth; functions also check-then-act.';

create index idx_idempotency_keys_expires_at
  on public.idempotency_keys (expires_at);

alter table public.idempotency_keys enable row level security;
revoke all on table public.idempotency_keys from public;
revoke all on table public.idempotency_keys from anon;
revoke all on table public.idempotency_keys from authenticated;
grant all on table public.idempotency_keys to service_role;
create policy idempotency_keys_service_role
  on public.idempotency_keys for all to service_role
  using (true) with check (true);

-- ----------------------------------------------------------------------------
-- 2. Google Maps caches
-- ----------------------------------------------------------------------------
create table public.geocoding_cache (
  id          uuid primary key default gen_random_uuid(),
  query_type  text not null,
  query_text  text,
  query_lat   numeric(10,7),
  query_lng   numeric(10,7),
  result      jsonb not null,
  cached_at   timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '30 days',

  constraint geocoding_cache_query_type_check
    check (query_type in ('forward', 'reverse')),
  constraint geocoding_cache_query_shape_check
    check (
      (query_type = 'forward' and query_text is not null and length(btrim(query_text)) > 0)
      or (
        query_type = 'reverse'
        and query_lat is not null
        and query_lng is not null
      )
    ),
  constraint geocoding_cache_result_object_check check (jsonb_typeof(result) = 'object')
);

comment on table public.geocoding_cache is
  'Google Geocoding results cached for 30 days. Edge Functions write through the service role.';

-- These indexes are intentionally not partial: PostgREST upserts use
-- ON CONFLICT (query_text) / (query_lat, query_lng) without an index predicate.
-- Reverse rows leave query_text NULL and forward rows leave the coordinates
-- NULL, so PostgreSQL still permits multiple rows on the unused side.
create unique index uq_geocoding_cache_forward
  on public.geocoding_cache (query_text);

create unique index uq_geocoding_cache_reverse
  on public.geocoding_cache (query_lat, query_lng);

create index idx_geocoding_cache_expires_at on public.geocoding_cache (expires_at);

alter table public.geocoding_cache enable row level security;
revoke all on table public.geocoding_cache from public;
revoke all on table public.geocoding_cache from anon;
revoke all on table public.geocoding_cache from authenticated;
grant all on table public.geocoding_cache to service_role;
create policy geocoding_cache_service_role
  on public.geocoding_cache for all to service_role
  using (true) with check (true);

create table public.distance_cache (
  id          uuid primary key default gen_random_uuid(),
  origin_lat  numeric(10,7) not null,
  origin_lng  numeric(10,7) not null,
  dest_lat    numeric(10,7) not null,
  dest_lng    numeric(10,7) not null,
  mode        text not null default 'driving',
  distance_km numeric(8,2) not null,
  duration_min numeric(8,2) not null,
  cached_at   timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',

  constraint distance_cache_mode_check
    check (mode in ('driving', 'walking', 'bicycling', 'transit')),
  constraint distance_cache_distance_check check (distance_km >= 0),
  constraint distance_cache_duration_check check (duration_min >= 0),
  constraint distance_cache_route_key
    unique (origin_lat, origin_lng, dest_lat, dest_lng, mode)
);

comment on table public.distance_cache is
  'Google Distance Matrix results cached for 7 days. Exact route+mode matching only.';

create index idx_distance_cache_expires_at on public.distance_cache (expires_at);

alter table public.distance_cache enable row level security;
revoke all on table public.distance_cache from public;
revoke all on table public.distance_cache from anon;
revoke all on table public.distance_cache from authenticated;
grant all on table public.distance_cache to service_role;
create policy distance_cache_service_role
  on public.distance_cache for all to service_role
  using (true) with check (true);

-- ----------------------------------------------------------------------------
-- 2b. Webhook event dedupe
-- ----------------------------------------------------------------------------
-- payment_webhooks is partitioned by received_at, so PostgreSQL cannot enforce
-- a unique index on (provider_id, event_id) alone there. This companion table
-- provides the durable database-level dedupe key. The insert and the append to
-- payment_webhooks happen in one function transaction.
create table public.payment_webhook_events (
  provider_id       uuid not null references public.payment_providers (id) on delete restrict,
  event_id          text not null,
  first_received_at timestamptz not null default now(),

  constraint payment_webhook_events_event_id_check
    check (length(btrim(event_id)) > 0),
  primary key (provider_id, event_id)
);

comment on table public.payment_webhook_events is
  'Durable webhook dedupe key. One row per (provider, provider event id).';

create index idx_payment_webhook_events_received_at
  on public.payment_webhook_events (first_received_at);

alter table public.payment_webhook_events enable row level security;
revoke all on table public.payment_webhook_events from public;
revoke all on table public.payment_webhook_events from anon;
revoke all on table public.payment_webhook_events from authenticated;
grant all on table public.payment_webhook_events to service_role;
create policy payment_webhook_events_service_role
  on public.payment_webhook_events for all to service_role
  using (true) with check (true);

create or replace function public.record_payment_webhook(
  p_provider_id uuid,
  p_event_type text,
  p_event_id text,
  p_provider_reference text,
  p_payload jsonb,
  p_signature_header text
)
returns table (webhook_id bigint, duplicate boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted integer;
  v_webhook_id bigint;
begin
  if not private.is_service_context() then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if p_event_id is null or length(btrim(p_event_id)) = 0 then
    raise exception 'event_id is required' using errcode = '22023';
  end if;
  if p_event_type is null or length(btrim(p_event_type)) = 0 then
    raise exception 'event_type is required' using errcode = '22023';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'payload must be a JSON object' using errcode = '22023';
  end if;

  insert into public.payment_webhook_events (provider_id, event_id)
  values (p_provider_id, btrim(p_event_id))
  on conflict (provider_id, event_id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    webhook_id := null;
    duplicate := true;
    return next;
    return;
  end if;

  insert into public.payment_webhooks (
    provider_id,
    event_type,
    event_id,
    provider_reference,
    payload,
    signature_header,
    signature_valid,
    processing_status
  ) values (
    p_provider_id,
    p_event_type,
    btrim(p_event_id),
    p_provider_reference,
    p_payload,
    p_signature_header,
    true,
    'pending'
  )
  returning id into v_webhook_id;

  webhook_id := v_webhook_id;
  duplicate := false;
  return next;
end;
$$;

comment on function public.record_payment_webhook(uuid, text, text, text, jsonb, text) is
  'Atomically dedupes and appends a verified provider webhook. Service role only.';

revoke all on function public.record_payment_webhook(uuid, text, text, text, jsonb, text)
  from public;
revoke all on function public.record_payment_webhook(uuid, text, text, text, jsonb, text)
  from anon;
revoke all on function public.record_payment_webhook(uuid, text, text, text, jsonb, text)
  from authenticated;
grant execute on function public.record_payment_webhook(uuid, text, text, text, jsonb, text)
  to service_role;

-- ----------------------------------------------------------------------------
-- 3. Dead letter queue
-- ----------------------------------------------------------------------------
create table public.dead_letter_queue (
  id               bigint generated always as identity primary key,
  function_name    text not null,
  payload          jsonb not null,
  error_message    text not null,
  error_stack      text,
  attempt_count    integer not null default 1,
  last_attempt_at  timestamptz not null default now(),
  resolved         boolean not null default false,
  resolved_at      timestamptz,
  resolution_notes text,
  created_at       timestamptz not null default now(),

  constraint dead_letter_queue_function_not_blank_check
    check (length(btrim(function_name)) > 0),
  constraint dead_letter_queue_payload_object_check
    check (jsonb_typeof(payload) = 'object'),
  constraint dead_letter_queue_attempt_check check (attempt_count > 0)
);

comment on table public.dead_letter_queue is
  'Final destination for provider calls that exhaust all Phase 7 retries.';

create index idx_dead_letter_queue_function_created
  on public.dead_letter_queue (function_name, created_at desc);

create index idx_dead_letter_queue_unresolved
  on public.dead_letter_queue (created_at desc)
  where resolved = false;

alter table public.dead_letter_queue enable row level security;
revoke all on table public.dead_letter_queue from public;
revoke all on table public.dead_letter_queue from anon;
revoke all on table public.dead_letter_queue from authenticated;
grant all on table public.dead_letter_queue to service_role;
create policy dead_letter_queue_service_role
  on public.dead_letter_queue for all to service_role
  using (true) with check (true);

-- ----------------------------------------------------------------------------
-- 4. Edge Function configuration
-- ----------------------------------------------------------------------------
create table public.edge_function_config (
  function_name text primary key,
  url           text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint edge_function_config_name_not_blank_check
    check (length(btrim(function_name)) > 0)
);

comment on table public.edge_function_config is
  'Scheduled Edge Function URLs. A NULL url means the HTTP cron switch is not enabled yet.';

alter table public.edge_function_config enable row level security;
revoke all on table public.edge_function_config from public;
revoke all on table public.edge_function_config from anon;
revoke all on table public.edge_function_config from authenticated;
grant all on table public.edge_function_config to service_role;
create policy edge_function_config_service_role
  on public.edge_function_config for all to service_role
  using (true) with check (true);

insert into public.edge_function_config (function_name, url) values
  ('scheduled-daily-metrics', null),
  ('scheduled-demand-capture', null),
  ('scheduled-retention', null)
on conflict (function_name) do nothing;

-- ----------------------------------------------------------------------------
-- 5. Vault reader and health probe
-- ----------------------------------------------------------------------------
create or replace function public.get_vault_secret(p_name text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret
    from vault.decrypted_secrets
   where name = p_name
   order by created_at desc
   limit 1;
$$;

comment on function public.get_vault_secret(text) is
  'Service-role-only Vault reader used by Phase 7 Edge Functions.';

revoke all on function public.get_vault_secret(text) from public;
revoke all on function public.get_vault_secret(text) from anon;
revoke all on function public.get_vault_secret(text) from authenticated;
grant execute on function public.get_vault_secret(text) to service_role;

create or replace function public.current_permissions()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct arp.permission_key order by arp.permission_key), '{}'::text[])
    from public.admin_roles ar
    join public.admin_role_permissions arp on arp.role_name = ar.role_name
   where ar.profile_id = auth.uid()
     and ar.is_active
     and ar.revoked_at is null
     and (ar.expires_at is null or ar.expires_at > now())
     and (
       ar.country_id is null
       or ar.country_id = (select p.default_country_id from public.profiles p where p.id = auth.uid())
     );
$$;

comment on function public.current_permissions() is
  'Returns the caller''s active admin permission keys for startup hydration.';

revoke all on function public.current_permissions() from public;
revoke all on function public.current_permissions() from anon;
grant execute on function public.current_permissions() to authenticated, service_role;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'safeshift_healthcheck') then
    perform vault.create_secret(
      'ok',
      'safeshift_healthcheck',
      'Non-sensitive Phase 7 health probe'
    );
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 6. Payment initiation and webhook completion
-- ----------------------------------------------------------------------------
create or replace function public.job_payment_initiate(
  p_job_id uuid,
  p_provider_code text,
  p_amount numeric default null,
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_payment_method_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job      public.jobs%rowtype;
  v_quote    public.quotes%rowtype;
  v_provider public.payment_providers%rowtype;
  v_method   public.payment_methods%rowtype;
  v_existing uuid;
  v_payment  uuid;
  v_reference text;
begin
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if not (private.is_service_context() or auth.uid() = v_job.customer_id) then
    raise exception 'only the job customer may initiate payment for job %', p_job_id
      using errcode = '42501';
  end if;

  if v_job.status not in ('delivered', 'completed') then
    raise exception 'job % is not payable in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  if v_job.payment_status <> 'pending' then
    raise exception 'job % is already %', p_job_id, v_job.payment_status
      using errcode = '23514';
  end if;

  select * into v_quote from public.quotes where id = v_job.quote_id;
  if not found then
    raise exception 'quote for job % not found', p_job_id using errcode = 'P0002';
  end if;

  if p_amount is not null and p_amount <> v_quote.total then
    raise exception 'payment amount % does not match quote total %', p_amount, v_quote.total
      using errcode = '23514';
  end if;

  select * into v_provider
    from public.payment_providers pp
   where pp.code = p_provider_code
     and pp.is_active
     and pp.country_id = (select c.country_id from public.cities c where c.id = v_job.city_id);

  if not found then
    raise exception 'payment provider % not found or inactive for this job country', p_provider_code
      using errcode = 'P0002';
  end if;

  if p_payment_method_id is not null then
    select * into v_method
      from public.payment_methods pm
     where pm.id = p_payment_method_id
       and pm.profile_id = v_job.customer_id
       and pm.provider_id = v_provider.id
       and pm.is_active;

    if not found then
      raise exception 'payment method % is not active or does not belong to the customer',
        p_payment_method_id
        using errcode = '42501';
    end if;
  end if;

  select p.id into v_existing
    from public.payments p
   where p.job_id = p_job_id
     and p.payment_type = 'charge'
     and p.metadata ->> 'idempotency_key' = p_idempotency_key
   order by p.created_at desc
   limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  v_reference := 'init:' || replace(gen_random_uuid()::text, '-', '');

  insert into public.payments (
    job_id, customer_id, provider_id, payment_method_id, amount, currency_code,
    provider_reference, provider_status, payment_type, metadata
  ) values (
    p_job_id, v_job.customer_id, v_provider.id, p_payment_method_id,
    v_quote.total, v_quote.currency_code,
    v_reference, 'pending', 'charge',
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'idempotency_key', p_idempotency_key,
      'provider_code', p_provider_code,
      'initiated_by', 'edge_function'
    )
  )
  returning id into v_payment;

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id, 'note', v_job.customer_id,
    jsonb_build_object(
      'payment_id', v_payment,
      'provider_code', p_provider_code,
      'stage', 'payment_initiated'
    )
  );

  return v_payment;
end;
$$;

comment on function public.job_payment_initiate(uuid, text, numeric, text, jsonb, uuid) is
  'Creates a pending charge before the provider call. Idempotent by (job_id, idempotency_key).';

revoke all on function public.job_payment_initiate(uuid, text, numeric, text, jsonb, uuid)
  from public;
revoke all on function public.job_payment_initiate(uuid, text, numeric, text, jsonb, uuid)
  from anon;
grant execute on function public.job_payment_initiate(uuid, text, numeric, text, jsonb, uuid)
  to authenticated, service_role;

-- Payments may move provider_reference while pending. This is required because
-- the provider reference is only known after the provider accepts the request.
-- Once the payment is terminal, every field remains immutable.
create or replace function private.enforce_payments_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_new_core jsonb;
  v_old_core jsonb;
begin
  if tg_op = 'DELETE' then
    raise exception 'payments are append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array[
    'provider_status', 'provider_reference', 'completed_at',
    'failure_reason', 'failure_code', 'updated_at'
  ];
  v_old_core := to_jsonb(old) - array[
    'provider_status', 'provider_reference', 'completed_at',
    'failure_reason', 'failure_code', 'updated_at'
  ];

  if v_new_core is distinct from v_old_core then
    raise exception 'payment identity and financial terms are immutable'
      using errcode = '42501';
  end if;

  if old.provider_status <> 'pending' then
    if new.provider_reference is distinct from old.provider_reference then
      raise exception 'provider_reference is immutable after a payment is terminal'
        using errcode = '42501';
    end if;
    raise exception 'payment status can only move once from pending to a terminal state'
      using errcode = '23514';
  end if;

  if new.provider_status = 'pending' then
    -- The provider reference may be attached after the initiate call. The core
    -- identity/financial fields were already checked above.
    return new;
  end if;

  if new.provider_status not in ('succeeded', 'failed', 'cancelled') then
    raise exception 'payment status can only move once from pending to a terminal state'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_payments_immutability() from public;
revoke all on function private.enforce_payments_immutability() from anon;
revoke all on function private.enforce_payments_immutability() from authenticated;

create or replace function public.job_pay_complete(
  p_payment_id uuid,
  p_provider_reference text,
  p_provider_status text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments%rowtype;
  v_job     public.jobs%rowtype;
  v_quote   public.quotes%rowtype;
  v_ledger  public.commission_ledger%rowtype;
  v_tax     numeric(14,2);
begin
  if p_provider_status not in ('succeeded', 'failed', 'cancelled') then
    raise exception 'unsupported terminal provider status: %', p_provider_status
      using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or public.has_permission('manage_payments')
  ) then
    raise exception 'manage_payments permission required' using errcode = '42501';
  end if;

  select * into v_payment from public.payments where id = p_payment_id for update;
  if not found then
    raise exception 'payment % not found', p_payment_id using errcode = 'P0002';
  end if;

  if v_payment.provider_status <> 'pending' then
    if v_payment.provider_status = p_provider_status then
      return p_payment_id;
    end if;
    raise exception 'payment % is already terminal with status %',
      p_payment_id, v_payment.provider_status using errcode = '23514';
  end if;

  update public.payments
     set provider_reference = coalesce(nullif(btrim(p_provider_reference), ''), provider_reference),
         provider_status = p_provider_status,
         completed_at = now(),
         failure_reason = case when p_provider_status = 'failed' then 'provider reported failure' else null end
   where id = p_payment_id;

  if p_provider_status <> 'succeeded' then
    return p_payment_id;
  end if;

  select * into v_job from public.jobs where id = v_payment.job_id for update;
  if not found then
    raise exception 'job for payment % not found', p_payment_id using errcode = 'P0002';
  end if;

  select * into v_quote from public.quotes where id = v_job.quote_id;
  if not found then
    raise exception 'quote for job % not found', v_job.id using errcode = 'P0002';
  end if;

  update public.jobs
     set payment_status = 'paid',
         final_amount = v_payment.amount,
         final_currency_code = v_payment.currency_code,
         payment_method = coalesce(
           (select pm.method_type from public.payment_methods pm where pm.id = v_payment.payment_method_id),
           v_job.payment_method
         )
   where id = v_job.id;

  if v_quote.promo_code_id is not null
     and not exists (select 1 from public.promo_redemptions pr where pr.job_id = v_job.id)
  then
    insert into public.promo_redemptions (
      promo_code_id, profile_id, job_id, discount_amount, currency_code,
      redeemed_at, created_at
    ) values (
      v_quote.promo_code_id, v_job.customer_id, v_job.id,
      v_quote.promo_discount, v_quote.currency_code, now(), now()
    );
  end if;

  perform public.calculate_and_record_commission(v_job.id);
  v_tax := public.apply_withholding_tax(v_job.id);

  select * into v_ledger
    from public.commission_ledger
   where job_id = v_job.id
   order by calculated_at desc
   limit 1;

  perform private.wallet_post(
    v_job.customer_id, -v_payment.amount, v_payment.currency_code,
    'payment', 'job', v_job.id, 'Customer payment for job', false, true
  );

  if v_ledger.driver_net_earning > 0 then
    perform private.wallet_post(
      v_ledger.driver_id, v_ledger.driver_net_earning, v_payment.currency_code,
      'driver_earning', 'job', v_job.id, 'Driver earning for job', false, false
    );
  end if;

  if v_ledger.commission_amount > 0 then
    perform private.wallet_post(
      '00000000-0000-4000-8000-000000000000',
      v_ledger.commission_amount, v_payment.currency_code,
      'commission_deduction', 'job', v_job.id, 'Platform commission', false, false
    );
  end if;

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    v_job.id, null, v_job.status, v_job.customer_id,
    'Payment captured by provider webhook'
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    v_job.id, 'note', v_job.customer_id,
    jsonb_build_object(
      'payment_id', p_payment_id,
      'provider_reference', v_payment.provider_reference,
      'amount', v_payment.amount,
      'currency_code', v_payment.currency_code,
      'commission_amount', v_ledger.commission_amount,
      'withholding_tax_amount', v_tax,
      'stage', 'payment_completed'
    )
  );

  return p_payment_id;
end;
$$;

comment on function public.job_pay_complete(uuid, text, text) is
  'Webhook-side finalizer: marks the pending payment terminal, records commission/withholding, credits wallets, and marks the job paid.';

revoke all on function public.job_pay_complete(uuid, text, text) from public;
revoke all on function public.job_pay_complete(uuid, text, text) from anon;
grant execute on function public.job_pay_complete(uuid, text, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Cleanup functions
-- ----------------------------------------------------------------------------
create or replace function public.cleanup_idempotency_keys()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from public.idempotency_keys where expires_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.cleanup_idempotency_keys() is
  'Deletes expired Phase 7 idempotency keys.';

revoke all on function public.cleanup_idempotency_keys() from public;
revoke all on function public.cleanup_idempotency_keys() from anon;
revoke all on function public.cleanup_idempotency_keys() from authenticated;
grant execute on function public.cleanup_idempotency_keys() to service_role;

create or replace function public.cleanup_expired_data_exports()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  -- Storage objects are removed through the Storage API by scheduled-retention.
  -- Direct deletes from storage.objects are blocked by Supabase and would leave
  -- orphaned objects. This function only clears stale delivery pointers.
  update public.data_subject_requests
     set delivered_file_path = null
   where delivered_file_path is not null
     and completed_at is not null
     and completed_at < now() - interval '30 days';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.cleanup_expired_data_exports() is
  'Clears stale data-export delivery pointers. Storage objects are deleted through the Storage API by scheduled-retention.';

revoke all on function public.cleanup_expired_data_exports() from public;
revoke all on function public.cleanup_expired_data_exports() from anon;
revoke all on function public.cleanup_expired_data_exports() from authenticated;
grant execute on function public.cleanup_expired_data_exports() to service_role;

create or replace function public.cleanup_payment_webhook_events(
  p_retention_days integer default 730
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_retention_days is null or p_retention_days < 1 then
    raise exception 'retention days must be positive' using errcode = '22023';
  end if;

  delete from public.payment_webhook_events
   where first_received_at < now() - make_interval(days => p_retention_days);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.cleanup_payment_webhook_events(integer) is
  'Deletes webhook dedupe rows older than the 24-month webhook retention window.';

revoke all on function public.cleanup_payment_webhook_events(integer) from public;
revoke all on function public.cleanup_payment_webhook_events(integer) from anon;
revoke all on function public.cleanup_payment_webhook_events(integer) from authenticated;
grant execute on function public.cleanup_payment_webhook_events(integer) to service_role;

-- ----------------------------------------------------------------------------
-- 8. Data export storage bucket and own-folder policies
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('data-exports', 'data-exports', false, 52428800, array['application/zip'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists data_exports_select_own on storage.objects;
create policy data_exports_select_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'data-exports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists data_exports_delete_own on storage.objects;
create policy data_exports_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'data-exports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- 9. Permissions for Phase 7 functions
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('send_sms',          'Send transactional SMS',                         'communication'),
  ('send_email',        'Send transactional email',                       'communication'),
  ('send_push',         'Send push notifications',                        'communication'),
  ('send_notification', 'Dispatch notifications across channels',         'communication')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select v.role_name, v.permission_key
  from (values
    ('super_admin',      'send_sms'),
    ('super_admin',      'send_email'),
    ('super_admin',      'send_push'),
    ('super_admin',      'send_notification'),
    ('operations_admin', 'send_sms'),
    ('operations_admin', 'send_email'),
    ('operations_admin', 'send_push'),
    ('operations_admin', 'send_notification'),
    ('support_agent',    'send_sms'),
    ('support_agent',    'send_email'),
    ('support_agent',    'send_push')
  ) as v(role_name, permission_key)
 where not exists (
   select 1
     from public.admin_role_permissions existing
    where existing.role_name = v.role_name
      and existing.permission_key = v.permission_key
 );

-- ----------------------------------------------------------------------------
-- 10. pg_cron cleanup
-- ----------------------------------------------------------------------------
do $$
declare
  j record;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for j in
      select jobid from cron.job where jobname = 'safeshift_cleanup_idempotency'
    loop
      perform cron.unschedule(j.jobid);
    end loop;

    perform cron.schedule(
      'safeshift_cleanup_idempotency',
      '0 6 * * *',
      $cron$select public.cleanup_idempotency_keys();$cron$
    );
  end if;
end $$;
