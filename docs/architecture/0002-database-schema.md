# Design 0002 — SafeShift Database Schema (written design, not SQL)

- **Status:** Accepted (design) — SQL migrations to be written in Sprint 2 from this document
- **Date:** 2026-10-07 (Sprint 1)
- **Source of truth at runtime:** Supabase Postgres with PostGIS — the single core data layer
- **Scope:** Design on paper only. No SQL in Sprint 1.

This document is the **reference for Sprint 2 migrations**. Every table below
must be implemented with the columns, relationships, and RLS intent described
here. Column types are given in **plain English**; the migration author chooses
exact Postgres types (with PostGIS `geography` for points, decimals for money).

Global conventions (apply to every table):

1. **Location storage:** pickup / destination / alert locations are PostGIS
   `geography` points. This enables fast "nearby driver" queries directly in
   the database (e.g. drivers within N km of a pickup) without an external
   geo-service.
2. **Money storage:** amounts are decimals with two places; currency is a
   separate field (default TZS). Never store money as text.
3. **Timestamps:** every table has a creation timestamp and an update
   timestamp (where the spec lists only `created timestamp`, migrations still
   add `updated timestamp` per convention §3 — see per-table notes). `jobs`
   additionally carries `scheduled / started / completed` timestamps for
   dispute resolution.
4. **Multi-city readiness:** no city-specific logic is hardcoded. Cities and
   pricing live in `cities` / `pricing_config`.
5. **Auditability:** every sensitive action writes to `audit_log` (verification
   approvals, payout changes, admin overrides, pricing-config changes).

Conventions used below: **Required** = must have a value (NOT NULL);
**Nullable** = may be empty. Relationships name the target table and behaviour.

---

## 1. Identity and People

### 1.1 `profiles` — one row per user (customer, driver, business, admin)

**Purpose:** Canonical user record linked to Supabase Auth; role drives RLS.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Linked to Supabase Auth user ID (one row per auth user) |
| role | text, fixed list | Required | `customer` / `driver` / `business` / `admin`; drives RLS and app routing |
| full_name | text | Required | Display name shown to counterparties and support |
| phone | text (E.164) | Required, unique | OTP identity (Beem Africa); unique login handle for drivers/most customers |
| email | text | Nullable | Used for business accounts (email/password) and Resend email |
| created_at | timestamp | Required | Record creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** parent of `drivers.id`, referenced by `jobs.customer_id`,
  `jobs.driver_id`, `trip_alerts.resolved_by`, `audit_log.actor_id`.
- **RLS intent:** users read/update their own row; admins (service role via
  Edge Functions) read all. See `0003-rls-policies.md`.

### 1.2 `drivers` — driver-specific data

**Purpose:** Verification, dispatch eligibility, and reputation for one driver.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Linked to `profiles.id` (the same person; role = `driver`) |
| licence_number | text | Required | Driving licence number collected at onboarding |
| licence_expiry_date | date | Required | Licence validity; expiry triggers `re_verification_due` |
| vehicle_id | reference to vehicles | Nullable | Currently operated vehicle; nullable (driver may be between vehicles) |
| verification_status | text, fixed list | Required | `pending` / `verified` / `rejected` / `re_verification_due`; only `verified` is dispatch-eligible |
| risk_tier | text, fixed list | Required, default `standard` | `standard` / `enhanced` / `restricted`; gates job eligibility and oversight |
| operating_zones | list of text | Required, default empty | Zones the driver accepts jobs in (Stage 1: Dar es Salaam corridors) |
| service_hours | structured data | Nullable | e.g. days + start/end windows; used by matching and availability |
| rating | decimal 0–5 | Required, default 0 | Aggregate customer rating shown on matched profiles |
| total_trips | integer | Required, default 0 | Completed-trip counter; feeds reputation and analytics |
| is_available | boolean (availability flag) | Required, default false | Whether the driver currently accepts offers |
| created_at | timestamp | Required | Record creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `drivers.id → profiles.id` (one-to-one);
  `drivers.vehicle_id → vehicles.id` (nullable); referenced by
  `vehicles.driver_id`, `jobs.driver_id`.
