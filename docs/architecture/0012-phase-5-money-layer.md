# Phase 5 — Money Layer

**Status:** implemented and verified  
**Migrations:** `0076`–`0096`  
**Seed:** `supabase/seed-phase-5.sql`  
**Gate:** `supabase/scripts/verify-phase-5-schema.sql`  
**Depends on:** Phase 1 (identity, geography, RBAC, audit), Phase 2 (fleets, vehicles, assignments), Phase 3 (currencies, VAT, promo codes) and Phase 4 (quotes, jobs, cancellations)

---

## 1. Scope

Phase 5 adds the cash, commission, tax, payout and billing layer on top of the Phase 4 operational core. It delivers eight domains:

| Domain | Tables |
| --- | --- |
| A. Payment configuration | `payment_providers`, `payment_methods` |
| B. Capture and refunds | `payments`, `payment_webhooks`, `refunds` |
| C. Wallets | `wallets`, `wallet_transactions` |
| D. Commission | `commission_rules`, `commission_ledger` |
| E. Tax | `tax_rates` |
| F. Payouts | `payout_batches`, `payouts`, `payout_items` |
| G. Business billing | `invoices`, `invoice_line_items` |
| H. Fleet billing | `fleet_billing_events` |

That is 16 public tables. Three of them are range-partitioned by month:

- `payment_webhooks` — webhook retention and ingest volume;
- `wallet_transactions` — the high-volume append-only ledger;
- `commission_ledger` — one immutable row per completed job.

Phase 5 also adds six finance read models, four `pg_cron` schedules, fifteen finance permissions and the Phase 4 closures described in section 14.

Phase 5 deliberately does **not** implement:

- real provider SDK calls or webhook signature verification — Phase 7;
- Flutter application code, edge functions or provider dashboards;
- push/SMS/email delivery, notification preferences or analytics pipelines — Phase 6;
- a general ledger, double-entry accounting package or tax filing integration;
- changes to Phase 1–4 schema beyond the permitted closures in `0091` and the catalogue guard updates in the Phase 1/3 gates.

---

## 2. Money representation

Every monetary column is `NUMERIC(14,2)` and every monetary row carries an explicit `currency_code CHAR(3)` referencing `public.currencies (code)`.

- No money column uses `FLOAT`, `REAL` or `DOUBLE PRECISION`.
- Percentages, multipliers and tax rates use `NUMERIC(6,4)` (commission rules, which also support flat fees, use `NUMERIC(14,4)`).
- Currency is never inferred at read time from the profile or country; it is stored on the financial row.
- Rounding is always explicit with `round(value, 2)` at the boundary where a money amount is produced.
- Wallet amounts are signed: credits are positive, debits are negative. `balance_after` is computed by trigger.

The currency FK prevents a row from being written in a currency the platform does not know. It does not attempt to perform FX conversion; a future multi-currency settlement feature must add an explicit conversion record.

---

## 3. Payment providers and saved methods

`payment_providers` is a per-country catalogue. A provider stores:

- a stable `code` and display `name`;
- `provider_type` (mobile-money aggregator, card processor, bank, etc.);
- capability flags `supports_refunds`, `supports_partial_refunds`, `supports_payouts`;
- a `webhook_secret_reference` (the secret itself lives outside the database);
- a JSONB `config` object for settlement and method metadata;
- `is_active`.

Provider rows are unique per `(country_id, code)`. Only staff with `manage_payments` may insert or update them, and the direct client grant is limited to insert/update.

`payment_methods` stores a tokenized, customer-owned payment instrument:

- `profile_id`, `provider_id`, `method_type`;
- a non-secret `display_name` and a provider token reference;
- `is_default` and `is_active`;
- optional `provider_customer_id`, `last_used_at` and metadata.

A partial unique index enforces at most one default method per profile. A check constraint prevents an inactive method from remaining the default. Customers can read their own methods and update only the `is_default`/`is_active` flags; the provider token and ownership columns are immutable through column-level grants.

---

## 4. Payments and idempotent capture

`payments` is the charge/refund attempt ledger. It stores:

- job, customer, saved method and provider;
- positive `amount` and explicit currency;
- a unique `provider_reference` when present;
- `provider_status` and `payment_type` (`charge`, `refund`, `partial_refund`);
- `refund_of_payment_id` for refund attempts;
- terminal timestamps, failure details and JSONB metadata.

