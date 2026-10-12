# Baseline 0005 — Security & Compliance Baseline

- **Status:** Accepted (Sprint 1)
- **Date:** 2026-10-07
- **Scope:** Baseline for the whole MVP. Technical items are enforced from
  Sprint 2; compliance items run in parallel with engineering, not in code.

---

## 1. Security baseline

- **RLS enabled on every table**, scoped to the authenticated user's role,
  per `0003-rls-policies.md`. Deny by default; no anonymous access in v1.
- **Service-role database access confined to Edge Functions only.**
  The service-role key (which bypasses RLS) is never shipped to a mobile or
  web client — non-negotiable (see `0003`, `0004`).
- **TLS in transit everywhere:** Supabase (Postgres/Auth/Storage/Realtime),
  Vercel, Edge Functions, and all provider APIs are HTTPS-only.
- **Postgres data encrypted at rest** (Supabase default); production adds
  point-in-time recovery (see `0004-environments.md`).
- **Google Maps API keys restricted by platform/referrer** (Android package
  name, iOS bundle ID, web HTTP referrer) with a hard monthly budget alert —
  see `0004-environments.md`.
- **Secrets stored only in Vercel and Supabase environment stores /
  Supabase Vault.** Nothing secret is committed to the repo; `.env*` files
  are gitignored.
- **Audit-log table records:** at minimum, verification approvals
  (driver/vehicle `pending → verified/rejected`), payout changes, admin
  overrides (status/payment/resolution changes), and pricing-config changes —
  each with actor, old/new values, and timestamp (see `0002`, §4.1).

## 2. Compliance checklist (worked in parallel, not in code)

| Item | Owner | Status |
| ---- | ----- | ------ |
| Tanzania PDPC data-controller/processor registration | Idea Owner | To be started by Idea Owner |
| Privacy-by-design review of data collection | Idea Owner + Engineering Lead | To be scheduled |
| LATRA touchpoints mapped for later sprints (tariffs, transport licensing surfaces) | Idea Owner | To be documented |
| Data minimization: only collect what the platform actually needs | Engineering (schema review) | Enforced in `0002` — every column justified; no speculative PII |

Notes:

- The schema in `0002-database-schema.md` is the data-minimization record:
  phone/email, licence and insurance docs, trip locations, and payment
  references are collected because booking, verification, safety, and
  reconciliation require them — nothing beyond that in v1.
- Regulatory tariff hooks (`pricing_config.is_regulated`,
  `pricing_config.regulatory_tariff`) exist so LATRA-mapped rules can land
  without schema changes.
- `audit_log` plus `jobs.scheduled/started/completed_at` and
  `job_evidence` give the dispute-resolution and regulator-inquiry trail.

## 3. Authentication approach

- **Phone OTP for drivers and most customers** (Beem Africa SMS/OTP,
  server-side via Supabase Auth + Edge Functions).
- **Email/password for business accounts** (business portal users).
- **Every API request authenticated:** clients call Supabase with the user
  JWT (anon key + Auth); privileged operations go through Edge Functions
  that verify the JWT and the caller's `profiles.role` before touching the
  service role. No anonymous data access; no long-lived custom tokens in v1.
