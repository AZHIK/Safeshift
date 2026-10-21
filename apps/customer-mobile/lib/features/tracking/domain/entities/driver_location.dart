// Planned: add heading/speed/accuracy fields and value equality in a later
// sprint.
// Placeholder entity only.
class DriverLocation {
  const DriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
}