The one public capture path is `public.job_pay(job, method, provider, provider_reference, idempotency_key)`. It:

1. locks the job;
2. authorises the job customer or a trusted service caller;
3. returns an existing payment when `provider_reference` matches;
4. returns an existing charge when the same job and `(metadata->>'idempotency_key')` match;
5. rejects jobs outside `delivered`/`completed` or not `pending`;
6. validates that the provider is active and belongs to the job country;
7. validates that the saved method belongs to the customer, provider and is active;
8. inserts the succeeded charge at the persisted quote total;
9. links the promo redemption if the quote had a promo and one is not already present;
10. marks the job paid and stores its final amount/currency/method;
11. records commission and withholding;
12. posts customer debit, driver earning and platform commission wallet entries;
13. writes status history and a job event.

Provider capture is a Phase 7 stub. The function records a succeeded attempt and performs the wallet movement atomically; it does not call Selcom or Flutterwave.

A second call with the same provider reference, or the same idempotency key on the same job, returns the original payment id. A provider reference that belongs to another job raises a uniqueness error rather than silently linking.

Only the customer or a trusted service caller can call `job_pay`. Client `INSERT` on `payments` is not granted.

---

## 5. Webhooks, dedupe and reconciliation

`payment_webhooks` is the raw provider callback log. It stores the provider, event type, provider event id, provider reference, JSONB payload, signature validity, processing status and error text.

Because the table is partitioned by `received_at`, PostgreSQL cannot enforce a global unique constraint on `(provider_id, event_id)`. A `BEFORE INSERT` trigger takes a transaction-scoped advisory lock keyed by the provider and event id and rejects a duplicate with SQLSTATE `23505`. This keeps webhook ingestion idempotent across partitions without a global unique index.

The table is append-only except for the processing state:

- `payload`, provider identity, event id and provider reference are immutable;
- `processing_status` can move once from `pending` to `processed`, `ignored` or `error`;
- `processing_error` and `processed_at` are mutable.

`payment_reconciliation` reports terminal payments with their webhook count and last webhook timestamp. A payment is marked reconciled when it is in a terminal provider state and at least one webhook is logged against the same provider reference.

---

## 6. Refunds

A refund creates both a `payments` row (`payment_type` = `refund` or `partial_refund`) and a `refunds` row linking:

- the original payment;
- the refund payment;
- the job;
- the requesting profile;
- amount, currency, reason, type and status;
- provider reference and terminal timestamp.

`public.payment_refund(payment, amount, type, reason)` is the refund entry point. It:

1. requires `process_refunds`, the internal refund context, or a trusted service caller;
2. locks the original charge and verifies it is a succeeded `charge`;
3. sums non-failed refunds and rejects over-refunds;
4. checks the provider supports refunds and, when partial, partial refunds;
5. creates the refund payment and refund record;
6. finds the job's commission ledger and claws back the driver net earning and platform commission in proportion to the refund;
7. marks the ledger `is_refunded = true`;
8. marks the job `refunded`;
9. writes a job event.

The provider call is a Phase 7 stub.

`public.job_refund(job, amount, type, reason)` finds the latest succeeded charge for a job and delegates to `payment_refund()` inside a transaction-local `safeshift.refund_context = on` setting. This lets a customer or service caller refund without needing the finance permission directly, while `payment_refund()` still enforces the original-payment checks.

A refund does not credit the customer wallet. The customer's original wallet debit stands; the refund is a provider-side reversal and is recorded in `refunds`/`payments`. This keeps the wallet ledger a record of captured platform movements rather than a duplicate provider settlement ledger.

---

## 7. Wallets and the append-only ledger

`wallets` is one row per `(profile_id, currency_code)` with:

- `cached_balance`;
- `is_frozen`;
- timestamps.

`wallet_transactions` is the append-only ledger. Each row stores the wallet, transaction type, signed amount, currency, computed `balance_after`, optional reference (`type`, `id`), description, metadata and creator.

The balance is derived from the ledger. A `BEFORE INSERT` trigger on `wallet_transactions`:

1. locks the wallet row;
2. verifies the transaction currency matches the wallet;
3. computes `balance_after = cached_balance + amount`;
4. updates `cached_balance`.

