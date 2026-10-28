-- ============================================================================
-- SafeShift — Phase 5 schema verification
--
-- Usage (local):
--   psql "$LOCAL_DB_URL" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-5-schema.sql
--
-- Run after migrations and after seed.sql + seed-phase-2.sql +
-- seed-phase-3.sql + seed-phase-4.sql + seed-phase-5.sql. The script is
-- read-mostly: behavioural checks create a fresh scratch customer, quotes and
-- jobs. Money rows are append-only, so those scratch rows intentionally remain.
-- ============================================================================

drop table if exists _phase5_verification;
create temporary table _phase5_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

drop table if exists _phase5_scratch;
create temporary table _phase5_scratch (
  key text primary key,
  id uuid not null
);

-- ----------------------------------------------------------------------------
-- 1. Tables
-- ----------------------------------------------------------------------------
drop table if exists _phase5_tables;
create temporary table _phase5_tables (name text primary key);
insert into _phase5_tables (name) values
  ('payment_providers'), ('payment_methods'), ('payments'), ('payment_webhooks'),
  ('refunds'), ('wallets'), ('wallet_transactions'), ('commission_rules'),
  ('commission_ledger'), ('tax_rates'), ('payout_batches'), ('payouts'),
  ('payout_items'), ('invoices'), ('invoice_line_items'), ('fleet_billing_events');

insert into _phase5_verification (check_no, check_name, status, details)
select 1, 'All 16 Phase 5 tables exist',
       case when count(*) = 16 then 'PASS' else 'FAIL' end,
       count(*) || ' of 16 present'
from _phase5_tables t
where to_regclass('public.' || t.name) is not null;

-- ----------------------------------------------------------------------------
-- 2. Foreign keys
-- ----------------------------------------------------------------------------
insert into _phase5_verification (check_no, check_name, status, details)
select 2, 'All foreign keys validated',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*) || ' unvalidated FK(s)'
from pg_constraint
where contype = 'f' and not convalidated;

insert into _phase5_verification (check_no, check_name, status, details)
select 2, 'No orphaned Phase 5 foreign keys',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*) || ' FK(s) reference a missing table'
from pg_constraint c
where c.contype = 'f'
  and c.connamespace = 'public'::regnamespace
  and not exists (
    select 1 from pg_class rc
    join pg_namespace rn on rn.oid = rc.relnamespace
    where rc.oid = c.confrelid
  );

-- ----------------------------------------------------------------------------
-- 3. RLS and policies
-- ----------------------------------------------------------------------------
insert into _phase5_verification (check_no, check_name, status, details)
select 3, 'RLS enabled on ' || t.name,
       case when c.relrowsecurity then 'PASS' else 'FAIL' end,
       coalesce(c.relkind::text, 'missing')
from _phase5_tables t
left join pg_class c on c.oid = to_regclass('public.' || t.name)
order by t.name;

insert into _phase5_verification (check_no, check_name, status, details)
select 4, 'At least one policy on ' || t.name,
       case when exists (
         select 1 from pg_policy p where p.polrelid = to_regclass('public.' || t.name)
       ) then 'PASS' else 'FAIL' end,
       (select count(*)::text || ' policies' from pg_policy p
        where p.polrelid = to_regclass('public.' || t.name))
from _phase5_tables t
order by t.name;

insert into _phase5_verification (check_no, check_name, status, details)
select 5, 'Partition children have no client privileges',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'no direct client access')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relispartition
  and (
    has_table_privilege('anon', c.oid, 'SELECT')
    or has_table_privilege('anon', c.oid, 'INSERT')
    or has_table_privilege('anon', c.oid, 'UPDATE')
    or has_table_privilege('anon', c.oid, 'DELETE')
    or has_table_privilege('authenticated', c.oid, 'SELECT')
    or has_table_privilege('authenticated', c.oid, 'INSERT')
    or has_table_privilege('authenticated', c.oid, 'UPDATE')
    or has_table_privilege('authenticated', c.oid, 'DELETE')
  );

-- ----------------------------------------------------------------------------
-- 4. Partitioned tables
-- ----------------------------------------------------------------------------
insert into _phase5_verification (check_no, check_name, status, details)
select 6, 'Partitioned: ' || t.name,
       case when c.relkind = 'p' and x.child_count >= t.min_children then 'PASS' else 'FAIL' end,
       coalesce(x.child_count::text || ' partitions', 'missing')
from (values
  ('payment_webhooks', 24),
  ('wallet_transactions', 12),
  ('commission_ledger', 12)
) as t(name, min_children)
left join pg_class c on c.oid = to_regclass('public.' || t.name)
left join lateral (
  select count(*)::integer as child_count
  from pg_inherits i
  where i.inhparent = to_regclass('public.' || t.name)
) x on true;

