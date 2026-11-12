# SafeShift

A digital logistics marketplace launching in Dar es Salaam, Tanzania — connecting
customers with verified drivers and trucks for moves, deliveries, and commercial
cargo.

Transparent pricing · Identity verification · Live GPS tracking · Digital proof
of delivery · Structured protection model.

Pilot: Stage 1 corridor, Dar es Salaam — 50–100 verified vehicles.

## Status

- Phase 1–9 database layer complete: 127 migrations, seven local demo seeds,
  the local SMS sandbox seed, and schema gates for every phase.
- Latest verified gate results: Phase 1 `151 PASS`, Phase 2 `166 PASS`, Phase 3
  `150 PASS`, Phase 4 `154 PASS`, Phase 5 `81 PASS`, Phase 6 `154 PASS`, all
  with `0 FAIL`; Phase 7–9 schema gates are run by `pnpm db:verify`, with
  function and integration gates run separately.
- Flutter customer and driver apps are wired to Supabase: OTP auth, Riverpod
  data providers, Hive offline cache, Realtime/polling, Storage uploads,
  delivery OTP, push-token registration, and deep links.
- Phase 9 marketplace flows are implemented locally: driver onboarding,
  business accounts, recurring jobs, fleet portal, admin console, disputes,
  support, safety, and trip sharing.
- Phase 7 provider integrations and Edge Functions are implemented locally. The
  Maps Edge Functions are deployed to the hosted test project; the remaining
  functions are not deployed. Phase 8 staging, real SMS/FCM, universal links,
  mobile Maps, and payment-provider checks still require external credentials
  and devices.
- Next.js web workspace is scaffolded.

## Stack

| Layer         | Technology                                                           |
| ------------- | -------------------------------------------------------------------- |
| Mobile        | Flutter — customer and driver apps                                   |
| Web           | Next.js App Router — customer web, business portal, admin console    |
| Backend       | Supabase — Postgres/PostGIS, Auth, Storage, Realtime, Edge Functions |
| Maps          | Google Maps Platform                                                 |
| Payments      | Selcom / Flutterwave, cards via Flutterwave / Stripe                 |
| Messaging     | Firebase Cloud Messaging, Beem Africa, Resend                        |
| Jobs          | Supabase pg_cron, Upstash QStash                                     |
| Observability | Sentry, BetterStack, PostHog                                         |
| CI/CD         | GitHub Actions, Vercel, Codemagic + Fastlane                         |
| Edge/DNS      | Cloudflare                                                           |

## Monorepo layout

```text
safeshift/
├── apps/
│   ├── customer-mobile/      # Flutter — Melos workspace
│   ├── driver-mobile/        # Flutter — Melos workspace
│   └── web/                  # Next.js — pnpm workspace
├── packages/
│   ├── shared-flutter/       # Shared Dart tokens, formatters, models
│   └── shared-types/         # Shared TypeScript contracts + generated DB types
├── supabase/
│   ├── migrations/           # SQL migrations — source of truth
│   ├── scripts/              # Phase 1–9 schema and integration gates
│   ├── functions/            # Deno Edge Functions
│   └── seed*.sql             # Seed fixtures
├── docs/
│   ├── api/
│   ├── architecture/
│   └── runbooks/
├── scripts/                  # Bootstrap and database verification
├── .github/workflows/        # CI
├── package.json              # pnpm + Turborepo entry point
├── pnpm-workspace.yaml
├── pubspec.yaml              # Dart pub workspace + Melos config
└── turbo.json
```

See `docs/architecture/0001-repository-structure.md` for the layout decision and
`docs/architecture/0014-monorepo-conventions.md` for tooling conventions.

## Prerequisites

- Node.js **24+** and Corepack
- pnpm **12.15.0** (pinned through `packageManager`)
- Flutter **3.47+** with Dart **3.13+**
- Melos **7.8.0** (pinned; newer Melos requires a `cli_util` version that
  conflicts with `flutter_launcher_icons` 0.14.4)
- Docker
- Supabase CLI — use `npx --yes supabase`, or install it globally

The repository currently pins:

```text
Node 24
pnpm 12.15.0
Flutter 3.47.1 / Dart 3.13.1
Melos 7.8.0
```

## Bootstrap

```bash
# from the repo root
corepack enable --install-directory "$HOME/.local/bin" pnpm
export PATH="$HOME/.local/bin:$PATH"
corepack pnpm run setup    # installs Node deps and bootstraps Melos
```

If `melos` is not on your PATH:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Manual equivalent:

```bash
corepack pnpm install
dart pub global activate melos 7.8.0
melos bootstrap
```