This makes the cache a materialised projection of the ledger and keeps concurrent postings serialised on the wallet row. `wallet_transactions` rejects every `UPDATE` and `DELETE`; `wallets` rejects identity changes and rejects direct `cached_balance` changes unless the caller is a trusted service context.

`private.wallet_post()` is the internal primitive. Public wrappers are:

- `wallet_credit(profile, amount, currency, type, reference_type, reference_id, description)` — positive amount only;
- `wallet_debit(profile, amount, currency, type, reference_type, reference_id, description, allow_negative)` — positive amount only, stored as a negative ledger entry.

Both return the wallet UUID because `wallet_transactions.id` is `BIGINT` and is not a stable public identifier.

The system wallets and their funding are seed fixtures, not hard-coded business logic. The platform profile UUID is deterministic: `00000000-0000-4000-8000-000000000000`. It is created idempotently by migration `0090` and owns the platform wallet.

`verify_all_wallet_balances()` compares every cached balance with the sum of its ledger; `wallet_balance_verify()` turns any mismatch into a warning and is scheduled nightly.

---

## 8. Commission rules and cascade

`commission_rules` supports percentage and flat-fee rules with optional minimum and maximum commission. Scopes are optional columns:

- `driver_id` — most specific;
- `fleet_id`;
- `vehicle_type_id`;
- `city_id`;
- `country_id`;
- all scope columns null — platform default.

`resolve_commission_rule(job)` chooses the most specific active rule whose scope matches the job's driver, fleet, vehicle type, city and country. Ordering is:

```text
driver > fleet > vehicle_type > city > country > platform default
```

Within the same specificity it orders by `priority` descending, then `effective_from` descending, then id. The job's fleet is `drivers.current_fleet_id`, falling back to the latest active `fleet_members` row. The vehicle type is the assigned vehicle's type, falling back to the quote request's type.

`calculate_and_record_commission(job)` adds the fleet column override:

1. resolve the rule;
2. if the winning rule is driver-specific or fleet-scoped, use that rule;
3. otherwise, if `fleets.commission_rate_override` is set, use the fleet percentage;
4. otherwise use the resolved vehicle/city/country/default rule;
5. apply min/max and clamp commission to `[0, gross]`;
6. write one immutable `commission_ledger` row and return its UUID.

This is Decision C: a fleet override participates before city/country/default, but a driver-specific rule always wins. A fleet-scoped rule also wins over the fleet column because it is the more explicit configuration.

The commission base is the job's `final_amount`, falling back to the quote total. The ledger stores the exact gross, commission, rate, driver net, withholding and currency. The ledger `id` is a UUID rather than a numeric sequence because `payout_items` and `fleet_billing_events` reference it directly; the composite FK also includes `calculated_at` for the partitioned key.

Because `commission_ledger` is partitioned by `calculated_at`, a global unique constraint on `job_id` is impossible. A `BEFORE INSERT` advisory-lock trigger enforces one row per job and rejects duplicates with SQLSTATE `23505`. The function is additionally idempotent: it returns the existing ledger id before inserting.

---

## 9. Withholding tax and VAT

`tax_rates` stores per-country tax configuration:

- `tax_type` (`vat`, `withholding`, etc.);
- `applies_to` (`customer_charge`, `driver_payout`, etc.);
- `rate NUMERIC(6,4)` constrained to `[0,1]`;
- effective window and active flag.

`resolve_tax_rate(country, type, applies_to, at_time)` returns the newest active rate in the window.

VAT is already part of the persisted quote total from Phase 3/4. Phase 5 does not recompute or overwrite it; it reports the quote's VAT in invoices and keeps the customer charge consistent with the quote. The seed configures 18% Tanzanian VAT.

Withholding is recorded separately on the commission ledger. `apply_withholding_tax(job)`:

1. finds the job's ledger;
2. resolves the country withholding rate for `driver_payout`;
3. computes `round(driver_net_earning * rate, 2)`;
4. writes it once, from zero, to `withholding_tax_amount`.

The ledger trigger permits only the one-way transition from zero to a non-negative withholding amount. The driver payout amount is `driver_net_earning - withholding_tax_amount`.

This is Decision H: VAT is on the customer gross and withholding is on the driver payout; they are recorded separately and never netted into one opaque number.

---

