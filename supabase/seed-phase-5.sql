-- ============================================================================
-- PHASE 5 SEED — run after seed-phase-4.sql.
-- Local/service-role execution only.
--
-- Demonstrates the money layer:
--   2 payment providers, 3 saved methods, 2 tax rates, 3 commission rules
--   2 charge payments + 1 refund payment, 1 succeeded refund
--   5 wallets (3 customers, 1 driver, 1 platform) with 10 ledger entries
--   1 commission-ledger row, 1 draft payout batch, 1 pending payout/item
--   1 draft business invoice with 3 lines, 1 fleet billing accrual
--
-- The platform profile is created idempotently by migration 0090. The wallet
-- and all financial movements are seeded here.
-- ============================================================================

set search_path = public, extensions;

begin;

-- ---------------------------------------------------------------------------
-- 1. Payment providers (per country).
-- ---------------------------------------------------------------------------
insert into public.payment_providers (
  id, country_id, code, name, provider_type, webhook_secret_reference,
  supports_refunds, supports_partial_refunds, supports_payouts, config, is_active
) values
  (
    '5b000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    'selcom', 'Selcom', 'mobile_money_aggregator',
    'selcom_webhook_secret', true, true, true,
    '{"settlement":"T+1","methods":["mpesa","tigopesa","airtelmoney","halopesa"]}'::jsonb,
    true
  ),
  (
    '5b000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    'flutterwave', 'Flutterwave', 'card_processor',
    'flutterwave_webhook_secret', true, true, false,
    '{"settlement":"T+2","methods":["card"]}'::jsonb,
    true
  );

-- ---------------------------------------------------------------------------
-- 2. Saved payment methods.
-- ---------------------------------------------------------------------------
insert into public.payment_methods (
  id, profile_id, provider_id, method_type, display_name, provider_token,
  provider_customer_id, is_default, is_active, last_used_at, metadata
) values
  (
    '5c000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    '5b000000-0000-4000-8000-000000000001',
    'mpesa', 'M-Pesa ••• 4567', 'tok_mpesa_c1', 'cust_c1',
    true, true, now() - interval '3 days',
    '{"network":"Vodacom"}'::jsonb
  ),
  (
    '5c000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000002',
    '5b000000-0000-4000-8000-000000000001',
    'airtelmoney', 'Airtel Money ••• 8899', 'tok_airtel_c2', 'cust_c2',
    true, true, now() - interval '2 hours',
    '{"network":"Airtel"}'::jsonb
  ),
  (
    '5c000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000001',
    '5b000000-0000-4000-8000-000000000001',
    'mpesa', 'Driver payout M-Pesa ••• 1122', 'tok_payout_d1', 'driver_d1',
    true, true, now() - interval '3 days',
    '{"purpose":"payout"}'::jsonb
  );

-- ---------------------------------------------------------------------------
-- 3. Tax rates: 18% VAT on customer charges, 5% withholding on payouts.
-- ---------------------------------------------------------------------------
insert into public.tax_rates (
  id, country_id, tax_type, name, rate, applies_to,
  effective_from, is_active, notes
) values
  (
    '5d000000-0000-4000-8000-000000000001',
    '33333333-0000-4000-8000-000000000001',
    'vat', 'Tanzania VAT', 0.1800, 'customer_charge',
    now() - interval '30 days', true,
    'VAT on the gross customer fare, already included in persisted quote totals.'
  ),
  (
    '5d000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    'withholding', 'Withholding on Transport Services', 0.0500, 'driver_payout',
    now() - interval '30 days', true,
    'Withholding tax applied to the driver net earning and recorded separately.'
  );

