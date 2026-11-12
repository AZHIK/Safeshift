/// A driver job: an offer to move cargo, or an accepted job in progress.
///
/// This is the live domain model. It is built from `job_offers` and `jobs`
/// rows by the driver repository, and it is also reused by the mock fixtures
/// in `lib/shared/mock/mock_jobs.dart`.
class DriverJob {
  const DriverJob({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.distanceKm,
    required this.estimatedFareTzs,
    required this.cargoClass,
    required this.customerName,
    required this.pickupDistanceKm,
    this.offerId,
    this.status,
    this.customerPhone,
    this.expiresAt,
    this.completedAt,
    this.cargoTypeId,
    this.cargoIconUrl,
    this.vehicleTypeId,
    this.vehicleIconUrl,
  });

  final String id;
  final String pickup;
  final String destination;
  final double distanceKm;
  final int estimatedFareTzs;
  final String cargoClass;
  final String customerName;
  final double pickupDistanceKm;

  /// Real backend identifiers. Null in design/mock fixtures.
  final String? offerId;
  final String? status;
  final String? customerPhone;
  final DateTime? expiresAt;
  final DateTime? completedAt;

  /// `public.cargo_types.id` of the cargo this job carries.
  final String? cargoTypeId;

  /// Icon path of the cargo type, served from the catalogue bucket.
  final String? cargoIconUrl;

  /// `public.vehicle_types.id` the customer booked.
  final String? vehicleTypeId;

  /// Icon path of the vehicle category, served from the catalogue bucket.
  final String? vehicleIconUrl;

  DriverJob copyWith({
    String? status,
    String? offerId,
  }) => DriverJob(
    id: id,
    pickup: pickup,
    destination: destination,
    distanceKm: distanceKm,
    estimatedFareTzs: estimatedFareTzs,
    cargoClass: cargoClass,
    customerName: customerName,
    pickupDistanceKm: pickupDistanceKm,
    offerId: offerId ?? this.offerId,
    status: status ?? this.status,
    customerPhone: customerPhone,
    expiresAt: expiresAt,
    completedAt: completedAt,
    cargoTypeId: cargoTypeId,
    cargoIconUrl: cargoIconUrl,
    vehicleTypeId: vehicleTypeId,
    vehicleIconUrl: vehicleIconUrl,
  );
}
