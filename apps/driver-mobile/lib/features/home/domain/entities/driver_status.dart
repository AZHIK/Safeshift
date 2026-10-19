// Driver job-flow states. Everything from incomingJob through
// tripCompleted is an active job rendered inside the single /home route.

enum DriverStatus {
  offline,
  onlineIdle,
  onlineSearching,
  incomingJob,
  headingToPickup,
  arrivedAtPickup,
  loading,
  inTransit,
  arrivedAtDestination,
  tripCompleted,
}

extension DriverStatusX on DriverStatus {
  /// True for every state from [incomingJob] through [tripCompleted].
  bool get hasActiveJob => switch (this) {
    DriverStatus.incomingJob ||
    DriverStatus.headingToPickup ||
    DriverStatus.arrivedAtPickup ||
    DriverStatus.loading ||
    DriverStatus.inTransit ||
    DriverStatus.arrivedAtDestination ||
    DriverStatus.tripCompleted => true,
    _ => false,
  };

  /// Bottom nav is visible only while idle (no active job).
  bool get showBottomNav => switch (this) {
    DriverStatus.offline ||
    DriverStatus.onlineIdle ||
    DriverStatus.onlineSearching => true,
    _ => false,
  };
}
