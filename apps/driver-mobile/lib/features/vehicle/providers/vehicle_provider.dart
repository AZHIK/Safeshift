// Driver vehicle state (mock).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_vehicle.dart';

part 'vehicle_provider.g.dart';

@riverpod
class VehicleState extends _$VehicleState {
  @override
  MockVehicle build() {
    ref.keepAlive();
    return mockVehicle;
  }
}
