# Phase 6 — Communication, Safety, Support, Compliance and Analytics

**Status:** implemented and verified  
**Migrations:** `0097`–`0117`  
**Seed:** `supabase/seed-phase-6.sql`  
**Gate:** `supabase/scripts/verify-phase-6-schema.sql`  
**Depends on:** Phase 1 (identity, geography, RBAC, audit), Phase 2 (verification, vehicles, fleets), Phase 3 (pricing, currencies), Phase 4 (jobs, quotes, disputes, live locations) and Phase 5 (payments, wallets, commission)

---

## 1. Scope

Phase 6 adds the communication, safety, support, compliance and analytics layer on top of the operational and money layers. It delivers six domains:

| Domain | Tables |
| --- | --- |
| A. Communication | `push_tokens`, `notification_templates`, `notification_log`, `notification_preferences` |
| B. Chat | `chat_threads`, `chat_messages`, `chat_attachments`, `chat_read_receipts` |
| C. Safety | `emergency_contacts`, `incidents`, `incident_actions`, `blocked_users`, `prohibited_items` |
| D. Support | `support_categories`, `support_tickets`, `support_ticket_messages` |
| E. Compliance | `data_access_log`, `retention_policies`, `data_subject_requests` |
| F. Analytics | `daily_metrics`, `zone_metrics`, `driver_metrics`, `customer_metrics`, `demand_snapshots` |

That is 24 public tables. Four are range-partitioned by month:

- `notification_log` — 24 forward monthly partitions;
- `chat_messages` — 12 forward monthly partitions;
- `data_access_log` — 84 forward monthly partitions (seven years);
- `demand_snapshots` — 3 forward monthly partitions.

Each partitioned parent also has a default partition so rows outside the pre-created window are not lost. Partition children have no direct `anon` or `authenticated` grants; all client access goes through the parent and its RLS policies.

Phase 6 deliberately does **not** implement:

- Flutter application code or Edge Functions;
- real FCM, Beem/SMS, or Resend/email providers;
- ML demand forecasting, ETA prediction, fraud scoring or model tables;
- automated GDPR/PDPC export or deletion jobs;
- Phase 7 automation and delivery workers;
- changes to Phase 1–5 schema other than the permitted PII logging/RLS modification in `0115`.

---

## 2. Decisions

| ID | Decision | Implementation |
| --- | --- | --- |
| A | One push-token row per `(profile_id, device_id)`. FCM only; APNs is reached through FCM bridging. | `push_tokens.device_id` references `user_devices`; `UNIQUE (profile_id, device_id)`; provider is constrained to `fcm`. |
| B | Notification templates are per country per language. | `notification_templates` is unique on `(country_id, language_id, code, channel)` with `NULLS NOT DISTINCT`; seed contains Tanzania Swahili and English templates. |
| C | Notification log is append-only and partitioned monthly, retained 24 months. | `notification_log` is partitioned by `created_at`; content fields are immutable; status transitions are restricted; retention is 24 months. |
| D | Chat threads are scoped to jobs. Completed/cancelled threads become read-only, then archive after 30 days rather than delete. | `chat_threads.job_id UNIQUE`; `status` is `active`, `read_only` or `archived`; `archive_stale_chat_threads()` implements the transition. |
| E | PDPC requires access logging for non-owner, non-service-role reads of PII. | `data_access_log` is partitioned monthly for seven years; `log_pii_select()` is called from the four PII read policies. |
| F | Analytics tables are computed nightly, not in real time. | `compute_daily_metrics`, `compute_zone_metrics`, `compute_driver_metrics` and `compute_customer_metrics` are batch functions scheduled by pg_cron. |
| G | Realtime is limited to five approved tables. | Publication contains `jobs`, `driver_locations`, `job_events`, `chat_messages` and `notification_log`; `driver_locations` uses a column subset. |
| H | Retention periods live in `retention_policies` and are executed by pg_cron. | `apply_retention_policies()` reads the catalogue, drops old partitions, deletes eligible leftover rows and records the run. |
| I | Support tickets remain separate from Phase 4 disputes. | `support_tickets.related_dispute_id` is a nullable reference only; tickets have their own status, priority, category and messages. |
| J | GDPR/PDPC requests are tracked manually in Phase 6. | `data_subject_requests` records the request, identity verification, assignment, completion and delivered file path; automated export is deferred to Phase 7. |