## Run the apps

```bash
# Next.js web
corepack pnpm dev:web

# Flutter customer app (local Supabase stack)
cd apps/customer-mobile
flutter run --dart-define=ENV=dev

# Flutter driver app (local Supabase stack)
cd apps/driver-mobile
flutter run --dart-define=ENV=dev

# Admin console (local Supabase stack)
corepack pnpm --filter @safeshift/admin-console dev
```

The web app runs at <http://localhost:3000>; the admin console runs at
<http://localhost:3001>.

## Local database

```bash
corepack pnpm db:start
corepack pnpm db:reset
corepack pnpm db:verify
```

`db:reset` applies all 127 migrations and all local seed files, including the
local SMS sandbox. `db:verify` runs the Phase 1–9 schema gates in order and
fails on the first `FAIL`. The Phase 8 and Phase 9 live integration gates run
separately:

```bash
supabase/scripts/verify-phase-8-integration.sh
supabase/scripts/verify-phase-9-functions.sh
supabase/scripts/verify-phase-9-integration.sh
```

If the `supabase` binary is not installed, the root scripts use `npx --yes
supabase`. To run the gates manually:

```bash
docker exec -i supabase_db_safeshift psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < supabase/scripts/verify-phase-6-schema.sql
```

## Hosted admin accounts

The admin console (`apps/admin-console`) signs in with **email + password** and
then calls `public.admin_console_role()`. That RPC only returns a role when
the profile has an active row in `public.admin_roles`, so a superuser needs
three pieces, not one:

| Piece                | Change                                               |
| -------------------- | ---------------------------------------------------- |
| `auth.users`         | email + password, email confirmed                    |
| `public.profiles`    | `primary_role = 'admin'`, `is_active = true`         |
| `public.admin_roles` | `role_name = 'super_admin'`, global scope, no expiry |

`supabase/scripts/create-superuser.sh` does all of that in one command, then
verifies the account can actually sign in and hold admin permissions.

### 1. Make sure the credentials are in place

The script reads `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and
`SUPABASE_ANON_KEY` from the canonical credential file, so if that file is
already filled in there is nothing to export:

```bash
# supabase/functions/.env.local — server-only section
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-or-secret-key>
SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

If you would rather not put the key in a file, export it for the one command:

```bash
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service-role-or-secret-key>"
export SUPABASE_ANON_KEY="<anon-or-publishable-key>"
```

Get the service role key from the dashboard (**Project Settings → API
Keys → service_role**), or with:

```bash
npx --yes supabase projects api-keys --project-ref <project-ref>
```

### 2. Inspect first

```bash
supabase/scripts/create-superuser.sh --email admin@safeshift.app --dry-run
```

This validates the key, checks the project is reachable, and reports what it
would change — without changing anything.

### 3. Create the superuser

```bash
supabase/scripts/create-superuser.sh \
  --email admin@safeshift.app \
  --password 'Use-A-Long-Password-2026!' \
  --name 'Platform Admin'
```

Omit `--password` and the script prompts for it (twice, without echo).

Expected output:

```text
==> Pre-flight checks
  ok Service role key accepted (role: service_role)
  ok Project reachable at https://<project-ref>.supabase.co
  ok 94 admin permissions in the catalogue
==> Creating the auth user
  ok Created auth user (…)
==> Promoting the profile to primary_role = 'admin'
  ok Profile updated (primary_role = admin, is_active = true)
==> Granting the 'super_admin' role
  ok Granted 'super_admin' (global scope, no expiry)
==> Verifying the account can sign in and hold permissions
  ok Signed in successfully
  ok admin_console_role() = super_admin
  ok current_user_role() = admin
  ok has_permission('view_all_users') = true
```

### 4. Sign in

Use the same email and password on the admin console at
`http://localhost:3001/login`. The console reads the Supabase URL and anon key
from `apps/admin-console/.env.local`, which `scripts/sync-dart-defines.sh`
generates from the canonical file.

### Options

| Flag              | Effect                                                                 |
| ----------------- | ---------------------------------------------------------------------- |
| `--dry-run`       | Validate the credentials and report what would change.                 |
| `--role <name>`   | Grant a different `admin_roles.role_name` (default `super_admin`).     |
| `--phone <e164>`  | Also record a phone number on the profile.                             |
| `--country <iso>` | Country ISO code used when the profile has to be created by hand.      |
| `--revoke`        | Remove the role grant and demote the profile back to `customer`.       |
| `--delete-user`   | With `--revoke`, also delete the auth user.                            |
| `--no-audit`      | Skip the `admin_actions_log` entry, which keeps the account deletable. |

