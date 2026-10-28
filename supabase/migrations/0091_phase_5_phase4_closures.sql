-- ============================================================================
-- SafeShift — Phase 5 / Migration 0091
-- Phase 4 closures required by the money layer.
--
-- 1. job_cancel() now refunds captured money when the job was already paid.
-- 2. The Phase 4 quote append-only trigger permits the service-only
--    quote_cleanup() context to delete expired, unconverted quotes.
-- 3. commission_ledger.is_refunded is present/backfilled.
-- 4. The Phase 4 offer-trigger is removed; acceptance statistics are now
--    maintained by the nightly pg_cron job (Decision D).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Permit the service-only quote cleanup path through the append-only guard
-- ----------------------------------------------------------------------------
create or replace function private.enforce_phase4_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service boolean := current_user in ('postgres', 'supabase_admin', 'service_role')
                       or coalesce(auth.role(), '') = 'service_role';
  v_new_offer jsonb;
  v_old_offer jsonb;
begin
  if tg_op = 'DELETE' then
    if tg_table_name = 'quotes'
       and coalesce(current_setting('safeshift.quote_cleanup', true), '') = 'on'
    then
      return old;
    end if;

    raise exception '% is append-only; rows cannot be deleted', tg_table_name
      using errcode = '42501';
  end if;

  if tg_table_name = 'job_offers' then
    if not v_service then
      raise exception 'job_offers can only be updated by the dispatch service'
        using errcode = '42501';
    end if;

    v_new_offer := to_jsonb(new) - array['responded_at', 'response', 'decline_reason'];
    v_old_offer := to_jsonb(old) - array['responded_at', 'response', 'decline_reason'];

    if v_new_offer is distinct from v_old_offer then
      raise exception 'job_offers identity and terms are immutable'
        using errcode = '42501';
    end if;

    if old.response <> 'pending' or new.response = 'pending' then
      raise exception 'job_offers response can only move once from pending to a terminal state'
        using errcode = '23514';
    end if;

    return new;
  end if;

  raise exception '% is append-only; updates are not allowed', tg_table_name
    using errcode = '42501';
end;
$$;

comment on function private.enforce_phase4_immutability() is
  'Blocks UPDATE/DELETE on Phase 4 append-only tables. job_offers permits one service-only pending -> terminal response transition. quotes permit service-only cleanup through quote_cleanup().';

