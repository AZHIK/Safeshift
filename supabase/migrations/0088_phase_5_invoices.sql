-- ============================================================================
-- SafeShift — Phase 5 / Migration 0088
-- Business-account invoices and line items.
-- ============================================================================

create table public.invoices (
  id                  uuid primary key default gen_random_uuid(),
  business_account_id uuid not null references public.business_accounts (id) on delete restrict,
  invoice_number      text not null unique,
  currency_code       char(3) not null references public.currencies (code) on update cascade on delete restrict,
  period_start        timestamptz not null,
  period_end          timestamptz not null,
  subtotal            numeric(14,2) not null default 0,
  tax_amount          numeric(14,2) not null default 0,
  total               numeric(14,2) not null default 0,
  amount_paid         numeric(14,2) not null default 0,
  status              text not null default 'draft',
  issued_at           timestamptz,
  due_at              timestamptz,
  paid_at             timestamptz,
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint invoices_number_check check (length(btrim(invoice_number)) > 0),
  constraint invoices_period_check check (period_end > period_start),
  constraint invoices_subtotal_check check (subtotal >= 0),
  constraint invoices_tax_check check (tax_amount >= 0),
  constraint invoices_total_check check (total >= 0),
  constraint invoices_amount_paid_check check (amount_paid >= 0),
  constraint invoices_status_check
    check (status in ('draft', 'sent', 'paid', 'partially_paid', 'overdue', 'cancelled', 'refunded')),
  constraint invoices_total_components_check
    check (total = round(subtotal + tax_amount, 2)),
  constraint invoices_paid_not_above_total_check check (amount_paid <= total)
);

comment on table public.invoices is
  'Business-account invoice header. Business members read their own invoices; finance staff see all.';

create trigger trg_invoices_updated_at
  before update on public.invoices
  for each row execute function public.set_updated_at();

create table public.invoice_line_items (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references public.invoices (id) on delete cascade,
  description text not null,
  quantity    numeric(10,2) not null default 1,
  unit_price  numeric(14,2) not null,
  amount      numeric(14,2) not null,
  job_id      uuid references public.jobs (id) on delete set null,
  created_at  timestamptz not null default now(),

  constraint invoice_line_items_description_check check (length(btrim(description)) > 0),
  constraint invoice_line_items_quantity_check check (quantity > 0),
  constraint invoice_line_items_unit_price_check check (unit_price >= 0),
  constraint invoice_line_items_amount_check check (amount >= 0),
  constraint invoice_line_items_calculation_check
    check (amount = round(quantity * unit_price, 2))
);

comment on table public.invoice_line_items is
  'Invoice lines. amount must equal quantity * unit_price to two decimals.';
