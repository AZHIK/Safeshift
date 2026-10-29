# Phase 8 — Staging Setup and Manual QA

This runbook covers the hosted staging project and the device checks that cannot
run in CI. It is intentionally separate from local demo seeding.

## 1. Staging project rules

- Staging is a **separate Supabase project** from development and production.
- Apply migrations with the Supabase CLI. Never hand-edit staging SQL.
- Seed **configuration only** with `supabase/seed-staging.sql`.
- Never run `supabase/seed.sql` or `seed-phase-2.sql` … `seed-phase-6.sql`
  against staging; those files create demo users, jobs, payments, and documents.
- UAT accounts are created through the Auth Admin API, not by the seed.
- The service-role key stays in the shell/CI secret store and never enters the
  repository or a mobile build.

## 2. Create and link the project

```bash
export STAGING_PROJECT_REF="<staging-project-ref>"
export STAGING_DATABASE_URL="postgresql://postgres:<password>@db.${STAGING_PROJECT_REF}.supabase.co:5432/postgres"

npx --yes supabase login
npx --yes supabase link --project-ref "$STAGING_PROJECT_REF"
```

If the project does not exist yet, create it in the Supabase dashboard or with
the Management API, then link it. Do not reuse the development project.

## 3. Push migrations

```bash
npx --yes supabase db push
```

Confirm the migration history ends at `0123_phase_8_chat_threads.sql`. The push
creates the Phase 8 RPCs, `job_delivery_codes`, the four private storage buckets,
their RLS policies, and the `job_offers` Realtime publication entry.

## 4. Apply the configuration-only seed

Run once on a fresh staging database:

```bash
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f supabase/seed-staging.sql
```

The file inserts only reference/configuration data:

- currencies, languages, country, regions, cities, service zones, neighbourhoods
- permission catalogue and role mappings
- document types, vehicle makes/types/models, equipment, cargo catalogue
- verification checklist templates
- regulated tariff and published pricing plans/versions/rates
- cancellation policies, rating categories, dispatch rule
- payment providers, tax rates, commission rules
- notification templates, prohibited items, support categories, retention policy

It contains no `auth.users`, `profiles`, `customers`, `drivers`, `vehicles`,
`jobs`, `payments`, `driver_documents`, `chat_threads`, or metrics rows.

### Verify configuration-only staging

```sql
-- Expect 0 for every demo-data table. auth.users contains only the
-- platform service profile created by migration 0090.
select 'demo_auth_users' as table_name,
       count(*) filter (where id <> '00000000-0000-4000-8000-000000000000')
from auth.users
union all select 'customers', count(*) from public.customers
union all select 'drivers', count(*) from public.drivers
union all select 'vehicles', count(*) from public.vehicles
union all select 'jobs', count(*) from public.jobs
union all select 'payments', count(*) from public.payments
union all select 'driver_documents', count(*) from public.driver_documents
union all select 'chat_threads', count(*) from public.chat_threads;

-- Expect configuration rows.
select 'vehicle_types' as table_name, count(*) from public.vehicle_types
union all select 'cargo_types', count(*) from public.cargo_types
union all select 'pricing_plans', count(*) from public.pricing_plans
union all select 'pricing_plan_versions', count(*) from public.pricing_plan_versions
union all select 'notification_templates', count(*) from public.notification_templates;
```

Expected counts after the seed:

| Table | Count |
| --- | --- |
| demo `auth.users` | 0 (platform account only) |
| `vehicle_types` | 6 |
| `cargo_types` | 10 |
| `pricing_plans` | 6 |
| `pricing_plan_versions` | 6 |
| `notification_templates` | 18 |

If any demo table is non-zero, stop and recreate the staging project. Do not
clean up by deleting individual rows.

## 5. Auth and storage settings

1. Enable phone auth and configure a staging SMS provider. Use a test sender and
   a low monthly cap; never use production SMS credentials in staging.
2. Keep OTP length at 6 and set a short expiry (5–10 minutes).
3. Add the staging bundle/package IDs to the Firebase project used for staging.
4. Keep all four Phase 8 buckets private. They are created by migration `0122`;
   do not make them public to work around a policy issue.
5. Configure a staging Google Maps key restricted to the staging package/bundle
   ID. Do not reuse the production key.

### Create UAT accounts

Use the Auth Admin API or dashboard. Example shape (never commit the key):

```bash
export STAGING_SERVICE_ROLE_KEY="<service-role-key>"

curl -sS -X POST "https://${STAGING_PROJECT_REF}.supabase.co/auth/v1/admin/users" \
  -H "apikey: ${STAGING_SERVICE_ROLE_KEY}" \
  -H "authorization: Bearer ${STAGING_SERVICE_ROLE_KEY}" \
  -H 'content-type: application/json' \
  -d '{"phone":"+2557XXXXXXXX","phone_confirm":true,"user_metadata":{"full_name":"Staging Customer"}}'
```

The app calls `ensure_my_profile('customer', ...)` on first OTP login. A driver
UAT account additionally needs a controlled `drivers` row and verified vehicle;
create that fixture through a service-role SQL session or the future Phase 9
onboarding flow. It is UAT data, not seed configuration, and must be documented
in the UAT ticket.

