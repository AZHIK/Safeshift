-- ============================================================================
-- SafeShift — Phase 5 / Migration 0093
-- Reconciliation, ledger and payout indexes.
-- ============================================================================

-- Providers and methods.
create index idx_payment_methods_profile_active
  on public.payment_methods (profile_id)
  where is_active;

create unique index uq_payment_methods_default
  on public.payment_methods (profile_id)
  where is_default and is_active;

create index idx_payment_methods_provider
  on public.payment_methods (provider_id);

-- Payments and refunds.
create index idx_payments_job
  on public.payments (job_id);

create index idx_payments_customer_created
  on public.payments (customer_id, created_at desc);

create unique index uq_payments_provider_reference
  on public.payments (provider_reference)
  where provider_reference is not null;

create index idx_payments_status_open
  on public.payments (provider_status)
  where provider_status in ('initiated', 'pending');

create index idx_payments_refund_of
  on public.payments (refund_of_payment_id)
  where refund_of_payment_id is not null;

create index idx_refunds_payment
  on public.refunds (payment_id);

create index idx_refunds_job
  on public.refunds (job_id);

create index idx_refunds_status_open
  on public.refunds (status)
  where status in ('requested', 'processing');

-- Webhooks.
create unique index uq_payment_webhooks_provider_event
  on public.payment_webhooks (provider_id, event_id, received_at)
  where event_id is not null;

create index idx_payment_webhooks_pending
  on public.payment_webhooks (processing_status)
  where processing_status = 'pending';

create index idx_payment_webhooks_provider_received
  on public.payment_webhooks (provider_id, received_at desc);

-- Wallets and ledger.
create index idx_wallet_transactions_wallet_created
  on public.wallet_transactions (wallet_id, created_at desc);

create index idx_wallet_transactions_reference
  on public.wallet_transactions (reference_type, reference_id);

-- Commission rules and ledger.
create index idx_commission_rules_active_scope
  on public.commission_rules (country_id, city_id, vehicle_type_id, fleet_id, driver_id)
  where is_active;

create index idx_commission_rules_active_priority
  on public.commission_rules (priority desc)
  where is_active;

create index idx_commission_rules_effective
  on public.commission_rules (effective_from desc);

create index idx_commission_ledger_job
  on public.commission_ledger (job_id);

create index idx_commission_ledger_driver_calculated
  on public.commission_ledger (driver_id, calculated_at desc);

create index idx_commission_ledger_unrefunded
  on public.commission_ledger (is_refunded)
  where is_refunded = false;

-- Tax rates.
create index idx_tax_rates_active_scope
  on public.tax_rates (country_id, tax_type, applies_to)
  where is_active;

-- Payouts.
create index idx_payout_batches_country_period
  on public.payout_batches (country_id, period_start desc);

create index idx_payout_batches_open
  on public.payout_batches (status)
  where status in ('draft', 'processing');

create index idx_payouts_batch
  on public.payouts (batch_id);

create index idx_payouts_driver_period
  on public.payouts (driver_id, period_start desc);

create index idx_payouts_open
  on public.payouts (status)
  where status in ('pending', 'processing');

create index idx_payout_items_payout
  on public.payout_items (payout_id);

-- Invoices.
create index idx_invoices_business_issued
  on public.invoices (business_account_id, issued_at desc);

create index idx_invoices_open
  on public.invoices (status)
  where status in ('draft', 'sent', 'overdue');

create index idx_invoice_line_items_invoice
  on public.invoice_line_items (invoice_id);

create index idx_invoice_line_items_job
  on public.invoice_line_items (job_id)
  where job_id is not null;

-- Fleet billing.
create index idx_fleet_billing_events_fleet_accrued
  on public.fleet_billing_events (fleet_id, accrued_at desc);