## 10. Payout batches and execution

Payouts are batched by country and period. `payout_batches` stores the country, period, status, total, currency, driver count and initiator. `payouts` stores one payout per driver and period with:

- gross earnings, commission deducted, withholding and net;
- optional provider/method;
- status and provider reference;
- denormalised `period_start`/`period_end` so a unique `(driver_id, period_start, period_end)` constraint can be enforced.

`payout_items` links each payout to the exact commission-ledger rows it pays, including `commission_calculated_at` and a composite FK `(commission_ledger_id, commission_calculated_at)`. PostgreSQL cannot foreign-key a partitioned table by `id` alone.

`public.create_payout_batch(country, period_start, period_end)`:

1. requires `process_payouts` or a trusted service caller;
2. returns an existing batch for the exact country/period;
3. aggregates completed, unrefunded, previously unpaid ledger rows in the period;
4. creates a draft batch;
5. creates one pending payout per driver with a positive net;
6. selects the driver's active payout-capable method when available;
7. inserts one payout item per ledger row.

`public.execute_payout(payout)`:

1. locks the payout;
2. returns early when already completed;
3. rejects failed/cancelled payouts;
4. marks it completed with a provider reference;
5. debits the driver wallet with `allow_negative`;
6. closes the batch as `completed` when no pending/processing payouts remain, otherwise `partial`;
7. writes an audit entry.

Provider execution is a Phase 7 stub. The batch period is caller-supplied; the default operational cadence is weekly, scheduled outside this schema (the migration only schedules the maintenance jobs).

Payment of a driver who has no wallet creates one through `wallet_post`; a payout can therefore produce a negative wallet if the driver earned commission without a prior capture. This is intentional: the ledger remains the source of truth and the cache mirrors it.

---

## 11. Business invoices

`invoices` stores one draft/issued/paid/overdue/cancelled/refunded invoice per business account and period, with:

- invoice number unique per account;
- explicit currency;
- subtotal, tax and total;
- amount paid constrained not to exceed the total;
- issue/due dates and optional notes.

`invoice_line_items` stores one line per completed job in the period, with description, quantity, unit price, amount and optional job reference.

`public.generate_invoice(business_account, period_start, period_end)`:

1. requires `manage_invoices` or a trusted service caller;
2. validates the active business account and its country currency;
3. sums completed jobs for accepted business members in the period;
4. creates a draft invoice with the account's payment terms;
5. creates one line per job at the quote subtotal;
6. returns the invoice UUID.

VAT is taken from the quote's persisted VAT, so the invoice total matches what the customer was charged. `invoice_summary` exposes the business name and overdue days; members and staff with `view_invoices` can read invoices, and line items are visible through their invoice.

---

## 12. Fleet billing accruals

`fleet_billing_events` records the fleet's commission accrual for a job:

- fleet, job and commission-ledger reference;
- fleet commission rate and amount;
- currency and accrual timestamp.

The composite FK to `(commission_ledger_id, commission_calculated_at)` is required for the same partitioning reason as payout items. The table is append-only: neither update nor delete is allowed.

The seed creates one accrual for the Phase 4 fleet on job J1 at the fleet's 8% override. Accruals are informational in Phase 5; settlement to fleets is deferred.

---

## 13. RLS, permissions and grants

RLS is enabled on all 16 tables. Policies use the cached `(select auth.uid())` form.

| Table | Client read | Client write |
| --- | --- | --- |
| `payment_providers` | any authenticated | insert/update with `manage_payments` |
| `payment_methods` | own or `view_all_payment_methods` | update only `is_default`/`is_active` on own rows |
| `payments` | own or `view_all_payments` | none |
| `payment_webhooks` | `view_payment_webhooks` | none |
| `refunds` | requester or `view_all_refunds` | none |
| `wallets` | own or `view_all_wallets` | none |
| `wallet_transactions` | own wallet or `view_all_wallets` | none |
| `commission_rules` | any authenticated | insert/update with `manage_commission` |
| `commission_ledger` | driver or `view_all_commissions` | none |
| `tax_rates` | any authenticated | insert/update with `manage_taxes` |
| `payout_batches` | `view_payouts` | none |
| `payouts` | driver or `view_payouts` | none |
| `payout_items` | driver or `view_payouts` | none |
| `invoices` | business member or `view_invoices` | none |
| `invoice_line_items` | visible invoice | none |
| `fleet_billing_events` | fleet member or `view_fleet_billing` | none |