- **RLS intent:** a driver reads/updates their own row (except
  `verification_status`, `risk_tier`, `rating`, `total_trips` — admin/server
  managed); customers read a matched driver's public profile (name, rating,
  vehicle class) once matched on a job; admins read all.

### 1.3 `vehicles` — vehicle data

**Purpose:** Capacity, identity, and compliance record for each truck/van.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Vehicle record identifier |
| driver_id | reference to drivers | Required | Owning/operating driver (`drivers.id`); fleet vehicles link via their assigned driver row |
| vehicle_class | text, fixed list | Required | `small_van` / `pickup` / `medium_truck` / `large_truck` / `special`; drives pricing and matching |
| registration_number | text | Required, unique | Plate number; unique ID for roadside/compliance checks |
| capacity_kg | decimal | Required | Payload capacity in kilograms; used by matching and quote engine |
| capacity_cbm | decimal | Required | Volume capacity in cubic metres; used by matching and quote engine |
| ownership_type | text, fixed list | Required | `owned` / `authorized` / `fleet`; `authorized`/`fleet` require proof documents |
| insurance_expiry_date | date | Required | Insurance validity; expiry blocks dispatch |
| verification_status | text, fixed list | Required | `pending` / `verified` / `rejected` / `re_verification_due` (same lifecycle as drivers) |
| created_at | timestamp | Required | Record creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `vehicles.driver_id → drivers.id`;
  referenced by `drivers.vehicle_id`, `jobs.vehicle_id`.
- **RLS intent:** a driver reads/updates their own vehicles (status fields are
  admin/server managed); customers read the vehicle on their active job;
  admins read all.

---

## 2. Jobs and Money

### 2.1 `jobs` — the core booking record

**Purpose:** Single lifecycle record for one booking from request to completion/cancellation/dispute.

Job status (fixed list, forward-only except `cancelled`/`disputed`):
`requested → quoted → matched → accepted → heading_to_pickup → arrived →
loading → in_transit → delivered → completed`, plus `cancelled`, `disputed`.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Booking identifier shared across apps, web, payments, evidence |
| customer_id | reference to profiles | Required | Booking customer (`profiles.id`, role `customer` or `business`) |
| driver_id | reference to drivers | Nullable | Matched driver; null until matching assigns one |
| vehicle_id | reference to vehicles | Nullable | Assigned vehicle; null until matching assigns one |
| status | text, fixed list | Required | Lifecycle state (list above); writes restricted by role |
| pickup_location | geographic point (PostGIS geography) | Required | Machine-readable pickup for nearby-driver queries |
| pickup_address | text | Required | Human-readable pickup shown to driver/customer |
| destination_location | geographic point (PostGIS geography) | Required | Machine-readable destination for distance/ETA and deviation checks |
| destination_address | text | Required | Human-readable destination |
| cargo_category | text | Required | e.g. household, office, commercial cargo; feeds pricing complexity |
| cargo_declared_value | decimal (2 places) | Nullable | Declared value for protection-model coverage |
| distance_km | decimal | Nullable | Quoted/measured distance in km; set at quote time |
| estimated_duration_minutes | integer | Nullable | ETA in minutes; set at quote time |
| quote_amount | decimal (2 places) | Nullable | Quoted price shown to customer; set at quote time |
| final_amount | decimal (2 places) | Nullable | Settled amount after completion/adjustments |
| payment_status | text, fixed list | Required, default `pending` | `pending` / `paid` / `refunded` / `failed`; only Edge Functions (service role) change this |
| payment_method | text | Nullable | e.g. mobile-money provider / card brand; display + reconciliation |
| scheduled_at | timestamp | Nullable | Requested pickup time; null = ASAP |
| started_at | timestamp | Nullable | When the active leg started; dispute-resolution evidence |
| completed_at | timestamp | Nullable | When the job reached terminal state; dispute-resolution evidence |
| created_at | timestamp | Required | Record creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `jobs.customer_id → profiles.id`;
  `jobs.driver_id → drivers.id` (nullable); `jobs.vehicle_id → vehicles.id`
  (nullable); parent of `job_evidence.job_id`, `payments.job_id`,
  `trip_alerts.job_id`.
