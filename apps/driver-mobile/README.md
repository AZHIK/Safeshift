# SafeShift Driver App

Driver-facing Flutter application for the SafeShift logistics marketplace (Dar es Salaam).

## Phase 8

The app is connected to Supabase through `supabase_flutter` and Riverpod:
driver profile and registration detection, availability and location updates,
realtime job offers with polling fallback, status advancement, delivery-code
verification, earnings, trips, documents, vehicle, ratings, storage uploads,
push-token registration, and `safeshift://` / `https://safeshift.app` deep
links. Hive provides cache-first offline rendering. Set `MOCK_MODE=true` to
open the design-only mock flows.

## Key design rule: single screen

The driver job flow lives on ONE route (`/home`). The map stays fixed and a
bottom sheet morphs in place through the states driven by `HomeNotifier`:

`offline → onlineIdle → onlineSearching → incomingJob → headingToPickup →
arrivedAtPickup → loading → inTransit → arrivedAtDestination → tripCompleted`

No `/job-request`, `/active-trip`, or `/trip-summary` routes exist. The bottom
navigation (Home, Trips, Earnings, Profile) is visible only while idle and is
hidden during an active job.

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
