# Supabase Edge Functions

Server-only functions live here. They run on Deno and are deployed with the
Supabase CLI.

## Rules

- `service_role` and provider secrets never leave this directory or Supabase
  Vault.
- Import shared contracts from `@safeshift/shared-types` (mapped in `deno.json`).
- Every function must verify the caller JWT unless it is an explicitly public
  webhook endpoint.
- Webhook handlers must verify signatures and be idempotent before mutating
  money or job state.
- Log `service_role` PII reads through `public.log_data_access()`.

## Local workflow

```bash
pnpm build
pnpm db:start
pnpm dlx supabase functions serve
```

`pnpm build` emits `packages/shared-types/dist`, which `deno.json` maps to
`@safeshift/shared-types`. Rebuild after changing shared contracts.

Phase 7 adds the first production functions.