## 6. Edge Functions

The Phase 8 mobile flows use PostgREST RPCs and Storage directly. Deploy the
Phase 7 Edge Functions only when testing provider integrations:

```bash
npx --yes supabase functions deploy --project-ref "$STAGING_PROJECT_REF"
```

Set function secrets in the Supabase dashboard or CLI secret store. Do not put
provider secrets in Flutter defines or `.env` files.

## 7. Universal links and push prerequisites

Before device QA, the web/domain team must publish:

```text
https://safeshift.app/.well-known/assetlinks.json
https://safeshift.app/.well-known/apple-app-site-association
```

and add the Associated Domains entitlement for `applinks:safeshift.app` to the
iOS Runner target. These files and the entitlement are not in this repository
yet, so universal links are expected to fail on a real device until they exist.
Custom-scheme links (`safeshift://...`) work from `adb`/`simctl` without them.

Firebase platform files are intentionally not committed. Supply the Firebase
values through `--dart-define` as documented in
`docs/architecture/0017-phase-8-client-integration.md`.

## 8. Manual QA checklist

Run against the local stack first, then repeat the device-only items in staging.

### Environment and build

- [ ] `flutter pub get`, `flutter analyze`, and `flutter test` pass in both apps.
- [ ] `npx supabase db reset` completes through migration `0123` and all local
      seeds.
- [ ] `verify-phase-8-schema.sql` reports `20 PASS, 0 FAIL`.
- [ ] `verify-phase-8-integration.sh` reports `0 failed`.
- [ ] `ENV=dev` app starts with no Supabase defines.
- [ ] `ENV=staging` without `SUPABASE_URL` fails fast with a clear error.
- [ ] `MOCK_MODE=true` still opens the design-only flows; normal builds do not.

### Customer auth and profile

- [ ] Requesting an OTP with an invalid/short number shows a validation error.
- [ ] A valid number receives an OTP and opens the OTP screen.
- [ ] An invalid OTP shows a safe error and does not authenticate.
- [ ] A successful OTP creates/loads the `profiles` row and opens `/home`.
- [ ] A deactivated profile is rejected.
- [ ] Signing out returns to `/login` and a second account cannot see the first
      account's cached history.

> Local blocker: Supabase CLI does not deliver real SMS without an SMS provider.
> Configure a test provider or read the OTP from the local auth container logs if
> your GoTrue version logs it. Real OTP delivery is a staging/device check.

### Customer booking and tracking

- [ ] Quote totals load from `quote_calculate_and_persist`, including retry after
      a forced network failure.
- [ ] Creating a job calls `match_dispatch`; a nearby seeded driver receives an
      offer.
- [ ] Tracking updates through Realtime and still updates via polling when the
      Realtime socket is interrupted.
- [ ] The delivery code shown to the customer is six digits.
- [ ] Uploading job evidence from tracking writes to `job-evidence/<job-id>/...`
      and shows the uploaded item.
- [ ] Chat photo upload writes to `chat-attachments/<job-id>/...` and appears in
      the thread.
- [ ] Cancelling a dispatchable job shows the correct confirmation/error state.
- [ ] Opening `safeshift://tracking/<job-id>` and
      `https://safeshift.app/jobs/<job-id>` opens live tracking.

### Driver

- [ ] Going online registers availability and location.
- [ ] A pending offer appears with countdown; accept and decline both work.
- [ ] Status advancement works through heading to pickup, arrived, loading, and
      in transit.
- [ ] The arrived-at-destination sheet requires the customer's six-digit code in
      real mode; a wrong code shows an error; the correct code completes delivery.
- [ ] Cargo evidence upload writes to `job-evidence/<job-id>/...`.
- [ ] Chat photo upload writes to `chat-attachments/<job-id>/...`.
- [ ] Earnings, trips, documents, vehicle, and ratings load from backend data and
      render cached values after a forced offline reload.
- [ ] Signing out clears cached driver data.
- [ ] Opening a job link opens `/home`; a history link opens `/trips`.

### Push and offline

- [ ] With Firebase defines present, the FCM token is upserted into
      `user_devices` and refresh updates the same row.
- [ ] Foreground notification displays through the local notification channel.
- [ ] Sign-out deletes the FCM token.
- [ ] With Firebase defines absent, the app starts normally and push is disabled.
- [ ] Airplane mode after a successful load still shows cached history/earnings
      with an offline/retry message.
- [ ] Returning online refreshes and replaces the cache.

### Storage security

- [ ] Customer A cannot read or upload to Customer B's job evidence path.
- [ ] A driver cannot upload to a job they are not assigned to.
- [ ] An unauthenticated request cannot read any Phase 8 bucket.
- [ ] Job evidence/chat objects cannot be updated or deleted by the client.

## 9. External blockers

Record these as blockers, not passed checks, until credentials/hardware exist:

- staging project creation and migration push;
- real SMS OTP delivery;
- Firebase platform config and real device push;
- universal-link association files, entitlement, and domain verification;
- Maps and payment provider sandbox credentials;
- camera/gallery and background-location device testing;
- Phase 5 refund/payout settlement and compensation decisions.
