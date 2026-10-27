# Phase 4 — Operational Core

**Status:** implemented and verified  
**Migrations:** `0052`–`0075`  
**Seed:** `supabase/seed-phase-4.sql`  
**Gate:** `supabase/scripts/verify-phase-4-schema.sql` — 154 PASS, 0 FAIL  
**Depends on:** Phase 1 (identity, geography, RBAC, audit), Phase 2 (vehicles, cargo, fleets) and Phase 3 (pricing versions, promo codes, LATRA tariffs)

---

## 1. Scope

Phase 4 turns the priced marketplace into an operational one. It delivers six domains:

| Domain | Tables |
| --- | --- |
| A. Quotes | `quote_requests`, `quotes` |
| B. Jobs | `jobs`, `job_stops`, `job_items`, `job_evidence`, `job_status_history`, `job_events`, `job_cancellations` |
| C. Tracking and dispatch | `driver_locations`, `matching_attempts`, `dispatch_rules`, `job_offers`, `driver_acceptance_stats` |
| D. Pricing operations | `cancellation_policies`, `surge_multipliers` |
| E. Trust and support | `rating_categories`, `ratings`, `rating_reports`, `disputes`, `dispute_messages`, `dispute_attachments`, `dispute_resolutions` |
| F. Recurring work | `recurring_job_templates`, `scheduled_jobs` |

That is 25 public tables. The implementation also adds five operational enums: `job_status`, `payment_status`, `payment_method`, `evidence_type` and `trip_alert_type`.

Phase 4 deliberately does **not** implement:

- payment processing, wallets, payouts, commissions or settlement — Phase 5;
- push/SMS delivery, notification preferences or analytics pipelines — Phase 6;
- Flutter application code;
- any change to Phase 1–3 schema beyond the draft-version visibility fix in `0053`.

---

## 2. Quote engine: the authoritative pricing path

Phase 3's `quote_preview()` remains a side-effect-free preview. Phase 4 adds the authoritative engine in `0070`:

```text
private.quote_calculate_core(...)
  -> pure fare calculation and JSONB breakdown

public.quote_calculate_and_persist(...)
  -> validates caller, resolves plan/version, applies surge/promo/cap,
     persists quote_requests + quotes, returns the quote uuid

public.quote_get_breakdown(uuid)
  -> authorised access to the immutable snapshot
```

`quote_calculate_and_persist` accepts the booking inputs plus:

- `p_waiting_minutes`;
- `p_stop_count`;
- `p_equipment_ids`;
- `p_promo_code_id`;
- optional `p_distance_km` and `p_duration_min` from a routing engine.

When distance or duration is omitted, the function derives great-circle distance with PostGIS and estimates duration at a conservative 20 km/h urban average.

The function:

1. requires an authenticated customer matching `p_customer_id`, or a trusted service context;
2. derives country/city and service zone from the pickup point;
3. validates the vehicle and cargo types against the city country;
4. resolves the active plan with `active_pricing_plan_for()` and then its published version with `active_pricing_plan_version()`;
5. runs the fare core, including waiting and extra-stop charges;
6. applies the highest matching active surge multiplier;
7. validates and applies at most one promo code;
8. applies the LATRA cap to the total including VAT;
9. inserts one `quote_requests` row and one immutable `quotes` row;
10. returns the quote id.

Quotes expire 15 minutes after creation. A client job insert from an expired quote is rejected.

---

## 3. Fare calculation and the persisted snapshot

`private.quote_calculate_core()` mirrors the Phase 3 rate structure:

- base fare, distance charge and time charge;
- distance tiers with a base-rate fallback for any uncovered remainder;
- weight and volume tiers;
- cargo and equipment surcharges;
- waiting time above the plan's free window;
- multi-stop fee for stops beyond pickup and dropoff;
- minimum charge;
- zone and time-of-day multipliers;
- VAT;
- LATRA maximum total.

Time-of-day multipliers use `p_scheduled_at` (or `now()` when no schedule is supplied), converted through the multiplier's IANA timezone. Plan, version, surge and promo validity use `now()`.

The immutable snapshot stores every decision:

```text
inputs        every request input, including locations as GeoJSON
service       country, city, timezone and resolved service zone
plan          plan/version ids, code, version number, currency, tariff
calculation   complete core breakdown, including uncapped total
surge         selected surge id, multiplier, reason and window
promo         code, discount type/value, discount amount, applied flag
final         net, discount, VAT, total, cap, VAT rate and expiry
```

The `quotes` row also stores the line-item columns and the exact `pricing_plan_version_id`. The version reference is the source of truth; the snapshot explains the result.

---

## 4. Promotions and regulated caps

Only one promo code can be attached to a quote. The engine evaluates:

- basic validity through `promo_code_valid()`;
- country/currency match;
- vehicle, city and cargo applicability arrays;
- minimum net purchase;
- advanced rules: `first_job`, `min_jobs_completed`, `min_account_age_days`, `specific_zone`, `specific_day_of_week`.

New-user promo validity is the Phase 3 rule: account age ≤ 30 days and zero prior redemptions.

Discount semantics:

| Type | Calculation |
| --- | --- |
| `flat_amount` | subtract the value, capped at net subtotal |
| `percentage` | net subtotal × percentage |
| `capped_percentage` | percentage, capped by `max_discount_amount` |
| `free_ride` | waive the net subtotal |

The discount is applied to the net subtotal. VAT is recalculated on the discounted net. The regulated cap is a maximum total including VAT; a discount can only reduce the customer-facing total below it.

The promo redemption ledger row is written when a priced quote becomes a job, inside the job-insert trigger. `promo_redemptions.job_id` remains a bare UUID, as Phase 3 designed, so Phase 3 schema is not changed.

---

## 5. Jobs and the lifecycle

Every job references a persisted quote. A `BEFORE INSERT` trigger derives customer, city, quoted distance, quote total and currency from the quote, so those values cannot silently disagree at creation.

For an authenticated customer:

- the quote must be unexpired;
- the quote must not already have a job;
- the new job is forced to `requested` with no driver, vehicle, timestamps, payment method or cancellation data;
- the customer id must match the quote request.

Service/seed inserts may create historical or already-advanced states for fixtures. The seed uses this to create completed, in-transit and cancelled examples.

`public.job_advance_status()` enforces the legal state machine:

```text
requested -> matched
quoted -> matched
matched -> accepted              (requires an assigned driver)
accepted -> heading_to_pickup
heading_to_pickup -> arrived
arrived -> loading
loading -> in_transit
in_transit -> delivered | disputed
delivered -> completed | disputed
completed -> disputed
```

Cancellation delegates to `job_cancel()`. Completion records `completed_at` and `actual_duration_min` from `started_at`. Every transition writes an immutable `job_status_history` row and a `job_events` row.

Direct client `UPDATE` on `jobs` is not granted. Status, assignment and cancellation are helper-only operations.

---

## 6. Stops, cargo and evidence

`job_stops` stores ordered, typed stops:

- `pickup`;
- `waypoint`;
- `dropoff`.

`stop_sequence` is unique per job. Each stop has its own location, address, contact details and arrival/completion timestamps.

`job_items` is the cargo manifest, including quantity, weight, volume, declared value/currency, fragility and handling flags.

`job_evidence` attaches proof to a job or to a specific stop through `stop_id`. Supported evidence types are `pickup_photo`, `delivery_photo`, `signature`, `otp`, `document`, `item_photo` and `cargo_manifest`. Files live in object storage; the database stores paths and metadata.

A trigger rejects evidence whose stop belongs to another job.

---

## 7. Cancellation policies and fees

Cancellation policies are country-scoped and role-scoped (`customer` or `driver`). A policy defines:

- a free-cancellation window in minutes;
- `flat`, `percentage_of_quote` or `tiered` fees;
- currency;
- optional tier thresholds.

`public.job_cancel(job_id, cancelled_by, reason)`:

1. validates the caller is the customer, assigned driver, an `assign_drivers` holder or service context;
2. resolves the active policy for the job country and canceller role;
3. compares minutes before the scheduled pickup with the free window;
4. computes and caps the fee at the job amount;
5. writes `jobs.cancellation_fee` and `job_cancellations`;
6. records a Phase 5 refund placeholder (`pending` for paid jobs, otherwise `not_applicable`);
7. writes immutable history and the `cancelled` event.