### Revoke an account

```bash
supabase/scripts/create-superuser.sh --email admin@safeshift.app --revoke --delete-user
```

### Troubleshooting

- **`This account has no active admin or fleet-owner role.`** — the grant is
  missing or expired. Run the script again, or check
  `select * from public.admin_roles where profile_id = <profile id>;`.
- **"The email already exists but the user could not be found."** — the script
  looks the user up through `public.profiles`, because the Admin API list
  endpoint (`GET /auth/v1/admin/users`) can fail with
  `500 Database error finding users` on a large auth schema. If the profile
  row is missing too, create the account with a different email.
- **"Could not delete the auth user: the audit trail still references it."** —
  `public.admin_actions_log.admin_profile_id` is `ON DELETE RESTRICT`, so an
  admin with audit history can never be deleted. The account is de-privileged
  instead. Pass `--no-audit` on creation to keep it deletable.
- **"The supplied key has role 'anon', not 'service_role'."** — you passed the
  anon or publishable key. The script needs the service role key.
- **"Target '…' is not a hosted Supabase project."** — a warning, not an
  error. It fires when the URL is not `*.supabase.co`, so you are running
  against the local stack.
- **`ENV=dev` pointing at a hosted project** — `scripts/sync-dart-defines.sh`
  refuses this, because `ENV=dev` makes the apps fall back to the local
  Supabase stack when no URL is supplied. Use `ENV=staging` or `ENV=prod`.
- **A server-only key in the client-safe section** —
  `scripts/sync-dart-defines.sh` refuses this too, so the service role key
  can never reach an app bundle.

Full reference: [hosted Supabase runbook](docs/runbooks/running-apps-and-hosted-supabase-testing.md).

## Catalogue icons

The vehicle categories and cargo types are database rows, and their artwork
lives in the public `catalog-icons` storage bucket. The artwork is committed
to the repository and uploaded with one command:

```bash
corepack pnpm catalog:icons:dry-run   # list the files
corepack pnpm catalog:icons           # upload them
```

The script reads the service role key from `supabase/functions/.env.local`
and never prints it. `vehicle_types.icon_url` and `cargo_types.icon_url`
hold the path inside the bucket (`vehicle/pickup.svg`), so the same row works
on the local stack, on staging, and in production — the apps resolve it
against their own Supabase project URL.

### Managing the catalogue

The admin console manages both catalogues at **Catalogue** (`/catalog`),
under the _Marketplace_ group in the sidebar: add a row, edit it, activate or
deactivate it, and delete it while nothing references it yet.

Nothing is hard-coded in the mobile apps, so a row that is not in the
database is a row the apps never show. Deactivating every row empties the
booking flow; an empty catalogue shows an explanation rather than a blank
screen.

To add a vehicle type or cargo type, add the row, add the SVG under
`supabase/storage/catalog-icons/`, and upload it. See
[the Phase 2 architecture note](docs/architecture/0009-phase-2-verification-vehicles-cargo-fleets.md).

## Workspace commands

| Command                         | Purpose                                          |
| ------------------------------- | ------------------------------------------------ |
| `corepack pnpm dev`             | Run all persistent JS/TS dev tasks               |
| `corepack pnpm build`           | Build shared types and web                       |
| `corepack pnpm typecheck`       | Typecheck all TypeScript packages                |
| `corepack pnpm lint`            | Lint all TypeScript packages                     |
| `corepack pnpm flutter:analyze` | Analyze all Flutter/Dart packages                |
| `corepack pnpm flutter:test`    | Test all Flutter/Dart packages                   |
| `corepack pnpm flutter:format`  | Format all Dart source                           |
| `corepack pnpm db:types`        | Regenerate Supabase TypeScript types             |
| `corepack pnpm catalog:icons`   | Upload the catalogue icons to Supabase Storage   |
| `corepack pnpm check`           | Typecheck, lint, build, Flutter analyze and test |

## Environment

Never commit real secrets.

```bash
cp .env.example .env
cp apps/web/.env.example apps/web/.env.local
```

### One credential file

`supabase/functions/.env.local` is the **single source of truth** for every
credential in the repository. It has two sections:

| Section     | Contains                                                            | Used by                             |
| ----------- | ------------------------------------------------------------------- | ----------------------------------- |
| Client-safe | Supabase URL + publishable key, Google Maps key, Firebase config    | mobile apps, web app, admin console |
| Server-only | Supabase service role key, shared gates, payment/SMS/email/FCM keys | Edge Functions only                 |

The client-side files are **generated** from the client-safe section, so the
service role key can never end up in an app bundle:

