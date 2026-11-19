





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