-- ----------------------------------------------------------------------------
-- 5. Indexes
-- ----------------------------------------------------------------------------
drop table if exists _phase5_indexes;
create temporary table _phase5_indexes (name text primary key);
insert into _phase5_indexes (name) values
  ('idx_payment_methods_profile_active'),
  ('uq_payment_methods_default'),
  ('idx_payment_methods_provider'),
  ('idx_payments_job'),
  ('idx_payments_customer_created'),
  ('uq_payments_provider_reference'),
  ('idx_payments_status_open'),
  ('idx_payments_refund_of'),
  ('idx_refunds_payment'),
  ('idx_refunds_job'),
  ('idx_refunds_status_open'),
  ('uq_payment_webhooks_provider_event'),
  ('idx_payment_webhooks_pending'),
  ('idx_payment_webhooks_provider_received'),
  ('idx_wallet_transactions_wallet_created'),
  ('idx_wallet_transactions_reference'),
  ('idx_commission_rules_active_scope'),
  ('idx_commission_rules_active_priority'),
  ('idx_commission_rules_effective'),
  ('idx_commission_ledger_job'),
  ('idx_commission_ledger_driver_calculated'),
  ('idx_commission_ledger_unrefunded'),
  ('idx_tax_rates_active_scope'),
  ('idx_payout_batches_country_period'),
  ('idx_payout_batches_open'),
  ('idx_payouts_batch'),
  ('idx_payouts_driver_period'),
  ('idx_payouts_open'),
  ('idx_payout_items_payout'),
  ('idx_invoices_business_issued'),
  ('idx_invoices_open'),
  ('idx_invoice_line_items_invoice'),
  ('idx_invoice_line_items_job'),
  ('idx_fleet_billing_events_fleet_accrued');

insert into _phase5_verification (check_no, check_name, status, details)
select 7, 'All Phase 5 indexes exist',
       case when count(*) = (select count(*) from _phase5_indexes) then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase5_indexes) || ' present'
from _phase5_indexes i
where to_regclass('public.' || i.name) is not null;

-- ----------------------------------------------------------------------------
-- 6. Functions
-- ----------------------------------------------------------------------------
drop table if exists _phase5_functions;
create temporary table _phase5_functions (signature text primary key);
insert into _phase5_functions (signature) values
  ('public.resolve_tax_rate(uuid,text,text,timestamptz)'),
  ('public.resolve_commission_rule(uuid)'),
  ('public.wallet_credit(uuid,numeric,char,text,text,uuid,text)'),
  ('public.wallet_debit(uuid,numeric,char,text,text,uuid,text,boolean)'),
  ('public.calculate_and_record_commission(uuid)'),
  ('public.apply_withholding_tax(uuid)'),
  ('public.job_pay(uuid,uuid,uuid,text,text)'),
  ('public.payment_refund(uuid,numeric,text,text)'),
  ('public.job_refund(uuid,numeric,text,text)'),
  ('public.create_payout_batch(uuid,timestamptz,timestamptz)'),
  ('public.execute_payout(uuid)'),
  ('public.generate_invoice(uuid,timestamptz,timestamptz)'),
  ('public.recompute_all_driver_acceptance_stats()'),
  ('public.verify_all_wallet_balances()'),
  ('public.wallet_balance_verify()'),
  ('public.quote_cleanup()');

insert into _phase5_verification (check_no, check_name, status, details)
select 8, 'All Phase 5 helper functions exist',
       case when count(*) = (select count(*) from _phase5_functions) then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase5_functions) || ' present'
from _phase5_functions f
where to_regprocedure(f.signature) is not null;

insert into _phase5_verification (check_no, check_name, status, details)
select 8, 'SECURITY DEFINER money functions pin search_path',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(p.proname, ', '), 'all pinned')
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'job_pay', 'payment_refund', 'job_refund', 'wallet_credit', 'wallet_debit',
    'calculate_and_record_commission', 'apply_withholding_tax',
    'create_payout_batch', 'execute_payout', 'generate_invoice'
  )
  and p.prosecdef
  and not exists (
    select 1 from unnest(coalesce(p.proconfig, array[]::text[])) cfg
    where cfg like 'search_path=%'
  );

-- ----------------------------------------------------------------------------
-- 7. Views
-- ----------------------------------------------------------------------------
drop table if exists _phase5_views;
create temporary table _phase5_views (name text primary key);
insert into _phase5_views (name) values
  ('job_payment_summary'),
  ('driver_earnings_summary'),
  ('wallet_balance_current'),
  ('payout_batch_summary'),
  ('invoice_summary'),
  ('payment_reconciliation');

insert into _phase5_verification (check_no, check_name, status, details)
select 9, 'All Phase 5 views exist with security_invoker',
       case when count(*) = (select count(*) from _phase5_views) then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase5_views) || ' correct'
from _phase5_views v
join pg_class c on c.oid = to_regclass('public.' || v.name)
where c.relkind = 'v'
  and coalesce(array_to_string(c.reloptions, ','), '') like '%security_invoker=true%';

-- ----------------------------------------------------------------------------
-- 8. pg_cron
-- ----------------------------------------------------------------------------
insert into _phase5_verification (check_no, check_name, status, details)
select 10, 'Four Phase 5 safeshift pg_cron jobs registered',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(jobname, ', ' order by jobname), 'none')
from cron.job
where jobname in (
  'safeshift_acceptance_stats',
  'safeshift_expire_offers',
  'safeshift_quote_cleanup',
  'safeshift_wallet_verify'
);

-- ----------------------------------------------------------------------------
-- 9. Seed counts (fixed seed identifiers only)
-- ----------------------------------------------------------------------------
insert into _phase5_verification (check_no, check_name, status, details)
select 11, 'Seed: ' || s.label,
       case when s.actual = s.expected then 'PASS' else 'FAIL' end,
       s.actual || ' expected ' || s.expected