- **RLS intent:** customers read only their own jobs; drivers read only jobs
  where they are the driver; admins read all. Customers create/cancel; drivers
  advance state; only Edge Functions change `payment_status`.

### 2.2 `job_evidence` — photos, signatures, OTP confirmations

**Purpose:** Tamper-evident proof trail for pickup and delivery.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Evidence record identifier |
| job_id | reference to jobs | Required | Job this evidence belongs to |
| evidence_type | text, fixed list | Required | `pickup_photo` / `delivery_photo` / `signature` / `otp` / `document` |
| storage_path | text | Required | Path in Supabase Storage (bucket + key); never a public URL with secrets |
| metadata | structured data | Nullable | e.g. GPS fix, device timestamp, OTP check reference, signer name |
| created_at | timestamp | Required | Capture/upload time (dispute evidence) |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `job_evidence.job_id → jobs.id` (many-to-one).
- **RLS intent:** only the customer and driver on the job read/add; admins read.

### 2.3 `payments` — every payment attempt

**Purpose:** Append-only ledger of payment attempts per job; reconciled against provider webhooks.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Payment-attempt identifier |
| job_id | reference to jobs | Required | Job being paid for |
| amount | decimal (2 places) | Required | Attempted amount; currency kept separate |
| currency | text | Required, default `TZS` | ISO code; pilot default TZS |
| provider | text | Required | e.g. Selcom / Flutterwave / Stripe (provider of this attempt) |
| provider_reference | text | Nullable | Provider-side transaction reference; set on callback |
| status | text, fixed list | Required | `initiated` / `pending` / `completed` / `failed` / `refunded` |
| webhook_payload | structured data | Nullable | Raw provider callback stored for reconciliation and disputes |
| created_at | timestamp | Required | Attempt creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `payments.job_id → jobs.id` (many-to-one; retries create
  new rows, never mutate a settled row except via webhook-driven status).
- **RLS intent:** counterparties on the job read payment status; only Edge
  Functions write (from webhooks with the service role).

### 2.4 `trip_alerts` — route deviations, prolonged stops, SOS

**Purpose:** Safety/oversight signal stream generated during active trips.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Alert identifier |
| job_id | reference to jobs | Required | Active job the alert belongs to |
| alert_type | text, fixed list | Required | `route_deviation` / `prolonged_stop` / `sos` / `unusual_activity` |
| location | geographic point (PostGIS geography) | Nullable | Fix at alert time (SOS should always include it; others best-effort) |
| details | structured data | Nullable | e.g. expected vs actual route, stop duration, device metadata |
| is_resolved | boolean (resolved flag) | Required, default false | Whether the alert has been handled |
| resolved_by | reference to profiles | Nullable | Admin/support who resolved it; null until resolved |
| created_at | timestamp | Required | Alert-raised time (response-time evidence) |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `trip_alerts.job_id → jobs.id`;
  `trip_alerts.resolved_by → profiles.id` (nullable).
- **RLS intent:** customer and driver on the job read; admins read and resolve.

---

## 3. Configuration (multi-city replication)

### 3.1 `cities` — each operating city

**Purpose:** One row per operating city; city-specific rules live in `config`, never in code.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | City identifier referenced by pricing and (later) jobs/drivers |
| name | text | Required | e.g. `Dar es Salaam` |
| country | text | Required | e.g. `Tanzania` |
| currency | text | Required | e.g. `TZS`; default currency for quotes in this city |
| timezone | text | Required | e.g. `Africa/Dar_es_Salaam`; scheduling and SLA math |
| is_active | boolean (active flag) | Required, default true | Whether the city accepts new bookings |
| config | structured data | Nullable | City-specific rules (zones, SLA windows, feature flags) |
| created_at | timestamp | Required | Record creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** parent of `pricing_config.city_id`.
- **RLS intent:** all authenticated users read; only admins (service role) write.

### 3.2 `pricing_config` — pricing rules per city per vehicle class