Tiered fees use the largest threshold less than or equal to the minutes before pickup. The full structured record lives in `job_cancellations`; the job keeps a denormalised fee for fast reads.

---

## 8. Driver locations and partitioning

`driver_locations` is a monthly range-partitioned time series on `recorded_at`:

- primary key `(id, recorded_at)`;
- 6 monthly partitions created from the current month;
- a default partition for out-of-range writes;
- GIST index on the geographic point;
- indexes on `(driver_id, recorded_at desc)` and active-job `(job_id, recorded_at desc)`.

`private.ensure_driver_location_partitions()` creates missing future partitions and revokes direct client privileges on every new child. Retention is documented as 90 days; the actual purge schedule belongs to Phase 5/6 operations.

`location` and `recorded_at` are immutable. An insert trigger keeps the denormalised `drivers.current_location` and `drivers.location_updated_at` columns current.

Clients may insert only their own driver pings. Job participants and `view_all_drivers` staff may read pings; direct access to partition children is revoked so the parent RLS cannot be bypassed.

---

## 9. Matching and dispatch policy

`matching_attempts` records one row per dispatch cycle: attempt number, driver considered/offered counts, success, failure reason, timing and metadata.

`dispatch_rules` is a scope cascade:

```text
vehicle + city  >  city  >  country  >  global
```

The unique key prevents duplicate rows at the same scope. `public.dispatch_rule_for(city_id, vehicle_type_id)` resolves the most specific active rule.

`public.find_nearby_drivers(pickup, vehicle_type, radius_km, limit)` returns verified, available drivers with a matching verified vehicle inside the radius. It orders by distance, then rating, and returns distance, rating, rolling acceptance rate and ETA.

---

## 10. Offers and acceptance statistics

`public.offer_job_to_driver(job_id, driver_id, timeout_seconds)`:

- validates the job state and driver eligibility;
- returns an existing pending offer instead of duplicating it;
- assigns the next `offer_sequence`;
- calculates distance/ETA from the driver's current location;
- creates a time-bounded `job_offers` row.

Offers are service/dispatch writes. Drivers respond only through:

- `public.accept_job_offer(offer_id)` — marks the offer accepted, auto-reassigns competing pending offers and delegates assignment to `job_assign_driver()`;
- `public.decline_job_offer(offer_id, reason)` — marks the offer declined;
- `public.expire_stale_offers()` — marks overdue pending offers expired.

Offer identity and terms are immutable. The only allowed update is one service-only transition from `pending` to a terminal response, limited to `response`, `responded_at` and `decline_reason`.

`driver_acceptance_stats` is maintained by an AFTER trigger over a rolling 30-day window: offers received/accepted/declined/expired, acceptance rate and average response seconds.

`public.job_assign_driver(job_id, driver_id, vehicle_id)` validates the driver, vehicle, vehicle type and ownership/assignment, moves the job to `accepted`, writes history/events and refreshes acceptance statistics.

---

## 11. Ratings

`rating_categories` is a five-row seed catalogue. `applies_to_role` identifies the rater role: customers rate drivers; drivers rate customers. The seeded categories are:

- customer: `overall`, `care_handling`, `vehicle_condition`;
- driver: `communication`, `punctuality`.

`ratings` stores one row per job, rater and category. A self-rating check blocks a profile rating itself. A unique key blocks duplicate category submissions for the same job.

RLS restricts visibility to the rater, the rated counterparty and `view_all_ratings` staff. Insertion requires the caller to be a job participant rating the counterparty.

`rating_reports` supports abuse/suspicion reports. The reporter or `view_all_ratings` staff can read them; `manage_ratings` staff can review them.

`public.recompute_driver_rating(driver_id)` aggregates driver-directed ratings from the last 90 days into `drivers.rating`.

---

## 12. Disputes

`disputes` is the workflow header:

- types: damage, loss, delay, rude behaviour, fare, no-show, safety, other;
- statuses: open, in review, resolved for customer/driver/split, dismissed, escalated;
- priorities, SLA deadline and compensation fields.

