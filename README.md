# SafeShift

A digital logistics marketplace launching in Dar es Salaam, Tanzania — connecting customers
with verified drivers and trucks for moves, deliveries, and commercial cargo.

Transparent pricing · Identity verification · Live GPS tracking ·
Digital proof of delivery · Structured protection model.

Pilot: Stage 1 corridor, Dar es Salaam — 50–100 verified vehicles.

> **Sprint 1 status (5–9 Oct 2026): foundation and documentation only.**
> No application code, no SQL migrations, no Edge Functions, no UI.
> App scaffolding (Flutter / Next.js) begins in Sprint 2.

## Core stack (non-negotiable)

- **Mobile:** Flutter (two apps — Customer and Driver)
- **Web:** Next.js (App Router) — customer web + business portal + admin console
- **Backend:** Supabase (Postgres + PostGIS, Auth, Storage, Realtime, Edge Functions)
- **Maps:** Google Maps Platform
- **Payments:** Selcom or Flutterwave (mobile money) + Flutterwave/Stripe (cards)
- **Messaging:** Firebase Cloud Messaging (push), Beem Africa (SMS/OTP), Resend (email)
- **Caching/Jobs:** Upstash Redis, Upstash QStash, Supabase pg_cron
- **Observability:** Sentry, BetterStack, PostHog
- **CI/CD:** GitHub Actions, Vercel, Codemagic + Fastlane
- **Edge/DNS:** Cloudflare

## Guiding principles

1. **Managed over self-hosted** — every layer is managed or serverless.
2. **One core data layer** — Supabase Postgres (with PostGIS) is the single source of truth.
3. **Config-driven growth** — city, pricing, and vehicle rules live in configuration tables,
   never hardcoded. Multi-city replication is a schema property from day one.
4. **Security by default** — Row Level Security on every table, restricted API keys,
   centralized secrets from day one. The service-role key never leaves the server.
5. **Cost scales with usage** — pay-as-you-go providers throughout.

## Repository structure

```text
safeshift/
├── apps/
│   ├── customer-mobile/      # Flutter — Customer app (scaffolded in Sprint 2+)
│   ├── driver-mobile/        # Flutter — Driver app (scaffolded in Sprint 2+)
│   └── web/                  # Next.js App Router — customer web + business portal + admin console
├── packages/
│   ├── shared-flutter/       # Shared Flutter package (design tokens, models, Supabase client)
│   └── shared-types/         # Shared TypeScript types
├── supabase/
│   ├── migrations/           # SQL migrations (first migrations land in Sprint 2)
│   └── functions/            # Edge Functions (first functions land after Sprint 2)
├── docs/
│   ├── api/                  # API documentation
│   ├── runbooks/             # Operational guides
│   └── architecture/         # Architecture decision records + design documents
├── .github/
│   └── workflows/            # CI/CD pipelines
├── .gitignore
├── README.md
└── LICENSE
```

See `docs/architecture/0001-repository-structure.md` for why this monorepo was chosen.

| Path | Purpose |
| ---- | ------- |
| `apps/customer-mobile/` | Customer Flutter app (booking, tracking, payments, proof of delivery) |
| `apps/driver-mobile/` | Driver Flutter app (availability, job offers, navigation, earnings) |
| `apps/web/` | Next.js App Router project: customer web, business portal, admin console |
| `packages/shared-flutter/` | Shared Dart code: design tokens, models, Supabase client helpers |
| `packages/shared-types/` | Shared TypeScript types used by web and Edge Functions |
| `supabase/migrations/` | Versioned SQL migrations — source of truth for schema evolution |
| `supabase/functions/` | Server-only Edge Functions (service-role usage confined here) |
| `docs/api/` | API contracts and integration notes |
| `docs/runbooks/` | Operational guides (incidents, deploys, key rotation) |
| `docs/architecture/` | ADRs and design docs (0001–0005 written in Sprint 1) |

## Key design documents (Sprint 1)

- `docs/architecture/0001-repository-structure.md` — monorepo ADR
- `docs/architecture/0002-database-schema.md` — full database design (reference for Sprint 2 migrations)
- `docs/architecture/0003-rls-policies.md` — who can see and change what
- `docs/architecture/0004-environments.md` — development / staging / production + secrets policy
- `docs/architecture/0005-security-compliance-baseline.md` — security baseline, compliance checklist, auth approach

## Getting started for a new developer

> Sprint 1 provides structure and documentation only. Steps marked *(coming in Sprint 2)*
> have no runnable project behind them yet.

1. **Clone**

   ```bash
   git clone <repo-url> safeshift
   cd safeshift
   ```

2. **Prerequisites (coming in Sprint 2)** — exact versions will be pinned then:
   - Flutter SDK + Dart
   - Node.js LTS + npm
   - Supabase CLI
   - Git

3. **Install dependencies (coming in Sprint 2)**

   ```bash
   # Flutter apps — not scaffolded yet
   # (cd apps/customer-mobile && flutter pub get)
   # (cd apps/driver-mobile && flutter pub get)

   # Web + shared types — not scaffolded yet
   # npm install
   ```

4. **Run local Supabase (coming in Sprint 2)**

   ```bash
   # supabase init   # already configured from Sprint 2 onward
   # supabase start
   # supabase db reset  # applies supabase/migrations/
   ```

   Sprint 1 intentionally contains **no migrations**. The schema reference is
   `docs/architecture/0002-database-schema.md`; SQL is written in Sprint 2.

5. **Environment variables** — never committed. Copy the example template
   (provided from Sprint 2 onward) to `.env.local` / `--env-file` equivalents:

   ```bash
   # cp .env.example .env.local   # (coming in Sprint 2)
   ```

   All keys live only in Supabase / Vercel environment stores and Supabase Vault.
   See `docs/architecture/0004-environments.md`.

6. **Run the apps (coming in Sprint 2)**

   ```bash
   # Flutter: flutter run --flavor development
   # Web:     npm run dev
   ```

## Sprint boundaries

- **Sprint 1 (this sprint):** structure + documentation only. No code, no SQL,
  no Edge Functions, no UI, no packages installed, no secrets.
- **Sprint 2 onward:** schema migrations, auth, app scaffolding — per the MVP plan.

## License

See `LICENSE`.
