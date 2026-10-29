# Phase 8 — Mobile Client Integration

- **Status:** Implemented locally; staging/production device verification pending
- **Date:** 2026-10-29
- **Scope ADR:** `docs/architecture/0015-phase-7-integrations-automation.md`
- **Migrations:** `0120_phase_8_supporting_functions.sql`,
  `0121_phase_8_matching_dispatch.sql`,
  `0122_phase_8_storage_policies.sql`,
  `0123_phase_8_chat_threads.sql`
- **Gates:** `supabase/scripts/verify-phase-8-schema.sql`,
  `supabase/scripts/verify-phase-8-integration.sh`
- **Staging seed:** `supabase/seed-staging.sql` (configuration only)

## 1. Purpose and boundaries

Phase 8 connects the existing Flutter customer and driver applications to the
Phase 1–7 Supabase backend. It adds the data layer, authentication bootstrap,
offline cache, realtime subscriptions, storage uploads, push-token registration,
and deep-link handling required by the existing screens.

The implementation keeps the Phase 1–7 database and Edge Functions unchanged.
All database work is additive in migrations `0120`–`0123`. Screens, widgets,
navigation structure, and the mock providers used for design work remain in
place; `mockEnabledProvider` is the only switch that enables mock flows.

No secret is committed. Firebase configuration is supplied at build time, the
Supabase anon key is the only client key, and the service-role key remains
server-only.

## 2. Client architecture

Both apps use the same layering:

```text
main()
  ├── Hive CacheService.init()
  ├── SupabaseInit.ensureInitialized()
  ├── PushService.initialize()          # no-op without Firebase defines
  └── ProviderScope
        ├── supabaseProvider            # one Riverpod-managed client
        ├── authProvider                # OTP session + profile bootstrap
        ├── feature repositories        # RPC/table/storage access
        ├── feature providers           # loading, error, cache, realtime
        └── GoRouter                    # auth and registration guards
```

Rules applied throughout:

- Features read `SupabaseClient` from `supabaseProvider`; there is no global
  Supabase or Storage singleton.
- Repositories own PostgREST/RPC/Storage calls and map rows to domain objects.
- Providers expose explicit loading, error, retry, and empty states.
- Realtime channels are created by the screen/provider that owns the data and
  are removed on disposal. Polling is a fallback when Realtime is unavailable.
- Errors pass through `ErrorHandler` before reaching the UI, so raw backend
  details are logged locally but never rendered.

## 3. Environment configuration

Configuration is compile-time via `--dart-define`. `ENV` defaults to `dev`;
unknown values fail fast.

| Define | Required | Purpose |
| --- | --- | --- |
| `ENV` | no (default `dev`) | `dev`, `staging`, or `prod` |
| `SUPABASE_URL` | staging/prod | Project API URL |
| `SUPABASE_ANON_KEY` | staging/prod | Public anon/publishable key |
| `FIREBASE_API_KEY` | push only | Firebase Android/iOS API key |
| `FIREBASE_APP_ID` | push only | Firebase app id |
| `FIREBASE_MESSAGING_SENDER_ID` | push only | FCM sender id |
| `FIREBASE_PROJECT_ID` | push only | Firebase project id |
| `FIREBASE_STORAGE_BUCKET` | optional | Firebase storage bucket |
| `MOCK_MODE` | no (default `false`) | Design-only mock flows |

`dev` falls back to the local Supabase CLI URL and local anon key when the
Supabase defines are omitted. Staging and production builds throw during startup
if the URL or anon key is missing.

### Launch commands

Customer app:

```bash
cd apps/customer-mobile

# Local stack
flutter run --dart-define=ENV=dev

# Staging
flutter run \
  --dart-define=ENV=staging \
  --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging-anon-key> \
  --dart-define=FIREBASE_API_KEY=<key> \
  --dart-define=FIREBASE_APP_ID=<app-id> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> \
  --dart-define=FIREBASE_PROJECT_ID=<project-id>

# Production
flutter run --release \
  --dart-define=ENV=prod \
  --dart-define=SUPABASE_URL=https://<prod-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<prod-anon-key> \
  --dart-define=FIREBASE_API_KEY=<key> \
  --dart-define=FIREBASE_APP_ID=<app-id> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> \
  --dart-define=FIREBASE_PROJECT_ID=<project-id>
```

