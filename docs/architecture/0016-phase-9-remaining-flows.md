# Phase 9 — Remaining Marketplace Flows

- **Status:** Implemented locally; staging, real-device, and provider verification pending
- **Date:** 2026-10-29
- **Scope ADR:** `docs/architecture/0015-phase-7-integrations-automation.md`
- **Migrations:** `0124_phase_9_recurring_job_scheduler.sql`,
  `0125_phase_9_safety_trip_sharing.sql`,
  `0126_phase_9_admin_console_support.sql`,
  `0127_phase_9_seed_updates.sql`
- **Seed additions:** `supabase/seed-phase-9.sql`
- **Gates:** `supabase/scripts/verify-phase-9-schema.sql`,
  `supabase/scripts/verify-phase-9-functions.sh`,
  `supabase/scripts/verify-phase-9-integration.sh`
- **Manual checklist:** `docs/testing/phase-9-manual-tests.md`

> Note: this document uses the filename requested by the Phase 9 brief. The
> repository already had `0016-phase-7-edge-functions.md`; both files are kept
> because that document is still referenced by Phase 7 material.

## 1. Purpose and boundaries

Phase 9 completes the marketplace surfaces that were intentionally left as
placeholders after Phase 8:

- driver onboarding and verification gating;
- business accounts and recurring jobs;
- a fleet-owner portal;
- a new Next.js admin console;
- notification preferences;
- disputes with evidence;
- support tickets;
- safety, SOS, and trip sharing;
- ratings/reviews;
- account, privacy, and data-request settings.

The implementation is additive. Phase 1–8 tables and functions are unchanged
except for Phase 9 policies, permissions, and the new driver trust-field guard
in migration `0126`. The customer and driver Flutter apps keep their existing
navigation and design system; Phase 9 screens are added behind new routes.

No service-role key is used by either mobile app. The admin console also avoids
the service-role key: its server components and server actions use the signed-in
admin session so RLS and `has_permission()` remain authoritative.

## 2. Backend additions

### 2.1 Recurring-job scheduler (`0124`)

`public.generate_recurring_scheduled_jobs(p_horizon_hours integer)` materialises
active recurring templates for verified, active businesses into
`public.scheduled_jobs`.

Supported RRULE subset:

- `FREQ=DAILY`
- `FREQ=WEEKLY` with optional `BYDAY=MO,TU,...`
- `FREQ=MONTHLY` using the template creation day-of-month

The function is idempotent for the same template/date/time and is executable by
`service_role` only. A `pg_cron` job named `safeshift_generate_scheduled_jobs`
runs hourly at minute 17 when `pg_cron` is available. The function remains
callable manually in environments without the extension.

### 2.2 Safety and trip sharing (`0125`)

New tables:

| Table | Purpose |
| --- | --- |
| `trip_alerts` | SOS, emergency, and safety-check alerts for a job |
| `trip_share_tokens` | 24-hour, unguessable public tracking tokens |

New RPCs:

- `create_trip_share_token(uuid)` — participant-only token creation.
- `trip_share_snapshot(text)` — anon-callable read model returning only status,
  route labels, driver first name, vehicle type, coarse coordinates, and
  timestamps.

Dispute evidence uses the existing private `job-evidence` bucket under
`dispute/{dispute_id}/...`. The new storage policies are named
`dispute_evidence_storage_*` so the Phase 8 storage-policy count remains stable.

### 2.3 Admin console support (`0126`)

- Extends `admin_roles` with the constrained `fleet_owner` role.
- Adds Phase 9 permissions: verification, dispute, support, incident, fleet,
  analytics, data-request, pricing, promo, and feature-flag administration.
- `admin_dashboard_metrics` is a `security_invoker=true` view; the caller's RLS
  and permissions still apply.
- `admin_search_profiles(text, integer)`, `admin_profile_summaries(uuid[])`, and
  `admin_recent_activity(integer)` are permission-checked read models. The two
  profile directory functions write PDPC `data_access_log` rows for each
  non-owner profile they return.
- `business_accounts.created_by` records the self-registering profile. A
  creator SELECT policy lets the insert return the new row before the
  after-insert owner-membership trigger has run.
- `admin_approve_verification(uuid, text)` and
  `admin_reject_verification(uuid, text)` update the subject, write
  `verification_history`, and append to `admin_actions_log`.
- `admin_console_role()` resolves the caller's active role for the console.
- Driver self-onboarding may insert its own `drivers` row only in `pending`
  state with standard risk. A trigger blocks drivers from changing
  `verification_status`, `risk_tier`, `verified_at`, or `verified_by`.

### 2.4 Seed updates (`0127`, `seed-phase-9.sql`)

Idempotent reference data adds the fleet-owner role, Phase 9 permissions,
support categories, feature-flag entries, and a demo emergency contact for the
seeded driver.

## 3. Flutter client integration

### 3.1 Customer app

New route group:

