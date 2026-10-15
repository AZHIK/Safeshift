// TODO: add copyWith, value equality, and remaining fields (cargo, schedule,
// vehicle class) in a later sprint. Placeholder entity only.
class Job {
  const Job({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.quoteAmount,
    this.createdAt,
    this.driverId,
    this.vehicleClassId,
    this.paymentMethod,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final double quoteAmount;
  final DateTime? createdAt;
  final String? driverId;
  final String? vehicleClassId;
  final String? paymentMethod;
}