from (
  select 'payment providers' as label,
         (select count(*)::int from public.payment_providers where id::text like '5b000000%') as actual,
         2 as expected
  union all
  select 'payment methods',
         (select count(*)::int from public.payment_methods where id::text like '5c000000%'), 3
  union all
  select 'tax rates',
         (select count(*)::int from public.tax_rates where id::text like '5d000000%'), 2
  union all
  select 'commission rules',
         (select count(*)::int from public.commission_rules where id::text like '5e000000%'), 3
  union all
  select 'charge payments',
         (select count(*)::int from public.payments where id::text like '5f000000%' and payment_type = 'charge'), 2
  union all
  select 'refund payment',
         (select count(*)::int from public.payments where id::text like '5f000000%' and payment_type = 'refund'), 1
  union all
  select 'refunds',
         (select count(*)::int from public.refunds where id::text like '60000000%'), 1
  union all
  select 'wallets',
         (select count(*)::int from public.wallets where id::text like '61000000%'), 5
  union all
  select 'wallet transactions',
         (select count(*)::int from public.wallet_transactions
          where description in (
            'Seed customer 1 top-up', 'Seed customer 2 top-up', 'Seed customer 3 top-up',
            'Seed platform float', 'Payment for completed job J1',
            'Payment hold for in-transit job J2', 'Driver earning for completed job J1',
            'Platform commission for J1', 'Withholding tax recorded for J1',
            'Goodwill refund for cancelled job J3'
          )), 10
  union all
  select 'commission ledger',
         (select count(*)::int from public.commission_ledger where id::text like '62000000%'), 1
  union all
  select 'payout batches',
         (select count(*)::int from public.payout_batches where id::text like '63000000%'), 1
  union all
  select 'payouts',
         (select count(*)::int from public.payouts where id::text like '64000000%'), 1
  union all
  select 'payout items',
         (select count(*)::int from public.payout_items where id::text like '65000000%'), 1
  union all
  select 'invoices',
         (select count(*)::int from public.invoices where id::text like '66000000%'), 1
  union all
  select 'invoice lines',
         (select count(*)::int from public.invoice_line_items where id::text like '67000000%'), 3
  union all
  select 'fleet billing events',
         (select count(*)::int from public.fleet_billing_events), 1
) s;

-- ----------------------------------------------------------------------------
-- 10. Scratch fixtures: a fresh customer, quotes, jobs and methods.
-- ----------------------------------------------------------------------------
do $$
declare
  v_customer uuid := gen_random_uuid();
  v_method   uuid := gen_random_uuid();
  v_quote_pay      uuid;
  v_quote_refund2  uuid;
  v_quote_cancel   uuid;
  v_quote_cascade  uuid;
  v_quote_payout   uuid;
  v_quote_invoice  uuid;
  v_job_pay        uuid;
  v_job_refund2    uuid;
  v_job_cancel     uuid;
  v_job_cascade_default uuid;
  v_job_cascade_city    uuid;
  v_job_cascade_fleet   uuid;
  v_job_cascade_driver  uuid;
  v_job_payout     uuid;
  v_job_invoice    uuid;
  v_payment_cancel uuid := gen_random_uuid();
  v_qtotal         numeric(14,2);
  v_email          text := 'verify-' || replace(gen_random_uuid()::text, '-', '') || '@example.test';
