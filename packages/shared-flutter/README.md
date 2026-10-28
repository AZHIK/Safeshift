# shared-flutter

Shared Dart package for `apps/customer-mobile` and `apps/driver-mobile`.

## Contents

- `SafeShiftColors`, `SafeShiftSpacing`, `SafeShiftRadii` design tokens
- `formatTzs`, `formatMoney` currency helpers
- `formatDarEsSalaam*` date/time helpers
- `SafeShiftJobStatus` canonical lifecycle enum

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
