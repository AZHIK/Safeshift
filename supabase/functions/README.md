# Supabase Edge Functions

Server-only Phase 7 functions. They run on Deno 2 and are deployed with the Supabase CLI. Flutter
apps must never hold provider credentials or call provider APIs directly.

## Rules

- `service_role` and provider secrets never leave this directory or Supabase Vault.
- Every response uses `{ data, error }`, including authentication and validation failures.
- Every user-facing function validates the Supabase JWT with `requireUser` or `requireAdmin`.
  Permissions come from `public.has_permission()` / `public.current_permissions()`, never from
  client-supplied claims.
- Webhooks verify provider signatures and return `401` on failure. Webhook replay is idempotent in
  `payment_webhook_events` and the append-only `payment_webhooks` log; user-facing mutating
  functions use `idempotency_keys`.
- Scheduled functions require `X-Cron-Secret`; internal sibling calls require `X-Internal-Secret`.
- Provider calls retry three times with 1s, 4s, and 16s backoff. Exhausted calls are written to
  `dead_letter_queue`.
- Logs are structured JSON and redact phone numbers, emails, names, addresses, coordinates, tokens,
  and secret-shaped fields. Never log request bodies.
- Money mutations go through the Phase 5 RPCs. Edge Functions only attach a pending provider
  reference and reconcile terminal webhook status on refunds and payouts; they never write wallet or
  ledger rows.

## Function inventory

| Function                       | Auth                  | Purpose                                         |
| ------------------------------ | --------------------- | ----------------------------------------------- |
| `health`                       | public                | Liveness and Vault/database readiness.          |
| `auth-validate`                | JWT                   | Return role, country, and hydrated permissions. |
| `maps-distance`                | JWT                   | Google Routes API with a seven-day cache.       |
| `maps-geocode`                 | JWT                   | Forward/reverse geocoding with a 30-day cache.  |
| `quote-calculate`              | JWT (customer)        | Phase 4 quote RPC.                              |
| `sms-send`                     | permission / internal | Beem SMS with Africa's Talking fallback.        |
| `email-send`                   | permission / internal | Resend transactional email.                     |
| `push-send`                    | permission / internal | FCM push to active devices.                     |
| `notification-dispatch`        | permission            | Fan out template notifications.                 |
| `payment-selcom-initiate`      | JWT (customer)        | Create and start a Selcom charge.               |
| `payment-selcom-webhook`       | signature             | Reconcile Selcom callbacks.                     |
| `payment-flutterwave-initiate` | JWT (customer)        | Create and start a Flutterwave charge.          |
| `payment-flutterwave-webhook`  | signature             | Reconcile Flutterwave callbacks.                |
| `payment-refund`               | permission            | Phase 5 refund RPC + provider refund.           |
| `payout-execute`               | permission            | Phase 5 payout RPC + provider transfer.         |
| `data-export`                  | JWT / permission      | ZIP export with signed URL.                     |
| `scheduled-daily-metrics`      | cron secret           | Previous-day metric rollups.                    |
| `scheduled-demand-capture`     | cron secret           | Pricing demand snapshot.                        |
| `scheduled-retention`          | cron secret           | Retention, idempotency, export cleanup.         |

Each directory has a `README.md` with its request, response, auth, and secret contract. Handlers
live in `handler.ts` and are exported without starting a server; `index.ts` only wires
`Deno.serve(createHandler(...))`. This split is what makes the Deno tests possible.

## Shared modules

- `_shared/auth.ts` — JWT validation, profile loading, permissions, cron and internal gates, webhook
  signature verification.
- `_shared/errors.ts`, `response.ts`, `handler.ts` — the `{ data, error }` envelope, status mapping,
  request IDs, CORS, and structured request logs.
- `_shared/db.ts`, `vault.ts` — service/user Supabase clients and Vault reads.
- `_shared/idempotency.ts`, `retry.ts`, `dead_letter.ts` — retry and replay controls.
- `_shared/providers/` — Selcom, Flutterwave, Beem, Africa's Talking, Resend, FCM, and Google Maps
  clients.
- `_shared/notifications.ts`, `notification_request.ts` — template/preference lookup,
  `notification_log`, provider fallback, and token deactivation.
- `_shared/maps_cache.ts`, `webhooks.ts` — cache and webhook persistence helpers.

## Local workflow

```bash
pnpm build
pnpm db:start
npx --yes supabase db reset
npx --yes supabase functions serve --env-file supabase/functions/.env.local
```

Copy `supabase/functions/.env.local.example` to `.env.local` and fill in local values. The filled
file is gitignored and must never be committed. For Vault, copy
`supabase/scripts/setup-vault-secrets.sh.example` and run it against the local database. The CLI
also injects `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` while serving.

Local endpoints:

- API: `http://127.0.0.1:54321`
- Functions: `http://127.0.0.1:54321/functions/v1`
- Studio: `http://127.0.0.1:54323`
- Mailpit: `http://127.0.0.1:54324`

Seed users use password `SafeshiftDev!2026`, for example `customer1@safeshift.local`.

## Tests and gate

```bash
cd supabase/functions
deno task check
deno task lint
deno task test
```

`deno task test` runs `_tests/` with injected fake auth, Supabase, provider, and cache dependencies.
No real provider credentials are required.

```bash
supabase/scripts/verify-phase-7-functions.sh
SAFESHIFT_LIVE_FUNCTIONS=1 supabase/scripts/verify-phase-7-functions.sh
```

The static gate checks every function directory, handler, README, and `verify_jwt` entry, then runs
check/lint/test. The live mode additionally probes health, unauthenticated auth, invalid webhook
signatures, and missing cron secrets against a running local stack.

## Deployment

- Deploy only after `pnpm db:verify` and the function gate are green.
- Set provider secrets in Supabase Vault; do not bake them into function env vars in production.
- Keep `verify_jwt = false` in `supabase/config.toml` and `_config.toml` only because each handler
  enforces its own gate. Removing an in-handler guard requires turning gateway JWT verification back
  on for that function.
- Scheduled functions are invoked by the external scheduler with `X-Cron-Secret`. The Phase 6
  database cron jobs remain unchanged.
- Webhook URLs must be registered with Selcom and Flutterwave per environment.
