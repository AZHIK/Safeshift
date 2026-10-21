// Planned: add rating, receipt, and pagination fields in a later sprint.
// Placeholder entity only.
class JobHistory {
  const JobHistory({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.completedAt,
    required this.amount,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime completedAt;
  final double amount;
}