```bash
scripts/sync-dart-defines.sh          # regenerate
scripts/sync-dart-defines.sh --check  # fail if anything is out of date
```

It writes `apps/*/dart_defines.local.json`, `apps/*/.env.local`,
`apps/*/.env.hosted-test` and `apps/admin-console/.env.local`. The script
refuses to run if the anon key is actually a service role key, if `ENV=dev`
points at a hosted project, or if a server-only key appears in the
client-safe section.

Build the apps against the generated file:

```bash
cd apps/customer-mobile
flutter run --dart-define-from-file=dart_defines.local.json
```

- Flutter `.env.example` files are documentation only; pass the values with
  `--dart-define`. They are not read at runtime. For example:
  `flutter run --dart-define=ENV=dev`.
- Browser-safe values only use `NEXT_PUBLIC_*`.
- The Supabase `service_role` key is server-only and belongs in Supabase Vault or
  Edge Function secrets.
- Provider keys for FCM, Beem, Resend, Selcom, and Flutterwave remain server
  secrets. Mobile builds receive only public Supabase/Firebase client values
  through `--dart-define`.
- Staging is a separate Supabase project seeded with configuration only:
  `supabase/seed-staging.sql`.

## Google Maps server key

The Google Cloud credential named **Maps Platform API key** is the API key.
There is no separate “server key” object. Use that key for the SafeShift server:

1. In Google Cloud Console, enable **Geocoding API** and **Routes API**.
2. Open **APIs & Services → Credentials → Maps Platform API key**.
3. Set **Application restrictions** to **None**.
4. If you restrict the key by API, select **Geocoding API** and **Routes API**.
5. Copy the key.

`Maps Platform API key` is only the credential name; it can call any enabled
Maps Platform API. The API restriction list shows only APIs that are already
enabled in the project. If **Geocoding API** or **Routes API** is missing from
that list, enable it first in **APIs & Services → Library**, then reopen the key.
You can also leave the key unrestricted while testing and restrict it afterward.

Run the commands below from the repository root. They use the local-only
`apps/customer-mobile/.env.hosted-test` file for the hosted test project. The
key is written to `supabase/functions/.env.local`, which is gitignored, and to
the hosted Edge Function secrets. No real secret is committed.

Load the hosted test project and prompt for the server key:

```bash
export TEST_SUPABASE_URL="$(sed -n 's/^SUPABASE_URL=//p' apps/customer-mobile/.env.hosted-test)"
export TEST_PROJECT_REF="$(printf '%s' "$TEST_SUPABASE_URL" | sed -E 's#^https://([^.]+)\.supabase\.co/?$#\1#')"
export TEST_ANON_KEY="$(sed -n 's/^SUPABASE_ANON_KEY=//p' apps/customer-mobile/.env.hosted-test)"

printf 'Google Maps server key: '
read -rs GOOGLE_MAPS_API_KEY
printf '\n'
```

Test **Geocoding API**. Stop if the status is not `OK`:

```bash
printf 'Geocoding API: '
curl -sS --get 'https://maps.googleapis.com/maps/api/geocode/json' \
  --data-urlencode 'address=Kariakoo Market, Dar es Salaam' \
  --data-urlencode "key=$GOOGLE_MAPS_API_KEY" |
python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("status"), "|", (d.get("results") or [{}])[0].get("formatted_address", ""))
raise SystemExit(0 if d.get("status") == "OK" else 1)
'
```

Test **Routes API**. Stop if the condition is not `ROUTE_EXISTS`:

```bash
printf 'Routes API: '
curl -sS -X POST 'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix' \
  -H 'Content-Type: application/json' \
  -H "X-Goog-Api-Key: $GOOGLE_MAPS_API_KEY" \
  -H 'X-Goog-FieldMask: originIndex,destinationIndex,duration,distanceMeters,status,condition' \
  -d '{"origins":[{"waypoint":{"location":{"latLng":{"latitude":-6.8180,"longitude":39.2700}}}}],"destinations":[{"waypoint":{"location":{"latLng":{"latitude":-6.7750,"longitude":39.2250}}}}],"travelMode":"DRIVE","routingPreference":"TRAFFIC_AWARE"}' |
python3 -c '
import json, sys
d = json.load(sys.stdin)
if isinstance(d, dict):
    print(d)
    raise SystemExit(1)
e = d[0] if d else {}
print(e.get("condition"), "|", e.get("distanceMeters"), "|", e.get("duration"))
raise SystemExit(0 if e.get("condition") == "ROUTE_EXISTS" else 1)
'
```

Store the key locally and in the hosted test project, then deploy the Maps
functions:

