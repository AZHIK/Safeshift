import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/mock/mock_drivers.dart';
import '../domain/entities/driver_location.dart';

class TrackingData {
  const TrackingData({required this.driverLocation, required this.currentStep});
  final DriverLocation driverLocation;
  final int currentStep;
}

final trackingProvider = Provider<TrackingData>((ref) {
  final driver = mockDrivers.first;
  return TrackingData(
    driverLocation: DriverLocation(
      driverId: driver.id,
      latitude: -6.7882,
      longitude: 39.2514,
      updatedAt: DateTime.now(),
    ),
    currentStep: 3,
  );
});