begin
  -- A fresh auth user/profile keeps the promo path repeatable across runs.
  insert into auth.users (
    instance_id, id, aud, role, email, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', v_customer,
    'authenticated', 'authenticated', v_email, now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Phase 5 Verification Customer","country_code":"TZ"}'::jsonb
  );

  insert into _phase5_scratch (key, id) values ('customer', v_customer)
  on conflict (key) do update set id = excluded.id;

  insert into public.payment_methods (
    id, profile_id, provider_id, method_type, display_name, provider_token,
    provider_customer_id, is_default, is_active
  ) values (
    v_method, v_customer, '5b000000-0000-4000-8000-000000000001',
    'mpesa', 'Verification M-Pesa', 'tok_verify_' || replace(gen_random_uuid()::text, '-', ''),
    'verify_customer', true, true
  );

  insert into _phase5_scratch (key, id) values ('method', v_method)
  on conflict (key) do update set id = excluded.id;

  v_quote_pay := public.quote_calculate_and_persist(
    v_customer,
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo verification pickup',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani verification dropoff',
    '22000000-0000-4000-8000-000000000003',
    '25000000-0000-4000-8000-000000000002',
    3000, 15, now() + interval '2 hours', 2, 0, '{}'::uuid[],
    '37000000-0000-4000-8000-000000000004', 12, 40
  );

  v_quote_refund2 := public.quote_calculate_and_persist(
    v_customer,
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo verification pickup',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani verification dropoff',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    300, 2, now() + interval '2 hours', 2, 0, '{}'::uuid[],
    null, 8.5, 25
  );

  v_quote_cancel := public.quote_calculate_and_persist(
    v_customer,
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo verification pickup',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani verification dropoff',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    300, 2, now() + interval '1 hour', 2, 0, '{}'::uuid[],
    null, 8.5, 25
  );

  v_quote_cascade := public.quote_calculate_and_persist(
    v_customer,
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo verification pickup',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani verification dropoff',
    '22000000-0000-4000-8000-000000000003',
    '25000000-0000-4000-8000-000000000002',
    3000, 15, now() + interval '2 hours', 2, 0, '{}'::uuid[],
    null, 12, 40
  );

  v_quote_payout := public.quote_calculate_and_persist(
    v_customer,
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo verification pickup',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani verification dropoff',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    300, 2, now() - interval '5 days', 2, 0, '{}'::uuid[],
    null, 8.5, 25
  );

  v_quote_invoice := public.quote_calculate_and_persist(
    'e0000000-0000-4000-8000-000000000001',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo business pickup',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani business dropoff',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    300, 2, now() + interval '2 hours', 2, 0, '{}'::uuid[],
    null, 8.5, 25
  );

  insert into _phase5_scratch (key, id) values
    ('quote_pay', v_quote_pay),
    ('quote_refund2', v_quote_refund2),
    ('quote_cancel', v_quote_cancel),
    ('quote_cascade', v_quote_cascade),
    ('quote_payout', v_quote_payout),
    ('quote_invoice', v_quote_invoice)
  on conflict (key) do update set id = excluded.id;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, accepted_at, started_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_pay, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000001',
    '28000000-0000-4000-8000-000000000001', 'completed',
    now() - interval '2 hours', now() - interval '110 minutes',
    now() - interval '100 minutes', now() - interval '1 hour', 'pending'
  ) returning id into v_job_pay;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, accepted_at, started_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_refund2, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000001',
    '28000000-0000-4000-8000-000000000001', 'completed',
    now() - interval '2 hours', now() - interval '110 minutes',
    now() - interval '100 minutes', now() - interval '1 hour', 'pending'
  ) returning id into v_job_refund2;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, accepted_at, started_at, payment_status, payment_method
  ) values (
    gen_random_uuid(), v_quote_cancel, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000001',
    '28000000-0000-4000-8000-000000000001', 'in_transit',
    now() + interval '1 hour', now() - interval '30 minutes',
    now() - interval '20 minutes', 'paid', 'mpesa'
  ) returning id into v_job_cancel;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_cascade, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000003',
    '28000000-0000-4000-8000-000000000001', 'completed',
    now() - interval '2 hours', now() - interval '1 hour', 'pending'
  ) returning id into v_job_cascade_default;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_cascade, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000003',
    '28000000-0000-4000-8000-000000000003', 'completed',
    now() - interval '2 hours', now() - interval '1 hour', 'pending'
  ) returning id into v_job_cascade_city;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_cascade, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000002',
    '28000000-0000-4000-8000-000000000003', 'completed',
    now() - interval '2 hours', now() - interval '1 hour', 'pending'
  ) returning id into v_job_cascade_fleet;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_cascade, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000003',
    '28000000-0000-4000-8000-000000000001', 'completed',
    now() - interval '2 hours', now() - interval '1 hour', 'pending'
  ) returning id into v_job_cascade_driver;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_payout, '55555555-0000-4000-8000-000000000001',
    v_customer, 'd0000000-0000-4000-8000-000000000003',
    '28000000-0000-4000-8000-000000000001', 'completed',
    now() - interval '5 days 2 hours', now() - interval '5 days', 'pending'
  ) returning id into v_job_payout;

  insert into public.jobs (
    id, quote_id, city_id, customer_id, driver_id, vehicle_id, status,
    scheduled_at, completed_at, payment_status
  ) values (
    gen_random_uuid(), v_quote_invoice, '55555555-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    '28000000-0000-4000-8000-000000000001', 'completed',
    now() - interval '2 hours', now() - interval '1 hour', 'pending'
  ) returning id into v_job_invoice;

  insert into _phase5_scratch (key, id) values
    ('job_pay', v_job_pay),
    ('job_refund2', v_job_refund2),
    ('job_cancel', v_job_cancel),
    ('job_cascade_default', v_job_cascade_default),
    ('job_cascade_city', v_job_cascade_city),
    ('job_cascade_fleet', v_job_cascade_fleet),
    ('job_cascade_driver', v_job_cascade_driver),
    ('job_payout', v_job_payout),
    ('job_invoice', v_job_invoice)
  on conflict (key) do update set id = excluded.id;

  select total into v_qtotal
  from public.quotes where id = v_quote_cancel;

  insert into public.payments (
    id, job_id, customer_id, payment_method_id, provider_id, amount,
    currency_code, provider_reference, provider_status, payment_type,
    completed_at, metadata
  ) values (
    v_payment_cancel, v_job_cancel, v_customer, v_method,
    '5b000000-0000-4000-8000-000000000001', v_qtotal, 'TZS',
    'verify-cancel-' || replace(gen_random_uuid()::text, '-', ''),
    'succeeded', 'charge', now(), '{"source":"phase5_verification"}'::jsonb
  );

  insert into _phase5_scratch (key, id) values ('payment_cancel', v_payment_cancel)
  on conflict (key) do update set id = excluded.id;
end $$;

-- ----------------------------------------------------------------------------
-- 11. job_pay() end-to-end and idempotency
-- ----------------------------------------------------------------------------
do $$
declare
  v_customer uuid := (select id from _phase5_scratch where key = 'customer');
  v_method   uuid := (select id from _phase5_scratch where key = 'method');
  v_job      uuid := (select id from _phase5_scratch where key = 'job_pay');
  v_payment  uuid;
  v_payment_again uuid;
  v_payment_idem  uuid;
  v_ref       text := 'verify-pay-' || replace(gen_random_uuid()::text, '-', '');
  v_idem      text := 'verify-idem-' || replace(gen_random_uuid()::text, '-', '');
  v_count     integer;
