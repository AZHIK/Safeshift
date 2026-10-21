// Planned: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/driver_location.dart';

/// Placeholder data model mirroring [DriverLocation].
class DriverLocationModel {
  const DriverLocationModel({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  factory DriverLocationModel.fromJson(Map<String, dynamic> json) {
    return DriverLocationModel(
      driverId: json['driver_id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'driver_id': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DriverLocation toEntity() {
    return DriverLocation(
      driverId: driverId,
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
    );
  }
}
