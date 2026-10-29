# SafeShift Admin Console

Next.js 16 App Router console for operations, verification, support, finance,
fleet owners, and trust & safety.

## Local development

1. Start the local database: `npx supabase start`
2. Copy `.env.example` to `.env.local` and set the local anon key.
3. Run `pnpm --filter @safeshift/admin-console dev`.
4. Sign in with a seeded admin, for example `superadmin@safeshift.local` /
   `SafeshiftDev!2026`.

There is no self-registration. Provision admin users in Supabase Studio or with
the CLI and grant a row in `public.admin_roles`. Fleet owners get the narrow
`fleet_owner` role and only see their own fleet.

The service-role key is never read by this app. Server components and actions
use the signed-in admin's session so RLS and permission checks remain in force.