**Purpose:** Versioned tariff table so quotes are reproducible and regulatable.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Tariff-row identifier |
| city_id | reference to cities | Required | City this rule applies to |
| vehicle_class | text, fixed list | Required | Same five values as `vehicles.vehicle_class` |
| base_fee | decimal (2 places) | Required | Fixed fee per job in city currency |
| per_km_rate | decimal (2 places) | Required | Rate per kilometre |
| per_minute_rate | decimal (2 places) | Required | Rate per minute (traffic/waiting component) |
| cargo_complexity_multiplier | decimal | Required, default 1 | Multiplier by cargo category/difficulty |
| is_regulated | boolean | Required, default false | Whether a regulatory tariff constrains this rule |
| regulatory_tariff | structured data | Nullable | Regulatory caps/floors and reference (LATRA touchpoints land here) |
| effective_from | timestamp | Required | Start of validity window (versioning) |
| effective_to | timestamp | Nullable | End of validity window; null = current rule |
| created_at | timestamp | Required | Record creation time |
| updated_at | timestamp | Required | Last modification time |

- **Relationships:** `pricing_config.city_id → cities.id` (many-to-one).
  Uniqueness on (`city_id`, `vehicle_class`, `effective_from`) to be enforced
  in Sprint 2 migrations.
- **RLS intent:** all authenticated users read; only admins (service role) write.
  Every change writes an `audit_log` row.

---

## 4. Compliance

### 4.1 `audit_log` — every sensitive action

**Purpose:** Append-only record of sensitive actions for dispute resolution and regulatory compliance.

| Column | Type (plain English) | Required / Nullable | Purpose |
| ------ | -------------------- | ------------------- | ------- |
| id | unique ID | Required, primary key | Audit-row identifier |
| actor_id | reference to profiles | Nullable | Who acted; null only for system-initiated rows |
| action | text | Required | e.g. `driver.verified`, `payout.changed`, `admin.override`, `pricing.updated` |
| entity_type | text | Required | e.g. `driver`, `vehicle`, `job`, `payment`, `pricing_config` |
| entity_id | text | Required | ID of the affected row (text to span entity types) |
| old_value | structured data | Nullable | State before the action |
| new_value | structured data | Nullable | State after the action |
| ip_address | text (IP) | Nullable | Caller IP where available |
| created_at | timestamp | Required | When the action occurred (immutable) |
| updated_at | timestamp | Required | Last modification time (row itself is append-only; updates forbidden by policy) |

- **Relationships:** `audit_log.actor_id → profiles.id` (nullable).
- **RLS intent:** only admins read; only Edge Functions write. No client writes.

---

## Key design decisions (restated for the migration author)

1. **PostGIS geography** for `jobs.pickup_location`,
   `jobs.destination_location`, `trip_alerts.location` — nearby-driver and
   deviation queries run in-database.
2. **Decimals for money** (`quote_amount`, `final_amount`,
   `cargo_declared_value`, `payments.amount`, all tariff fields) with a
   separate `currency` field. Never text.
3. **Timestamps everywhere** (`created_at` + `updated_at` on all tables) plus
   `scheduled_at` / `started_at` / `completed_at` on `jobs` for disputes.
4. **Config-driven cities:** `cities` + `pricing_config` with validity windows;
   no city logic hardcoded. Pilot seed row: Dar es Salaam / Tanzania / TZS /
   `Africa/Dar_es_Salaam`.
5. **Audit everything sensitive** via `audit_log` (verification approvals,
   payout changes, admin overrides, pricing-config changes).

## What Sprint 2 must enforce (non-exhaustive checklist)

- PostGIS extension + geography columns + spatial indexes on location fields.
- Unique constraints: `profiles.phone`, `vehicles.registration_number`,
  (`pricing_config`: `city_id` + `vehicle_class` + `effective_from`).
- Foreign keys as documented above; `jobs.driver_id` / `jobs.vehicle_id`
  nullable until matching.
- Check constraints on fixed lists (role, verification_status, risk_tier,
  vehicle_class, job status, payment status, alert type, evidence type).
- RLS enabled on every table per `0003-rls-policies.md` (policies deny by
  default; service role reserved for Edge Functions).
- Seed: one `cities` row for Dar es Salaam; one current `pricing_config` row
  per vehicle class.
