# Running SafeShift Apps and Testing Against a Hosted Supabase Project

This runbook explains how to:

1. run the customer app, driver app, web app, and admin console locally;
2. create a **separate hosted Supabase test project** and point the apps at it;
3. create test users and exercise the main marketplace flows;
4. place Google Maps API keys correctly when the keys are available.

> **Scope:** local development and a disposable hosted **test** project only.
> Do not use the production Supabase project for these steps. Do not run demo
> seeds against staging or production.

---

## 1. Safety rules

- Use a **new, separate Supabase project** for hosted testing. Never reuse the
  production project.
- Never put the Supabase `service_role` / secret key in a mobile app, browser
  bundle, `NEXT_PUBLIC_*` variable, or committed file.
- Never run `supabase/seed.sql`, `seed-phase-2.sql` … `seed-phase-9.sql`, or
  `seed-local-sms.sql` against a hosted project. Those files create demo users,
  jobs, payments, documents, and a local SMS hook.
- Use `supabase/seed-staging.sql` for a hosted test project. It contains
  configuration data only.
- Use sandbox payment credentials only. Do not move real money.
- Never run `supabase db reset --linked` against a hosted project. It drops and
  recreates the remote database.
- Keep real phone numbers, API keys, and passwords out of git. `.env.local`,
  `android/local.properties`, and `ios/Flutter/Secrets.xcconfig` are ignored by
  this repository.
- The local SMS hook in `supabase/config.toml` is **local-only**. Do not copy it
  to a hosted project.

---

## 2. What runs where

| Component       | Where it runs                    | Auth                                  | Default URL                                             |
| --------------- | -------------------------------- | ------------------------------------- | ------------------------------------------------------- |
| Customer mobile | Flutter on Android/iOS           | Phone OTP                             | n/a                                                     |
| Driver mobile   | Flutter on Android/iOS           | Phone OTP                             | n/a                                                     |
| Admin console   | Next.js                          | Email + password                      | `http://localhost:3001`                                 |
| Web app         | Next.js                          | Public / future auth                  | `http://localhost:3000`                                 |
| Supabase API    | Local CLI or hosted project      | Supabase Auth                         | `http://127.0.0.1:54321` or `https://<ref>.supabase.co` |
| Edge Functions  | Supabase runtime                 | JWT / permissions / webhook signature | `/functions/v1`                                         |
| Storage         | Supabase Storage                 | RLS                                   | private buckets                                         |
| Google Maps     | Edge Functions now; mobile later | Server key / client key               | see §8                                                  |

The customer and driver apps are **compile-time configured** with
`--dart-define`. They do not read `.env` files at runtime.

---

## 3. Prerequisites

Check the toolchain:

```bash
node --version          # Node 24+
corepack pnpm --version # 12.15.0
flutter --version       # Flutter 3.47+ / Dart 3.13+
dart --version
docker --version
psql --version
npx --yes supabase --version
```

You also need:

- Android Studio / Xcode and a working emulator or simulator.
- A Supabase account.
- A phone number you control for hosted OTP testing.
- Optional: `jq` for the curl examples.
- Optional: Deno 2 if you want to run the Edge Function check/lint/test tasks
  locally. The Supabase CLI handles hosted deployment, but install Deno 2 if
  your CLI version asks for it.

---

## 4. First-time repository setup

From the repository root:

```bash
corepack enable --install-directory "$HOME/.local/bin" pnpm
export PATH="$HOME/.local/bin:$PATH"

corepack pnpm run setup
```

Manual equivalent:

```bash
corepack pnpm install
dart pub global activate melos 7.8.0
melos bootstrap
export PATH="$PATH:$HOME/.pub-cache/bin"
```

If a Flutter build complains about fonts, confirm the Poppins/Inter files exist
under each app's `assets/fonts/` directory. They are already present in this
repository.

---

## 5. Run everything locally first

Local testing is faster and does not consume hosted SMS quota.

### 5.1 Start the local Supabase stack

```bash
corepack pnpm db:start
corepack pnpm db:reset
corepack pnpm db:verify
```

`db:reset` applies all 127 migrations and the local demo seeds, including the
local SMS sandbox. `db:verify` runs the Phase 1–9 schema gates.

Local endpoints:

| Service         | URL                                                       |
| --------------- | --------------------------------------------------------- |
| API             | `http://127.0.0.1:54321`                                  |
| Studio          | `http://127.0.0.1:54323`                                  |
| Mailpit (email) | `http://127.0.0.1:54324`                                  |
| Database        | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |

### 5.2 Print local OTPs in the terminal

The local stack captures SMS OTPs instead of sending them.

Terminal 1:

```bash
corepack pnpm db:watch-otp
```

Terminal 2:

```bash
cd apps/customer-mobile
flutter run --dart-define=ENV=dev
```

Request an OTP in the app. The watcher prints it, for example:

```text
OTP 123456 -> +255712000001
```

Useful local seeded phone numbers:

| User        | Phone           |
| ----------- | --------------- |
| Customer 1  | `+255711000001` |
| Driver 1    | `+255712000001` |
| Fleet owner | `+255714000001` |

The local seed also contains email/password accounts used by the admin console
and the integration gates:

```text
superadmin@safeshift.local / SafeshiftDev!2026
fleet.owner@safeshift.local / SafeshiftDev!2026
customer1@safeshift.local / SafeshiftDev!2026
driver1@safeshift.local / SafeshiftDev!2026
```

### 5.3 Run the mobile apps locally

Customer:

```bash
cd apps/customer-mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=ENV=dev
```

Driver:

```bash
cd apps/driver-mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=ENV=dev
```

To run the design-only mock flows, add `--dart-define=MOCK_MODE=true`.

### 5.4 Run the web app and admin console locally

Web:

```bash
cp apps/web/.env.example apps/web/.env.local
# set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
corepack pnpm dev:web
```

Admin console:

```bash
cp apps/admin-console/.env.example apps/admin-console/.env.local
# set NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY,
# and NEXT_PUBLIC_SITE_URL=http://localhost:3001
corepack pnpm --filter @safeshift/admin-console dev
```

Sign in at `http://localhost:3001/login` with the seeded super admin.

### 5.5 Serve Edge Functions locally (optional)

```bash
cp supabase/functions/.env.local.example supabase/functions/.env.local
# fill in only the providers you are testing
npx --yes supabase functions serve --env-file supabase/functions/.env.local
```

Local functions are available at
`http://127.0.0.1:54321/functions/v1/<function-name>`.

---

## 6. Create the hosted Supabase test project

### 6.1 Create the project

1. Open the Supabase dashboard.
2. Create a **new project** named something like `safeshift-test`.
3. Choose the region closest to you.
4. Save the database password in a password manager.
5. Do not reuse the development or production project.

Collect these values from **Project Settings → API** and **Connect**:

| Value                                            | Where it goes                                                                     |
| ------------------------------------------------ | --------------------------------------------------------------------------------- |
| Project URL, e.g. `https://abcd1234.supabase.co` | `SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_URL`                                       |
| Anon or publishable key                          | Mobile `--dart-define=SUPABASE_ANON_KEY`, Next.js `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| Service role or secret key                       | Shell/CI only; never in an app                                                    |
| Database connection string                       | `psql` and `supabase db push`                                                     |

Set shell variables for the rest of this runbook:

```bash
export TEST_PROJECT_REF="<project-ref>"
export TEST_SUPABASE_URL="https://${TEST_PROJECT_REF}.supabase.co"
export TEST_ANON_KEY="<anon-or-publishable-key>"
export TEST_SERVICE_ROLE_KEY="<service-role-or-secret-key>"
export TEST_DATABASE_URL="<connection-string-from-dashboard>"
```

`TEST_DATABASE_URL` is usually the **Session pooler** or **Direct connection**
string from the dashboard. If direct connections are IPv6-only on your network,
use the pooler string.

### 6.2 Link and push migrations

```bash
npx --yes supabase login
npx --yes supabase link --project-ref "$TEST_PROJECT_REF"
npx --yes supabase db push
```

`db push` applies the 127 migrations from `supabase/migrations/`. It does **not**
apply the local seed files.

If the CLI reports a migration-history mismatch on a brand-new project, confirm
you linked the correct empty project. Do not edit applied migrations. For a new
project, `supabase db push --include-all` is sometimes needed; use it only after
confirming the target project is empty.

### 6.3 Apply the configuration-only seed

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed-staging.sql
```

This creates configuration data such as countries, cities, service zones,
vehicle types, cargo types, pricing plans, notification templates, support
categories, and feature flags. It does **not** create demo users or jobs.

Do not run any of these against the hosted project:

```text
supabase/seed.sql
supabase/seed-phase-2.sql
supabase/seed-phase-3.sql
supabase/seed-phase-4.sql
supabase/seed-phase-5.sql
supabase/seed-phase-6.sql
supabase/seed-phase-9.sql
supabase/seed-local-sms.sql
```

### 6.4 Verify the hosted schema and seed

Check the latest migration:

```bash
psql "$TEST_DATABASE_URL" -Atc \
  "select version, name from supabase_migrations.schema_migrations order by version desc limit 5;"
```

Expected latest version: `0127`.

Check the configuration seed:

