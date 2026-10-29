# SafeShift Customer App

Customer-facing mobile app for **SafeShift** — a digital logistics marketplace
connecting customers in Dar es Salaam with verified drivers and trucks for
moves, deliveries, and commercial cargo.

This app lives in the SafeShift monorepo at `apps/customer-mobile/` alongside
the Driver app (`apps/driver-mobile/`) and web (`apps/web/`).

## Phase 8

The app is connected to Supabase through `supabase_flutter` and Riverpod:
phone OTP auth, quote and job creation, dispatch matching, live tracking,
delivery codes, history, storage uploads, push-token registration, and
`safeshift://` / `https://safeshift.app` deep links. Hive provides cache-first
offline rendering. Set `MOCK_MODE=true` to open the design-only mock flows.

## Stack

Flutter (iOS + Android) with Riverpod, GoRouter, Supabase, Hive, Freezed +
json_serializable, flutter_hooks, cached_network_image, shimmer,
flutter_secure_storage, connectivity_plus, google_maps_flutter, geolocator,
image_picker, camera, Firebase Messaging, flutter_local_notifications,
flutter_native_splash, flutter_launcher_icons, intl, and logger.

## Getting started

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run --dart-define=ENV=dev
```

Configuration is compile-time through `--dart-define`; the app does not read
`.env` files at runtime. See
`docs/architecture/0017-phase-8-client-integration.md` for staging and
production launch commands.

**Note:** download the Poppins font files into `assets/fonts/` before building
— see the `fonts` section in `pubspec.yaml`.

## Project layout

Clean-architecture features under `lib/features/` (auth, home, ride, tracking,
history, profile), shared primitives under `lib/core/`, and design-only mock
data under `lib/shared/mock/`.