Driver app uses the same commands from `apps/driver-mobile`.

Release builds use the same defines with `flutter build apk`, `flutter build
appbundle`, or `flutter build ipa`. Values must come from the CI/CD secret store;
never commit a filled `.env` file.

## 4. Authentication and profiles

- Auth is phone OTP only: `signInWithOtp(phone, shouldCreateUser: true)` then
  `verifyOTP(type: OtpType.sms)`.
- Phone numbers are normalized to E.164 (`+255...`) before every call.
- Sessions persist in Keychain / EncryptedSharedPreferences through
  `SecureLocalStorage`; `detectSessionInUri` is disabled because `app_links`
  owns deep links.
- After verification the app calls the `ensure_my_profile(p_role,
  p_full_name)` RPC. The function can create a missing profile or complete a
  customer profile into a driver profile, but never grants admin, fleet, or
  business roles.
- The customer router redirects unauthenticated protected routes to `/login`.
- The driver router also checks for a `drivers` row. An authenticated profile
  without one is routed to `/driver-onboarding`; the placeholder screen keeps
  the Phase 9 onboarding gate without deleting or replacing existing screens.
- Inactive profiles are rejected during profile fetch.
- Sign-out clears the session, unregisters the push token, and deletes the
  user's Hive namespace.

## 5. Offline cache

`CacheService` wraps a single Hive box (`safeshift_cache_v1`) and scopes every
key by user id:

```text
<profile-id>:<namespace>[:<record-id>]
```

History, earnings, trips, documents, vehicle, ratings, and active ride/job
snapshots use cache-first rendering. A network refresh replaces the cache;
when the request fails the last snapshot remains visible with an error/retry
state. Sign-out calls `clearUser(userId)` so a second account cannot see the
first account's cached data.

## 6. Realtime, polling, and dispatch

- The customer app subscribes to the active job's `jobs` row after booking and
  polls as a fallback. Status changes update the tracking sheet.
- The driver app subscribes to `job_offers` for its driver id and to the active
  `jobs` row, and polls both the pending-offer RPC and active-job RPC as a
  fallback.
- `match_dispatch(job_id, radius_km, limit, timeout_seconds)` is the customer
  entry point after job creation. It verifies the caller owns the job, selects
  verified/available drivers with a verified vehicle of the quoted type, and
  inserts time-bounded offers. Existing `accept_job_offer` and
  `decline_job_offer` remain the only driver responses.
- Subscriptions are disposed when the owning provider or screen is disposed.

## 7. Storage uploads

Four private buckets are created in migration `0122`:

| Bucket | Path | Writer |
| --- | --- | --- |
| `driver-documents` | `<driver_id>/...` | that driver |
| `vehicle-documents` | `<vehicle_id>/...` | vehicle owner/primary driver |
| `job-evidence` | `<job_id>/...` | job customer or assigned driver |
| `chat-attachments` | `<job_id>/...` | job customer or assigned driver |

Storage RLS checks the first path segment against the job, driver, or vehicle.
Job evidence and chat attachments are append-only from the app: the client can
insert and read its own job's files but cannot update or delete them.

Uploads are performed with the signed-in user's client. No feature uses a
service-role key. Evidence rows are inserted into `job_evidence`; chat
attachments are linked through `chat_messages` and `chat_attachments`.

## 8. Delivery OTP

Migration `0120` adds `job_delivery_codes`, which stores only a bcrypt hash:

```text
job_id, code_hash, issued_by, issued_at, expires_at, attempts, verified_at
```

