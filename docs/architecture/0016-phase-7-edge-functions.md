# Phase 7 — Edge Functions Implementation

- **Status:** Implemented locally; not deployed
- **Date:** 2026-10-28
- **Scope ADR:** `docs/architecture/0015-phase-7-integrations-automation.md`
- **Migrations:** `0118_phase_7_security_hardening.sql`, `0119_phase_7_edge_function_support.sql`
- **Function gate:** `supabase/scripts/verify-phase-7-functions.sh`
- **Database gate:** `pnpm db:verify` (Phases 1–7)

## 1. Purpose and boundaries

Phase 7 adds the server-side integration layer between the verified Phase 1–6
database and external providers. It covers JWT-protected user functions,
provider webhooks, notification delivery, Maps caching, payment initiation and
reconciliation, refunds, payouts, data export, and scheduled automation.

The implementation stays inside `supabase/functions/`, additive migrations,
`supabase/config.toml`, `supabase/scripts/`, and architecture documentation.
Flutter applications, Phase 1–6 migrations, and the Phase 1–6 verification
scripts are unchanged. No staging or production deployment is performed.

## 2. Runtime and layout

Functions run on Deno 2 (Supabase Edge Runtime). No Node.js runtime or Node-only
provider SDK is used. Every function directory contains:

- `index.ts` — `Deno.serve(createHandler(name, handle))`.
- `handler.ts` — testable handler with injected dependencies.
- `README.md` — auth, request, response, secret, and error contract.

`_shared/` contains cross-cutting code. `_tests/` contains Deno tests with
in-memory Supabase, auth, provider, and cache fakes. Directories beginning with
`_` are not deployed as functions.

## 3. Function inventory

| # | Function | Gate | Responsibility |
| --- | --- | --- | --- |
| 1 | `health` | public | Database/Vault readiness. |
| 2 | `auth-validate` | JWT | Hydrated role, country, permissions. |
| 3 | `maps-distance` | JWT | Routes API + cache. |
| 4 | `maps-geocode` | JWT | Forward/reverse geocode + cache. |
| 5 | `quote-calculate` | JWT | Phase 4 quote RPC. |
| 6 | `sms-send` | permission/internal | Beem SMS, Africa's Talking fallback. |
| 7 | `email-send` | permission/internal | Resend email. |
| 8 | `push-send` | permission/internal | FCM push. |
| 9 | `notification-dispatch` | permission | Multi-channel template fan-out. |
| 10 | `payment-selcom-initiate` | JWT | Pending charge + Selcom call. |
| 11 | `payment-selcom-webhook` | signature | Selcom reconciliation. |
| 12 | `payment-flutterwave-initiate` | JWT | Pending charge + Flutterwave call. |
| 13 | `payment-flutterwave-webhook` | signature | Flutterwave reconciliation. |
| 14 | `payment-refund` | permission | Phase 5 refund + provider refund. |
| 15 | `payout-execute` | permission | Phase 5 payout + provider transfer. |
| 16 | `data-export` | JWT/permission | ZIP export + signed URL. |
| 17 | `scheduled-daily-metrics` | cron secret | Daily metric rollups. |
| 18 | `scheduled-demand-capture` | cron secret | Pricing demand snapshot. |
| 19 | `scheduled-retention` | cron secret | Retention and cleanup. |

## 4. Authentication and authorization

`_shared/auth.ts` provides four gates:

- `requireUser()` verifies the bearer token with `supabase.auth.getUser()`,
  decodes `user_role` and `country_id`, loads `profiles`, rejects inactive
  profiles, and returns an `AuthContext`.
- `requireAdmin()` calls `requireUser()` and then checks a permission through
  `public.has_permission(permission_key)`. It does not trust JWT claims.
- `requireInternalSecret()` compares `X-Internal-Secret` with the
  `INTERNAL_FUNCTION_SECRET` Vault secret for trusted sibling calls.
- `requireServiceRole()` compares `X-Cron-Secret` with `CRON_SECRET` for
  scheduled functions.

All gateway `verify_jwt` settings are `false` in `supabase/config.toml` and
`supabase/functions/_config.toml`. This is deliberate: the handler must return
the shared `{ data, error }` envelope for authentication failures instead of a
platform-generated response. Each handler still enforces its own gate. If a
handler guard is ever removed, gateway JWT verification must be re-enabled for
that function.

## 5. Request and response contract

Every JSON response is:

```json
{
  "data": null,
  "error": {
    "code": "validation_error",
    "message": "Request validation failed",
    "details": [{ "field": "job_id", "message": "Invalid uuid", "code": "invalid_string" }]
  }
}
```

Status mapping is centralized in `_shared/errors.ts` and `_shared/handler.ts`:

| Condition | Status |
| --- | --- |
| Success (default) | `200` |
| Resource created | `201` |
| Invalid body/query | `422` |
| Missing/invalid JWT, cron, internal, or webhook signature | `401` |
| Authenticated but not allowed | `403` |
| Missing row | `404` |
| Method not allowed | `405` |
| Conflict/idempotency conflict | `409` |
| Validation conflict (provider/state) | `422` |
| Provider or upstream failure | `502` |
| Unexpected error | `500` |