The direct grants are deliberately asymmetric:

- `authenticated` receives `SELECT` on every table;
- `INSERT`/`UPDATE` only on `payment_providers`, `commission_rules` and `tax_rates`;
- column-level `UPDATE (is_default, is_active)` on `payment_methods`;
- no `INSERT`, `UPDATE` or `DELETE` on payments, refunds, wallets, wallet ledger, commission ledger, payout batches, payouts, payout items, invoices, invoice line items or fleet billing events;
- no `DELETE` anywhere at the client role.

Partition children are revoked from `anon` and `authenticated`; access is only through the parent policies.

Fifteen permissions are added to the Phase 1 catalogue and assigned to `super_admin`, `finance_admin`, `operations_admin`, `support_agent` and `analyst` according to least privilege.

---

## 14. Immutability, Phase 4 closures and audit

Phase 5 uses `private.audit_trigger()` on mutable money roots: payment providers, payment methods, commission rules, tax rates, payout batches, payouts and invoices. Append-only tables do not need audit rows because their own immutability is the audit.

The immutable rules are:

| Table | Mutable fields | Transition |
| --- | --- | --- |
| `payments` | provider status, completed/failure fields | pending → succeeded/failed/cancelled |
| `payment_webhooks` | processing status/error/time | pending → processed/ignored/error |
| `refunds` | status, completion/failure/reference | requested → processing/succeeded/failed; processing → succeeded/failed |
| `wallets` | `cached_balance` (service only), `is_frozen` | identity immutable |
| `wallet_transactions` | none | append-only |
| `commission_ledger` | `is_refunded`, `withholding_tax_amount` | false → true; withholding 0 → ≥0 |
| `payouts` | status/completion/failure/reference | pending → processing/completed/failed/cancelled; processing → completed/failed/cancelled |
| `payout_items` | none | append-only |
| `fleet_billing_events` | none | append-only |
| `invoices` | status/payment fields | not append-only; audit only |

`0091` makes three permitted Phase 4 closures:

1. **`job_cancel()` refund path.** When a job was paid and a refund is due, `job_cancel()` finds the original succeeded charge and calls `payment_refund()` inside the internal refund context. This is Decision B: all client money mutations go through `SECURITY DEFINER` helpers.
2. **Quote cleanup.** The Phase 4 quote append-only trigger now permits deletion only when `safeshift.quote_cleanup = on`, which only `quote_cleanup()` sets. The function deletes expired quotes with no jobs and is scheduled nightly.
3. **Acceptance stats trigger removed.** `driver_acceptance_stats` is recomputed nightly by `recompute_all_driver_acceptance_stats()`; the Phase 4 job-offer trigger is dropped. This is Decision D.

`commission_ledger.is_refunded` is added/backfilled in `0091` so refunded ledger entries are excluded from future payouts.

No other Phase 1–4 schema was changed.

---

## 15. Indexes, partitions and views

Phase 5 adds the indexes required by the read paths:

- payment lookup by job, customer/time, terminal state and refund linkage;
- open refunds and refunds by payment/job;
- pending webhooks and provider/time reconciliation;
- wallet ledger by wallet/time and by reference;
- active commission rules by scope and priority;
- unrefunded commission by driver/time;
- active tax scopes;
- payout batches by country/period and open batches;
- payouts by batch, driver/period and open status;
- invoice by business/issue date and open status;
- fleet accruals by fleet/time.

Partial indexes cover the hot open states (`provider_status = 'pending'`, `refunds.status in (...)`, `payouts.status in (...)`, `invoices.status in (...)`).

Each partitioned table has a `DEFAULT` partition plus monthly partitions created at migration time: twelve months for wallet transactions and commission ledger, and twenty-four months for payment webhooks. The partition key is part of each primary key:

- `payment_webhooks (id, received_at)`;
- `wallet_transactions (id, created_at)`;
- `commission_ledger (id, calculated_at)`.

The helper functions `private.ensure_payment_webhook_partitions()`, `private.ensure_wallet_transaction_partitions()` and `private.ensure_commission_ledger_partitions()` create missing months; `0095` schedules maintenance but the migration itself creates the first twelve months.