- `job_issue_delivery_otp(job_id)` is customer-only and returns a fresh
  6-digit code. It is allowed while the job is `accepted` through `in_transit`
  and expires after 24 hours.
- `job_verify_delivery_otp(job_id, code)` is assigned-driver-only, allows five
  attempts, and marks an `in_transit` job `delivered` on success.
- Direct table access is revoked from `anon` and `authenticated`; only the
  `SECURITY DEFINER` functions read or write it.
- The customer app shows the code during tracking. The driver app requires the
  code on the arrived-at-destination sheet in real mode; mock mode keeps the
  original UI-only completion path.

## 9. Push notifications and deep links

`PushService` initializes Firebase only when all required Firebase defines are
present. It requests permission, shows foreground notifications through
`flutter_local_notifications`, registers the FCM token in `user_devices`, and
updates the token on refresh. Without Firebase config it is a no-op, so local
UI work and tests do not require Firebase.

Supported link shapes:

```text
safeshift://tracking/<job-id>
safeshift://jobs/<job-id>
safeshift://history/<job-id>
https://safeshift.app/tracking/<job-id>
https://safeshift.app/jobs/<job-id>
https://safeshift.app/history/<job-id>
```

The customer app opens `/tracking?jobId=...` or `/history/<id>`. The driver app
opens `/home` for job links and `/trips` for history links. Android manifests
declare the custom scheme and `https://safeshift.app`; iOS declares the custom
URL type.

## 10. Backend additions

Migration `0120` adds these client-facing read models and commands:

- `ensure_my_profile(text, text)`
- `customer_jobs(integer)`, `customer_job(uuid)`
- `driver_pending_offers()`, `driver_active_job()`, `driver_trips(integer)`
- `driver_earnings_summary()`, `driver_documents_list()`,
  `driver_vehicle_info()`, `driver_ratings_list(integer)`
- `job_issue_delivery_otp(uuid)`, `job_verify_delivery_otp(uuid, text)`

All functions are `SECURITY DEFINER`, set an empty `search_path`, revoke public
and anon execution, and grant execution only to `authenticated` and
`service_role` unless noted otherwise.

Migration `0121` adds `match_dispatch` and publishes `job_offers` on
`supabase_realtime`. Migration `0122` adds the storage buckets and policies.
Migration `0123` adds `ensure_job_chat_thread(uuid)` so either job participant
can create the single Phase 6 chat thread idempotently.

## 11. Verification

Local prerequisites: Docker, Supabase CLI, Flutter, and the local stack running.

```bash
# Backend
npx --yes supabase db reset
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-8-schema.sql
supabase/scripts/verify-phase-8-integration.sh

# Phase 1–8 schema gates
bash scripts/verify-db.sh

# Flutter
cd apps/customer-mobile && flutter pub get && flutter analyze && flutter test
cd ../driver-mobile && flutter pub get && flutter analyze && flutter test
```

The schema gate covers the OTP table, RPCs, storage buckets/policies,
Realtime publication, chat tables, and seeded configuration. The live
integration gate signs in the seeded customer and driver through the real Auth
API and exercises quote → job → dispatch → offer → accept → status advance →
chat attachment → delivery OTP → completion → evidence, plus the driver read
models. It is local-only and does not call SMS, Maps, FCM, or payment providers.

## 12. Known external blockers

The following cannot be completed without project credentials or hardware:

- Staging Supabase project creation, linking, migration push, and staging seed.
- Firebase project/platform configuration, real FCM delivery, and notification
  tap handling on a device.
- Universal-link association files (`apple-app-site-association` and
  `assetlinks.json`), Apple associated-domains entitlement, and domain
  verification.
- Real SMS OTP delivery, Maps keys, and payment provider sandbox credentials.
- Physical-device or emulator QA for push, deep links, camera/gallery uploads,
  and background location.
- Phase 5 refund/payout settlement semantics and compensation decisions.

These are tracked in `docs/runbooks/phase-8-staging-and-qa.md`. Phase 8 does
not claim those device-level checks passed.