```bash
psql "$TEST_DATABASE_URL" -Atc "
select 'countries', count(*) from public.countries
union all select 'vehicle_types', count(*) from public.vehicle_types
union all select 'cargo_types', count(*) from public.cargo_types
union all select 'pricing_plans', count(*) from public.pricing_plans
union all select 'notification_templates', count(*) from public.notification_templates;
"
```

Expected values:

```text
countries|3
vehicle_types|6
cargo_types|10
pricing_plans|6
notification_templates|18
```

Check Storage buckets (created by migrations, not by the seed):

```bash
psql "$TEST_DATABASE_URL" -Atc \
  "select id, public, file_size_limit from storage.buckets order by id;"
```

Expected buckets:

```text
chat-attachments
data-exports
driver-documents
job-evidence
vehicle-documents
```

Check Realtime tables:

```bash
psql "$TEST_DATABASE_URL" -Atc \
  "select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by 1;"
```

### 6.5 Configure hosted Auth

In the Supabase dashboard:

1. **Authentication → Providers → Phone**
   - Enable phone authentication.
   - Enable phone signups. The mobile apps call
     `signInWithOtp(shouldCreateUser: true)`.
   - Configure an SMS provider. For a first test, Twilio trial is the simplest
     option; verify the recipient numbers in the Twilio console.
   - If your project shows a **Test OTP** section, you can add a phone number and
     a fixed code there instead of sending real SMS.
   - Keep OTP length at 6 and a short expiry (5–10 minutes) for testing.

2. **Authentication → Providers → Email**
   - Keep email enabled for admin-console accounts.
   - For test admins, create users with `email_confirm: true` (or confirm them in
     the dashboard) so password sign-in works immediately.

3. **Authentication → URL Configuration**
   - Site URL: `http://localhost:3000`
   - Additional redirect URLs:
     ```text
     http://localhost:3000/**
     http://localhost:3001/**
     safeshift://**
     https://safeshift.app/**
     ```
   - Add your real test domains later if you use them.

4. **Authentication → Hooks → Custom Access Token**
   - Enable the hook and point it at:
     ```text
     pg-functions://postgres/public/custom_access_token_hook
     ```
     (the dashboard may let you select the function instead of pasting the URI)
   - This is the hosted equivalent of the local
     `[auth.hook.custom_access_token]` setting. It adds the role/country claims
     used by the application.
   - Do **not** enable the local `public.send_sms_hook` on a hosted project. That
     function is installed by `seed-local-sms.sql`, which must not run hosted.

5. **Authentication → Rate Limits**
   - Keep SMS limits low while testing. Raise them only when you have a real SMS
     provider and a test budget.

6. **Authentication → Sign In / Providers**
   - Leave anonymous sign-ins disabled.

### 6.6 Create hosted test users

There are two ways to create users.

#### Option A — app-first (closest to real usage)

Open the customer or driver app, enter a phone number, request the OTP, and
verify it. The Auth trigger creates the `profiles` row automatically. The driver
app then sends a new driver through onboarding.

This is the recommended way to test the real phone-auth and onboarding flows.

#### Option B — Admin API (predictable test accounts)

Create an email/password admin:

```bash
curl -sS -X POST "$TEST_SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $TEST_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $TEST_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin.test@safeshift.example",
    "password": "Use-A-Long-Test-Password-2026!",
    "email_confirm": true,
    "user_metadata": {
      "full_name": "Test Admin",
      "country_code": "TZ"
    }
  }'
```

Create a phone user:

```bash
curl -sS -X POST "$TEST_SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $TEST_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $TEST_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+255712345678",
    "phone_confirm": true,
    "user_metadata": {
      "full_name": "Test Driver",
      "country_code": "TZ"
    }
  }'
```

Use phone numbers you control in E.164 format (`+255...`). The mobile apps
accept local formats such as `0712345678` and normalize them before calling
Supabase. If you use Twilio trial, verify the numbers in Twilio first. If you
use hosted Test OTP, add them there first.

The `handle_new_user()` trigger creates a `profiles` row for every new
`auth.users` row. Verify it:

```bash
psql "$TEST_DATABASE_URL" -c \
  "select id, email, phone, primary_role from public.profiles
   where email = 'admin.test@safeshift.example'
      or phone like '%712345678';"
```

#### Grant the admin role

The admin console checks `public.admin_console_role()`, which reads active
`public.admin_roles` grants. A user with no grant is signed out with:

```text
This account has no active admin or fleet-owner role.
```

