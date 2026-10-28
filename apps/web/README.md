# SafeShift Web

Next.js App Router project for three surfaces:

- customer web
- business portal
- admin console

## Workspace

This app is the `@safeshift/web` package in the root pnpm workspace. It consumes
`@safeshift/shared-types` through `workspace:*`.

```bash
# from the repo root
corepack pnpm install
corepack pnpm dev:web
```

The app runs at <http://localhost:3000>.

## Environment

```bash
cp apps/web/.env.example apps/web/.env.local
```

Use the local Supabase URL and anon key printed by `pnpm db:start`. Never put the
`service_role` key in a `NEXT_PUBLIC_*` variable.

## Commands

```bash
corepack pnpm --filter @safeshift/web dev
corepack pnpm --filter @safeshift/web build
corepack pnpm --filter @safeshift/web typecheck
corepack pnpm --filter @safeshift/web lint
```

Server-side admin writes must go through Edge Functions. Do not ship the
service-role key to the browser.