-- ---------------------------------------------------------------------------
-- 4. Commission rules.
-- ---------------------------------------------------------------------------
insert into public.commission_rules (
  id, country_id, city_id, vehicle_type_id, fleet_id, driver_id,
  commission_type, commission_value, min_commission, max_commission,
  priority, effective_from, is_active
) values
  (
    '5e000000-0000-4000-8000-000000000001',
    null, null, null, null, null,
    'percentage', 12.0000, 0, null, 0,
    now() - interval '30 days', true
  ),
  (
    '5e000000-0000-4000-8000-000000000002',
    '33333333-0000-4000-8000-000000000001',
    '55555555-0000-4000-8000-000000000001',
    '22000000-0000-4000-8000-000000000003',
    null, null,
    'percentage', 10.0000, 0, null, 10,
    now() - interval '30 days', true
  ),
  (
    '5e000000-0000-4000-8000-000000000003',
    '33333333-0000-4000-8000-000000000001',
    null, null,
    '0f1e2d3c-4b5a-4968-8776-655443322110', null,
    'percentage', 8.0000, 0, null, 20,
    now() - interval '30 days', true
  );

-- Keep the Phase 2 fleet column consistent with the Phase 5 fleet rule.
update public.fleets
   set commission_rate_override = 8.00,
       updated_at = now()
 where id = '0f1e2d3c-4b5a-4968-8776-655443322110';

-- ---------------------------------------------------------------------------
-- 5. Payments: J1 succeeded charge, J2 pending charge, J3 refund payment.
--    The refund payment is linked to the cancelled J3 through refunds.job_id;
--    the original charge row is the completed J1 charge because Phase 4's J3
--    was cancelled before capture.
-- ---------------------------------------------------------------------------
insert into public.payments (
  id, job_id, customer_id, payment_method_id, provider_id, amount,
  currency_code, provider_reference, provider_status, payment_type,
  refund_of_payment_id, completed_at, metadata, created_at
) values
  (
    '5f000000-0000-4000-8000-000000000001',
    '4f000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    '5c000000-0000-4000-8000-000000000001',
    '5b000000-0000-4000-8000-000000000001',
    (select total from public.quotes where id = '4e000000-0000-4000-8000-000000000001'),
    'TZS', 'seed-charge-j1', 'succeeded', 'charge', null,
    now() - interval '3 days' + interval '55 minutes',
    '{"source":"seed-phase-5","capture":"simulated"}'::jsonb,
    now() - interval '3 days' + interval '55 minutes'
  ),
  (
    '5f000000-0000-4000-8000-000000000002',
    '4f000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000002',
    '5c000000-0000-4000-8000-000000000002',
    '5b000000-0000-4000-8000-000000000001',
    (select total from public.quotes where id = '4e000000-0000-4000-8000-000000000002'),
    'TZS', 'seed-charge-j2', 'pending', 'charge', null,
    null,
    '{"source":"seed-phase-5","capture":"awaiting_webhook"}'::jsonb,
    now() - interval '2 hours'
  ),
  (
    '5f000000-0000-4000-8000-000000000003',
    '4f000000-0000-4000-8000-000000000003',
    'c0000000-0000-4000-8000-000000000002',
    '5c000000-0000-4000-8000-000000000002',
    '5b000000-0000-4000-8000-000000000001',
    5000.00, 'TZS', 'seed-refund-j3', 'succeeded', 'refund',
    '5f000000-0000-4000-8000-000000000001',
    now() - interval '10 minutes',
    '{"source":"seed-phase-5","refund_type":"goodwill"}'::jsonb,
    now() - interval '10 minutes'
  );

insert into public.refunds (
  id, payment_id, refund_payment_id, job_id, reason, requested_by,
  amount, currency_code, status, refund_type, provider_reference, completed_at,
  created_at
) values (
  '60000000-0000-4000-8000-000000000001',
  '5f000000-0000-4000-8000-000000000001',
  '5f000000-0000-4000-8000-000000000003',
  '4f000000-0000-4000-8000-000000000003',
  'Goodwill cancellation refund for the undelivered job.',
  'c0000000-0000-4000-8000-000000000002',
  5000.00, 'TZS', 'succeeded', 'goodwill', 'seed-refund-j3',
  now() - interval '10 minutes', now() - interval '10 minutes'
);