```bash
printf 'GOOGLE_MAPS_API_KEY=%s\n' "$GOOGLE_MAPS_API_KEY" > supabase/functions/.env.local
npx --yes supabase secrets set --project-ref "$TEST_PROJECT_REF" \
  --env-file supabase/functions/.env.local
npx --yes supabase functions deploy maps-geocode --project-ref "$TEST_PROJECT_REF"
npx --yes supabase functions deploy maps-distance --project-ref "$TEST_PROJECT_REF"
npx --yes supabase functions deploy maps-route --project-ref "$TEST_PROJECT_REF"
unset GOOGLE_MAPS_API_KEY
```

Test the deployed functions with the hosted test OTP user. This uses the test
phone and Test OTP configured for the hosted test project only:

```bash
USER_JWT="$(curl -sS -X POST "$TEST_SUPABASE_URL/auth/v1/verify" \
  -H "apikey: $TEST_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"sms","phone":"+255712345678","token":"123456"}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')"

if [ -z "$USER_JWT" ]; then
  echo 'No JWT returned. Check the hosted Test OTP configuration.'
else
  curl -sS -X POST "$TEST_SUPABASE_URL/functions/v1/maps-geocode" \
    -H "apikey: $TEST_ANON_KEY" \
    -H "Authorization: Bearer $USER_JWT" \
    -H "Content-Type: application/json" \
    -d '{"address":"Kariakoo Market, Dar es Salaam"}' | python3 -m json.tool

  curl -sS -X POST "$TEST_SUPABASE_URL/functions/v1/maps-distance" \
    -H "apikey: $TEST_ANON_KEY" \
    -H "Authorization: Bearer $USER_JWT" \
    -H "Content-Type: application/json" \
    -d '{"origins":[{"lat":-6.8180,"lng":39.2700}],"destinations":[{"lat":-6.7750,"lng":39.2250}],"mode":"driving"}' | python3 -m json.tool
fi
```

Expected results:

- `maps-geocode` returns a formatted address.
- `maps-distance` returns `distance_km` and `duration_min`.
- `Google Maps API key is not configured` means the hosted secret was not set.
- `The provided API key is invalid` or `API_KEY_INVALID` means the key was
  copied incorrectly or deleted. Copy it again from Google Cloud Credentials.
- `REQUEST_DENIED` or `PERMISSION_DENIED` means billing, API enablement, or key
  restrictions are wrong.

Clean up the shell variables:

```bash
unset USER_JWT TEST_ANON_KEY TEST_SUPABASE_URL TEST_PROJECT_REF
```

Use a **separate mobile key** later for Android/iOS. Do not put this server key
in a Flutter app or browser. See
`docs/runbooks/running-apps-and-hosted-supabase-testing.md` §8 for mobile key
placement.

## Shared code rules

- `packages/shared-types` is the contract between Postgres, Edge Functions, and
  web. Regenerate it with `pnpm db:types` after schema changes.
- `packages/shared-flutter` holds only cross-app design tokens, formatters,
  domain primitives, and client helpers. App-specific widgets stay in the apps.
- Apps must not import from another app. Shared code goes through `packages/`.
- `supabase/functions` is the only place service-role code runs.
- Migrations are append-only; never edit an applied migration in a deployed
  environment.

## CI

`.github/workflows/ci.yml` runs three jobs:

1. Node workspace — frozen install, typecheck, lint, build.
2. Flutter workspace — Melos bootstrap, analyze, test.
3. Database gates — Supabase start, reset, Phase 1–9 schema verification, and
   the Phase 8 live integration script.

## Documentation

- `docs/architecture/0001-repository-structure.md` — monorepo layout
- `docs/architecture/0002-database-schema.md` — schema design
- `docs/architecture/0003-rls-policies.md` — access model
- `docs/architecture/0004-environments.md` — environments and secrets
- `docs/architecture/0005-security-compliance-baseline.md` — security baseline
- `docs/architecture/0008`–`0013` — Phase 1–6 design records
- `docs/architecture/0014-monorepo-conventions.md` — workspace tooling
- `docs/architecture/0015`–`0016` — Phase 7 integration and Edge Functions
- `docs/architecture/0016-phase-9-remaining-flows.md` — Phase 9 marketplace flows
- `docs/architecture/0017-phase-8-client-integration.md` — Phase 8 mobile clients
- `docs/runbooks/phase-8-staging-and-qa.md` — staging setup and manual QA
- `docs/runbooks/running-apps-and-hosted-supabase-testing.md` — run all apps and
  test against a hosted Supabase test project

## License

See `LICENSE`.
