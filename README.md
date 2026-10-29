# SafeShift

A digital logistics marketplace launching in Dar es Salaam, Tanzania — connecting
customers with verified drivers and trucks for moves, deliveries, and commercial
cargo.

Transparent pricing · Identity verification · Live GPS tracking · Digital proof
of delivery · Structured protection model.

Pilot: Stage 1 corridor, Dar es Salaam — 50–100 verified vehicles.

## Status

- Phase 1–8 database layer complete: 123 migrations, six local seed files, and
  schema gates for every phase.
- Latest verified gate results: Phase 1 `151 PASS`, Phase 2 `166 PASS`, Phase 3
  `150 PASS`, Phase 4 `154 PASS`, Phase 5 `81 PASS`, Phase 6 `154 PASS`, all
  with `0 FAIL`; Phase 7 and Phase 8 gates are run by `pnpm db:verify`.
- Flutter customer and driver apps are wired to Supabase: OTP auth, Riverpod
  data providers, Hive offline cache, Realtime/polling, Storage uploads,
  delivery OTP, push-token registration, and deep links.
- Phase 7 provider integrations and Edge Functions are implemented locally but
  not deployed. Phase 8 staging, real SMS/FCM, universal links, Maps, and
  payment-provider checks still require external credentials and devices.
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
│   ├── scripts/              # Phase 1–8 schema and integration gates
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
corepack pnpm setup        # installs Node deps and bootstraps Melos
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
```

The web app runs at <http://localhost:3000>.

## Local database

```bash
corepack pnpm db:start
corepack pnpm db:reset
corepack pnpm db:verify
```

`db:reset` applies all 123 migrations and all six local seed files. `db:verify`
runs the Phase 1–8 schema gates in order and fails on the first `FAIL`. The
Phase 8 live integration gate runs separately:

```bash
supabase/scripts/verify-phase-8-integration.sh
```

If the `supabase` binary is not installed, the root scripts use `npx --yes
supabase`. To run the gates manually:

```bash
docker exec -i supabase_db_safeshift psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < supabase/scripts/verify-phase-6-schema.sql
```

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
| `corepack pnpm check`           | Typecheck, lint, build, Flutter analyze and test |

## Environment

Never commit real secrets.

```bash
cp .env.example .env
cp apps/web/.env.example apps/web/.env.local
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
3. Database gates — Supabase start, reset, Phase 1–8 verification, and the
   Phase 8 live integration script.

## Documentation

- `docs/architecture/0001-repository-structure.md` — monorepo layout
- `docs/architecture/0002-database-schema.md` — schema design
- `docs/architecture/0003-rls-policies.md` — access model
- `docs/architecture/0004-environments.md` — environments and secrets
- `docs/architecture/0005-security-compliance-baseline.md` — security baseline
- `docs/architecture/0008`–`0013` — Phase 1–6 design records
- `docs/architecture/0014-monorepo-conventions.md` — workspace tooling
- `docs/architecture/0015`–`0016` — Phase 7 integration and Edge Functions
- `docs/architecture/0017-phase-8-client-integration.md` — Phase 8 mobile clients
- `docs/runbooks/phase-8-staging-and-qa.md` — staging setup and manual QA

## License

See `LICENSE`.
