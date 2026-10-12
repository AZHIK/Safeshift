# ADR 0001 — Monorepo Repository Structure

- **Status:** Accepted
- **Date:** 2026-10-07 (Sprint 1)
- **Deciders:** Idea Owner (Marius Alex Isaay), Engineering Lead (Azaria Kilasi)
- **Scope:** Sprint 1 — foundation only. No app code, no migrations, no functions.

## Context

SafeShift ships five deployables from one data layer: two Flutter apps
(customer, driver), one Next.js web project (customer web + business portal +
admin console), Supabase migrations, and Supabase Edge Functions. The team is
small, the pilot is a single corridor in Dar es Salaam, and consistency
(design tokens, domain models, TypeScript types, pricing rules) matters more
than independent release cadences at this stage.

Options considered:

1. **Monorepo (chosen)** — one `safeshift` repo with `apps/`, `packages/`,
   `supabase/`, `docs/`, `.github/workflows/`.
2. **Polyrepo** — one repo per app plus one for backend.
3. **Hybrid** — mobile repos separate, web + backend together.

## Decision

Use a single `safeshift` monorepo with this exact top-level layout:

```text
safeshift/
├── apps/
│   ├── customer-mobile/      # Flutter — Customer app
│   ├── driver-mobile/        # Flutter — Driver app
│   └── web/                  # Next.js — customer web + business portal + admin console
├── packages/
│   ├── shared-flutter/       # Shared Flutter package (design tokens, models, Supabase client)
│   └── shared-types/         # Shared TypeScript types
├── supabase/
│   ├── migrations/           # SQL migrations
│   └── functions/            # Edge Functions
├── docs/
│   ├── api/
│   ├── runbooks/
│   └── architecture/
├── .github/
│   └── workflows/
├── .gitignore
├── README.md
└── LICENSE
```

Sprint 1 creates folders and documentation only. Flutter and Next.js
scaffolding happens in Sprint 2 onward.

## Rationale

- **One data-layer contract.** Schema (`0002`), RLS (`0003`), and shared types
  live next to every consumer, so a column rename is reviewed in one PR.
- **Shared code without publishing.** `shared-flutter` (tokens, models,
  Supabase client) and `shared-types` are consumed by path reference — no
  private package registry needed for a pre-seed team.
- **Atomic cross-cutting changes.** A job-status change touching Postgres,
  Edge Functions, Flutter models, and web types lands as one commit.
- **One CI surface.** GitHub Actions + Vercel + Codemagic/Fastlane all trigger
  from one repo with path-filtered workflows.
- **Matches the guiding principles:** one core data layer, config-driven
  growth, managed/serverless everything.

## Consequences

- **Positive:** single clone onboarding; shared lint/format config; unified
  audit trail for compliance (`audit_log` discipline starts with git history).
- **Negative:** CI must use path filters to stay fast; Flutter and web
  toolchains share a repo but need separate pipelines; access control is by
  branch policy, not repo boundary (admin console code is visible to all
  contributors — runtime access is still enforced by RLS + Auth).
- **Mitigations:** path-filtered workflows under `.github/workflows/`;
  per-app README placeholders state ownership; CODEOWNERS-style review
  discipline from Sprint 2.

## Alternatives rejected

- **Polyrepo:** multiplies secret stores, version-skew risk between
  mobile/web and the schema, and overhead the team cannot afford during a
  10-sprint MVP.
- **Hybrid:** saves little over a full monorepo while keeping the worst
  cross-repo coupling (schema ↔ mobile models).

## Notes

- `supabase/migrations/` is empty in Sprint 1 by design — SQL is written in
  Sprint 2 from `0002-database-schema.md`.
- `supabase/functions/` is empty in Sprint 1 — service-role code lives here
  from Sprint 2 onward and nowhere else.