`createHandler()` adds a request ID, CORS, structured request logs, and a
uniform `OPTIONS` response. Unknown errors return a generic message; stack
traces and database errors are not exposed to callers.

## 6. Secrets and Vault

Production provider credentials live in Supabase Vault. `_shared/vault.ts`
reads `Deno.env` first for local development, then calls the
service-role-only `public.get_vault_secret(name)` RPC. `get_vault_secret` is
revoked from `public`, `anon`, and `authenticated`.

The local setup is `supabase/functions/.env.local.example` plus
`supabase/scripts/setup-vault-secrets.sh.example`. The filled files are
uncommitted. The service-role key and provider secrets never appear in Flutter
code, client responses, or logs.

`payment_providers.webhook_secret_reference` can point at a Vault secret name;
webhook handlers fall back to the provider-specific environment/Vault name.

## 7. Idempotency

Idempotency exists at two layers:

1. **Function layer:** `_shared/idempotency.ts` reads/writes
   `public.idempotency_keys` with a `(key, scope)` unique constraint. Payment
   initiation, refunds, and payouts require `X-Idempotency-Key`.
2. **Database layer:** `job_payment_initiate()` is idempotent by
   `(job_id, idempotency_key)` in payment metadata. `payment_webhook_events`
   is unique by `(provider_id, event_id)`; `record_payment_webhook()`
   atomically claims the dedupe key and appends to the partitioned
   `payment_webhooks` log. `job_pay_complete()`, `payment_refund()`, and
   `execute_payout()` re-check terminal state before mutating money.

A cached idempotent response is returned before any provider call. The
database uniqueness constraint is the final arbiter under concurrent requests.
`cleanup_idempotency_keys()` removes expired rows.

## 8. Retry and dead-letter behavior

Provider HTTP calls use `_shared/retry.ts`. The policy is three retries after
the initial attempt, with 1s, 4s, and 16s delays. Network failures, timeouts,
`408`, `429`, and `5xx` are retryable; `4xx` validation/auth failures are not.

When retries are exhausted, the handler records the sanitized function name,
non-PII payload identifiers, error message/stack, and attempt count in
`public.dead_letter_queue`. A dead letter is not a success; the caller receives
`502 provider_error` and the operation is left in a recoverable state.

## 9. Provider clients

All clients implement small interfaces in `_shared/providers/`:

- **Selcom:** payment initiation, payout initiation, refund, webhook parsing.
- **Flutterwave:** payment initiation, transfer initiation, refund, webhook
  parsing.
- **Beem:** SMS send with Basic auth.
- **Africa's Talking:** SMS fallback.
- **Resend:** transactional email.
- **FCM:** OAuth2 service-account JWT (RS256 via WebCrypto
  `RSASSA-PKCS1-v1_5`), token and topic sends.
- **Google Maps:** Routes API and Geocoding.

Clients accept an injectable `fetch` and sleep function so tests never hit the
network. Response bodies are never logged.

## 10. Payments: initiation and reconciliation

The Phase 5 `job_pay()` captures and finalizes payment in one call. Phase 7
splits the provider flow without modifying Phase 5:

1. `job_payment_initiate()` creates a pending `payments` row with an
   `init:<random>` placeholder reference. It validates job status, quote total,
   provider country, and optional payment method ownership.
2. The Edge Function calls the provider and attaches the real
   `provider_reference` while the row is still pending.
3. A verified webhook calls `job_pay_complete()`, which re-checks terminal
   state, updates the payment, completes the job payment status, records
   commission/withholding, and posts wallet entries.

Migration `0119` replaces the payments immutability trigger so
`provider_reference` may be attached while pending. Once terminal, financial
terms and references remain immutable.

## 11. Refunds and payouts

`payment-refund` calls the Phase 5 `payment_refund()` RPC with the caller's JWT
to create the refund payment and ledger entries, then asks the original
provider for the refund. It requires `process_refunds`, a succeeded original
charge, and a provider with `supports_refunds`.

`payout-execute` requires `process_payouts`, moves an approved payout to
`processing`, initiates the transfer, and then calls `execute_payout()` to
complete the payout and debit the wallet. Completed payouts are returned
idempotently. Provider rejection marks the payout failed and records a dead
letter.

## 12. Notifications

`notification-dispatch` calls `public.send_notification()` per channel. That
Phase 6 RPC owns template lookup, variables, recipient preferences, quiet
hours, and `notification_log` insertion. A `null` return means the channel was
skipped, not failed.

`_shared/notifications.ts` then delivers the created row. SMS uses Beem first
and Africa's Talking as fallback; email uses Resend; push uses active
`push_tokens` and FCM. Invalid FCM tokens are deactivated. If every requested
channel fails, the function returns `502 provider_error`; partial success
returns `200` with a `failures` array.