Phase 5 decisions remain in force: `NUMERIC(14,2)` money with explicit `currency_code`, `SECURITY DEFINER` client money helpers with `SET search_path = ''`, the commission cascade, derived wallet balances, batched payouts and separated VAT/withholding.

---

## 3. Notifications

### 3.1 Push tokens

`push_tokens` stores one registration per `(profile_id, device_id)`:

- `token`, `provider`, `platform`, `app_version`;
- `is_active`, `last_used_at`;
- `UNIQUE (profile_id, device_id)` and a foreign key to `user_devices`; `provider` is constrained to `fcm`.

The function `send_notification()` chooses the most recently used active token for a profile. Device deletion cascades the token row.

### 3.2 Templates

Templates are country- and language-scoped. A `NULL` `country_id` is a global fallback. Resolution prefers:

1. exact country and preferred/fallback language;
2. exact country and English;
3. global template in the requested language;
4. global English template.

Push templates require a title; every channel requires a non-blank body. The `variables` array documents which placeholders the renderer understands. Rendering replaces both `{name}` and `{{name}}` forms.

The seed contains 18 Tanzania templates:

- 12 push templates (6 event codes × Swahili/English);
- 3 Swahili SMS templates;
- 3 English email templates.

The event codes are `job_offer`, `trip_started`, `trip_completed`, `payment_received`, `document_expiry` and `emergency_alert`.

### 3.3 Preferences and quiet hours

`notification_preferences` is unique on `(profile_id, category, channel)` and supports categories:

- `job_updates`, `payment`, `promotions`, `safety_alerts`, `chat`, `system`.

Quiet hours require both a start and an end. `send_notification()` treats them as a local-time window in the preference timezone, the country timezone, or `Africa/Dar_es_Salaam` as a final fallback. Overnight windows are supported. Safety/emergency templates bypass opt-out and quiet hours.

### 3.4 Send pipeline and the public-id compromise

`public.send_notification(profile, template_code, channel, variables, reference_type, reference_id)`:

1. authorises service role or `manage_notifications`;
2. resolves the recipient country and language;
3. resolves the template;
4. derives the preference category and criticality;
5. applies opt-out and quiet hours;
6. selects the push token, phone or email recipient;
7. renders variables;
8. inserts a `pending` row into `notification_log`;
9. returns the API-facing identifier.

`notification_log.id` is a `BIGINT` identity and the partition key `created_at` is part of the primary key. The function therefore returns `public_id UUID` rather than the composite/BIGINT identity. Actual provider delivery is Phase 7; Phase 6 stops at the log boundary.

Status transitions are:

- `pending` → `sent` or `failed`;
- `sent` → `delivered`, `failed` or `read`;
- `delivered` → `read`;
- `failed` → `pending` or `sent`.

Content fields, recipient, provider, reference and `created_at` are immutable. The append-only trigger allows the service/owner path to delete for retention, but client roles have no `DELETE` grant.

---

## 4. Chat

### 4.1 Threads

A thread is unique per job. The status lifecycle is:

- `active` — both job participants can send;
- `read_only` — the job is completed/cancelled but the 30-day archive window has not elapsed;
- `archived` — the 30-day window has elapsed; history remains readable.

`public.archive_stale_chat_threads()` performs the transition. It is called by the retention job and is idempotent.

### 4.2 Messages and attachments

`chat_messages` is monthly partitioned. It supports `text`, `image`, `location` and `system` messages. Soft deletion uses `is_deleted`/`deleted_at`; physical `DELETE` is blocked for clients and reserved for retention.

A partitioned table cannot be referenced by `id` alone, so three integrity checks are trigger-based:

- `reply_to_message_id` must exist in the same thread;
- `chat_attachments.message_id` must exist in the same thread;
- `chat_read_receipts.last_read_message_id` must exist in the same thread.

Message identity fields are immutable. A sender may edit the body/metadata within five minutes; the trigger sets `is_edited` and `edited_at`. A sender may soft-delete their own message, but cannot un-delete it. The thread summary (`last_message_at`, `last_message_preview`) is maintained by an insert trigger.

