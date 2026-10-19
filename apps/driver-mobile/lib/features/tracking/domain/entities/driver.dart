// Shim entity so the shared DriverAvatarCard widget compiles unchanged.
class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.vehicleClass,
    required this.rating,
    required this.phone,
    required this.completedTrips,
    required this.verified,
  });

  final String id;
  final String name;
  final String vehicleClass;
  final double rating;
  final String phone;
  final int completedTrips;
  final bool verified;

  String get initials => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