begin
  v_payment := public.job_pay(
    v_job, v_method, '5b000000-0000-4000-8000-000000000001',
    v_ref, v_idem
  );

  v_payment_again := public.job_pay(
    v_job, v_method, '5b000000-0000-4000-8000-000000000001',
    v_ref, v_idem
  );

  v_payment_idem := public.job_pay(
    v_job, v_method, '5b000000-0000-4000-8000-000000000001',
    'verify-pay-second-' || replace(gen_random_uuid()::text, '-', ''), v_idem
  );

  insert into _phase5_scratch (key, id) values
    ('payment_pay', v_payment),
    ('payment_pay_again', v_payment_again),
    ('payment_pay_idem', v_payment_idem)
  on conflict (key) do update set id = excluded.id;

  insert into _phase5_verification values (
    12, 'job_pay creates a succeeded charge and marks the job paid',
    case when exists (
      select 1 from public.payments p
      where p.id = v_payment and p.job_id = v_job
        and p.payment_type = 'charge' and p.provider_status = 'succeeded'
        and p.amount > 0
    ) and exists (
      select 1 from public.jobs j where j.id = v_job and j.payment_status = 'paid'
    ) then 'PASS' else 'FAIL' end,
    'payment=' || coalesce(v_payment::text, 'null')
  );

  insert into _phase5_verification values (
    13, 'job_pay writes one commission ledger row, driver/platform wallets and a promo redemption',
    case when (select count(*) from public.commission_ledger where job_id = v_job) = 1
              and (select count(*) from public.promo_redemptions where job_id = v_job) = 1
              and (select count(*) from public.wallet_transactions
                   where reference_id = v_job and reference_type = 'job'
                     and transaction_type in ('payment', 'driver_earning', 'commission_deduction')) >= 3
         then 'PASS' else 'FAIL' end,
    (select count(*) from public.commission_ledger where job_id = v_job)::text || ' ledger, '
    || (select count(*) from public.promo_redemptions where job_id = v_job)::text || ' redemption, '
    || (select count(*) from public.wallet_transactions where reference_id = v_job)::text || ' wallet rows'
  );

  insert into _phase5_verification values (
    14, 'job_pay retries are idempotent by provider_reference and idempotency_key',
    case when v_payment = v_payment_again and v_payment = v_payment_idem then 'PASS' else 'FAIL' end,
    coalesce(v_payment::text, 'null') || ' / ' || coalesce(v_payment_again::text, 'null')
    || ' / ' || coalesce(v_payment_idem::text, 'null')
  );

  insert into _phase5_verification values (
    15, 'job_pay writes status history and a job event',
    case when exists (select 1 from public.job_status_history where job_id = v_job)
              and exists (select 1 from public.job_events where job_id = v_job)
         then 'PASS' else 'FAIL' end,
    'history/event present'
  );
end $$;

-- ----------------------------------------------------------------------------
-- 12. payment_refund() partial and full, job_refund(), job_cancel closure
-- ----------------------------------------------------------------------------
do $$
declare
  v_customer uuid := (select id from _phase5_scratch where key = 'customer');
  v_method   uuid := (select id from _phase5_scratch where key = 'method');
  v_payment  uuid := (select id from _phase5_scratch where key = 'payment_pay');
  v_job      uuid := (select id from _phase5_scratch where key = 'job_pay');
  v_job2     uuid := (select id from _phase5_scratch where key = 'job_refund2');
  v_job3     uuid := (select id from _phase5_scratch where key = 'job_cancel');
  v_payment2 uuid;
  v_refund1  uuid;
  v_refund2  uuid;
  v_refund3  uuid;
  v_remaining numeric(14,2);
  v_original numeric(14,2);
  v_refundable numeric(14,2);
begin
  select amount into v_original from public.payments where id = v_payment;
  v_remaining := v_original - 1000.00;

  v_refund1 := public.payment_refund(v_payment, 1000.00, 'partial', 'Verification partial refund');
  v_refund2 := public.payment_refund(v_payment, v_remaining, 'full', 'Verification full refund');

  insert into _phase5_scratch (key, id) values
    ('refund_partial', v_refund1),
    ('refund_full', v_refund2)
  on conflict (key) do update set id = excluded.id;

  select coalesce(sum(amount), 0) into v_refundable
  from public.refunds where payment_id = v_payment and status <> 'failed';

  insert into _phase5_verification values (
    16, 'payment_refund creates partial and full refund payments and refunds',
    case when (
      select count(*) = 2 from public.refunds
      where payment_id = v_payment and status = 'succeeded'
    ) and v_refundable = v_original then 'PASS' else 'FAIL' end,
    'refunded=' || v_refundable::text || ' original=' || v_original::text
  );

  insert into _phase5_verification values (
    17, 'payment_refund marks the job refunded and commission ledger refunded',
    case when exists (
      select 1 from public.jobs where id = v_job and payment_status = 'refunded'
    ) and exists (
      select 1 from public.commission_ledger where job_id = v_job and is_refunded = true
    ) then 'PASS' else 'FAIL' end,
    'job and ledger refund flags'
  );

  -- job_refund() delegates through the latest succeeded charge.
  v_payment2 := public.job_pay(
    v_job2, v_method, '5b000000-0000-4000-8000-000000000001',
    'verify-refund-job-' || replace(gen_random_uuid()::text, '-', '')
  );
  v_refund3 := public.job_refund(v_job2, 500.00, 'partial', 'Verification job_refund');

  insert into _phase5_scratch (key, id) values ('refund_job', v_refund3)
  on conflict (key) do update set id = excluded.id;

  insert into _phase5_verification values (
    18, 'job_refund creates a refund linked to the job charge',
    case when exists (
      select 1 from public.refunds r
      where r.refund_payment_id = v_refund3
        and r.job_id = v_job2 and r.amount = 500.00
    ) and exists (
      select 1 from public.jobs where id = v_job2 and payment_status = 'refunded'
    ) then 'PASS' else 'FAIL' end,
    'refund=' || coalesce(v_refund3::text, 'null')
  );

  -- Phase 4 closure: a captured in-transit job is refunded by job_cancel().
  perform public.job_cancel(v_job3, v_customer, 'Verification cancellation refund');

  insert into _phase5_verification values (
    19, 'job_cancel calls payment_refund when the job was paid',
    case when exists (
      select 1 from public.jobs where id = v_job3
        and status = 'cancelled' and payment_status = 'refunded'
    ) and exists (
      select 1 from public.refunds r
      where r.job_id = v_job3 and r.status = 'succeeded'
    ) then 'PASS' else 'FAIL' end,
    'cancelled job refunded'
  );
