// Planned: add copyWith, value equality, and currency handling (TZS) in a later
// sprint. Placeholder entity only.
class Quote {
  const Quote({
    required this.baseFee,
    required this.distanceFee,
    required this.timeFee,
    required this.total,
    this.cargoHandlingFee = 0,
    this.vat = 0,
    this.vehicleClassId,
  });

  final double baseFee;
  final double distanceFee;
  final double timeFee;
  final double total;
  final double cargoHandlingFee;
  final double vat;
  final String? vehicleClassId;

  double get subtotal => baseFee + distanceFee + timeFee + cargoHandlingFee;
}