`dispute_messages` is the conversation. Internal notes are visible only to `view_all_disputes` staff. `dispute_attachments` stores object-storage paths and validates that an attached message belongs to the same dispute. `dispute_resolutions` is an append-only audit of assignments, status changes, compensation, escalation and closure.

Customers and assigned drivers see their own dispute, external messages and attachments. Staff with `view_all_disputes` see internal notes. `resolve_disputes` controls status/compensation updates.

The Phase 4 schema has no separate “assigned to” column. `dispute_summary.assigned_to_name` is therefore an explicit alias of `disputes.resolved_by`, and the view comment documents the gap.

---

## 13. Recurring jobs

`recurring_job_templates` belongs to a business account and stores:

- pickup/destination addresses;
- vehicle and cargo types;
- default weight/volume;
- an RFC 5545 RRULE;
- local time-of-day and IANA timezone;
- optional preferred driver.

Business owners/admins create and update templates; accepted business members can read them; `manage_business_accounts` staff can also manage them.

`scheduled_jobs` stores concrete occurrences, their quote/job links, status and generation errors. A unique key prevents duplicate occurrences for the same template and scheduled time. The seed generates the next three Mondays.

---

## 14. RLS, permissions and grants

Every Phase 4 table has RLS enabled and at least one policy. Policies use the cached `(select auth.uid())` form.

New permissions:

| Permission | Purpose |
| --- | --- |
| `view_all_quotes` | Read every quote request and quote |
| `manage_surge` | Manage demand surge rows |
| `view_all_jobs` | Read every job and operational record |
| `assign_drivers` | Assign drivers/vehicles and perform operations |
| `manage_cancellation_policies` | Manage country cancellation policies |
| `manage_dispatch` | Manage dispatch rules and matching configuration |
| `manage_ratings` | Manage categories and moderation |
| `view_all_ratings` | Read every rating and report |
| `view_all_disputes` | Read every dispute, including internal notes |
| `resolve_disputes` | Resolve disputes and grant compensation |

Role grants are additive to the existing Phase 1–3 roles. `operations_admin` owns dispatch/assignment/surge/cancellation operations; `support_agent` owns ratings and disputes; `finance_admin` can inspect quotes/jobs and manage cancellation policy; `analyst` has read-only operational access; `super_admin` receives every new permission.

Grant rules:

- clients receive `SELECT` on all 25 tables subject to RLS;
- clients may `INSERT` only where a policy defines a safe initial state;
- clients may `UPDATE` only cancellation policies, surge, dispatch rules, rating categories, rating reports, disputes and recurring templates;
- clients never receive `DELETE` on any Phase 4 table;
- `jobs` has `INSERT` but no `UPDATE`/`DELETE`;
- quotes, history, events, cancellations, matching attempts, offers, acceptance stats, resolutions and scheduled jobs are server-write only;
- partition children have all client privileges revoked.

---

## 15. Immutability, append-only tables and audit

`private.enforce_phase4_immutability()` blocks UPDATE and DELETE on:

- `quotes`;
- `job_status_history`;
- `job_events`;
- `dispute_resolutions`;
- `job_offers` (with the narrow service-only pending-to-terminal exception described above).

`private.protect_driver_location_fields()` blocks changes to `driver_locations.location` and `recorded_at`, including service writes. Telemetry corrections must be inserted as new pings.

`private.audit_trigger()` from Phase 1 is reused on the mutable operational roots: jobs, cancellation policies, surge, dispatch rules, rating categories, rating reports, disputes, recurring templates and scheduled jobs.

The job insert trigger also writes the promo redemption ledger when the quote carries a valid promo.

---

## 16. Indexes and views

`0072` adds query-path indexes for:

- quote-request history by customer, city and vehicle type;
- quote expiry and promo lookup;
- active surge windows by city/zone/vehicle;
- job lookup by customer, driver, status, city and active schedule;
- evidence, history and event timelines;
- driver-location history and GIST geography;
- dispatch attempts, pending offers and acceptance stats;
- ratings, reports, disputes and messages;
- recurring templates and due scheduled jobs.

