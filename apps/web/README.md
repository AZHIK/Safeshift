# Next.js — SafeShift Web (customer web + business portal + admin console)

> **Sprint 1 placeholder.** No Next.js project is scaffolded yet.

This folder will hold the Next.js **App Router** project serving three surfaces:

- **Customer web** — booking, quotes, tracking, payments, receipts
- **Business portal** — business accounts, repeat bookings, invoicing views
- **Admin console** — verification queues, job oversight, alert resolution,
  pricing-config management (all writes via server-side service-role calls)

Shared TypeScript types will live in `packages/shared-types/`.

Scaffolding (`create-next-app`, App Router, Vercel project wiring) happens in
Sprint 2 or later — not in Sprint 1.
