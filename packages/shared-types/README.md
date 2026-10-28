# shared-types

Shared TypeScript contracts for `apps/web`, `supabase/functions`, and any future
TypeScript service.

## Contents

- `database.generated.ts` — Supabase-generated types for the `public` schema
- `enums.ts` — typed constants derived from the generated database enums
- `jobs.ts` — job lifecycle transitions and terminal states
- `realtime.ts` — approved Realtime tables and event envelopes
- `api.ts` — API result, pagination, and money envelopes

## Usage

```ts
import { JOB_STATUSES, type JobStatus } from '@safeshift/shared-types';

const status: JobStatus = 'in_transit';
```

The package is consumed through the pnpm workspace:

```json
{
  "dependencies": {
    "@safeshift/shared-types": "workspace:*"
  }
}
```

The package builds to `dist/` and exports the compiled ESM entry point. Turborepo
builds `@safeshift/shared-types` before the web app and before typechecking, so
the generated declarations are always available.

## Regenerate database types

With the local Supabase stack running:

```bash
pnpm db:types
```

The generated file is intentionally excluded from Prettier. Commit it whenever
the schema changes so type changes are reviewed with the migration.

## Rules

- Do not hand-edit `database.generated.ts`.
- Keep transport contracts here, not in app code.
- Do not import React, Next.js, Flutter, or Supabase client code into this package.
