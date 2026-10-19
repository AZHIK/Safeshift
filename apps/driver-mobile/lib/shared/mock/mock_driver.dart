// Mock logged-in driver profile. No backend — demo data only.

/// Minimal driver profile used across home, profile, and trip sheets.
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.rating,
    required this.completedTrips,
    required this.verified,
    required this.vehicleClass,
    required this.zone,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final double rating;
  final int completedTrips;
  final bool verified;
  final String vehicleClass;
  final String zone;

  String get initials => fullName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  /// True when the minimum fields required to drive are filled.
  /// Real completeness rules (documents, vehicle, verification) will be
  /// enforced by the backend later.
  bool get isComplete =>
      fullName.trim().isNotEmpty && phone.trim().isNotEmpty;

  DriverProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    double? rating,
    int? completedTrips,
    bool? verified,
    String? vehicleClass,
    String? zone,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rating: rating ?? this.rating,
      completedTrips: completedTrips ?? this.completedTrips,
      verified: verified ?? this.verified,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      zone: zone ?? this.zone,
    );
  }
}

const DriverProfile mockDriver = DriverProfile(
  id: 'driver-001',
  fullName: 'Baraka Mwansa',
  phone: '+255713456789',
  email: 'baraka.mwansa@example.com',
  rating: 4.9,
  completedTrips: 1243,
  verified: true,
  vehicleClass: 'Pickup',
  zone: 'Kinondoni',
);