Grant a global super admin:

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
insert into public.admin_roles (profile_id, role_name, country_id, city_id, is_active)
select p.id, 'super_admin', null, null, true
from public.profiles p
where p.email = 'admin.test@safeshift.example'
  and not exists (
    select 1
    from public.admin_roles r
    where r.profile_id = p.id
      and r.role_name = 'super_admin'
      and r.is_active
  );
SQL
```

#### Optional: create a fleet-owner test account

Fleet owners use the admin console with email/password and only see
`dashboard`, `fleets`, and `settings`.

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
update public.profiles
set primary_role = 'fleet_owner'
where email = 'fleet.owner.test@safeshift.example';

insert into public.fleets (
  country_id, primary_city_id, name, contact_email, contact_phone,
  owner_profile_id, verified_at
)
select
  '33333333-0000-4000-8000-000000000001',
  '55555555-0000-4000-8000-000000000001',
  'Test Fleet',
  'fleet.owner.test@safeshift.example',
  '+255712345679',
  p.id,
  now()
from public.profiles p
where p.email = 'fleet.owner.test@safeshift.example'
  and not exists (
    select 1 from public.fleets f where f.owner_profile_id = p.id
  );

insert into public.admin_roles (profile_id, role_name, country_id, city_id, is_active)
select p.id, 'fleet_owner', '33333333-0000-4000-8000-000000000001', null, true
from public.profiles p
where p.email = 'fleet.owner.test@safeshift.example'
  and not exists (
    select 1
    from public.admin_roles r
    where r.profile_id = p.id
      and r.role_name = 'fleet_owner'
      and r.is_active
  );
SQL
```

### 6.7 Deploy Edge Functions and set secrets

Deploy all functions:

```bash
npx --yes supabase functions deploy --project-ref "$TEST_PROJECT_REF"
```

Set the shared gates and the Google Maps server key:

```bash
npx --yes supabase secrets set --project-ref "$TEST_PROJECT_REF" \
  CRON_SECRET="$(openssl rand -hex 32)" \
  INTERNAL_FUNCTION_SECRET="$(openssl rand -hex 32)" \
  GOOGLE_MAPS_API_KEY="<google-maps-server-key>"
```

Add provider secrets only for the integrations you are testing:

```bash
# SMS / email / push / payments — optional for a first UI test
npx --yes supabase secrets set --project-ref "$TEST_PROJECT_REF" \
  BEEM_API_KEY="<sandbox>" \
  BEEM_SECRET_KEY="<sandbox>" \
  RESEND_API_KEY="<sandbox>" \
  FCM_SERVICE_ACCOUNT_JSON='<one-line-service-account-json>' \
  SELCOM_API_KEY="<sandbox>" \
  SELCOM_API_SECRET="<sandbox>" \
  SELCOM_VENDOR_ID="<sandbox>" \
  SELCOM_WEBHOOK_SECRET="<sandbox>" \
  FLUTTERWAVE_SECRET_KEY="<sandbox>" \
  FLUTTERWAVE_WEBHOOK_SECRET="<sandbox>"
```

Core auth, profiles, jobs, quotes, storage, and realtime do not require those
provider secrets. Maps functions require `GOOGLE_MAPS_API_KEY`; payment flows
require sandbox payment credentials.

Check the deployed function health:

```bash
curl -sS "$TEST_SUPABASE_URL/functions/v1/health" | jq
```

The `health` function checks the database and the Vault secret
`safeshift_healthcheck`. A brand-new test project returns HTTP `503` with
`status: "degraded"` until that secret exists. Core app flows do not depend on
this check. To make it green, create the Vault secret once:

```bash
psql "$TEST_DATABASE_URL" -c \
  "select vault.create_secret('ok', 'safeshift_healthcheck');"
```

A healthy response uses the standard envelope:

```json
{
  "data": {
    "status": "ok",
    "checks": {
      "db": true,
      "vault": true,
      "timestamp": "2026-10-30T12:00:00.000Z"
    }
  },
  "error": null
}
```

If `health` still reports a Vault/database issue, confirm the project is linked
and the secrets are set for the correct project ref.

> For production, provider secrets belong in Supabase Vault. For a disposable
> test project, CLI secrets are acceptable. Never commit them.

---

## 7. Point the apps at the hosted test project

Use `ENV=staging` for a hosted test build. It forces explicit URL/key values and
fails fast if one is missing.

For convenience, you can keep a local-only `.env.hosted-test` file containing
`ENV`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` and run:

```bash
flutter run --dart-define-from-file=.env.hosted-test
```

The file is ignored by git and is compile-time configuration, not runtime env.

### 7.1 Customer app

```bash
cd apps/customer-mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter run \
  --dart-define=ENV=staging \
  --dart-define=SUPABASE_URL="$TEST_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$TEST_ANON_KEY"
