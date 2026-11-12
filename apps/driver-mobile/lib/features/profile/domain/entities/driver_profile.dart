/// The signed-in driver's profile, as the app shows it.
///
/// The vehicle category is not a fixed list: it comes from
/// `public.vehicle_types`, reached through the driver's current vehicle.
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.rating,
    required this.completedTrips,
    required this.verified,
    required this.zone,
    this.vehicleTypeId,
    this.vehicleClass = '',
    this.vehicleIconUrl,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final double rating;
  final int completedTrips;
  final bool verified;
  final String zone;

  /// `public.vehicle_types.id` of the vehicle the driver operates.
  final String? vehicleTypeId;

  /// Display name of that vehicle category, e.g. "Pickup".
  final String vehicleClass;

  /// Icon path of that vehicle category, served from the catalogue bucket.
  final String? vehicleIconUrl;

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
    String? zone,
    String? vehicleTypeId,
    String? vehicleClass,
    String? vehicleIconUrl,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rating: rating ?? this.rating,
      completedTrips: completedTrips ?? this.completedTrips,
      verified: verified ?? this.verified,
      zone: zone ?? this.zone,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      vehicleIconUrl: vehicleIconUrl ?? this.vehicleIconUrl,
    );
  }
}