| Route | Screen |
| --- | --- |
| `/business` | Business hub and memberships |
| `/business/register` | Self-service business registration |
| `/business/recurring` | Recurring templates and generated jobs |
| `/settings/notifications` | Per-category/channel toggles and quiet hours |
| `/settings/account` | Profile and contact re-verification |
| `/settings/privacy` | Export/deletion requests |
| `/disputes`, `/disputes/new`, `/disputes/:id` | Dispute list, create, thread |
| `/support`, `/support/new`, `/support/:id` | Support ticket list, create, thread |
| `/safety/contacts` | Emergency contacts |
| `/reviews` | Ratings and reviews |

`tracking_screen.dart` now calls the shared `shareTrip()` and `raiseSos()`
helpers instead of showing placeholder snackbars. The profile screen links to
the new account, safety, support, business, and ratings surfaces.

### 3.2 Driver app

The driver app replaces the Phase 8 onboarding placeholder with a real
verification flow:

1. identity and driving-licence details;
2. vehicle details;
3. insurance details;
4. document uploads for national ID, licence, vehicle registration, and
   insurance certificate;
5. driver and vehicle verification requests.

The go-online control reads `AuthState.canGoOnline`. Unverified drivers see a
verification card, cannot toggle online, and are routed to documents or the
verification status screen. The active-trip sheet exposes Share Trip and SOS.
Driver settings, disputes, support, emergency contacts, and privacy routes mirror
the customer surfaces with driver-scoped queries.

### 3.3 Shared client helpers

Both apps now include:

- `core/utils/reference_number.dart` — readable, collision-resistant reference
  numbers for support and privacy requests;
- `core/widgets/feedback/app_empty_state.dart`;
- `core/widgets/feedback/app_error_view.dart`.

## 4. Admin console

`apps/admin-console` is a Next.js 16 App Router application using React 19,
`@supabase/ssr`, and Supabase Realtime.

### 4.1 Authentication and authorization

- Email/password only. No self-registration.
- Middleware refreshes the session and redirects unauthenticated requests.
- The console layout calls `admin_console_role()`; a user without an active
  `admin_roles` row is signed out and returned to `/login`.
- `fleet_owner` sees only Dashboard, Fleets, and Settings. Operations, finance,
  verification, support, and analyst roles see only their areas.
- Every mutating server action relies on the admin's session, so database
  permission checks are the final authority.

### 4.2 Routes

| Area | Routes |
| --- | --- |
| Overview | `/dashboard`, `/analytics` |
| Marketplace | `/jobs`, `/users`, `/drivers`, `/fleets` |
| Trust & safety | `/verifications`, `/incidents`, `/disputes`, `/support`, `/support/[id]` |
| Finance & growth | `/payments`, `/payouts`, `/pricing`, `/promos` |
| Governance | `/data-requests`, `/audit`, `/settings` |
| Public | `/trip/[token]` |

The dashboard subscribes to Realtime changes on jobs, incidents, support tickets,
disputes, verification requests, and trip alerts, then refreshes server data.
The public trip page uses an anon client and the token-scoped RPC only.

### 4.3 Environment

```text
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<local anon key>
NEXT_PUBLIC_SITE_URL=http://localhost:3001
```

Copy `.env.example` to `.env.local`; never commit `.env.local`. The app is
deployed to Vercel with the same three public variables.

## 5. Edge Functions

| Function | Purpose |
| --- | --- |
| `sos_alert` | Verifies the caller owns the alert, SMSes emergency contacts, pushes on-call admins, logs attempts |
| `create-trip-share-token` | Calls the token RPC and returns a public `share_url` |

Both are registered with `verify_jwt = false` because they perform their own
JWT/user checks in the handler. Validation schemas live in
`supabase/functions/_shared/validation.ts`.

## 6. Security and privacy invariants

- Every new table has RLS enabled and explicit policies.
- Admin actions require `has_permission()` and are audited.
- Drivers cannot self-verify.
- Public trip links expose no customer identity, fare, exact address text, or
  exact live position.
- Emergency contacts are private to their owner and safety staff.
- Data exports and deletions go through the existing manual request workflow.
- No secret is committed; the service-role key is never bundled into a client.

## 7. Verification

Run:

```bash
npx --yes supabase db reset
bash scripts/verify-db.sh
bash supabase/scripts/verify-phase-9-functions.sh
bash supabase/scripts/verify-phase-9-integration.sh
(cd apps/customer-mobile && flutter analyze && flutter test)
(cd apps/driver-mobile && flutter analyze && flutter test)
pnpm --filter @safeshift/admin-console lint
pnpm --filter @safeshift/admin-console build
```

The Phase 9 schema gate checks tables, RLS, policies, permissions, functions,
cron registration, and public snapshot safety. The function gate checks Edge
Function source/config wiring. The integration gate exercises the live local
API with seeded users.

Run the integration gate after the schema gates. It creates business, dispute,
support, and safety rows, so rerun `supabase db reset` before repeating the
seed-count-sensitive Phase 1–8 gates.

## 8. Known gaps

- Staging Supabase, Firebase, SMS, Maps, and payment-provider credentials are
  not available locally.
- Real-device testing of push, deep links, camera/gallery, and background
  location is still required.
- Universal-link association files and Apple associated-domains entitlements are
  environment work, not app code.
- Phase 5 refund/payout settlement and compensation semantics remain a separate
  finance decision; the console displays existing payout data but does not
  invent new settlement rules.
