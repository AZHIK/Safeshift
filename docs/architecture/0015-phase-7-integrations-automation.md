# Phase 7 — Integrations and Automation

- **Status:** Accepted for implementation
- **Date:** 2026-10-28
- **Deciders:** Engineering
- **Depends on:** Phase 5 money layer, Phase 6 communication/safety layer, ADR 0014
- **Migrations:** `0118+` (additive)
- **Gate:** `supabase/scripts/verify-phase-7-schema.sql`

## 1. Context

Phases 1–6 delivered a verified database, but the system still stops at several
deliberate boundaries:

- `public.send_notification()` writes a `pending` row to `notification_log`;
  no provider actually delivers it.
- `payment_webhooks` stores raw provider events, but no Edge Function verifies
  signatures or reconciles them with `payments`.
- Realtime and Storage have schema/config support but no live-client proof.
- Flutter apps still use mock data.
- There are no server-side secrets, request logging, retry policy, or
  integration runbooks.

Phase 7 closes those boundaries. It does not add a new business domain; it
connects the existing domains to external providers and to live clients.

## 2. Scope

### 2.1 In scope

| Workstream                  | Outcome                                                                                                    |
| --------------------------- | ---------------------------------------------------------------------------------------------------------- |
| A. Edge Function foundation | Shared auth, HTTP, secrets, logging, error, and idempotency helpers.                                       |
| B. Notification delivery    | FCM push, Beem SMS, and Resend email delivery from `notification_log`, with retries and failure recording. |
| C. Payment webhooks         | Selcom and Flutterwave webhook ingestion, signature verification, idempotent storage, and reconciliation.  |
| D. Realtime and Storage     | Live-client tests for the five approved Realtime tables and the Phase 7 Storage buckets.                   |
| E. Flutter integration      | One end-to-end customer/driver flow using Supabase Auth, jobs, Realtime, and push-token registration.      |
| F. Operations               | Request IDs, structured logs, redaction, retry/dead-letter handling, dashboards, and runbooks.             |

### 2.2 Out of scope

- New payment providers beyond Selcom and Flutterwave.
- New notification channels beyond push, SMS, and email.
- ML demand forecasting, fraud scoring, ETA prediction, or model tables.
- Automated GDPR/PDPC export or deletion execution.
- Production provider accounts, production cutover, or app-store release.
- Changes to Phase 1–6 business rules other than the additive delivery and
  processing state required by this phase.

## 3. Architecture

```text
Flutter / Next.js
      │  JWT
      ▼
Supabase Edge Function  ──►  Postgres (RLS + service_role)
      │                            │
      │  provider HTTPS            │  notification_log / payment_webhooks
      ▼                            ▼
 FCM / Beem / Resend       pg_cron + pg_net
      ▲                            │
      │                            ▼
 Payment provider  ──►  public webhook Edge Function
```

Rules:

- Edge Functions are the only place provider secrets are read.
- Public webhook functions are the only functions allowed to skip JWT
  verification. Every other function rejects missing or invalid JWTs.
- Browser and Flutter code never receive `service_role`, provider secrets, or
  Vault values.
- All writes that touch money or job state are idempotent.
- Realtime and Storage continue to enforce table RLS and bucket policies.

## 4. Edge Function foundation

Every function uses the same `_shared` helpers:

```text
supabase/functions/_shared/
├── auth.ts       # JWT extraction, user lookup, service-role guard
├── http.ts       # JSON responses, request IDs, structured errors, CORS
├── idempotency.ts# idempotency keys and duplicate handling
├── logger.ts     # JSON logs and PII/token redaction
├── secrets.ts    # env/Vault resolution, required-secret checks
└── providers/    # fcm, beem, resend, selcom, flutterwave adapters
```

### 4.1 Request contract

- Every request gets a request ID from `x-request-id` or a generated UUID.
- Success responses return the resource plus `request_id`.
- Errors return:

```json
{
  "error": {
    "code": "unauthorized",
    "message": "A valid bearer token is required.",
    "request_id": "..."
  }
}
```

- The HTTP status is meaningful: `400` validation, `401` auth, `403`
  authorization, `404` not found, `409` duplicate/idempotency conflict,
  `422` provider rejection, `429` rate limit, `5xx` retryable failure.
- Stack traces and provider payloads are logged, never returned to clients.

### 4.2 Authentication

- `requireUser(req)` validates the bearer token through Supabase Auth and
  returns the profile and claims.
- `requireServiceRole(req)` is used only by cron/worker endpoints and compares
  a dedicated worker secret; it never trusts a client-supplied role claim.
- Webhook functions call `verifyProviderSignature()` before any database write.
- The database still enforces RLS; the Edge Function is not the only
  authorization layer.

### 4.3 Secrets

