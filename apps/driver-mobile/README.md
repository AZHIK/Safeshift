# SafeShift Driver App

Driver-facing Flutter application for the SafeShift logistics marketplace (Dar es Salaam).

> **Mock UI phase.** No backend. No Supabase. No real GPS. All state is local
> and deterministic for demo purposes.

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
flutter run
```
