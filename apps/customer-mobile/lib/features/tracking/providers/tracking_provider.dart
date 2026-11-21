import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ride/providers/ride_provider.dart';
import '../domain/entities/driver_location.dart';

class TrackingData {
  const TrackingData({this.driverLocation, this.currentStep = 0});
  final DriverLocation? driverLocation;
  final int currentStep;
}

/// Derived from real ride state (no mock data).
final trackingProvider = Provider<TrackingData>((ref) {
  final ride = ref.watch(rideProvider);
  final lat = ride.driverLatitude;
  final lng = ride.driverLongitude;
  final driverId = ride.driver?.id;
  return TrackingData(
    driverLocation:
        lat != null &&
            lng != null &&
            driverId != null &&
            ride.driverLocationUpdatedAt != null
        ? DriverLocation(
            driverId: driverId,
            latitude: lat,
            longitude: lng,
            updatedAt: ride.driverLocationUpdatedAt!,
          )
        : null,
    currentStep: switch (ride.jobStatus) {
      'accepted' || 'heading_to_pickup' => 0,
      'arrived' => 1,
      'cargo_verified' => 2,
      'loading' => 3,
      'in_transit' => 4,
      'arrived_destination' => 5,
      'delivered' || 'completed' => 6,
      _ => 0,
    },
  );
});
