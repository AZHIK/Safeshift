-- ============================================================================
-- SafeShift — Phase 5 / Migration 0096
-- Finance read models. Every view uses security_invoker so base-table RLS
-- remains in force for the caller.
-- ============================================================================

create or replace view public.job_payment_summary
with (security_invoker = true)
as
select
  j.id as job_id,
  p.full_name as customer_name,
  j.payment_status,
  coalesce(sum(pay.amount) filter (
    where pay.payment_type = 'charge' and pay.provider_status = 'succeeded'
  ), 0)::numeric(14,2) as total_paid,
  coalesce((
    select sum(r.amount) from public.refunds r
    where r.job_id = j.id and r.status = 'succeeded'
  ), 0)::numeric(14,2) as total_refunded,
  coalesce(cl.commission_amount, 0)::numeric(14,2) as commission_amount,
  coalesce(cl.driver_net_earning, 0)::numeric(14,2) as driver_net_earning,
  coalesce(j.final_currency_code, q.currency_code) as currency_code
from public.jobs j
join public.quotes q on q.id = j.quote_id
join public.profiles p on p.id = j.customer_id
left join public.payments pay on pay.job_id = j.id
left join public.commission_ledger cl on cl.job_id = j.id
group by j.id, p.full_name, j.payment_status, q.currency_code,
         cl.commission_amount, cl.driver_net_earning, j.final_currency_code;

comment on view public.job_payment_summary is
  'Per-job captured/refunded totals with commission and driver net earning.';

create or replace view public.driver_earnings_summary
with (security_invoker = true)
as
with ledger as (
  select
    cl.driver_id,
    cl.calculated_at,
    cl.driver_gross_earning,
    cl.commission_amount,
    cl.withholding_tax_amount,
    cl.driver_net_earning - cl.withholding_tax_amount as net_earning
  from public.commission_ledger cl
  where cl.is_refunded = false
),
buckets as (
  select driver_id, 'day'::text as period, date_trunc('day', calculated_at) as period_start,
         driver_gross_earning, commission_amount, withholding_tax_amount, net_earning
  from ledger
  union all
  select driver_id, 'week'::text, date_trunc('week', calculated_at),
         driver_gross_earning, commission_amount, withholding_tax_amount, net_earning
  from ledger
  union all
  select driver_id, 'month'::text, date_trunc('month', calculated_at),
         driver_gross_earning, commission_amount, withholding_tax_amount, net_earning
  from ledger
)
select
  b.driver_id,
  b.period,
  b.period_start,
  coalesce(sum(b.driver_gross_earning), 0)::numeric(14,2) as gross_earnings,
  coalesce(sum(b.commission_amount), 0)::numeric(14,2) as commissions_deducted,
  coalesce(sum(b.withholding_tax_amount), 0)::numeric(14,2) as withholding_tax,
  coalesce(sum(b.net_earning), 0)::numeric(14,2) as net_earnings,
  (
    select p.status
    from public.payouts p
    where p.driver_id = b.driver_id
    order by p.initiated_at desc
    limit 1
  ) as payout_status
from buckets b
group by b.driver_id, b.period, b.period_start;

comment on view public.driver_earnings_summary is
  'Driver earnings by day/week/month with the latest payout status.';

create or replace view public.wallet_balance_current
with (security_invoker = true)
as
select
  w.id as wallet_id,
  p.full_name as profile_name,
  w.currency_code,
  w.cached_balance,
  (
    select max(wt.created_at)
    from public.wallet_transactions wt
    where wt.wallet_id = w.id
  ) as last_transaction_at
from public.wallets w
join public.profiles p on p.id = w.profile_id;

comment on view public.wallet_balance_current is
  'Current wallet cache with the latest ledger timestamp.';

create or replace view public.payout_batch_summary
with (security_invoker = true)
as
select
  pb.id as batch_id,
  c.name as country,
  pb.period_start,
  pb.period_end,
  pb.driver_count,
  pb.total_amount,
  pb.currency_code,
  pb.status
from public.payout_batches pb
join public.countries c on c.id = pb.country_id;

comment on view public.payout_batch_summary is
  'Payout batch totals by country and period.';

create or replace view public.invoice_summary
with (security_invoker = true)
as
select
  i.id as invoice_id,
  coalesce(b.trading_name, b.legal_name) as business_name,
  i.invoice_number,
  i.total,
  i.status,
  i.issued_at,
  i.due_at,
  case
    when i.status in ('paid', 'cancelled', 'refunded') or i.due_at is null then 0
    else greatest(0, current_date - i.due_at::date)
  end as days_overdue
from public.invoices i
join public.business_accounts b on b.id = i.business_account_id;

comment on view public.invoice_summary is
  'Invoice list with business name and overdue-day count.';

create or replace view public.payment_reconciliation
with (security_invoker = true)
as
select
  p.id as payment_id,
  p.job_id,
  pp.name as provider,
  p.amount,
  p.provider_status,
  count(w.id)::integer as webhook_count,
  max(w.received_at) as last_webhook_at,
  (
    p.provider_status in ('succeeded', 'failed', 'cancelled')
    and count(w.id) > 0
  ) as is_reconciled
from public.payments p
join public.payment_providers pp on pp.id = p.provider_id
left join public.payment_webhooks w
  on w.provider_id = p.provider_id
 and w.provider_reference = p.provider_reference
group by p.id, p.job_id, pp.name, p.amount, p.provider_status;

comment on view public.payment_reconciliation is
  'Payment-to-webhook reconciliation: terminal provider state plus at least one logged webhook.';

revoke all on
  public.job_payment_summary,
  public.driver_earnings_summary,
  public.wallet_balance_current,
  public.payout_batch_summary,
  public.invoice_summary,
  public.payment_reconciliation
from anon, authenticated;

grant select on
  public.job_payment_summary,
  public.driver_earnings_summary,
  public.wallet_balance_current,
  public.payout_batch_summary,
  public.invoice_summary,
  public.payment_reconciliation
to authenticated;