`chat_attachments` stores storage paths and file metadata. It does not store binary content; object storage is outside the database.

### 4.3 Read receipts

`chat_read_receipts` is unique on `(thread_id, profile_id)` and stores the last read message and timestamp. `chat_unread_summary` counts messages with an id greater than the stored last-read id.

---

## 5. Safety

### 5.1 Emergency contacts

`emergency_contacts` is profile-owned. A partial unique index enforces at most one primary contact per profile. Notification flags are recorded for trip-start and SOS events; actual delivery is Phase 7.

### 5.2 Incidents

`incidents` records:

- optional job linkage;
- reporter, type, severity and status;
- description, location, occurrence time;
- assignee, resolution time and summary.

Incident types are `accident`, `theft`, `harassment`, `damage`, `medical`, `security` and `other`. Severity is `low`, `medium`, `high` or `critical`. Status is `open`, `investigating`, `resolved` or `closed`.

`incident_actions` is an append-only lifecycle trail. Clients can read actions when they can read the incident; inserts are service/staff-only in Phase 6.

### 5.3 Blocked users

`blocked_users` prevents self-blocking and supports a global block or a job-specific block. A unique constraint with `NULLS NOT DISTINCT` covers `(blocker, blocked, scope, job_id)`.

### 5.4 Prohibited items

`prohibited_items` is a country catalogue of prohibited, licence-required and restricted-route cargo. The seed covers firearms, narcotics, hazardous materials, live animals, large cash consignments, wildlife products, ivory and counterfeit goods for Tanzania. Cargo-declaration integration is Phase 7.

---

## 6. Support

Support is intentionally separate from disputes:

- `support_categories` — per-country category catalogue with display order;
- `support_tickets` — ticket number, opener, assignee, category, status, priority, optional job/dispute references, SLA due time, resolution/closure and satisfaction rating;
- `support_ticket_messages` — append-only conversation with an `is_internal_note` flag.

Status is `open`, `in_progress`, `waiting_customer`, `resolved` or `closed`. Priority is `low`, `normal`, `high` or `urgent`. A closed ticket must have both `resolved_at` and `closed_at`.

Customers see their own tickets and non-internal messages. Staff with `view_all_tickets` see every ticket, including internal notes. Agents with `manage_tickets` or the current assignee can update tickets.

---

## 7. Compliance

### 7.1 Data access log

`data_access_log` records non-owner PII reads, exports and modifications. It is partitioned monthly for seven years. Fields include accessor, role, target profile, target table/field/id, access type, purpose and authorization result.

PostgreSQL has no `SELECT` trigger. Phase 6 uses an RLS predicate that calls `public.log_pii_select()` for the four highest-risk surfaces:

- `profiles`;
- `driver_documents`;
- `vehicle_documents`;
- `driver_locations`.

The predicate logs only when the caller is not the owner, not the service role and not an anonymous session. This is a deliberate database-level compromise:

- direct database reads by staff are logged;
- `service_role` reads bypass RLS and must be logged explicitly by the Edge Function that performs them;
- the current policy logs after permission checks in the same boolean expression, so unauthorized attempts may also be recorded as authorized; Phase 7 should refine the access-log writer with an explicit authorization result.

### 7.2 Retention policies

`retention_policies` is the declarative catalogue. The seed defines:

| Table | Retention | Action |
| --- | --- | --- |
| `driver_locations` | 90 days | delete |
| `job_events` | 5 years | delete |
| `audit_log` | 7 years | delete |
| `chat_messages` | 2 years | delete |
| `notification_log` | 24 months | delete |
| `data_access_log` | 7 years | delete |
| `demand_snapshots` | 90 days | delete |
| `daily_metrics` | indefinite | archive |

`apply_retention_policies()`:

1. runs the chat archive transition;
2. drops monthly partitions whose month ends before the cutoff;
3. deletes leftover rows from the default partition for non-append-only tables;
4. records `last_run_at` and `last_run_rows_affected`.

`job_events` and private `audit_log` are partition-drop only because their Phase 4/Phase 1 append-only triggers block `DELETE`. This is why retention never issues `DELETE` against those two parents.

### 7.3 Data subject requests