end $$;

-- ----------------------------------------------------------------------------
-- 13. Commission cascade, withholding and tax resolution
-- ----------------------------------------------------------------------------
do $$
declare
  v_default uuid := (select id from _phase5_scratch where key = 'job_cascade_default');
  v_city    uuid := (select id from _phase5_scratch where key = 'job_cascade_city');
  v_fleet   uuid := (select id from _phase5_scratch where key = 'job_cascade_fleet');
  v_driver  uuid := (select id from _phase5_scratch where key = 'job_cascade_driver');
  v_rule    uuid := gen_random_uuid();
  v_resolved uuid;
  v_ledger_default uuid;
  v_ledger_city uuid;
  v_ledger_fleet uuid;
  v_ledger_driver uuid;
  v_total numeric(14,2);
  v_commission numeric(14,2);
  v_net numeric(14,2);
  v_tax numeric(14,2);
begin
  -- Resolve and calculate before the driver-specific rule exists.
  v_resolved := public.resolve_commission_rule(v_default);
  v_ledger_default := public.calculate_and_record_commission(v_default);
  v_ledger_city := public.calculate_and_record_commission(v_city);
  v_ledger_fleet := public.calculate_and_record_commission(v_fleet);

  insert into _phase5_scratch (key, id) values ('ledger_default', v_ledger_default)
  on conflict (key) do update set id = excluded.id;

  insert into public.commission_rules (
    id, country_id, city_id, vehicle_type_id, fleet_id, driver_id,
    commission_type, commission_value, min_commission, max_commission,
    priority, effective_from, is_active
  ) values (
    v_rule, '33333333-0000-4000-8000-000000000001', null, null, null,
    'd0000000-0000-4000-8000-000000000003',
    'percentage', 15.0000, 0, null, 100, now() - interval '1 day', true
  );

  v_resolved := public.resolve_commission_rule(v_driver);
  v_ledger_driver := public.calculate_and_record_commission(v_driver);

  select total into v_total from public.quotes where id = (select quote_id from public.jobs where id = v_default);
  select commission_amount into v_commission from public.commission_ledger where id = v_ledger_default;
  select driver_net_earning into v_net from public.commission_ledger where id = v_ledger_default;

  insert into _phase5_verification values (
    20, 'Commission cascade resolves driver > fleet > vehicle/city > country > default',
    case when exists (
      select 1 from public.commission_ledger where id = v_ledger_default
        and commission_amount = round(v_total * 0.1200, 2)
    ) and exists (
      select 1 from public.commission_ledger where id = v_ledger_city
        and commission_amount = round(v_total * 0.1000, 2)
    ) and exists (
      select 1 from public.commission_ledger where id = v_ledger_fleet
        and commission_amount = round(v_total * 0.0800, 2)
    ) and exists (
      select 1 from public.commission_ledger where id = v_ledger_driver
        and commission_amount = round(v_total * 0.1500, 2)
    ) then 'PASS' else 'FAIL' end,
    'default=' || (select commission_amount from public.commission_ledger where id = v_ledger_default)::text
    || ', city=' || (select commission_amount from public.commission_ledger where id = v_ledger_city)::text
    || ', fleet=' || (select commission_amount from public.commission_ledger where id = v_ledger_fleet)::text
    || ', driver=' || (select commission_amount from public.commission_ledger where id = v_ledger_driver)::text
  );

  update public.commission_rules set is_active = false where id = v_rule;

  v_tax := public.apply_withholding_tax(v_default);

  insert into _phase5_verification values (
    21, 'apply_withholding_tax records 5% of driver net earning',
    case when v_tax = round(v_net * 0.0500, 2)
              and exists (
                select 1 from public.commission_ledger
                where id = v_ledger_default and withholding_tax_amount = v_tax
              )
         then 'PASS' else 'FAIL' end,
    'tax=' || v_tax::text || ' net=' || v_net::text
  );

  insert into _phase5_verification values (
    22, 'resolve_tax_rate returns VAT 18% and withholding 5%',
    case when public.resolve_tax_rate(
                '33333333-0000-4000-8000-000000000001', 'vat', 'customer_charge', now()
              ) = 0.1800
              and public.resolve_tax_rate(
                '33333333-0000-4000-8000-000000000001', 'withholding', 'driver_payout', now()
              ) = 0.0500
         then 'PASS' else 'FAIL' end,
    'VAT/withholding lookup'
  );

  insert into _phase5_verification values (
    23, 'commission_ledger is one row per job',
    case when (select count(*) from public.commission_ledger where job_id = v_default) = 1
              and public.calculate_and_record_commission(v_default) = v_ledger_default
         then 'PASS' else 'FAIL' end,
    'repeat call returned the existing ledger id'
  );