```

### 7.2 Driver app

```bash
cd apps/driver-mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter run \
  --dart-define=ENV=staging \
  --dart-define=SUPABASE_URL="$TEST_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$TEST_ANON_KEY"
```

### 7.3 Admin console

```bash
cp apps/admin-console/.env.example apps/admin-console/.env.local
```

Edit `apps/admin-console/.env.local`:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-or-publishable-key>
NEXT_PUBLIC_SITE_URL=http://localhost:3001
```

Run:

```bash
corepack pnpm --filter @safeshift/admin-console dev
```

Open `http://localhost:3001/login` and sign in with the test admin email/password.
The console uses the signed-in admin's session, not the `service_role` key, so
RLS and permission checks stay in force.

### 7.4 Web app

```bash
cp apps/web/.env.example apps/web/.env.local
```

Edit `apps/web/.env.local`:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

Run:

```bash
corepack pnpm dev:web
```

Open `http://localhost:3000`.

### 7.5 Optional Firebase push configuration

Push is optional. If the Firebase defines are absent, the apps skip push
registration and continue to work.

```bash
--dart-define=FIREBASE_API_KEY=<key> \
--dart-define=FIREBASE_APP_ID=<app-id> \
--dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> \
--dart-define=FIREBASE_PROJECT_ID=<project-id>
```

Do not put the Firebase service-account JSON in a mobile build. That is a server
secret for the `push-send` Edge Function.

### 7.6 Physical-device notes

- A hosted Supabase URL works from a real phone without LAN configuration.
- If you point a physical device at the **local** stack, replace
  `127.0.0.1` with your computer's LAN IP, for example
  `http://192.168.1.20:54321`.
- Local HTTP may require cleartext-traffic configuration on Android. Hosted
  HTTPS does not.
- Use `flutter devices` to confirm the target before `flutter run`.

---

## 8. Google Maps API key placement

### 8.1 Current state

The server-side Maps integration is already implemented:

- `supabase/functions/maps-geocode` — forward/reverse geocoding.
- `supabase/functions/maps-distance` — Routes API `computeRouteMatrix`.
- `supabase/functions/quote-calculate` — can use distance when the caller does
  not supply it.
- `supabase/functions/_shared/provider_factory.ts` reads
  `GOOGLE_MAPS_API_KEY` first, then `GOOGLE_MAPS_SERVER_API_KEY`.

The mobile map UI is still a placeholder:

- Customer: `apps/customer-mobile/lib/features/ride/presentation/widgets/shiny_map_view.dart`
  and `apps/customer-mobile/lib/features/tracking/presentation/widgets/map_view.dart`.
- Driver: `apps/driver-mobile/lib/features/home/presentation/widgets/map_placeholder.dart`.

`google_maps_flutter` is already in both `pubspec.yaml` files, but the key is not
read by the Flutter code yet. The `.env.*.example` files list
`GOOGLE_MAPS_API_KEY` as a placeholder for the future wiring. **Adding the key
alone will not make the placeholder map render Google Maps.** The map widgets
must be replaced with `GoogleMap` widgets and the native SDK keys must be set.

### 8.2 Server key — can be placed now

Local:

```bash
cp supabase/functions/.env.local.example supabase/functions/.env.local
# set:
# GOOGLE_MAPS_API_KEY=<server-key>
npx --yes supabase functions serve --env-file supabase/functions/.env.local
```

Hosted test project:

```bash
npx --yes supabase secrets set --project-ref "$TEST_PROJECT_REF" \
  GOOGLE_MAPS_API_KEY="<server-key>"
```

Optional Vault path: the Edge Functions also read Vault through
`public.get_vault_secret()`. For a test project, CLI secrets are simpler. For
production, use Vault.

Use a **server key** with:

- Geocoding API enabled.
- Routes API enabled.
- Places API enabled only if you test address search.
- Application restrictions set to “None” or to the server egress IPs if you have
  stable egress. Supabase Edge Function egress IPs are not guaranteed static, so
  API restrictions and quotas are usually safer than IP restrictions.
- Billing enabled and a low quota for testing.

Distance Matrix API is legacy and cannot be enabled on new Google Cloud
projects. The `maps-distance` function uses Routes API `computeRouteMatrix`
instead, so enable **Routes API**, not Distance Matrix.

Do not put the server key in a mobile app.

### 8.3 Mobile key — exact placement when the key arrives

Use a separate **mobile key** for Android/iOS, restricted by app identity. When
you provide the key, the wiring will be:

1. **Flutter config**

   Add a field to both
   `apps/customer-mobile/lib/core/config/env_config.dart` and
   `apps/driver-mobile/lib/core/config/env_config.dart`:

   ```dart
   static const String googleMapsApiKey =
       String.fromEnvironment('GOOGLE_MAPS_API_KEY');
   ```

   Pass it at run/build time:

   ```bash
   --dart-define=GOOGLE_MAPS_API_KEY=<mobile-key>
   ```

2. **Android**

   - Customer package: `com.safeshift.safeshift_customer`
   - Driver package: `com.safeshift.safeshift_driver`

   Add the manifest entry inside `<application>` in
   `apps/<app>/android/app/src/main/AndroidManifest.xml`:

   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="${GOOGLE_MAPS_API_KEY}" />
   ```

   Keep the real key in `android/local.properties` (already gitignored) or inject
   it in CI, and expose it as a Gradle manifest placeholder. Do not commit the
   key.

3. **iOS**

   - Customer bundle: `com.safeshift.safeshiftCustomer`
   - Driver bundle: `com.safeshift.safeshiftDriver`

   Add `import GoogleMaps` and the key call in
   `apps/<app>/ios/Runner/AppDelegate.swift` before plugin registration:

   ```swift
   import GoogleMaps

   GMSServices.provideAPIKey("YOUR_MOBILE_MAPS_KEY")
   ```

   For a non-hardcoded setup, store the key in
   `ios/Flutter/Secrets.xcconfig`, expose it through `Info.plist`, and read it
   from `Bundle.main` in `AppDelegate.swift`. Do not commit the xcconfig file.

4. **Replace the placeholders**

   - Customer ride map: replace `ShinyMapView` with a `GoogleMap` and markers.
   - Customer tracking map: replace the “Map view — coming soon” widget.
   - Driver home map: replace `MapPlaceholder`.
   - Start the camera around Dar es Salaam:
     `-6.7924, 39.2083`.
   - Add pickup/destination markers, driver marker, route polyline, and
     permission handling.

5. **Restrict the mobile key**

   - Android: restrict by package name and release/debug SHA-1.
   - iOS: restrict by bundle ID.
   - Enable Maps SDK for Android and Maps SDK for iOS.
   - Use a different key from the server key.

### 8.4 Web/admin maps (only if added later)

The current web and admin console do not render Google Maps. If a web map is
added, use a browser key with HTTP-referrer restrictions and expose it as
`NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`. Never reuse the server key in the browser.

### 8.5 Test the server Maps integration now

Get a user JWT with an email/password test account:

```bash
USER_JWT="$(curl -sS -X POST \
  "$TEST_SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $TEST_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin.test@safeshift.example","password":"Use-A-Long-Test-Password-2026!"}' \
  | jq -r '.access_token')"
```

Geocode:

```bash
curl -sS -X POST "$TEST_SUPABASE_URL/functions/v1/maps-geocode" \
  -H "apikey: $TEST_ANON_KEY" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"address":"Kariakoo Market, Dar es Salaam"}' | jq
```

Distance:

```bash
curl -sS -X POST "$TEST_SUPABASE_URL/functions/v1/maps-distance" \
  -H "apikey: $TEST_ANON_KEY" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "origins": [{"lat": -6.8180, "lng": 39.2700}],
    "destinations": [{"lat": -6.7750, "lng": 39.2250}],
    "mode": "driving"
  }' | jq