- Local development reads `.env` or `supabase/functions/.env.local`.
- Deployed functions read Supabase Edge Function secrets or Vault values.
- `payment_providers.webhook_secret_reference` stores only a Vault key name.
- Secret values are never logged. `logger.redact()` removes tokens, phone
  numbers, emails, authorization headers, and keys matching
  `secret|token|password|private_key`.

## 5. Notification delivery

### 5.1 Source of truth

`notification_log` remains the delivery log and queue. A row is eligible when:

- `status = 'pending'`; or
- `status = 'failed'` and the retry policy allows another attempt.

The first implementation processes rows by `public_id` and records every
attempt in a new `notification_delivery_attempts` table (migration `0119`).
That table is append-only and service-role only. It stores:

- notification `public_id`;
- attempt number;
- provider and request ID;
- status (`succeeded`, `retryable`, `permanent_failure`);
- provider status code and redacted error;
- duration in milliseconds.

### 5.2 Status transitions

The Phase 6 trigger already permits:

- `pending` → `sent` / `failed`;
- `sent` → `delivered` / `failed` / `read`;
- `delivered` → `read`;
- `failed` → `pending` / `sent`.

Phase 7 uses:

- provider accepted → `sent`, then provider receipt → `delivered`;
- retryable error → `failed` with a redacted `failure_reason`, then `pending`
  when the retry window opens;
- permanent error or exhausted retries → `failed` with a dead-letter marker in
  `provider_response`.

### 5.3 Retry policy

- Maximum 5 attempts.
- Backoff: 1, 5, 15, 60, and 240 minutes, with jitter.
- Retry only on network errors, `429`, and `5xx`.
- Do not retry invalid tokens, malformed payloads, or provider `4xx`
  validation errors.
- An invalid FCM token deactivates the matching `push_tokens` row.
- A retry is keyed by `notification_log.public_id`; duplicate worker runs must
  not send twice.

### 5.4 Provider adapters

| Provider    | Channel | Contract                                                                                                                  |
| ----------- | ------- | ------------------------------------------------------------------------------------------------------------------------- |
| FCM HTTP v1 | Push    | OAuth service-account token; send to the active device token; map `UNREGISTERED`/`INVALID_ARGUMENT` to permanent failure. |
| Beem        | SMS     | API key/secret; Tanzania sender ID; map provider status to retryable/permanent.                                           |
| Resend      | Email   | API key; template body as HTML/text; map `4xx` validation to permanent, `429`/`5xx` to retryable.                         |

Provider calls use a 10-second timeout. The worker never holds a database
transaction open while waiting on a provider.

### 5.5 Triggering

- Local: `supabase functions serve notification-dispatch` plus a manual POST.
- Deployed: `pg_cron` calls `pg_net.http_post` every minute with the worker
  secret. The Edge Function claims a bounded batch (default 25) and exits.
- A second cron job retries `failed` rows whose backoff has elapsed.
- The worker is safe to run concurrently; claims use row locks or an
  idempotent attempt record.

## 6. Payment webhooks

### 6.1 Endpoints

- `POST /functions/v1/webhooks/selcom`
- `POST /functions/v1/webhooks/flutterwave`

These are the only public endpoints in Phase 7. They accept raw bodies, verify
the provider signature, insert the raw event into `payment_webhooks`, and
return `2xx` only after the event is durably stored.

### 6.2 Processing

1. Resolve the provider by country and code.
2. Verify the signature against the Vault-backed secret reference.
3. Insert the raw payload with `signature_valid`, `event_type`, `event_id`,
   and `provider_reference`.
4. Let the Phase 5 dedupe trigger reject duplicate `(provider_id, event_id)`
   events.
5. Return `200` for a new event, `200`/`409` for a duplicate, and `401` for an
   invalid signature.
6. A separate processor claims `pending` rows, reconciles
   `provider_reference` with `payments`, and moves the webhook to `processed`,
   `ignored`, or `error`.

### 6.3 Money invariants

- The webhook handler never edits `payments.amount`, `currency_code`, or
  `job_id`.
- A provider success can only move a payment toward `succeeded`; it cannot
  create a second charge.
- Refunds remain separate `payments` rows linked by `refund_of_payment_id`.
- The Phase 5 immutability trigger remains the final guard.
- A webhook that cannot be reconciled is stored as `error` and surfaced in the
  finance runbook; it is never silently dropped.

## 7. Realtime and Storage

### 7.1 Realtime

The publication remains limited to:

- `jobs`;
- `driver_locations` (approved column subset);
- `job_events`;
- `chat_messages`;
- `notification_log`.

Phase 7 proves with a live client that:

- an authenticated customer receives job and chat changes;
- a driver receives only their own job/location changes;
- anon receives nothing;
- a user cannot subscribe to another user's rows.