`data_subject_requests` tracks export, delete, rectify and restrict-processing requests. Fields cover request number, requester, status, reason, identity verification, assignment, completion, rejection and delivered file path. Phase 6 records and processes these manually; Phase 7 adds automated export/deletion.

---

## 8. Analytics

All analytics are batch-computed. No application query performs real-time aggregation.

### 8.1 Daily metrics

`compute_daily_metrics(target_date)` upserts one row per active city:

- jobs created/completed/cancelled;
- gross booking value, net revenue and currency;
- active/new customers and drivers;
- acceptance, completion time, cancellation rate and rating.

It writes zero rows for active cities with no jobs, so a nightly run still produces a complete city set.

### 8.2 Zone metrics

`compute_zone_metrics(target_date)` upserts one row per active service zone:

- demand score (0–100);
- available supply minutes;
- average ETA and surge multiplier;
- requested/fulfilled jobs.

Zone membership uses `ST_Within` on the quote-request pickup location and zone boundary.

### 8.3 Driver and customer metrics

`compute_driver_metrics(target_date)` writes one row per driver with trips, online hours, gross/net earnings, acceptance, on-time rate, rating and average distance.

`compute_customer_metrics(target_date)` writes one row per customer with jobs created/completed, spend, rating given and last activity.

### 8.4 Demand snapshots

`capture_demand_snapshot()` writes one row per active zone per five-minute bucket:

- active job requests;
- active drivers;
- pending offers;
- average wait seconds.

The seed contains **432 demand snapshots = 3 zones × 144 five-minute buckets (12 hours)**. The original brief was ambiguous between 144 total and 144 per zone; the gate accepts 432 as the seed baseline and tolerates additional buckets produced by the live pg_cron schedule.

### 8.5 Operational views

Six `security_invoker` views expose read models:

- `notification_summary`;
- `chat_unread_summary`;
- `incident_summary`;
- `support_ticket_summary`;
- `active_demand_zones`;
- `operational_dashboard`.

They are convenience projections, not security boundaries. RLS on the underlying tables applies.

---

## 9. Realtime

The `supabase_realtime` publication contains exactly five tables:

- `jobs`;
- `driver_locations` — column subset: `id`, `driver_id`, `job_id`, `location`, `heading_degrees`, `speed_kmh`, `recorded_at`;
- `job_events`;
- `chat_messages`;
- `notification_log`.

The publication uses `publish_via_partition_root = true`, so subscribers receive changes from the partitioned parents rather than individual child tables. Table RLS still applies to Realtime. Live-client validation is a Phase 7 task.

---

## 10. Scheduled jobs

Phase 6 registers six `safeshift_*` pg_cron jobs in addition to the four Phase 4/5 jobs:

| Job | Schedule | Action |
| --- | --- | --- |
| `safeshift_compute_daily_metrics` | `15 1 * * *` | daily city metrics |
| `safeshift_compute_zone_metrics` | `20 1 * * *` | daily zone metrics |
| `safeshift_compute_driver_metrics` | `25 1 * * *` | daily driver metrics |
| `safeshift_compute_customer_metrics` | `30 1 * * *` | daily customer metrics |
| `safeshift_capture_demand` | `*/5 * * * *` | demand snapshot |
| `safeshift_retention` | `0 5 * * *` | retention + chat archive |

The Phase 5 gate was narrowed from “exactly four `safeshift_*` jobs” to “exactly the four Phase 5 job names exist” so the Phase 6 schedules can coexist without weakening the Phase 5 check. The Phase 1 and Phase 3 “no future tables” guards were changed to Phase 7+ names.

---

## 11. RLS, permissions and grants

Every Phase 6 public table has RLS enabled and at least one policy. Policy expressions use scalar subqueries such as `(select auth.uid())` and `(select public.has_permission(...))` so PostgreSQL can initialise them once per statement.

Thirteen permissions were added:

`manage_notifications`, `view_incidents`, `manage_incidents`, `manage_prohibited_items`, `manage_support`, `view_all_tickets`, `manage_tickets`, `view_data_access`, `view_retention`, `manage_retention`, `manage_data_requests`, `view_analytics`, `manage_analytics`.

Assignments:

- `super_admin` — all 13;
- `operations_admin` — notifications, incidents, prohibited items, all tickets/ticket management and analytics viewing;
- `verification_admin` — incident viewing and analytics viewing;
- `support_agent` — incident viewing, ticket viewing/management, support management and data-request processing;
- `finance_admin` — analytics viewing;
- `analyst` — analytics, data-access and retention viewing.

Client grants are intentionally narrow:

- own-row CRUD: push tokens, preferences, emergency contacts, blocked users, read receipts;
- own-row select: notification log, support tickets/messages, data subject requests;
- participant select/insert: chat threads, messages, attachments;
- authenticated read: templates, prohibited items, support categories;
- staff writes: templates, prohibited items, support categories, retention policies, tickets;
- no client writes: notification log, data access log, incident actions, analytics tables and demand snapshots.

Because `supabase db reset` applies migrations as the `postgres` role, Supabase's default privileges can grant `ALL` on new public tables to `anon` and `authenticated`. Migration `0114` explicitly revokes all table and identity-sequence grants from those roles before applying the least-privilege grants above, so the gate behaves the same under CLI reset and the manual rebuild path.

The generic `private.audit_trigger()` is attached to 12 mutable communication, safety, support and compliance roots: push tokens, notification templates/preferences, chat threads, emergency contacts, incidents, blocked users, prohibited items, support categories/tickets, retention policies and data-subject requests. Append-only logs and high-volume telemetry/analytics tables are deliberately not audited row-by-row, matching the Phase 4/5 convention.

---

## 12. Seed

`supabase/seed-phase-6.sql` is registered after the Phase 5 seed and creates:

- 2 devices and 2 push tokens;
- 18 notification templates;
- 6 customer notification preferences;
- 2 chat threads and 8 messages;
- 2 chat attachments and 4 read receipts;
- 1 emergency contact;
- 2 incidents and 2 incident actions;
- 1 blocked user;
- 8 Tanzania prohibited items;
- 5 support categories, 2 tickets and 5 ticket messages;
- 5 data-access seed rows;
- 8 retention policies;
- 1 data subject request;
- 7 daily metric rows;
- 21 zone, 21 driver and 21 customer metric rows;
- 432 demand snapshots.

The seed is repeatable: fixed IDs and natural keys use `ON CONFLICT DO NOTHING`, while chat messages and attachments are guarded by per-thread/per-message existence checks.

---

## 13. Verification

`supabase/scripts/verify-phase-6-schema.sql` reports:

```text
PHASE 6 SCHEMA VERIFICATION: 154 PASS, 0 FAIL
```

It covers table inventory, RLS enablement and policies, scalar-subquery policy form, partition counts and privileges, Realtime membership and column subset, six cron schedules, six `security_invoker` views, SECURITY DEFINER/search_path discipline across public and private helpers, permissions, audit-trigger coverage, TEXT + CHECK status fields, money columns, seed counts, RLS read/write behaviour, PII logging, notifications, chat immutability and integrity, analytics writes, retention, and operational views.

The Phase 1–5 gates remain green:

```text
PHASE 1: 151 PASS, 0 FAIL
PHASE 2: 166 PASS, 0 FAIL
PHASE 3: 150 PASS, 0 FAIL
PHASE 4: 154 PASS, 0 FAIL
PHASE 5:  81 PASS, 0 FAIL
```

The gate is behavioural and removes its scratch rows from the domain tables. Audit entries for those scratch operations may remain in the append-only audit trail by design. Demand-snapshot count assertions tolerate extra five-minute buckets written by the live pg_cron schedule.

---

## 14. Known limitations and Phase 7 handoff

- No real push/SMS/email provider calls; `send_notification()` stops at `notification_log`.
- No Flutter or Edge Function changes.
- No automated DSR export or deletion.
- No ML/ETA/fraud models; only descriptive batch metrics.
- PII logging is trigger/policy-based, not a full database audit system; `service_role` reads must be logged by their callers.
- Chat storage is path/metadata only; object storage policy and malware scanning are Phase 7.
- Realtime has not been tested with a live client; publication and RLS are configured.
- Incident action inserts, notification delivery status updates and support agent assignment are service/staff workflows that should be exposed through Edge Functions in Phase 7.