```

Expected response shape (distance and duration values are illustrative):

```json
{
  "data": {
    "distance_km": 12.3,
    "duration_min": 28,
    "cached": false
  },
  "error": null
}
```

If you see `REQUEST_DENIED`, check billing, enabled APIs, key restrictions, and
whether you used the server key rather than the mobile key.

### 8.6 When you provide the Google Maps key

The wiring and test sequence will be:

1. Put the server key in Supabase secrets (or Vault) and test `maps-geocode` and
   `maps-distance` first.
2. Put the mobile key in the Android/iOS native configuration and add the
   `GOOGLE_MAPS_API_KEY` dart-define.
3. Replace the customer `ShinyMapView` and driver `MapPlaceholder` widgets with
   `GoogleMap`, markers, and route polylines.
4. Test the Dar es Salaam camera, pickup/destination pins, driver marker,
   permissions, and a route between Kariakoo and Mlimani City.
5. Run `flutter analyze`, `flutter test`, and the app smoke tests again.

The server key and mobile key must be different and restricted separately.

---

## 9. Hosted test plan

Run these in order. Stop and fix the first failure before continuing.

### 9.1 Backend smoke checks

- [ ] Latest migration is `0127`.
- [ ] Config seed counts match §6.4.
- [ ] Storage buckets exist and are private.
- [ ] `health` function returns HTTP `200` with `status: "ok"` after the Vault
      health secret is created.
- [ ] Realtime publication includes the expected tables.

### 9.2 Customer app

- [ ] Phone OTP request succeeds and the code arrives (or Test OTP works).
- [ ] OTP verification creates/signs in the customer profile.
- [ ] Home loads nearby vehicle types and service zones.
- [ ] Quote calculation returns a fare breakdown.
- [ ] Job creation succeeds with pickup, destination, cargo, and vehicle type.
- [ ] Job appears in history.
- [ ] Tracking updates arrive via Realtime; polling fallback works when Realtime
      is unavailable.
- [ ] Delivery code entry completes the job.
- [ ] Rating and receipt are shown.
- [ ] Notification preferences save.
- [ ] Recurring job template can be created.
- [ ] Trip share link opens the public snapshot.
- [ ] SOS/trip alert creates a `trip_alerts` row and notifies the on-call path.
- [ ] Dispute with evidence uploads to the private `job-evidence` bucket.
- [ ] Support ticket can be created.
- [ ] Offline mode shows cached data and recovers when connectivity returns.

### 9.3 Driver app

- [ ] Phone OTP request and verification succeed.
- [ ] A new driver is routed through onboarding.
- [ ] Driver profile and documents upload to `driver-documents`.
- [ ] Vehicle details and documents upload to `vehicle-documents`.
- [ ] Driver cannot self-verify trust fields.
- [ ] Admin approves the driver and vehicle.
- [ ] Driver can go online and update location.
- [ ] Job offer arrives via Realtime or polling.
- [ ] Accept, arrive, load, start, arrive at destination, and complete
      transitions work.
- [ ] Delivery code verification works.
- [ ] Earnings and trip history load.
- [ ] Push token registration is skipped cleanly when Firebase is not configured.

### 9.4 Admin console

- [ ] Login works for the test super admin.
- [ ] Login is rejected for a user without an `admin_roles` grant.
- [ ] Role-based navigation matches the grant:
      `super_admin`, `operations_admin`, `verification_admin`, `support_agent`,
      `finance_admin`, `analyst`, `fleet_owner`.
- [ ] Dashboard metrics load.
- [ ] Driver/vehicle verification approve and reject actions work and are
      audited.
- [ ] Users, drivers, jobs, payments, payouts, disputes, support, incidents, and
      data requests load.
- [ ] Pricing, promotions, fleets, and settings load for authorized roles.
- [ ] Audit log records admin actions.
- [ ] Fleet owner sees only dashboard, fleets, and settings, and only their own
      fleet data.

### 9.5 RLS and isolation

Use two customer accounts and two driver accounts.

- [ ] Customer A cannot read Customer B's jobs, addresses, payments, or
      disputes.
- [ ] A driver cannot read an unassigned job's private details.
- [ ] A driver cannot read another driver's documents or earnings.
- [ ] An admin without the relevant permission cannot call the corresponding
      RPC or Edge Function.
- [ ] Storage objects are readable only by the owner or an authorized admin.
- [ ] Public trip-share links expose only the snapshot, not the full job.

### 9.6 Payments, notifications, and maps

- [ ] Payment initiation uses sandbox credentials only.
- [ ] Webhook signatures are verified; invalid signatures return `401`.
- [ ] Refund and payout actions remain permission-gated.
- [ ] Notification templates render and log without leaking PII.
- [ ] Maps geocode/distance work with the server key.
- [ ] Mobile maps render after the client key and widgets are wired.

---

## 10. Verification commands

Local backend gates:

```bash
corepack pnpm db:verify
supabase/scripts/verify-phase-9-functions.sh
supabase/scripts/verify-phase-9-integration.sh
```

Static app checks:

```bash
corepack pnpm typecheck
corepack pnpm lint
corepack pnpm build
corepack pnpm flutter:analyze
corepack pnpm flutter:test
```

Edge Functions, if Deno is installed:

```bash
cd supabase/functions
deno task check
deno task lint
deno task test
```

The Phase 8/9 integration scripts are **local-only** and use the demo seed
accounts. Do not run them against the hosted test project.

---

## 11. Troubleshooting

| Symptom                                                 | Likely cause                                                      | Fix                                                                                       |
| ------------------------------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `phone_provider_disabled` or no OTP                     | Phone provider/SMS provider not enabled                           | Enable Phone auth and an SMS provider; use Test OTP or Twilio trial                       |
| OTP never arrives                                       | Recipient not verified in Twilio, rate limit, wrong number format | Verify the number in Twilio; use E.164; check Auth logs                                   |
| `Invalid login credentials` on admin console            | Email not confirmed, wrong password, or no admin role             | Confirm the user; grant `admin_roles`; check `admin_console_role()`                       |
| `This account has no active admin or fleet-owner role`  | No active `admin_roles` row                                       | Insert a grant per §6.6                                                                   |
| `relation "..." does not exist`                         | Migrations not pushed or wrong project                            | Link the correct project; `supabase db push`                                              |
| `new row violates row-level security policy`            | Wrong account/role or missing profile                             | Check the signed-in user and the relevant RLS policy                                      |
| `permission denied for schema extensions` while seeding | Seed run as the wrong role                                        | Use the dashboard connection string with the postgres user                                |
| `supabase db push` migration mismatch                   | Linked project has different history                              | Do not edit migrations; confirm the target; use `migration repair` only with a clear plan |
| Edge Function returns `401`                             | Missing/expired JWT, or handler requires a user                   | Sign in again; send `Authorization: Bearer <access_token>`                                |
| Edge Function returns `403`                             | Missing permission                                                | Grant the correct admin permission/role                                                   |
| Maps returns `REQUEST_DENIED`                           | API not enabled, billing off, key restriction, wrong key          | Enable the API, check restrictions, use the server key                                    |
| Maps returns `OVER_QUERY_LIMIT`                         | Quota exhausted                                                   | Raise the test quota or wait                                                              |
| Admin console cannot reach Supabase                     | Wrong `.env.local` or stale Next.js process                       | Recheck the URL/key; restart the dev server                                               |
| Mobile app ignores the hosted URL                       | Missing `ENV=staging` or empty define                             | Pass both `SUPABASE_URL` and `SUPABASE_ANON_KEY`; use `ENV=staging`                       |
| Physical device cannot reach local Supabase             | `127.0.0.1` points at the device                                  | Use the computer's LAN IP and the correct port                                            |
| Local OTP not printed                                   | Watcher not running or hook not installed                         | `pnpm db:watch-otp`; `pnpm db:reset`                                                      |

Useful diagnostic queries:

```sql
-- Auth users and profiles
select u.id, u.email, u.phone, p.primary_role
from auth.users u
left join public.profiles p on p.id = u.id
order by u.created_at desc
limit 20;