Six `security_invoker` views expose read models:

| View | Purpose |
| --- | --- |
| `job_payment_summary` | captured/refunded totals, commission and driver net per job |
| `driver_earnings_summary` | day/week/month driver earnings and latest payout status |
| `wallet_balance_current` | cached wallet balance and last ledger timestamp |
| `payout_batch_summary` | batch totals by country and period |
| `invoice_summary` | invoice list with business name and overdue days |
| `payment_reconciliation` | payment-to-webhook matching |

`security_invoker = true` means the caller's RLS policies on the base tables remain in force; the views are not a privilege bypass.

---

## 16. pg_cron maintenance

`0095` registers four `safeshift_*` jobs:

| Job | Schedule | Function |
| --- | --- | --- |
| `safeshift_expire_offers` | every 30 seconds | `expire_stale_offers()` |
| `safeshift_quote_cleanup` | daily 03:00 | `quote_cleanup()` |
| `safeshift_acceptance_stats` | daily 02:00 | `recompute_all_driver_acceptance_stats()` |
| `safeshift_wallet_verify` | daily 04:00 | `wallet_balance_verify()` |

The migration unschedules any previous `safeshift_%` job before recreating them, so re-running migrations does not duplicate schedules. The functions that mutate state require a trusted service context; `wallet_balance_verify()` and `verify_all_wallet_balances()` compare the cache against the ledger.

Payout batching is not scheduled in Phase 5 because the period and country are operational choices. The default cadence is weekly, and the function accepts explicit dates.

---

## 17. Seed and verification

`supabase/seed-phase-5.sql` runs after the Phase 4 seed and creates:

- 2 providers (Selcom, Flutterwave);
- 3 saved methods (two customers, one driver payout method);
- 2 tax rates (18% VAT, 5% withholding);
- 3 commission rules (12% default, 10% Dar es Salaam medium truck, 8% fleet);
- 2 charge payments and 1 refund payment, plus 1 succeeded refund;
- 5 wallets (3 customers, 1 driver, 1 platform) and 10 ledger entries;
- 1 commission-ledger row with withholding;
- 1 draft weekly payout batch, 1 pending payout and 1 payout item;
- 1 draft business invoice with 3 lines;
- 1 fleet billing accrual.

The seed verifies wallet cache integrity at the end and fails the transaction if any cache differs from its ledger sum.

`supabase/scripts/verify-phase-5-schema.sql` checks:

1. all 16 tables and foreign keys;
2. RLS and at least one policy per table;
3. partition children and parent partition counts;
4. required indexes;
5. helper function signatures and pinned `search_path`;
6. `security_invoker` views;
7. four cron jobs;
8. fixed seed counts;
9. a fresh scratch customer, quote and job paid by `job_pay()`;
10. idempotent retries by provider reference and idempotency key;
11. partial and full refunds through `payment_refund()`;
12. `job_refund()` and the `job_cancel()` refund closure;
13. commission cascade (driver, fleet, city, default), withholding and tax resolution;
14. payout batch creation and execution;
15. invoice generation;
16. wallet balance verification and nightly acceptance recompute;
17. immutability triggers;
18. customer RLS reads and blocked direct client writes.

The behavioural block creates fresh fixtures because money rows are append-only. Those rows intentionally remain after the gate; the fixed seed counts use the seed UUID prefixes, not total row counts.

---

## 18. Known limitations and deferred work

- Provider capture, refund, payout and webhook signature verification are stubs. Phase 7 replaces the TODO boundaries with real SDK calls and secret management.
- There is no FX conversion. Every financial row is single-currency.
- The customer wallet is not credited on refund; provider reversals are recorded in `refunds`/`payments`. A future customer-credit policy must decide whether to mirror provider reversals into the wallet.
- Fleet billing events are informational accruals; fleet settlement is not implemented.
- Invoice payment collection, dunning and tax filing are out of scope.
- Payout batching is caller-driven. A production scheduler may add a weekly wrapper, but Phase 5 deliberately leaves the country/period choice to operations.
- Partition maintenance is monthly and only creates future months; a production job should run `ensure_*_partitions()` before the first of each month.
- `payment_webhooks` dedupe uses an advisory lock, which serialises duplicates but does not provide a declarative unique constraint across partitions.