### 7.2 Storage

Phase 7 defines and tests these private buckets:

- `avatars` — profile images;
- `documents` — driver and vehicle documents;
- `job-proofs` — pickup/delivery evidence;
- `chat-attachments` — chat images and files.

Rules:

- Buckets are private by default.
- Object paths start with the owner/profile or job scope.
- Signed URLs are short-lived.
- Uploads are size- and MIME-limited.
- `service_role` may read for moderation; clients never receive it.

## 8. Flutter integration

One vertical slice proves the mobile path:

1. Customer signs in with Supabase Auth.
2. Customer creates a job through an Edge Function or RPC.
3. Driver sees the job through RLS and Realtime.
4. Driver updates status; the customer receives the Realtime update.
5. Customer opens chat; messages arrive over Realtime.
6. Both apps register an FCM token through `push_tokens`.
7. A notification is written by `send_notification()` and delivered by the
   worker.

The slice is intentionally narrow. It proves auth, RLS, Realtime, Storage, and
push together without rewriting the whole app.

## 9. Observability and operations

- Structured JSON logs with `request_id`, function name, route, status, and
  duration.
- Provider latency and error-rate counters per provider/channel.
- Dead-letter views for `notification_log` and `payment_webhooks`.
- Runbooks:
  - rotate a provider secret;
  - replay a failed notification;
  - reconcile a stuck webhook;
  - disable a provider;
  - investigate a duplicate charge.
- Alerts:
  - webhook signature failures above threshold;
  - notification failure rate above threshold;
  - pending webhook age above 10 minutes;
  - Realtime connection failures.

## 10. Phase 7 gate

`supabase/scripts/verify-phase-7-schema.sql` runs after the Phase 1–6 gates and
checks the integration contract, not provider credentials:

- Phase 5/6 prerequisite tables and columns exist;
- `notification_log` and `payment_webhooks` remain partitioned and retain
  their status constraints;
- `send_notification()` is `SECURITY DEFINER` with an empty `search_path` and
  is not executable by `anon`;
- client roles cannot write `notification_log` or `payment_webhooks`;
- service-role access remains available for workers;
- RLS and policies remain enabled;
- immutability and webhook-dedupe triggers remain installed;
- provider secrets are referenced by name, not stored in
  `payment_providers.config`;
- the five approved Realtime tables are published;
- `pg_cron` and `pg_net` are available for scheduled workers;
- all public `SECURITY DEFINER` functions that are not client entry points are
  not executable by `anon`;
- active push, SMS, and email templates exist for the first delivery slice.

`pnpm db:verify` runs Phase 1–7. A Phase 7 implementation is not complete until
the gate is green and the live-client checks in sections 5–8 have passed.

## 11. Rollout

1. **Local:** migrations, gate, `functions serve`, mock provider endpoints.
2. **Sandbox:** real Selcom/Flutterwave test keys, FCM test project, Beem and
   Resend test credentials.
3. **Staging:** production-like secrets in Vault, cron workers enabled, live
   Realtime/Storage tests.
4. **Production:** provider accounts, alerting, runbooks, and a rollback plan
   that can disable a provider without a database migration.

## 12. Risks

| Risk                      | Mitigation                                                                         |
| ------------------------- | ---------------------------------------------------------------------------------- |
| Duplicate provider events | Database dedupe trigger plus idempotency keys.                                     |
| Duplicate sends           | Claim rows, record attempts, and use `public_id` as the key.                       |
| Secret leakage            | Env/Vault only, redaction, no secrets in logs or client bundles.                   |
| Provider outage           | Retry with backoff, dead-letter state, provider kill switch.                       |
| Realtime over-sharing     | Keep the five-table publication and test RLS with live clients.                    |
| Storage path traversal    | Owner/job-scoped paths, private buckets, signed URLs.                              |
| Webhook forgery           | Signature verification before insert, invalid signatures stored but not processed. |
| Cron storm                | Bounded batches, advisory locks, and one-minute schedules.                         |

## 13. Alternatives rejected

- **Provider calls from Postgres:** `pg_net` is useful for triggering workers,
  but provider payloads, retries, and secret handling belong in Edge Functions.
- **Send notifications directly from `send_notification()`:** a database
  transaction cannot safely wait on FCM/Beem/Resend, and retries would be
  coupled to the write path.
- **Process webhooks synchronously in the HTTP handler:** a provider timeout
  would lose the event. Store first, process asynchronously.
- **Expose `service_role` to Flutter for convenience:** violates the security
  baseline and makes RLS meaningless.
- **Add a new integration database:** the existing Phase 5/6 tables already
  have the right boundaries; Phase 7 adds state, not a second source of truth.