end $$;

-- ----------------------------------------------------------------------------
-- 14. Payout batch and execution
-- ----------------------------------------------------------------------------
do $$
declare
  v_job      uuid := (select id from _phase5_scratch where key = 'job_payout');
  v_batch    uuid;
  v_payout   uuid;
  v_ledger   uuid;
  v_net      numeric(14,2);
  v_tax      numeric(14,2);
  v_batch_status text;
  v_payout_status text;
begin
  v_ledger := public.calculate_and_record_commission(v_job);
  v_tax := public.apply_withholding_tax(v_job);
  select driver_net_earning into v_net from public.commission_ledger where id = v_ledger;

  v_batch := public.create_payout_batch(
    '33333333-0000-4000-8000-000000000001',
    now() - interval '10 days',
    now() - interval '4 days'
  );

  select p.id into v_payout
  from public.payouts p
  where p.batch_id = v_batch
    and p.driver_id = 'd0000000-0000-4000-8000-000000000003'
  order by p.created_at desc
  limit 1;

  if v_payout is not null then
    perform public.execute_payout(v_payout);
  end if;

  select status into v_batch_status from public.payout_batches where id = v_batch;
  select status into v_payout_status from public.payouts where id = v_payout;

  insert into _phase5_scratch (key, id) values ('payout_batch', v_batch)
  on conflict (key) do update set id = excluded.id;
  if v_payout is not null then
    insert into _phase5_scratch (key, id) values ('payout', v_payout)
    on conflict (key) do update set id = excluded.id;
  end if;

  insert into _phase5_verification values (
    24, 'create_payout_batch aggregates commission ledger into a payout and item',
    case when v_batch is not null
              and exists (select 1 from public.payouts where batch_id = v_batch)
              and exists (
                select 1 from public.payout_items pi
                join public.payouts p on p.id = pi.payout_id
                where p.batch_id = v_batch
              )
         then 'PASS' else 'FAIL' end,
    'batch=' || coalesce(v_batch::text, 'null') || ', payout=' || coalesce(v_payout::text, 'null')
  );

  insert into _phase5_verification values (
    25, 'execute_payout completes the payout, closes the batch and debits the wallet',
    case when v_payout_status = 'completed'
              and v_batch_status = 'completed'
              and exists (
                select 1 from public.wallet_transactions wt
                where wt.reference_id = v_payout and wt.reference_type = 'payout'
                  and wt.transaction_type = 'payout' and wt.amount < 0
              )
         then 'PASS' else 'FAIL' end,
    'payout=' || coalesce(v_payout_status, 'null') || ', batch=' || coalesce(v_batch_status, 'null')
  );
end $$;

-- ----------------------------------------------------------------------------
-- 15. Invoice generation
-- ----------------------------------------------------------------------------
do $$
declare
  v_job      uuid := (select id from _phase5_scratch where key = 'job_invoice');
  v_quote    uuid;
  v_invoice  uuid;
  v_lines    integer;
  v_total    numeric(14,2);
  v_expected numeric(14,2);
  v_completed timestamptz;
begin
  select quote_id, completed_at into v_quote, v_completed
  from public.jobs where id = v_job;
  select total into v_expected from public.quotes where id = v_quote;

  v_invoice := public.generate_invoice(
    'b0000000-0000-4000-8000-000000000001',
    v_completed - interval '1 second',
    v_completed + interval '1 second'
  );

  select count(*) into v_lines
  from public.invoice_line_items where invoice_id = v_invoice;

  select total into v_total from public.invoices where id = v_invoice;

  insert into _phase5_scratch (key, id) values ('invoice', v_invoice)
  on conflict (key) do update set id = excluded.id;

  insert into _phase5_verification values (
    26, 'generate_invoice creates a draft invoice with job line items',
    case when v_invoice is not null and v_lines >= 1 and v_total = v_expected
         then 'PASS' else 'FAIL' end,
    'invoice=' || coalesce(v_invoice::text, 'null') || ', lines=' || v_lines::text
  );
end $$;

-- ----------------------------------------------------------------------------
-- 16. Wallet verification and nightly acceptance recompute
-- ----------------------------------------------------------------------------
insert into _phase5_verification (check_no, check_name, status, details)
select 27, 'verify_all_wallet_balances returns zero mismatches',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*) || ' mismatch(es)'
from public.verify_all_wallet_balances() where matches = false;

do $$
declare
  v_count integer;
  v_stats integer;
begin
  v_count := public.recompute_all_driver_acceptance_stats();
  select count(*) into v_stats from public.driver_acceptance_stats;

  insert into _phase5_verification values (
    28, 'Nightly acceptance recompute updates every driver',
    case when v_count > 0 and v_stats >= v_count then 'PASS' else 'FAIL' end,
    v_count || ' driver(s), ' || v_stats || ' stats row(s)'
  );

  perform public.expire_stale_offers();

  insert into _phase5_verification values (
    29, 'expire_stale_offers is callable from the cron path',
    'PASS', 'call completed'
  );
