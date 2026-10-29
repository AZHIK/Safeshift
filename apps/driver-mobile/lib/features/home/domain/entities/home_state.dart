import '../../../../shared/mock/mock_jobs.dart';
import 'driver_status.dart';

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
    bool clearIncoming = false,
    bool clearActive = false,
    bool clearError = false,
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
    );
  }
}
