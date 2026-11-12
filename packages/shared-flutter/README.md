# shared-flutter

Shared Dart package for `apps/customer-mobile` and `apps/driver-mobile`.

## Contents

- `SafeShiftColors`, `SafeShiftSpacing`, `SafeShiftRadii` design tokens
- `formatTzs`, `formatMoney` currency helpers
- `formatDarEsSalaam*` date/time helpers
- `SafeShiftJobStatus` canonical lifecycle enum
- `CatalogRepository`, `VehicleTypeOption`, `CargoTypeOption` — the vehicle
  and cargo catalogues read from the database
- `CatalogIcon`, `CatalogIcons` — draws the icon a catalogue row points at

## Usage

Add the path dependency once per app:

```yaml
dependencies:
  safeshift_shared:
    path: ../../packages/shared-flutter
```

```dart
import 'package:safeshift_shared/safeshift_shared.dart';

Text(formatTzs(125000));
```

## Workspace

Melos manages this package with both apps:

```bash
melos bootstrap
melos run analyze
melos run test
```

Keep app-specific widgets and screens in the app. Put only cross-app design,
formatting, models, and client helpers here.

## The vehicle and cargo catalogue

Vehicle categories (`public.vehicle_types`) and cargo types
(`public.cargo_types`) are database rows, so neither app carries a hard-coded
list of them. `CatalogRepository` reads them, scoped to the signed-in
profile's country:

```dart
final repository = CatalogRepository(ref.watch(supabaseProvider));
final vehicles = await repository.getVehicleTypes();
```

The rows carry an `icon_url`, and `CatalogIcon` draws it. The value is a path
inside the public `catalog-icons` bucket (`vehicle/pickup.svg`), which the
app resolves against its own Supabase project URL:

```dart
CatalogIcon(
  iconUrl: vehicle.iconUrl,
  supabaseUrl: EnvConfig.current.supabaseUrl,
  fallbackIcon: Icons.local_shipping_outlined,
)
```

See [the Phase 2 architecture note](../../docs/architecture/0009-phase-2-verification-vehicles-cargo-fleets.md)
for how to add a catalogue row and its artwork.
