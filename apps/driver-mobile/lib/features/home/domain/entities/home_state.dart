import '../../../../shared/mock/mock_jobs.dart';
import 'driver_status.dart';

/// Local UI state for the single-screen driver home.
class HomeState {
  const HomeState({
    this.driverStatus = DriverStatus.offline,
    this.todayEarnings = 161000,
    this.completedToday = 3,
    this.acceptanceRate = 0.94,
    this.incomingJob,
    this.activeJob,
    this.countdownSeconds = 15,
    this.jobIndex = 0,
  });

  final DriverStatus driverStatus;
  final int todayEarnings;
  final int completedToday;
  final double acceptanceRate;
  final DriverJob? incomingJob;
  final DriverJob? activeJob;
  final int countdownSeconds;
  final int jobIndex;

  HomeState copyWith({
    DriverStatus? driverStatus,
    int? todayEarnings,
    int? completedToday,
    double? acceptanceRate,
    DriverJob? incomingJob,
    DriverJob? activeJob,
    int? countdownSeconds,
    int? jobIndex,
    bool clearIncoming = false,
    bool clearActive = false,
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
    );
  }
}
