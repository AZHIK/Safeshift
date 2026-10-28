-- ============================================================================
-- SafeShift — Phase 5 / Migration 0094
-- RLS, permissions and privileges for every Phase 5 table.
--
-- Policies use the cached (select auth.uid()) form. No money table receives a
-- client INSERT, UPDATE or DELETE grant. Admin-managed catalogues receive only
-- insert/update grants; the financial tables are service/function written.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Permissions
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_payments',           'Manage payment providers and payment configuration', 'finance'),
  ('view_all_payment_methods',  'View every saved payment method',                    'finance'),
  ('process_refunds',           'Create and process refunds',                         'finance'),
  ('view_all_payments',         'View every payment attempt',                         'finance'),
  ('view_payment_webhooks',     'View raw provider webhook logs',                     'finance'),
  ('view_all_refunds',          'View every refund',                                  'finance'),
  ('view_all_wallets',          'View every wallet and wallet ledger',                'finance'),
  ('manage_commission',         'Manage commission rules',                            'finance'),
  ('view_all_commissions',      'View every commission ledger entry',                 'finance'),
  ('manage_taxes',              'Manage country tax rates',                           'compliance'),
  ('view_payouts',              'View payout batches and driver payouts',             'finance'),
  ('process_payouts',           'Create and execute payouts',                         'finance'),
  ('view_invoices',             'View all business invoices',                         'finance'),
  ('manage_invoices',           'Generate and manage business invoices',              'finance'),
  ('view_fleet_billing',        'View fleet commission accruals',                     'finance')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'manage_payments', 'view_all_payment_methods', 'process_refunds', 'view_all_payments',
  'view_payment_webhooks', 'view_all_refunds', 'view_all_wallets', 'manage_commission',
  'view_all_commissions', 'manage_taxes', 'view_payouts', 'process_payouts',
  'view_invoices', 'manage_invoices', 'view_fleet_billing'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('finance_admin', 'manage_payments'),
  ('finance_admin', 'view_all_payment_methods'),
  ('finance_admin', 'process_refunds'),
  ('finance_admin', 'view_all_payments'),
  ('finance_admin', 'view_payment_webhooks'),
  ('finance_admin', 'view_all_refunds'),
  ('finance_admin', 'view_all_wallets'),
  ('finance_admin', 'manage_commission'),
  ('finance_admin', 'view_all_commissions'),
  ('finance_admin', 'manage_taxes'),
  ('finance_admin', 'view_payouts'),
  ('finance_admin', 'process_payouts'),
  ('finance_admin', 'view_invoices'),
  ('finance_admin', 'manage_invoices'),
  ('finance_admin', 'view_fleet_billing'),
  ('operations_admin', 'view_all_payment_methods'),
  ('operations_admin', 'view_all_payments'),
  ('operations_admin', 'view_all_wallets'),
  ('operations_admin', 'view_payouts'),
  ('operations_admin', 'view_invoices'),
  ('operations_admin', 'view_fleet_billing'),
  ('support_agent', 'view_all_payment_methods'),
  ('support_agent', 'view_all_payments'),
  ('support_agent', 'view_all_refunds'),
  ('support_agent', 'view_all_wallets'),
  ('support_agent', 'view_invoices'),
  ('analyst', 'view_all_payments'),
  ('analyst', 'view_all_commissions'),
  ('analyst', 'view_all_wallets'),
  ('analyst', 'view_payouts'),
  ('analyst', 'view_invoices'),
  ('analyst', 'view_fleet_billing')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 2. RLS enablement
-- ----------------------------------------------------------------------------
-- Supabase's base image normally grants schema usage. Re-state it here so a
-- schema-first reset cannot leave client roles unable to reach these policies.
grant usage on schema public to anon, authenticated, service_role;

alter table public.payment_providers      enable row level security;
alter table public.payment_methods        enable row level security;
alter table public.payments               enable row level security;
alter table public.payment_webhooks       enable row level security;
alter table public.refunds                enable row level security;
alter table public.wallets                enable row level security;
alter table public.wallet_transactions    enable row level security;
alter table public.commission_rules       enable row level security;
alter table public.commission_ledger      enable row level security;
alter table public.tax_rates              enable row level security;
alter table public.payout_batches         enable row level security;
alter table public.payouts                enable row level security;
alter table public.payout_items           enable row level security;
alter table public.invoices               enable row level security;
alter table public.invoice_line_items     enable row level security;
alter table public.fleet_billing_events   enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Policies
-- ----------------------------------------------------------------------------
create policy payment_providers_select_authenticated
  on public.payment_providers for select to authenticated
  using (true);

create policy payment_providers_manage
  on public.payment_providers for all to authenticated
  using ((select public.has_permission('manage_payments')))
  with check ((select public.has_permission('manage_payments')));

