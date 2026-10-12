# Policy 0003 — Row Level Security (RLS) Policies

- **Status:** Accepted (Sprint 1)
- **Date:** 2026-10-07
- **Enforcement:** Sprint 2 migrations (RLS enabled on every table; deny by default)

> **Hard rule (non-negotiable):**
> **The Supabase service-role key (which bypasses RLS) lives ONLY inside Edge
> Functions. It is NEVER shipped to a mobile or web client. This is a
> non-negotiable rule.**

Mobile and web clients use only the Supabase **anon key** plus the signed-in
user's Auth JWT. Any operation that needs to bypass RLS (admin reads,
payment-status changes, audit writes) goes through an Edge Function that holds
the service-role key server-side and re-authorizes the caller.

Conventions for the rules below: **read** = SELECT; **write** = INSERT /
UPDATE / DELETE as noted. All policies assume an authenticated user with
`auth.uid()` mapped to `profiles.id`. Unauthenticated (anon) access is denied
on every table except where explicitly noted (nowhere in v1).

---

## 1. `profiles`

- **Read:** a user reads their own row (`id = auth.uid()`). Admins read all —
  only via Edge Functions with the service-role key, never direct client reads.
- **Write:** a user updates their own non-privileged fields (`full_name`,
  `phone`, `email`). `role` is NOT client-writable (role changes are an
  audited Edge Function operation). No client deletes.
- **Rationale:** role drives every other policy; letting clients escalate
  their own role would collapse the model.

## 2. `drivers`

- **Read:** a driver reads their own row (`id = auth.uid()`). A customer
  reads a driver's **public profile subset** (name via `profiles`, `rating`,
  `vehicle_class` via `vehicles`) **only once matched on a job** (i.e. a
  `jobs` row exists linking them) — enforced via a job-membership check, not
  a blanket select. Admins read all via Edge Functions.
- **Write:** a driver updates their own operational fields (`licence_number`,
  `licence_expiry_date`, `vehicle_id`, `operating_zones`, `service_hours`,
  `is_available`). `verification_status`, `risk_tier`, `rating`, `total_trips`
  are NOT client-writable (Edge Functions / admin flows only, each writing
  `audit_log`).
- **Rationale:** dispatch eligibility and reputation are server-computed;
  drivers control availability, not trust state.

## 3. `vehicles`

- **Read:** a driver reads/updates their own vehicles
  (`vehicles.driver_id = auth.uid()`). A customer reads the vehicle details
  for the driver on **their active job** only. Admins read all via Edge
  Functions.
- **Write:** a driver inserts/updates their own vehicle rows (capacity,
  registration, ownership, insurance date). `verification_status` is NOT
  client-writable (admin verification flow only, audited).
- **Rationale:** compliance state (insurance/verification) gates dispatch and
  must not be self-asserted.

## 4. `jobs`

- **Read:** a customer reads only jobs where they are the customer
  (`jobs.customer_id = auth.uid()`). A driver reads only jobs where they are
  the driver (`jobs.driver_id = auth.uid()`). Admins read all via Edge
  Functions. No cross-customer or cross-driver visibility.
- **Write:**
  - **Customers** create jobs (with `driver_id`/`vehicle_id` null,
    `status = requested`, `payment_status = pending`) and may cancel their own
    jobs within the allowed states (→ `cancelled`).
  - **Drivers** advance job state on jobs assigned to them
    (`accepted → heading_to_pickup → arrived → loading → in_transit →
    delivered`); they cannot change `customer_id`, money fields, or
    `payment_status`.
  - **Only Edge Functions (service role)** change `payment_status` and set
    `driver_id`/`vehicle_id` during matching, and mark `completed`/`disputed`
    transitions that carry money or trust consequences.
- **Rationale:** the job is the money record — state advances are
  role-restricted and payment truth is server-only.

## 5. `job_evidence`

- **Read:** only the customer and driver on the job
  (`jobs.customer_id = auth.uid() OR jobs.driver_id = auth.uid()` via the
  parent job). Admins read via Edge Functions.
- **Write:** only the customer and driver on the job may add rows
  (INSERT; no UPDATE/DELETE — evidence is append-only). Storage objects follow
  the same membership rule.
- **Rationale:** proof must be tamper-evident and visible only to the two
  counterparties plus support.

## 6. `payments`

- **Read:** the customer and driver on the job read payment **status**
  (amount/status/provider, not raw secrets). Admins read all via Edge Functions.
- **Write:** **only Edge Functions write** payments (INSERT from checkout
  initiation; UPDATE from provider webhooks with the service role). No direct
  client writes of any kind.
- **Rationale:** money truth comes from provider webhooks, never from client
  claims.

## 7. `trip_alerts`

- **Read:** the customer and driver on the job read alerts for their job.
  Admins read all via Edge Functions.
- **Write:** alert rows are created by server-side trip monitoring (Edge
  Functions / scheduled jobs with the service role), not by clients.
  **Admins resolve** (`is_resolved`, `resolved_by`) via Edge Functions.
  Clients never set `is_resolved`.
- **Rationale:** SOS and deviation signals must be trustworthy and
  resolution must be attributable to support staff.

## 8. `cities`, `pricing_config`

- **Read:** all authenticated users read (quotes and city config must be
  visible to price transparently).
- **Write:** **only admins via service role** (Edge Functions). Every write
  appends an `audit_log` row with old/new values.
- **Rationale:** pricing is the trust surface of the marketplace; changes are
  versioned (`effective_from`/`effective_to`) and audited.

## 9. `audit_log`

- **Read:** **only admins** via Edge Functions. No customer/driver reads.
- **Write:** **only Edge Functions** (service role). No client writes;
  rows are append-only (no UPDATE/DELETE).
- **Rationale:** the audit trail is evidence for disputes and regulators; if
  clients could write or erase it, it proves nothing.

## Implementation notes for Sprint 2

- Enable RLS on every table; default-deny; add one policy per operation above.
- Customer "matched driver public profile" and "vehicle on my active job"
  rules must join through `jobs` — never grant blanket SELECT on
  `drivers`/`vehicles`.
- `role` (profiles), trust fields (drivers/vehicles), money fields and
  `payment_status` (jobs/payments), and `audit_log` must have **no client
  write policy at all** — server-only paths.
- Storage buckets for evidence inherit the `job_evidence` membership rule.
