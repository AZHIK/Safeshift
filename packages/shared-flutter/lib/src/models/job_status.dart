/// Canonical job lifecycle shared by the customer and driver apps.
enum SafeShiftJobStatus {
  requested,
  quoted,
  matched,
  accepted,
  headingToPickup,
  arrived,
  loading,
  inTransit,
  delivered,
  completed,
  cancelled,
  disputed;

  /// The database/API representation.
  String get wireValue => switch (this) {
        SafeShiftJobStatus.headingToPickup => 'heading_to_pickup',
        SafeShiftJobStatus.inTransit => 'in_transit',
        _ => name,
      };

  static SafeShiftJobStatus fromWire(String value) => switch (value) {
        'heading_to_pickup' => SafeShiftJobStatus.headingToPickup,
        'in_transit' => SafeShiftJobStatus.inTransit,
        _ => SafeShiftJobStatus.values.firstWhere(
            (status) => status.name == value,
            orElse: () => throw ArgumentError.value(value, 'value', 'Unknown job status'),
          ),
      };

  bool get isTerminal =>
      this == SafeShiftJobStatus.completed ||
      this == SafeShiftJobStatus.cancelled;

  bool get needsOversight => this == SafeShiftJobStatus.disputed;
}
