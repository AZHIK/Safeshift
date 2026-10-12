# Flutter — SafeShift Customer App

> **Sprint 1 placeholder.** No Flutter project is scaffolded yet.

This folder will hold the customer-facing Flutter application:

- Job booking (pickup, destination, cargo details, scheduling)
- Transparent quotes and mobile-money / card payment
- Live GPS tracking of the matched driver
- Push notifications (FCM), SMS/OTP via Beem Africa (server-sent)
- Digital proof of delivery (photos, signature, OTP confirmation views)
- Ratings, trip history, support

Shared code (design tokens, models, Supabase client) will live in
`packages/shared-flutter/` and be consumed by path dependency.

Scaffolding (`flutter create`, flavors for development / staging / production)
happens in Sprint 2 or later — not in Sprint 1.
