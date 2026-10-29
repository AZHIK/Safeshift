# Strategy 0004 — Environments

- **Status:** Accepted (Sprint 1)
- **Date:** 2026-10-07

SafeShift runs **three environments**. Same schema and RLS model everywhere;
they differ in data, domains, build flavors, and safeguards.

---

## 1. Development

- **Supabase:** local Supabase project on each developer's machine
  (`supabase start`). Source of schema truth is `supabase/migrations/`
  (first migrations land in Sprint 2).
- **Web:** local Next.js dev build (`npm run dev`) — from Sprint 2 onward.
- **Mobile:** local Flutter dev builds (development flavor) — from Sprint 2 onward.
- **Used for:** feature development and unit testing.
- **Data:** throwaway / seeded fixtures only. Never production data, never
  real phone numbers or licence documents.

## 2. Staging

- **Supabase:** a dedicated Supabase staging project (hosted, separate from
  production; its own Auth, Storage, and Vault).
- **Web:** a Vercel preview/staging domain (non-production).
- **Mobile:** Flutter staging flavor builds (distinct bundle ID / package
  name and app icon so staging cannot be mistaken for production).
- **Used for:** Sprint 9 system testing, UAT, and regression. Staging mirrors
  production configuration (RLS, key restrictions, webhook endpoints) with
  sandbox payment providers.
- **Data:** configuration-only seed (`supabase/seed-staging.sql`). UAT accounts
  are created through the Auth Admin API; demo fixtures from the local seed
  files are never copied into staging. No live pilot customers.

## 3. Production

- **Supabase:** a dedicated Supabase project on the **Pro plan with
  point-in-time recovery (PITR) enabled**.
- **Web:** Vercel production domain.
- **Mobile:** Flutter production flavor builds (store-signed).
- **Used for:** live Dar es Salaam pilot from Sprint 10 (50–100 verified
  vehicles, Stage 1 corridor).
- **Data:** real customer/driver data under the compliance baseline in
  `0005-security-compliance-baseline.md` (PDPC registration, data
  minimization, audit logging).

Promotion is always development → staging → production. Hotfixes still pass
through staging verification. Migrations run in order in every environment;
no hand-edits to staging/production databases.

---

## Secrets policy

- **All API keys and secrets live only in** Supabase environment variables
  (Edge Functions), Vercel environment variables (web), and Supabase Vault
  (database-side secrets). **Never in the repository** — no `.env` files, no
  keys in code, docs, or screenshots.
- `.gitignore` excludes `.env*` files; PRs touching env templates must use
  redacted `.env.example` files only.
- The **Supabase service-role key never leaves the server**: it is injected
  into Edge Functions as an environment variable and is never shipped to a
  mobile or web client (restated from `0003-rls-policies.md` — non-negotiable).
- Key rotation path (detail to become a runbook): rotate in the provider
  console → update Supabase/Vercel env → redeploy functions/web → verify
  staging → verify production.

## Google Maps API key rule

- **Each API key is restricted by platform:** Android key by package name
  (per flavor: dev / staging / production), iOS key by bundle ID, web key by
  HTTP referrer (local / staging domain / production domain). Unrestricted
  keys are forbidden.
- APIs enabled per key on a least-privilege basis (maps, routes, places —
  only what each surface uses).
- A **hard monthly budget alert is set in Google Cloud Console** (billing
  alert + quota caps) from the first key creation, before any pilot traffic.
- Staging and production use separate keys so a leak or quota event in one
  cannot take down the other.

## Supabase service-role rule (restated)

The service-role key bypasses RLS and therefore lives **only inside Edge
Functions**. It is never embedded in Flutter or Next.js client code, never
committed, and never shared with testers. Any admin operation needed by the
web admin console or mobile apps is exposed as an authenticated Edge Function
endpoint that re-checks the caller's role.