-- ----------------------------------------------------------------------------
-- 2. job_cancel() replacement: refund captured money after cancellation
-- ----------------------------------------------------------------------------
create or replace function public.job_cancel(
  p_job_id uuid,
  p_cancelled_by uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor          uuid := auth.uid();
  v_job            public.jobs%rowtype;
  v_quote          public.quotes%rowtype;
  v_policy         public.cancellation_policies%rowtype;
  v_policy_found   boolean := false;
  v_policy_name    text;
  v_role           public.user_role;
  v_country_id     uuid;
  v_minutes_before integer;
  v_fee            numeric(14,2) := 0;
  v_refund         numeric(14,2) := 0;
  v_currency       char(3);
  v_refund_status  text;
  v_tier           record;
  v_original_payment uuid;
begin
  if p_job_id is null or p_cancelled_by is null then
    raise exception 'job and cancelling profile are required' using errcode = '22004';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a cancellation reason is required' using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or (v_actor is not null and p_cancelled_by = v_actor)
    or public.has_permission('assign_drivers')
  ) then
    raise exception 'not authorised to cancel this job' using errcode = '42501';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_job.status in ('completed', 'cancelled', 'disputed') then
    raise exception 'job % cannot be cancelled in status %', p_job_id, v_job.status
      using errcode = '23514';
  end if;

  if p_cancelled_by = v_job.customer_id then
    v_role := 'customer';
  elsif p_cancelled_by = v_job.driver_id then
    v_role := 'driver';
  elsif private.is_service_context() or public.has_permission('assign_drivers') then
    v_role := 'admin';
  else
    raise exception 'profile % is not a party to job %', p_cancelled_by, p_job_id
      using errcode = '42501';
  end if;

  select * into v_quote
  from public.quotes
  where id = v_job.quote_id;

  select c.country_id into v_country_id
  from public.cities c
  where c.id = v_job.city_id;

  v_minutes_before := floor(
    extract(epoch from (coalesce(v_job.scheduled_at, now()) - now())) / 60.0
  )::integer;

  if v_role in ('customer', 'driver') then
    select * into v_policy
    from public.cancellation_policies cp
    where cp.country_id = v_country_id
      and cp.applies_to_role = v_role
      and cp.is_active
    order by cp.created_at desc, cp.id
    limit 1;

    v_policy_found := found;
  end if;

  if v_policy_found then
    v_policy_name := v_policy.name;

    if v_minutes_before < v_policy.free_cancellation_window_minutes then
      if v_policy.fee_type = 'flat' then
        v_fee := v_policy.fee_value;
      elsif v_policy.fee_type = 'percentage_of_quote' then
        v_fee := round(
          coalesce(v_job.final_amount, v_quote.total, 0) * v_policy.fee_value / 100.0,
          2
        );
      elsif v_policy.fee_type = 'tiered' then
        select (tier ->> 'fee')::numeric into v_fee
        from jsonb_array_elements(v_policy.fee_tiers) tier
        where (tier ->> 'minutes_before_pickup')::numeric <= v_minutes_before
        order by (tier ->> 'minutes_before_pickup')::numeric desc
        limit 1;

        if not found then
          v_fee := 0;
        end if;
      end if;
    end if;
  end if;

  v_fee := round(
    least(
      greatest(coalesce(v_fee, 0), 0),
      coalesce(v_job.final_amount, v_quote.total, 0)
    ),
    2
  );

  v_currency := coalesce(v_job.final_currency_code, v_quote.currency_code);

  if v_job.payment_status in ('paid', 'partially_refunded') then
    v_refund := round(
      greatest(coalesce(v_job.final_amount, v_quote.total, 0) - v_fee, 0),
      2
    );
    v_refund_status := 'pending';
  else
    v_refund := 0;
    v_refund_status := 'not_applicable';
  end if;

  update public.jobs
     set status = 'cancelled',
         cancelled_at = now(),
         cancellation_policy_applied = v_policy_name,
         cancellation_fee = v_fee
   where id = p_job_id;

  insert into public.job_cancellations (
    job_id, cancelled_by, canceller_role, reason, cancellation_policy_id,
    fee_applied, refund_amount, currency_code, refund_status, notes
  ) values (
    p_job_id, p_cancelled_by, v_role, p_reason,
    case when v_policy_found then v_policy.id else null end,
    v_fee, v_refund, v_currency, v_refund_status, p_reason
  );

  -- Phase 5: if the job was captured, refund the amount not retained as the
  -- cancellation fee. payment_refund() additionally marks the commission
  -- ledger refunded and claws back driver/platform wallet entries.
  if v_job.payment_status = 'paid' and v_refund > 0 then
    select p.id into v_original_payment
    from public.payments p
    where p.job_id = p_job_id
      and p.payment_type = 'charge'
      and p.provider_status = 'succeeded'
    order by p.completed_at desc nulls last, p.created_at desc
    limit 1;

    if v_original_payment is not null then
      begin
        perform set_config('safeshift.refund_context', 'on', true);
        perform public.payment_refund(
          v_original_payment, v_refund, 'cancellation_fee',
          'Cancellation refund: ' || p_reason
        );
        perform set_config('safeshift.refund_context', 'off', true);
      exception when others then
        perform set_config('safeshift.refund_context', 'off', true);
        raise;
      end;
    end if;
  end if;

  insert into public.job_status_history (
    job_id, from_status, to_status, changed_by, reason
  ) values (
    p_job_id, v_job.status, 'cancelled', p_cancelled_by, p_reason
  );

  insert into public.job_events (job_id, event_type, actor_id, details)
  values (
    p_job_id,
    'cancelled',
    p_cancelled_by,
    jsonb_build_object(
      'canceller_role', v_role,
      'policy_id', case when v_policy_found then v_policy.id else null end,
      'fee_applied', v_fee,
      'refund_amount', v_refund,
      'refund_status', v_refund_status,
      'currency_code', v_currency,
      'reason', p_reason
    )
  );
end;
$$;

comment on function public.job_cancel(uuid, uuid, text) is
  'Cancels a job, resolves the policy fee, writes the cancellation record, and calls payment_refund() when the job was already paid.';

revoke all on function public.job_cancel(uuid, uuid, text) from public;
revoke all on function public.job_cancel(uuid, uuid, text) from anon;
grant execute on function public.job_cancel(uuid, uuid, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. commission_ledger.is_refunded backfill and comment
-- ----------------------------------------------------------------------------
alter table public.commission_ledger
  add column if not exists is_refunded boolean not null default false;

update public.commission_ledger
   set is_refunded = false
 where is_refunded is null;

comment on column public.commission_ledger.is_refunded is
  'Set once by payment_refund(). Refunded ledger entries are excluded from future payout batches.';

-- ----------------------------------------------------------------------------
-- 4. Decision D: nightly recompute, no offer trigger
-- ----------------------------------------------------------------------------
drop trigger if exists trg_job_offers_sync_acceptance_stats on public.job_offers;

comment on table public.driver_acceptance_stats is
  'Rolling 30-day offer metrics recomputed nightly by recompute_all_driver_acceptance_stats() via pg_cron. No trigger maintenance.';