Geographic columns use GIST indexes: quote pickup/destination, job stops, job events and driver locations. Partial indexes cover active jobs, pending offers, due scheduled jobs and non-null foreign keys.

`0075` adds six `security_invoker` read models:

| View | Purpose |
| --- | --- |
| `job_summary` | Participant/staff job list with names, addresses, amount and rating count |
| `active_jobs_by_driver` | Non-terminal jobs with distance from the latest driver ping to pickup |
| `driver_dashboard_summary` | Today/week trips and earnings, open offers, 30-day acceptance and rating |
| `quote_summary` | Quote list with customer, vehicle type, total and validity |
| `dispute_summary` | Dispute queue with raiser, assigned alias, SLA and age |
| `matching_performance` | Daily attempt volume, success rate, attempts and seconds to match |

Because the views are `security_invoker`, the caller's RLS on the base tables remains in force.

---

## 17. Seed and verification

`supabase/seed-phase-4.sql` is registered after the Phase 3 seed and creates:

- 2 cancellation policies;
- 5 rating categories;
- 1 dispatch rule;
- 3 quote requests (2 accepted, 1 abandoned) and 2 quotes;
- 3 jobs (completed, in transit, cancelled);
- 6 stops, 3 cargo items, 4 evidence rows;
- 16 status-history rows and 15 lifecycle events;
- 1 cancellation record;
- 15 driver-location pings;
- 2 matching attempts, 2 offers and 3 acceptance-stat rows;
- 4 ratings;
- 1 open dispute with 3 messages (one internal note);
- 1 recurring template and 3 scheduled occurrences.

Quote 2 backs both the in-transit and cancelled job. `jobs.quote_id` is intentionally not unique; the client insert trigger enforces one job per quote for clients, while service/seed inserts may create historical fixtures.

Run the Phase 4 gate:

```bash
docker exec -i supabase_db_safeshift psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/scripts/verify-phase-4-schema.sql
```

The gate checks enums, tables, RLS, grants, column types, partitions, functions, triggers, indexes, views, seed counts, quote-engine behaviour, promo/surge/cap semantics, helper workflows, immutability and RLS as mocked customers, drivers and staff.

Current results:

```text
PHASE 4 SCHEMA VERIFICATION: 154 PASS, 0 FAIL
PHASE 3 SCHEMA VERIFICATION: 150 PASS, 0 FAIL
PHASE 2 SCHEMA VERIFICATION: 166 PASS, 0 FAIL
PHASE 1 SCHEMA VERIFICATION: 151 PASS, 0 FAIL
```

The Phase 1 and Phase 3 gates were updated only to recognise Phase 4 tables while still blocking Phase 5+ tables. The Phase 2 enum check now recognises the five Phase 4 enums.

---

## 18. Known limitations and deferred work

- **Payment processing is Phase 5.** `jobs.payment_status`, `payment_method` and refund fields are recorded but no processor is called. `job_cancellations.refund_status = 'pending'` is a placeholder.
- **No commissions, payouts or wallets.** Driver earnings and payout estimates are not computed yet.
- **No notification delivery.** Offers, events and disputes are persisted, but push/SMS/email belongs to Phase 6. `offer_job_to_driver()` returns the offer row as the source of truth.
- **`trip_alert_type` is defined but unused.** It is the vocabulary for the Phase 5/6 telemetry and safety pipeline.
- **Partition maintenance and stale-offer expiry are not scheduled.** `private.ensure_*_partitions()` and `public.expire_stale_offers()` are ready for a Phase 5 pg_cron job.
- **Driver location retention is documented, not enforced.** The 90-day purge is a Phase 5/6 operational job.
- **Dispute assignment is not modelled separately.** `assigned_to_name` is derived from `resolved_by`.
- **One promo per quote.** Stacking multiple codes is intentionally out of scope.
- **Quote-to-job uniqueness is client-only.** The database allows service/seed reuse of a quote so the required Phase 4 seed can demonstrate two jobs from one quote.
- **Promo redemption is recorded at job creation, not quote creation.** Unconverted quotes do not consume a redemption.
- **No loyalty tiers, insurance, tolls or financing** are modelled.