-- ---------------------------------------------------------------------------
-- 6. Wallets: 3 customers, driver, platform.
-- ---------------------------------------------------------------------------
insert into public.wallets (id, profile_id, currency_code) values
  ('61000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'TZS'),
  ('61000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002', 'TZS'),
  ('61000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000003', 'TZS'),
  ('61000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000001', 'TZS'),
  ('61000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000000', 'TZS');

-- ---------------------------------------------------------------------------
-- 7. Computed money fixtures: ledger, wallet movements, payout, fleet accrual.
-- ---------------------------------------------------------------------------
do $$
declare
  v_total1   numeric(14,2) := (select total from public.quotes where id = '4e000000-0000-4000-8000-000000000001');
  v_total2   numeric(14,2) := (select total from public.quotes where id = '4e000000-0000-4000-8000-000000000002');
  v_comm     numeric(14,2) := round((select total from public.quotes where id = '4e000000-0000-4000-8000-000000000001') * 0.1200, 2);
  v_net      numeric(14,2);
  v_wh       numeric(14,2);
  v_pay_net  numeric(14,2);
  v_calc_at  timestamptz := now() - interval '3 days' + interval '55 minutes';
  v_week     timestamptz := date_trunc('week', now());
  v_ledger   uuid := '62000000-0000-4000-8000-000000000001';
  v_batch    uuid := '63000000-0000-4000-8000-000000000001';
  v_payout   uuid := '64000000-0000-4000-8000-000000000001';
begin
  v_net := round(v_total1 - v_comm, 2);
  v_wh := round(v_net * 0.0500, 2);
  v_pay_net := round(v_net - v_wh, 2);

  insert into public.commission_ledger (
    id, job_id, driver_id, rule_id, commission_amount, commission_rate,
    currency_code, driver_gross_earning, driver_net_earning,
    withholding_tax_amount, is_refunded, calculated_at, created_at
  ) values (
    v_ledger,
    '4f000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000001',
    '5e000000-0000-4000-8000-000000000001',
    v_comm, 0.1200, 'TZS', v_total1, v_net, v_wh, false, v_calc_at, v_calc_at
  );

  insert into public.wallet_transactions (
    wallet_id, transaction_type, amount, currency_code, balance_after,
    reference_type, reference_id, description, created_at
  ) values
    ('61000000-0000-4000-8000-000000000001', 'topup', 100000.00, 'TZS', 0,
     'topup', null, 'Seed customer 1 top-up', now() - interval '5 days'),
    ('61000000-0000-4000-8000-000000000002', 'topup', 200000.00, 'TZS', 0,
     'topup', null, 'Seed customer 2 top-up', now() - interval '5 days'),
    ('61000000-0000-4000-8000-000000000003', 'topup', 50000.00, 'TZS', 0,
     'topup', null, 'Seed customer 3 top-up', now() - interval '5 days'),
    ('61000000-0000-4000-8000-000000000005', 'topup', 100000.00, 'TZS', 0,
     'topup', null, 'Seed platform float', now() - interval '5 days'),
    ('61000000-0000-4000-8000-000000000001', 'payment', -v_total1, 'TZS', 0,
     'job', '4f000000-0000-4000-8000-000000000001', 'Payment for completed job J1',
     now() - interval '3 days' + interval '55 minutes'),
    ('61000000-0000-4000-8000-000000000002', 'payment', -v_total2, 'TZS', 0,
     'job', '4f000000-0000-4000-8000-000000000002', 'Payment hold for in-transit job J2',
     now() - interval '2 hours'),
    ('61000000-0000-4000-8000-000000000004', 'driver_earning', v_net, 'TZS', 0,
     'job', '4f000000-0000-4000-8000-000000000001', 'Driver earning for completed job J1',
     now() - interval '3 days' + interval '55 minutes'),
    ('61000000-0000-4000-8000-000000000005', 'commission_deduction', v_comm, 'TZS', 0,
     'job', '4f000000-0000-4000-8000-000000000001', 'Platform commission for J1',
     now() - interval '3 days' + interval '55 minutes'),
    ('61000000-0000-4000-8000-000000000005', 'withholding_tax', v_wh, 'TZS', 0,
     'job', '4f000000-0000-4000-8000-000000000001', 'Withholding tax recorded for J1',
     now() - interval '3 days' + interval '55 minutes'),
    ('61000000-0000-4000-8000-000000000002', 'refund', 5000.00, 'TZS', 0,
     'payment', '5f000000-0000-4000-8000-000000000003', 'Goodwill refund for cancelled job J3',
     now() - interval '10 minutes');

  insert into public.fleet_billing_events (
    fleet_id, job_id, commission_ledger_id, commission_calculated_at,
    fleet_commission_rate, fleet_commission_amount, currency_code, accrued_at
  ) values (
    '0f1e2d3c-4b5a-4968-8776-655443322110',
    '4f000000-0000-4000-8000-000000000001',
    v_ledger, v_calc_at, 8.00, round(v_total1 * 0.0800, 2), 'TZS', v_calc_at
  );

  insert into public.payout_batches (
    id, country_id, period_start, period_end, status, total_amount,
    currency_code, driver_count, initiated_by, created_at, updated_at
  ) values (
    v_batch,
    '33333333-0000-4000-8000-000000000001',
    v_week, v_week + interval '7 days', 'draft', v_pay_net,
    'TZS', 1, 'a0000000-0000-4000-8000-000000000002',
    now() - interval '1 hour', now() - interval '1 hour'
  );

  insert into public.payouts (
    id, batch_id, driver_id, period_start, period_end, amount, currency_code,
    gross_earnings, commission_deducted, withholding_tax, net_amount,
    payment_provider_id, payment_method_id, status, initiated_at
  ) values (
    v_payout, v_batch, 'd0000000-0000-4000-8000-000000000001',
    v_week, v_week + interval '7 days', v_pay_net, 'TZS',
    v_total1, v_comm, v_wh, v_pay_net,
    '5b000000-0000-4000-8000-000000000001',
    '5c000000-0000-4000-8000-000000000003',
    'pending', now() - interval '1 hour'
  );

  insert into public.payout_items (
    id, payout_id, commission_ledger_id, commission_calculated_at, job_id, amount
  ) values (
    '65000000-0000-4000-8000-000000000001',
    v_payout, v_ledger, v_calc_at,
    '4f000000-0000-4000-8000-000000000001', v_pay_net
  );
end $$;

-- ---------------------------------------------------------------------------
-- 8. Business invoice and three lines.
-- ---------------------------------------------------------------------------
insert into public.invoices (
  id, business_account_id, invoice_number, currency_code,
  period_start, period_end, subtotal, tax_amount, total, amount_paid,
  status, issued_at, due_at, notes
) values (
  '66000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'INV-2026-0001', 'TZS',
  now() - interval '30 days', now(),
  100000.00, 18000.00, 118000.00, 0.00,
  'draft', now(), now() + interval '30 days',
  'Seed draft invoice for Kilimanjaro Fresh Produce.'
);

insert into public.invoice_line_items (
  id, invoice_id, description, quantity, unit_price, amount, job_id
) values
  (
    '67000000-0000-4000-8000-000000000001',
    '66000000-0000-4000-8000-000000000001',
    'Weekly distribution runs — Dar es Salaam', 2.00, 30000.00, 60000.00, null
  ),
  (
    '67000000-0000-4000-8000-000000000002',
    '66000000-0000-4000-8000-000000000001',
    'Cold-chain packing materials', 1.00, 20000.00, 20000.00, null
  ),
  (
    '67000000-0000-4000-8000-000000000003',
    '66000000-0000-4000-8000-000000000001',
    'Loading and handling', 1.00, 20000.00, 20000.00, null
  );

-- ---------------------------------------------------------------------------
-- 9. Cache verification: fail the seed if any wallet cache drifted.
-- ---------------------------------------------------------------------------
do $$
declare
  v_drift integer;
begin
  select count(*) into v_drift
  from public.verify_all_wallet_balances()
  where matches = false;

  if v_drift > 0 then
    raise exception 'wallet cache drift after Phase 5 seed: % wallet(s)', v_drift;
  end if;
end $$;

commit;
