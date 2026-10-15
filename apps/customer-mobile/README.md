# SafeShift Customer App

Customer-facing mobile app for **SafeShift** — a digital logistics marketplace
connecting customers in Dar es Salaam with verified drivers and trucks for
moves, deliveries, and commercial cargo.

This app lives in the SafeShift monorepo at `apps/customer-mobile/` alongside
the Driver app (`apps/driver-mobile/`) and web (`apps/web/`).

> **Scaffold stage:** every screen is a placeholder, every model is a
> placeholder, and every provider is a placeholder. No real business logic,
> no backend connections, and no real UI yet. This skeleton prepares the
> codebase for mock UI development.

## Stack

Flutter (iOS + Android) with Riverpod, GoRouter, Dio, Freezed +
json_serializable, flutter_hooks, cached_network_image, shimmer,
flutter_secure_storage, connectivity_plus, google_maps_flutter, geolocator,
image_picker, camera, firebase_messaging, flutter_native_splash,
flutter_launcher_icons, intl, and logger.

## Getting started

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Copy `.env.example` to `.env` and fill in the keys (the real `.env` is
gitignored and must never be committed).

**Note:** download the Inter font files (Regular/Medium/Bold) into
`assets/fonts/` before building — see the `fonts` section in `pubspec.yaml`.

## Project layout

Clean-architecture features under `lib/features/` (auth, home, booking,
tracking, delivery, history, profile), shared primitives under `lib/core/`,
mock data under `lib/shared/mock/`, and localization source in `lib/l10n/`.
