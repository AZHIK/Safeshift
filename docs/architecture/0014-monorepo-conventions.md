# ADR 0014 — Monorepo Tooling and Workspace Conventions

- **Status:** Accepted
- **Date:** 2026-10-28
- **Deciders:** Engineering
- **Supersedes:** none
- **Related:** ADR 0001 (monorepo repository structure)

## Context

ADR 0001 chose a single repository, but the initial layout was directory-only:
there was no root JavaScript workspace, no Dart workspace manager, and the web
and shared packages were placeholders. Phase 6 is now complete, Phase 7 adds
Next.js, Edge Functions, provider integrations, and shared contracts, so the
repository needs executable workspace tooling rather than folders alone.

The stack spans two toolchains:

- TypeScript/JavaScript: Next.js web, Edge Functions, shared types, future
  workers.
- Dart/Flutter: customer app, driver app, shared Flutter package.

A single tool cannot manage both well. The decision is to use the best native
workspace manager for each toolchain and keep the Supabase backend at the repo
root.

## Decision

### JavaScript/TypeScript: pnpm + Turborepo

- `pnpm` owns `apps/web` and `packages/*`.
- `pnpm-workspace.yaml` is the workspace boundary.
- `turbo.json` defines `build`, `dev`, `lint`, `typecheck`, `test`, and `clean`.
- Root `package.json` is private and pins `pnpm@12.15.0` through `packageManager`.
- Workspace packages use the `@safeshift/*` scope.
- Internal dependencies use `workspace:*`.

### Dart/Flutter: Pub Workspaces + Melos

- Root `pubspec.yaml` defines the Dart pub workspace and owns
  `apps/customer-mobile`, `apps/driver-mobile`, and `packages/shared-flutter`.
- Every Dart package sets `resolution: workspace`.
- Apps consume the shared package through a path dependency.
- Melos scripts are the canonical entry points for `analyze`, `test`, and
  `format`.
- `melos bootstrap` is the Flutter/Dart equivalent of `pnpm install`.
- Melos is pinned to `7.8.0`: newer releases require `cli_util >=0.5.0`, which
  conflicts with `flutter_launcher_icons` 0.14.4.

### Supabase: root `supabase/`

- Migrations, seeds, gates, Edge Functions, and local config stay in
  `supabase/`.
- The Supabase CLI expects this layout. Moving it under `apps/` adds path
  rewriting risk for every script and gate with no isolation benefit.
- Edge Functions are Deno, not pnpm packages. They import shared contracts
  through `supabase/functions/deno.json`.

## Workspace map

```text
safeshift/
├── apps/
│   ├── customer-mobile/      # Flutter, Melos
│   ├── driver-mobile/        # Flutter, Melos
│   └── web/                  # Next.js, pnpm
├── packages/
│   ├── shared-flutter/       # Dart, Melos
│   └── shared-types/         # TypeScript, pnpm
├── supabase/                 # SQL, seeds, gates, Edge Functions
├── scripts/                  # bootstrap and database gate scripts
├── docs/
├── package.json              # pnpm + Turborepo entry point
├── pnpm-workspace.yaml
├── pubspec.yaml              # Dart pub workspace + Melos config
└── turbo.json
```

## Root commands

| Command                | Purpose                                          |
| ---------------------- | ------------------------------------------------ |
| `pnpm setup`           | Install pnpm workspace and bootstrap Melos       |
| `pnpm dev`             | Run all persistent JS/TS dev tasks               |
| `pnpm dev:web`         | Run only the Next.js app                         |
| `pnpm build`           | Build shared types and web through Turborepo     |
| `pnpm typecheck`       | Typecheck all TypeScript packages                |
| `pnpm lint`            | Lint all JavaScript/TypeScript packages          |
| `pnpm flutter:analyze` | Analyze all Flutter/Dart packages                |
| `pnpm flutter:test`    | Test all Flutter/Dart packages                   |
| `pnpm db:start`        | Start local Supabase                             |
| `pnpm db:reset`        | Apply migrations and seeds                       |
| `pnpm db:types`        | Regenerate Supabase TypeScript types             |
| `pnpm db:verify`       | Run Phase 1–6 schema gates                       |
| `pnpm check`           | Typecheck, lint, build, Flutter analyze and test |

## Environment conventions

- Root `.env.example` documents backend and provider variables.
- `apps/web/.env.example` documents browser-safe `NEXT_PUBLIC_*` values only.
- Flutter apps keep their own `.env.example` files.
- The `service_role` key must never be exposed to Flutter or browser code.
- Provider secrets live in Supabase Vault or the deployment platform, never in
  git.

## CI

`.github/workflows/ci.yml` runs three independent jobs:

1. **Node workspace** — frozen pnpm install, typecheck, lint, build.
2. **Flutter workspace** — Melos bootstrap, analyze, test.
3. **Database gates** — Supabase start, reset, and Phase 1–6 verification.

A final job fails the workflow if any dependency job fails or is cancelled.

## Consequences

- **Positive:** one clone, one lockfile per ecosystem, one task graph, shared
  contracts, and a single CI surface.
- **Positive:** Supabase paths and Phase 1–6 gates remain unchanged.
- **Negative:** contributors need Node 24, pnpm 12, Flutter 3.47, Dart 3.13,
  Docker, and Melos 7.8.0.
- **Negative:** Melos is pinned until `flutter_launcher_icons` relaxes its
  `cli_util` constraint.
- **Mitigation:** `pnpm setup` checks prerequisites and installs workspace
  dependencies; `README.md` lists exact versions.

## Alternatives rejected

- **npm workspaces:** works, but slower and lacks Turborepo's task graph and
  cache ergonomics for a multi-app TS workspace.
- **Nx:** powerful, but heavier than needed for one Next.js app and one shared
  TS package.
- **Melos for everything:** cannot manage Next.js or Edge Functions.
- **Move Supabase under `apps/backend`:** no isolation benefit and breaks the
  standard CLI layout.