create policy payment_methods_select_own_or_staff
  on public.payment_methods for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('view_all_payment_methods'))
  );

create policy payment_methods_update_own_flags
  on public.payment_methods for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy payments_select_own_or_staff
  on public.payments for select to authenticated
  using (
    customer_id = (select auth.uid())
    or (select public.has_permission('view_all_payments'))
  );

create policy payment_webhooks_select_webhook_staff
  on public.payment_webhooks for select to authenticated
  using ((select public.has_permission('view_payment_webhooks')));

create policy refunds_select_requester_or_staff
  on public.refunds for select to authenticated
  using (
    requested_by = (select auth.uid())
    or (select public.has_permission('view_all_refunds'))
  );

create policy wallets_select_own_or_staff
  on public.wallets for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (select public.has_permission('view_all_wallets'))
  );

create policy wallet_transactions_select_own_or_staff
  on public.wallet_transactions for select to authenticated
  using (
    (select public.has_permission('view_all_wallets'))
    or exists (
      select 1 from public.wallets w
      where w.id = wallet_transactions.wallet_id
        and w.profile_id = (select auth.uid())
    )
  );

create policy commission_rules_select_authenticated
  on public.commission_rules for select to authenticated
  using (true);

create policy commission_rules_manage
  on public.commission_rules for all to authenticated
  using ((select public.has_permission('manage_commission')))
  with check ((select public.has_permission('manage_commission')));

create policy commission_ledger_select_driver_or_staff
  on public.commission_ledger for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_commissions'))
  );

create policy tax_rates_select_authenticated
  on public.tax_rates for select to authenticated
  using (true);

create policy tax_rates_manage
  on public.tax_rates for all to authenticated
  using ((select public.has_permission('manage_taxes')))
  with check ((select public.has_permission('manage_taxes')));

create policy payout_batches_select_finance
  on public.payout_batches for select to authenticated
  using ((select public.has_permission('view_payouts')));

create policy payout_batches_manage
  on public.payout_batches for all to authenticated
  using ((select public.has_permission('process_payouts')))
  with check ((select public.has_permission('process_payouts')));

create policy payouts_select_driver_or_finance
  on public.payouts for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_payouts'))
  );

create policy payouts_manage
  on public.payouts for all to authenticated
  using ((select public.has_permission('process_payouts')))
  with check ((select public.has_permission('process_payouts')));

create policy payout_items_select_driver_or_finance
  on public.payout_items for select to authenticated
  using (
    (select public.has_permission('view_payouts'))
    or exists (
      select 1 from public.payouts p
      where p.id = payout_items.payout_id
        and p.driver_id = (select auth.uid())
    )
  );

create policy invoices_select_member_or_staff
  on public.invoices for select to authenticated
  using (
    (select public.has_permission('view_invoices'))
    or exists (
      select 1 from public.business_members bm
      where bm.business_account_id = invoices.business_account_id
        and bm.profile_id = (select auth.uid())
        and bm.accepted_at is not null
    )
  );

create policy invoice_line_items_select_via_invoice
  on public.invoice_line_items for select to authenticated
  using (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_line_items.invoice_id
    )
  );

create policy fleet_billing_events_select_member_or_staff
  on public.fleet_billing_events for select to authenticated
  using (
    (select public.has_permission('view_fleet_billing'))
    or (select public.is_fleet_member(fleet_billing_events.fleet_id))
  );

-- ----------------------------------------------------------------------------
-- 4. Privileges
-- ----------------------------------------------------------------------------
revoke all on
  public.payment_providers,
  public.payment_methods,
  public.payments,
  public.payment_webhooks,
  public.refunds,
  public.wallets,
  public.wallet_transactions,
  public.commission_rules,
  public.commission_ledger,
  public.tax_rates,
  public.payout_batches,
  public.payouts,
  public.payout_items,
  public.invoices,
  public.invoice_line_items,
  public.fleet_billing_events
from anon, authenticated;

grant select on
  public.payment_providers,
  public.payment_methods,
  public.payments,
  public.payment_webhooks,
  public.refunds,
  public.wallets,
  public.wallet_transactions,
  public.commission_rules,
  public.commission_ledger,
  public.tax_rates,
  public.payout_batches,
  public.payouts,
  public.payout_items,
  public.invoices,
  public.invoice_line_items,
  public.fleet_billing_events
to authenticated;

grant insert, update on
  public.payment_providers,
  public.commission_rules,
  public.tax_rates
to authenticated;

grant update (is_default, is_active) on public.payment_methods to authenticated;

-- Partition children are accessed only through the parent RLS policies.
do $$
declare
  v_partition record;
begin
  for v_partition in
    select c.oid::regclass as rel
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relispartition
  loop
    execute format('revoke all on table %s from anon, authenticated', v_partition.rel);
  end loop;
end $$;
