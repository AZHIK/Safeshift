# Flutter — SafeShift Driver App

> **Sprint 1 placeholder.** No Flutter project is scaffolded yet.

This folder will hold the driver-facing Flutter application:

- Availability toggle and operating-zone / service-hours management
- Job offers, accept / decline, heading-to-pickup → delivered state advances
- Navigation handoff (Google Maps Platform)
- Foreground location updates during active jobs
- Earnings views, verification status, document re-upload
- Push notifications (FCM), SOS affordance (server-recorded `trip_alerts`)

Shared code (design tokens, models, Supabase client) will live in
`packages/shared-flutter/` and be consumed by path dependency.

Scaffolding (`flutter create`, flavors for development / staging / production)
happens in Sprint 2 or later — not in Sprint 1.
