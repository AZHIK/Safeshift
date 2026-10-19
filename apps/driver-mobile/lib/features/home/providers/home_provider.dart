// Driver home state machine. All job-flow states live inside /home —
// no routes are pushed during the job flow. Mock timers only.
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_earnings.dart';
import '../../../shared/mock/mock_jobs.dart';
import '../domain/entities/driver_status.dart';
import '../domain/entities/home_state.dart';

part 'home_provider.g.dart';

/// Durations are constants so tests can await them deterministically.
abstract final class HomeDelays {
  static const Duration idleToSearching = Duration(seconds: 2);
  static const Duration searchingToIncoming = Duration(seconds: 5);
  static const int countdownSeconds = 15;
}

/// Whether the mock location/notification permission dialogs were shown.
@riverpod
class HomePermissions extends _$HomePermissions {
  @override
  bool build() {
    ref.keepAlive();
    return false;
  }

  void markAsked() => state = true;
}

@riverpod
class HomeNotifier extends _$HomeNotifier {  Timer? _idleTimer;
  Timer? _incomingTimer;
  Timer? _countdownTimer;

  @override
  HomeState build() {
    ref.keepAlive();
    ref.onDispose(_cancelAll);
    return const HomeState(
      todayEarnings: MockEarnings.todayTzs,
      completedToday: MockEarnings.todayTrips,
    );
  }

  void _cancelAll() {
    _idleTimer?.cancel();
    _incomingTimer?.cancel();
    _countdownTimer?.cancel();
    _idleTimer = null;
    _incomingTimer = null;
    _countdownTimer = null;
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Offline -> onlineIdle, then after 2s -> onlineSearching.
  void goOnline() {
    _cancelAll();
    state = state.copyWith(
      driverStatus: DriverStatus.onlineIdle,
      clearIncoming: true,
      clearActive: true,
    );
    _idleTimer = Timer(HomeDelays.idleToSearching, () {
      if (!ref.mounted) return;
      state = state.copyWith(driverStatus: DriverStatus.onlineSearching);
      _startIncomingJobSimulation();
    });
  }

  /// Reset to offline and cancel all timers.
  void goOffline() {
    _cancelAll();
    state = state.copyWith(
      driverStatus: DriverStatus.offline,
      clearIncoming: true,
      clearActive: true,
      countdownSeconds: HomeDelays.countdownSeconds,
    );
  }

  /// After 5s of searching, surface the next mock job with a countdown.
  void _startIncomingJobSimulation() {
    _incomingTimer?.cancel();
    _incomingTimer = Timer(HomeDelays.searchingToIncoming, () {
      if (!ref.mounted) return;
      if (state.driverStatus != DriverStatus.onlineSearching) return;
      final job = mockJobs[state.jobIndex % mockJobs.length];
      state = state.copyWith(
        driverStatus: DriverStatus.incomingJob,
        incomingJob: job,
        countdownSeconds: HomeDelays.countdownSeconds,
      );
      _startCountdown();
    });
  }

  /// 15-second accept window; auto-declines on expiry.
  void _startCountdown() {
    _cancelCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final next = state.countdownSeconds - 1;
      if (next <= 0) {
        declineJob();
        return;
      }
      state = state.copyWith(countdownSeconds: next);
    });
  }

  /// Accept the pending job and collapse the sheet to the pickup stage.
  void acceptJob() {
    final job = state.incomingJob;
    if (job == null || state.driverStatus != DriverStatus.incomingJob) return;
    _cancelCountdown();
    _incomingTimer?.cancel();
    state = state.copyWith(
      driverStatus: DriverStatus.headingToPickup,
      activeJob: job,
      clearIncoming: true,
    );
  }

  /// Decline (or countdown expiry) — back to searching with the next job.
  void declineJob() {
    if (state.driverStatus != DriverStatus.incomingJob) return;
    _cancelCountdown();
    state = state.copyWith(
      driverStatus: DriverStatus.onlineSearching,
      clearIncoming: true,
      countdownSeconds: HomeDelays.countdownSeconds,
      jobIndex: state.jobIndex + 1,
    );
    _startIncomingJobSimulation();
  }

  /// Advance one stage through the active-job flow.
  void advanceStage() {
    final next = switch (state.driverStatus) {
      DriverStatus.headingToPickup => DriverStatus.arrivedAtPickup,
      DriverStatus.arrivedAtPickup => DriverStatus.loading,
      DriverStatus.loading => DriverStatus.inTransit,
      DriverStatus.inTransit => DriverStatus.arrivedAtDestination,
      DriverStatus.arrivedAtDestination => DriverStatus.tripCompleted,
      _ => null,
    };
    if (next == null) return;
    if (next == DriverStatus.tripCompleted) {
      final fare = state.activeJob?.estimatedFareTzs ?? 0;
      state = state.copyWith(
        driverStatus: next,
        todayEarnings: state.todayEarnings + fare,
        completedToday: state.completedToday + 1,
      );
      return;
    }
    state = state.copyWith(driverStatus: next);
  }

  /// After trip completion — collapse back to idle and resume searching.
  void goBackOnline() {
    _cancelAll();
    state = state.copyWith(
      driverStatus: DriverStatus.onlineIdle,
      clearIncoming: true,
      clearActive: true,
      countdownSeconds: HomeDelays.countdownSeconds,
      jobIndex: state.jobIndex + 1,
    );
    _idleTimer = Timer(HomeDelays.idleToSearching, () {
      if (!ref.mounted) return;
      state = state.copyWith(driverStatus: DriverStatus.onlineSearching);
      _startIncomingJobSimulation();
    });
  }
}