-- Admin grants
select p.email, r.role_name, r.is_active, r.country_id, r.city_id
from public.admin_roles r
join public.profiles p on p.id = r.profile_id
order by r.granted_at desc;

-- Recent jobs
select id, status, customer_id, driver_id, created_at
from public.jobs
order by created_at desc
limit 20;
```

---

## 12. Cleanup

When testing is finished:

1. Delete the hosted test project from the Supabase dashboard.
2. Rotate any provider keys that were pasted into a shell or shared in chat.
3. Remove local env files if they contain real credentials:
   ```bash
   rm -f apps/web/.env.local apps/admin-console/.env.local
   rm -f supabase/functions/.env.local
   ```
4. Stop the local stack:
   ```bash
   corepack pnpm db:stop
   ```

---

## 13. Known gaps before production

- Hosted staging and real-device checks still need real SMS/FCM/Maps/payment
  credentials and physical devices.
- The mobile map widgets are placeholders until the Google Maps client key is
  wired.
- Push, universal links, camera/gallery, and background location need real
  device verification.
- Deno is not installed in the current environment, so Edge Functions have been
  source/config-checked locally but not executed here.
- The hosted test project must never be promoted to production. Production
  migrations, secrets, and provider accounts are a separate controlled process.

---

## 14. Quick command summary

```bash
# Local
corepack pnpm db:start
corepack pnpm db:reset
corepack pnpm db:verify
corepack pnpm db:watch-otp

# Hosted test project
npx --yes supabase login
npx --yes supabase link --project-ref "$TEST_PROJECT_REF"
npx --yes supabase db push
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/seed-staging.sql
npx --yes supabase functions deploy --project-ref "$TEST_PROJECT_REF"
npx --yes supabase secrets set --project-ref "$TEST_PROJECT_REF" \
  CRON_SECRET="$(openssl rand -hex 32)" \
  INTERNAL_FUNCTION_SECRET="$(openssl rand -hex 32)" \
  GOOGLE_MAPS_API_KEY="<server-key>"

# Customer app against hosted test project
cd apps/customer-mobile
flutter run \
  --dart-define=ENV=staging \
  --dart-define=SUPABASE_URL="$TEST_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$TEST_ANON_KEY"

# Driver app against hosted test project
cd ../driver-mobile
flutter run \
  --dart-define=ENV=staging \
  --dart-define=SUPABASE_URL="$TEST_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$TEST_ANON_KEY"

# Admin console
cd ../..
corepack pnpm --filter @safeshift/admin-console dev

# Web
corepack pnpm dev:web
```