end $$;

-- ----------------------------------------------------------------------------
-- 17. Immutability triggers
-- ----------------------------------------------------------------------------
do $$
declare
  v_blocked integer := 0;
  v_error   text;
  v_payment uuid := (select id from _phase5_scratch where key = 'payment_cancel');
  v_ledger  uuid := (select id from _phase5_scratch where key = 'ledger_default');
  v_webhook bigint;
begin
  begin
    update public.payments set amount = amount + 1 where id = v_payment;
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    update public.wallet_transactions set amount = amount + 1
    where id = (select min(id) from public.wallet_transactions);
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    delete from public.commission_ledger where id = v_ledger;
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    update public.payout_items set amount = amount + 1
    where id = (select min(id) from public.payout_items);
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    update public.fleet_billing_events set fleet_commission_amount = fleet_commission_amount + 1
    where id = (select min(id) from public.fleet_billing_events);
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  insert into public.payment_webhooks (
    provider_id, event_type, event_id, provider_reference, payload, signature_valid
  ) values (
    '5b000000-0000-4000-8000-000000000001', 'verification.event',
    'verify-webhook-' || replace(gen_random_uuid()::text, '-', ''),
    'verify-pay-reference', '{"check":true}'::jsonb, true
  )
  returning id into v_webhook;

  begin
    update public.payment_webhooks set payload = '{"tampered":true}'::jsonb
    where id = v_webhook;
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    update public.payment_webhooks
       set processing_status = 'processed', processed_at = now()
     where id = v_webhook;
    -- This transition is allowed and must not count as blocked.
  exception when others then
    v_blocked := v_blocked + 1;
    v_error := sqlerrm;
  end;

  insert into _phase5_verification values (
    30, 'Immutability triggers block financial-field UPDATE/DELETE',
    case when v_blocked = 6 then 'PASS' else 'FAIL' end,
    v_blocked || ' of 6 blocked; last=' || coalesce(v_error, 'none')
  );
end $$;

-- ----------------------------------------------------------------------------
-- 18. RLS: own reads allowed, direct client writes blocked
-- ----------------------------------------------------------------------------
do $$
declare
  v_customer uuid := (select id from _phase5_scratch where key = 'customer');
  v_blocked integer := 0;
  v_error text;
  v_own integer;
  v_other integer;
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', v_customer::text, 'role', 'authenticated'
  )::text, true);
  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  select count(*) into v_own from public.payments where customer_id = v_customer;
  select count(*) into v_other from public.payments
  where customer_id = 'c0000000-0000-4000-8000-000000000002';

  begin
    insert into public.payments (job_id, customer_id, provider_id, amount, currency_code)
    values ((select id from _phase5_scratch where key = 'job_pay'), v_customer,
            '5b000000-0000-4000-8000-000000000001', 1.00, 'TZS');
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    update public.wallets set cached_balance = 0
    where id = (select id from public.wallets where profile_id = v_customer limit 1);
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    delete from public.refunds where id = '60000000-0000-4000-8000-000000000001';
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    insert into public.commission_ledger (
      job_id, driver_id, commission_amount, currency_code,
      driver_gross_earning, driver_net_earning, calculated_at
    ) values ((select id from _phase5_scratch where key = 'job_pay'),
              'd0000000-0000-4000-8000-000000000001', 0, 'TZS', 0, 0, now());
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    insert into public.payouts (
      driver_id, period_start, period_end, amount, currency_code,
      gross_earnings, net_amount
    ) values ('d0000000-0000-4000-8000-000000000001', now() - interval '2 days',
              now() - interval '1 day', 1, 'TZS', 1, 1);
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  begin
    insert into public.invoices (
      business_account_id, invoice_number, currency_code, period_start,
      period_end, total
    ) values ('b0000000-0000-4000-8000-000000000001',
              'CLIENT-' || replace(gen_random_uuid()::text, '-', ''), 'TZS',
              now() - interval '2 days', now() - interval '1 day', 1);
  exception when others then v_blocked := v_blocked + 1; v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase5_verification values (
    31, 'RLS lets a customer read own payments but not another customer''s',
    case when v_own > 0 and v_other = 0 then 'PASS' else 'FAIL' end,
    'own=' || v_own || ', other=' || v_other
  );

  insert into _phase5_verification values (
    32, 'RLS/grants block direct client writes to every money table',
    case when v_blocked = 6 then 'PASS' else 'FAIL' end,
    v_blocked || ' of 6 writes blocked; last=' || coalesce(v_error, 'none')
  );
exception when others then
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  insert into _phase5_verification values (
    32, 'RLS/grants block direct client writes to every money table',
    'FAIL', sqlerrm
  );
end $$;

-- ----------------------------------------------------------------------------
-- 19. Results
-- ----------------------------------------------------------------------------
select
  check_no,
  lpad(check_no::text, 2, '0') as no,
  check_name,
  status,
  details
from _phase5_verification
order by check_no, check_name;

select
  'PHASE 5 SCHEMA VERIFICATION: '
  || count(*) filter (where status = 'PASS')::text || ' PASS, '
  || count(*) filter (where status = 'FAIL')::text || ' FAIL' as result
from _phase5_verification;