## 13. Maps caching

`maps-distance` and `maps-geocode` use `distance_cache` and `geocoding_cache`.
Distance rows are keyed by exact origin/destination/mode and expire after seven
days. Geocoding rows are keyed by lower-cased address or exact reverse
coordinates and expire after 30 days. Cache failures are non-fatal; the
provider result is still returned.

`quote-calculate` reuses the service-role cache client and then calls the Phase
4 RPC with the user's JWT, so pricing and promo rules stay database-enforced.

## 14. Data export

`data-export` supports self-service export and admin fulfillment of a
`data_subject_requests` row. It gathers the profile and related domain rows,
writes one JSON file per domain into a ZIP, uploads to the `data-exports`
Storage bucket, and returns a seven-day signed URL. The request is marked
`completed` with `delivered_file_path`. `PUBLIC_SUPABASE_URL` rewrites the
signed URL host for local development, where the runtime reaches Storage
through `http://kong:8000`.

`scheduled-retention` deletes expired archives through the Storage API, not by
directly deleting `storage.objects` rows. Supabase blocks direct deletion to
prevent orphaned objects. The function then calls
`cleanup_expired_data_exports` to clear stale `delivered_file_path` pointers and
`cleanup_payment_webhook_events` to enforce the 24-month webhook dedupe window.

## 15. Scheduled automation

The three scheduled functions are invoked with `X-Cron-Secret` and call
existing Phase 4/6 database functions:

- `compute_daily_metrics`, `compute_zone_metrics`, `compute_driver_metrics`,
  `compute_customer_metrics`;
- `capture_demand_snapshot`;
- `apply_retention_policies`, `cleanup_idempotency_keys`,
  `cleanup_expired_data_exports`, `cleanup_payment_webhook_events`.

The existing Phase 6 `pg_cron` schedules remain in the database. HTTP
invocation is documented for environments that prefer an external scheduler.
The functions are idempotent for the same target date or snapshot window.

## 16. Logging and privacy

`_shared/logger.ts` emits one JSON line per event with level, function name,
request ID, message, duration, and redacted context. Keys containing phone,
email, name, recipient, address, coordinates, token, secret, authorization,
password, card, PAN, or CVV are redacted. Strings are scrubbed for phone and
email shapes; UUIDs and ISO timestamps are preserved as non-PII identifiers.

Request bodies, provider response bodies, JWTs, service-role keys, and Vault
values are never logged. Errors are sanitized before logging and before being
returned to callers.

## 17. Testing strategy

`_tests/` uses `Deno.test` and `jsr:@std/assert`. Handlers are imported
directly, so no Edge Runtime is started. Fakes cover:

- JWT/profile/permission resolution;
- Supabase query chains, RPCs, Storage uploads, and signed URLs;
- provider retry/failure behavior;
- webhook signatures, duplicates, and terminal-state transitions;
- notification preference skips and partial failures;
- Maps cache hits/misses;
- scheduled cron gates and aggregate counts.

The tests assert both status codes and the `{ data, error }` envelope. Provider
tests use an injected `fetch`; no real credentials or network calls are needed.

## 18. Deployment and operations

1. Run `pnpm db:verify` to confirm Phases 1–7 database gates.
2. Run `supabase/scripts/verify-phase-7-functions.sh` and the Deno test suite.
3. Provision Vault secrets per environment.
4. Register webhook URLs with Selcom and Flutterwave.
5. Deploy functions with `npx --yes supabase functions deploy`.
6. Configure the external scheduler with `X-Cron-Secret`.
7. Monitor `dead_letter_queue`, `payment_webhooks`, and function error logs.

Rollback is provider-by-provider: deactivate the `payment_providers` row or
remove the provider secret to stop new calls without a schema migration. Do not
delete `payment_webhooks` or financial rows; resolve them through the normal
reconciliation path.

## 19. Verification, open questions, and non-goals

**Verification:** the Phase 7 function gate checks all 19 directories,
handlers, READMEs, config entries, Deno type checking, linting, and tests.
`pnpm db:verify` remains the authoritative Phase 1–7 database gate. Live HTTP
checks are opt-in with `SAFESHIFT_LIVE_FUNCTIONS=1`.

**Open questions:**

- Real Selcom, Flutterwave, Beem, Africa's Talking, Resend, FCM, and Google
  Maps credentials are not configured in this environment. Provider-specific
  request/response fields must be validated against sandbox accounts before
  staging.
- Flutterwave transfer webhooks and Selcom payout webhooks need sandbox
  verification of their event names and signature headers.
- The Phase 7 scope ADR mentions per-attempt delivery rows; this implementation
  records structured retry logs and final dead letters. A dedicated attempts
  table can be added without changing the function contracts.
- Production Realtime and Storage live-client checks remain Phase 8.

**Non-goals:** Flutter app changes, Phase 1–6 migration edits, live
Realtime/Storage integration tests, staging/production deployment, and
committing provider secrets.
