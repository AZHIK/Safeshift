import 'driver_job.dart';
import 'driver_status.dart';

/// Why the driver's location cannot be used right now.
enum LocationIssue {
  /// Device location (GPS) is switched off.
  serviceOff,

  /// Permission not granted yet; the system prompt can still be shown.
  permissionDenied,

  /// Permission blocked; only the app's system settings can grant it.
  permissionBlocked,
}

/// Local UI state for the single-screen driver home.
class HomeState {
  const HomeState({
    this.driverStatus = DriverStatus.offline,
    this.todayEarnings = 0,
    this.completedToday = 0,
    this.acceptanceRate = 0,
    this.incomingJob,
    this.activeJob,
    this.countdownSeconds = 15,
    this.jobIndex = 0,
    this.errorMessage,
    this.isSubmitting = false,
    this.isLoading = false,
    this.isMockMode = false,
    this.driverLat,
    this.driverLng,
    this.driverHeading,
    this.driverSpeedKmh,
    this.pickupFreeWaitEndsAt,
    this.notice,
    this.noticeSeq = 0,
    this.locationIssue,
  });

  final DriverStatus driverStatus;
  final int todayEarnings;
  final int completedToday;
  final double acceptanceRate;
  final DriverJob? incomingJob;
  final DriverJob? activeJob;
  final int countdownSeconds;
  final int jobIndex;
  final String? errorMessage;
  final bool isSubmitting;
  final bool isLoading;
  final bool isMockMode;

  /// Latest GPS position, mirrored from the location stream for the map.
  final double? driverLat;
  final double? driverLng;

  /// Last known direction of travel (0–359); kept while stationary.
  final double? driverHeading;

  /// Latest ground speed, for the navigation camera zoom.
  final double? driverSpeedKmh;

  /// End of the free waiting time at the pickup; set while `arrived`.
  final DateTime? pickupFreeWaitEndsAt;

  /// One-off message for the driver (shown as a snackbar). [noticeSeq]
  /// changes every time, so the same text can be shown twice.
  final String? notice;
  final int noticeSeq;

  /// Set while location is unusable. Going online is blocked, and while
  /// online or on a job the home screen shows a persistent banner.
  final LocationIssue? locationIssue;

  HomeState copyWith({
    DriverStatus? driverStatus,
    int? todayEarnings,
    int? completedToday,
    double? acceptanceRate,
    DriverJob? incomingJob,
    DriverJob? activeJob,
    int? countdownSeconds,
    int? jobIndex,
    String? errorMessage,
    bool? isSubmitting,
    bool? isLoading,
    bool? isMockMode,
    double? driverLat,
    double? driverLng,
    double? driverHeading,
    double? driverSpeedKmh,
    bool clearIncoming = false,
    bool clearActive = false,
    bool clearError = false,
    DateTime? pickupFreeWaitEndsAt,
    bool clearPickupWait = false,
    String? notice,
    LocationIssue? locationIssue,
    bool clearLocationIssue = false,
  }) {
    return HomeState(
      driverStatus: driverStatus ?? this.driverStatus,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      completedToday: completedToday ?? this.completedToday,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      incomingJob: clearIncoming ? null : (incomingJob ?? this.incomingJob),
      activeJob: clearActive ? null : (activeJob ?? this.activeJob),
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      jobIndex: jobIndex ?? this.jobIndex,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoading: isLoading ?? this.isLoading,
      isMockMode: isMockMode ?? this.isMockMode,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      driverHeading: driverHeading ?? this.driverHeading,
      driverSpeedKmh: driverSpeedKmh ?? this.driverSpeedKmh,
      pickupFreeWaitEndsAt: clearPickupWait || clearActive
          ? null
          : (pickupFreeWaitEndsAt ?? this.pickupFreeWaitEndsAt),
      notice: notice ?? this.notice,
      noticeSeq: notice != null ? noticeSeq + 1 : noticeSeq,
      locationIssue: clearLocationIssue
          ? null
          : (locationIssue ?? this.locationIssue),
    );
  }
}
