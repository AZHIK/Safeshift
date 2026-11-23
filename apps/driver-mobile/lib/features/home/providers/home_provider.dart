// Driver home state machine. Everything from the offer inbox through trip
// completion stays on the single /home route. In real mode the state is driven
// by Supabase RPCs, realtime offers and a slow poll fallback. Mock mode remains
// available through --dart-define=MOCK_MODE=true for design work and tests.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/mock_mode.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/mock/mock_earnings.dart';
import '../../../shared/mock/mock_jobs.dart';
import '../data/driver_repository.dart';
import '../data/live_location.dart';
import '../domain/entities/driver_job.dart';
import '../domain/entities/driver_status.dart';
import '../domain/entities/home_state.dart';

/// Durations are constants so mock tests can await them deterministically.
abstract final class HomeDelays {
  static const Duration idleToSearching = Duration(seconds: 2);
  static const Duration searchingToIncoming = Duration(seconds: 5);
  static const int countdownSeconds = 15;
}

class HomePermissions extends Notifier<bool> {
  @override
  bool build() => false;

  void markAsked() => state = true;
}

final homePermissionsProvider = NotifierProvider<HomePermissions, bool>(
  HomePermissions.new,
);

class HomeNotifier extends Notifier<HomeState> {
  Timer? _idleTimer;
  Timer? _incomingTimer;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  /// When going online was last blocked by a location problem. If the driver
  /// fixes it soon after, they are taken online without tapping again.
  DateTime? _onlineBlockedAt;
  AppLifecycleListener? _lifecycle;
  RealtimeChannel? _offersChannel;
  RealtimeChannel? _jobChannel;
  String? _activeJobId;
  String? _lastNotifiedOfferId;

  DriverRepository get _repo => DriverRepository(ref.read(supabaseProvider));

  bool get _isMock => ref.read(mockEnabledProvider);

  @override
  HomeState build() {
    try {
      _lifecycle = AppLifecycleListener(
        onResume: () {
          if (_isMock) return;
          unawaited(_recheckLocationOnResume());
        },
      );
    } catch (_) {
      // No binding (plain unit tests); the resume refresh is optional.
      _lifecycle = null;
    }
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
      _cancelAll();
    });
    final mock = ref.read(mockEnabledProvider);
    if (mock) {
      return const HomeState(
        todayEarnings: MockEarnings.todayTzs,
        completedToday: MockEarnings.todayTrips,
        acceptanceRate: 0.94,
        isMockMode: true,
      );
    }
    // Riverpod has not initialized `state` until build returns. Start the
    // network bootstrap on the next microtask so it can safely update state.
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(_bootstrap());
    });
    return const HomeState();
  }

  Future<void> _bootstrap() async {
    final user = ref.read(authProviderUserId);
    if (user == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final active = await _repo.activeJob();
      DriverEarningsSnapshot? earnings;
      try {
        earnings = await _repo.earnings();
      } catch (_) {
        // Earnings can refresh later. Restore the active trip first.
      }
      if (!ref.mounted) return;
      if (active == null) {
        state = state.copyWith(
          isLoading: false,
          todayEarnings: earnings?.todayAmount,
          completedToday: earnings?.todayTrips,
        );
        return;
      }
      _activeJobId = active.id;
      state = state.copyWith(
        isLoading: false,
        activeJob: active,
        driverStatus: _statusFor(active.status),
        todayEarnings: earnings?.todayAmount,
        completedToday: earnings?.todayTrips,
      );
      _subscribeJob(active.id);
      _startPolling();
      _startLocationUpdates(jobId: active.id);
      _syncPickupWait(active);
    } catch (error, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  Future<void> refresh() => _bootstrap();

  DriverStatus _statusFor(String? status) => switch (status) {
    'accepted' || 'heading_to_pickup' => DriverStatus.headingToPickup,
    'arrived' => DriverStatus.arrivedAtPickup,
    'cargo_verified' => DriverStatus.cargoVerified,
    'loading' => DriverStatus.loading,
    'in_transit' => DriverStatus.inTransit,
    'arrived_destination' => DriverStatus.arrivedAtDestination,
    'delivered' => DriverStatus.delivered,
    'completed' => DriverStatus.tripCompleted,
    _ => DriverStatus.onlineSearching,
  };

  Future<void> goOnline() async {
    _cancelAll();
    if (_isMock) {
      _mockGoOnline();
      return;
    }
    state = state.copyWith(
      isLoading: true,
      clearIncoming: true,
      clearActive: true,
      clearError: true,
    );
    // Dispatch finds drivers by location, so an online driver without a
    // usable location would silently never get a job. Block until fixed.
    final issue = await _locationIssue();
    if (!ref.mounted) return;
    if (issue != null) {
      _onlineBlockedAt = DateTime.now();
      state = state.copyWith(
        driverStatus: DriverStatus.offline,
        isLoading: false,
        locationIssue: issue,
      );
      return;
    }
    _onlineBlockedAt = null;
    state = state.copyWith(clearLocationIssue: true);
    try {
      // Dispatch matches on drivers.current_vehicle_id. Without it the driver
      // is invisible to every job, so make sure it is set before going online.
      if (!await _repo.ensureCurrentVehicle()) {
        state = state.copyWith(
          driverStatus: DriverStatus.offline,
          isLoading: false,
          errorMessage: 'Add a vehicle and wait for it to be verified before going online.',
        );
        return;
      }
      await _repo.setAvailability(true);
      state = state.copyWith(
        driverStatus: DriverStatus.onlineSearching,
        isLoading: false,
      );
      _subscribeOffers();
      _startPolling();
      final locationFailure = await _startLocationUpdates();
      if (locationFailure != null) {
        // Still online, but dispatch cannot see this driver until the fix
        // lands. Say so instead of failing silently.
        state = state.copyWith(errorMessage: locationFailure);
      }
      await _checkOffer();
    } catch (error, stack) {
      state = state.copyWith(
        driverStatus: DriverStatus.offline,
        isLoading: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  Future<void> goOffline() async {
    _cancelAll();
    if (!_isMock) {
      try {
        await _repo.setAvailability(false);
      } catch (_) {
        // Going offline locally still matters when the network is down.
      }
    }
    state = state.copyWith(
      driverStatus: DriverStatus.offline,
      clearIncoming: true,
      clearActive: true,
      countdownSeconds: HomeDelays.countdownSeconds,
    );
  }

  Future<void> acceptJob() async {
    final job = state.incomingJob;
    if (job == null ||
        state.driverStatus != DriverStatus.incomingJob ||
        state.isSubmitting) {
      return;
    }
    _cancelCountdown();
    _incomingTimer?.cancel();

    if (_isMock) {
      state = state.copyWith(
        driverStatus: DriverStatus.headingToPickup,
        activeJob: job,
        clearIncoming: true,
      );
      return;
    }

    final offerId = job.offerId;
    if (offerId == null) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.acceptOffer(offerId);
      // The confirmed offer already contains the two endpoints and cargo.
      _activeJobId = job.id;
      state = state.copyWith(
        driverStatus: DriverStatus.headingToPickup,
        activeJob: job.copyWith(status: 'accepted'),
        clearIncoming: true,
      );
      _subscribeJob(job.id);
      unawaited(_startLocationUpdates(jobId: job.id));
      await _repo.advanceJob(job.id, 'heading_to_pickup');
      state = state.copyWith(
        isSubmitting: false,
        activeJob: job.copyWith(status: 'heading_to_pickup'),
      );
    } catch (error, stack) {
      if (_activeJobId == null) await _bootstrap();
      if (_activeJobId != null) {
        state = state.copyWith(
          isSubmitting: false,
          clearIncoming: true,
          errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
        );
        await _refreshActiveJob(_activeJobId!);
        return;
      }
      final message = ErrorHandler.map(error, stackTrace: stack).message;
      state = state.copyWith(
        isSubmitting: false,
        driverStatus: DriverStatus.onlineSearching,
        clearIncoming: true,
        errorMessage: message,
        notice: message,
      );
      await _checkOffer();
    }
  }

  Future<void> declineJob() async {
    if (state.driverStatus != DriverStatus.incomingJob || state.isSubmitting) {
      return;
    }
    _cancelCountdown();
    final offerId = state.incomingJob?.offerId;
    state = state.copyWith(
      driverStatus: DriverStatus.onlineSearching,
      clearIncoming: true,
      countdownSeconds: HomeDelays.countdownSeconds,
      jobIndex: state.jobIndex + 1,
    );
    if (_isMock) {
      _startIncomingJobSimulation();
      return;
    }
    if (offerId != null) {
      try {
        await _repo.declineOffer(offerId);
      } catch (_) {
        // The offer may already have expired or been reassigned.
      }
    }
    await _checkOffer();
  }

  /// Uploads cargo/pickup/delivery evidence for the active job.
  Future<bool> uploadEvidence({
    required String evidenceType,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final job = state.activeJob;
    if (job == null) {
      state = state.copyWith(errorMessage: 'No active job to attach proof to.');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.uploadJobEvidence(
        jobId: job.id,
        evidenceType: evidenceType,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  /// Sends a photo/file to the customer through the job chat.
  Future<bool> sendChatAttachment({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    String? caption,
  }) async {
    final job = state.activeJob;
    if (job == null) {
      state = state.copyWith(errorMessage: 'No active job to chat about.');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.sendChatAttachment(
        jobId: job.id,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        caption: caption,
      );
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  Future<void> advanceStage() async {
    if (state.isSubmitting) return;
    final next = switch (state.driverStatus) {
      DriverStatus.headingToPickup => DriverStatus.arrivedAtPickup,
      DriverStatus.arrivedAtPickup => DriverStatus.cargoVerified,
      DriverStatus.cargoVerified => DriverStatus.loading,
      DriverStatus.loading => DriverStatus.inTransit,
      DriverStatus.inTransit => DriverStatus.arrivedAtDestination,
      DriverStatus.arrivedAtDestination => DriverStatus.delivered,
      DriverStatus.delivered => DriverStatus.tripCompleted,
      _ => null,
    };
    if (next == null) return;

    if (_isMock) {
      if (next == DriverStatus.tripCompleted) {
        _completeMockTrip();
        return;
      }
      state = state.copyWith(driverStatus: next);
      return;
    }

    final job = state.activeJob;
    if (job == null ||
        next == DriverStatus.delivered ||
        next == DriverStatus.tripCompleted) {
      return;
    }
    final backendStatus = switch (next) {
      DriverStatus.arrivedAtPickup => 'arrived',
      DriverStatus.cargoVerified => 'cargo_verified',
      DriverStatus.loading => 'loading',
      DriverStatus.inTransit => 'in_transit',
      DriverStatus.arrivedAtDestination => 'arrived_destination',
      _ => null,
    };
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      if (job.status == 'accepted' && next == DriverStatus.arrivedAtPickup) {
        await _repo.advanceJob(job.id, 'heading_to_pickup');
      }
      if (backendStatus != null) {
        await _repo.advanceJob(job.id, backendStatus);
      }
      final advanced = job.copyWith(status: backendStatus);
      state = state.copyWith(
        isSubmitting: false,
        activeJob: advanced,
        driverStatus: next,
      );
      _syncPickupWait(advanced);
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      await _refreshActiveJob(job.id);
    }
  }

  /// Confirms handover using the code shown in the customer's app.
  Future<bool> verifyDeliveryOtp(String code) async {
    if (state.isSubmitting ||
        state.driverStatus != DriverStatus.arrivedAtDestination) {
      return false;
    }
    final job = state.activeJob;
    if (job == null || code.trim().length != 6) {
      state = state.copyWith(errorMessage: 'Enter the 6-digit delivery code.');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final ok = await _repo.verifyDeliveryOtp(job.id, code.trim());
      if (!ok) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'That delivery code is incorrect. Ask the customer again.',
        );
        return false;
      }
      // OTP verification moves the backend to `delivered`; the driver still
      // confirms completion from the next screen.
      state = state.copyWith(
        driverStatus: DriverStatus.delivered,
        activeJob: job.copyWith(status: 'delivered'),
        isSubmitting: false,
      );
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  /// Completes a delivered job (separate from confirming delivery).
  Future<void> completeTrip() async {
    final job = state.activeJob;
    if (job == null ||
        state.driverStatus != DriverStatus.delivered ||
        state.isSubmitting) {
      return;
    }
    if (_isMock) {
      _completeMockTrip();
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    await _completeRealTrip(job);
  }

  Future<void> _completeRealTrip(DriverJob job) async {
    try {
      await _repo.advanceJob(job.id, 'completed');
    } catch (_) {
      // OTP verification already moved the job to delivered. A retry can still
      // complete it, so keep the UI in the delivered state and show the error.
      state = state.copyWith(
        driverStatus: DriverStatus.delivered,
        isSubmitting: false,
        errorMessage: 'Delivery verified. Completing the trip will retry.',
      );
      return;
    }
    DriverEarningsSnapshot? earnings;
    try {
      earnings = await _repo.earnings();
    } catch (_) {
      // The job is already complete. Earnings can refresh on the next load.
    }
    state = state.copyWith(
      driverStatus: DriverStatus.tripCompleted,
      isSubmitting: false,
      activeJob: job.copyWith(status: 'completed'),
      todayEarnings: earnings?.todayAmount,
      completedToday: earnings?.todayTrips,
    );
    _cancelAll();
  }

  Future<void> goBackOnline() async {
    _cancelAll();
    if (_isMock) {
      _mockGoOnline();
      return;
    }
    final issue = await _locationIssue();
    if (!ref.mounted) return;
    if (issue != null) {
      _onlineBlockedAt = DateTime.now();
      state = state.copyWith(
        driverStatus: DriverStatus.offline,
        clearIncoming: true,
        clearActive: true,
        locationIssue: issue,
      );
      return;
    }
    _onlineBlockedAt = null;
    try {
      if (!await _repo.ensureCurrentVehicle()) {
        state = state.copyWith(
          driverStatus: DriverStatus.offline,
          clearIncoming: true,
          clearActive: true,
          errorMessage: 'Add a vehicle and wait for it to be verified before going online.',
        );
        return;
      }
      await _repo.setAvailability(true);
      final earnings = await _repo.earnings();
      state = state.copyWith(
        driverStatus: DriverStatus.onlineSearching,
        todayEarnings: earnings.todayAmount,
        completedToday: earnings.todayTrips,
        clearIncoming: true,
        clearActive: true,
        clearError: true,
        countdownSeconds: HomeDelays.countdownSeconds,
      );
    } catch (_) {
      state = state.copyWith(
        driverStatus: DriverStatus.onlineSearching,
        clearIncoming: true,
        clearActive: true,
      );
    }
    _subscribeOffers();
    _startPolling();
    await _startLocationUpdates();
    await _checkOffer();
  }

  Future<void> _checkOffer() async {
    if (_isMock || !ref.mounted || state.isSubmitting) return;
    final searching =
        state.driverStatus == DriverStatus.onlineSearching ||
        state.driverStatus == DriverStatus.onlineIdle;
    final incoming = state.driverStatus == DriverStatus.incomingJob;
    if (!searching && !incoming) return;
    try {
      final offer = await _repo.nextOffer();
      if (!ref.mounted ||
          state.isSubmitting ||
          _activeJobId != null ||
          state.driverStatus == DriverStatus.offline) {
        return;
      }

      if (offer == null) {
        // Our offer expired or another driver accepted first.
        if (incoming) {
          _cancelCountdown();
          state = state.copyWith(
            driverStatus: DriverStatus.onlineSearching,
            clearIncoming: true,
            countdownSeconds: HomeDelays.countdownSeconds,
          );
        }
        return;
      }

      if (incoming && state.incomingJob?.offerId == offer.offerId) {
        // Refresh the TTL from the server without restarting the countdown.
        state = state.copyWith(countdownSeconds: _remainingSeconds(offer));
        return;
      }

      _notifyOffer(offer);
      state = state.copyWith(
        driverStatus: DriverStatus.incomingJob,
        incomingJob: offer,
        countdownSeconds: _remainingSeconds(offer),
        clearError: true,
      );
      _startCountdown();
    } catch (_) {
      // Poll failures are non-fatal; the next tick retries.
    }
  }

  /// Seconds left on an offer using the server clock where possible.
  int _remainingSeconds(DriverJob offer) {
    final expires = offer.expiresAt;
    if (expires != null) {
      final diff = expires.difference(DateTime.now()).inSeconds;
      if (diff > 0) return diff.clamp(1, 600);
    }
    final ttl = offer.offerTtlSeconds;
    if (ttl != null && ttl > 0) return ttl.clamp(1, 600);
    return HomeDelays.countdownSeconds;
  }

  void _notifyOffer(DriverJob offer) {
    if (_lastNotifiedOfferId == offer.offerId) return;
    _lastNotifiedOfferId = offer.offerId;
    unawaited(HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  void _startCountdown() {
    _cancelCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final next = state.countdownSeconds - 1;
      if (next <= 0) {
        unawaited(declineJob());
        return;
      }
      state = state.copyWith(countdownSeconds: next);
    });
  }

  void _subscribeOffers() {
    _offersChannel?.unsubscribe();
    final userId = ref.read(authProviderUserId);
    if (userId == null) return;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'driver_id',
      value: userId,
    );
    _offersChannel = ref
        .read(supabaseProvider)
        .channel('driver-offers-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'job_offers',
          filter: filter,
          callback: (_) => unawaited(_checkOffer()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'job_offers',
          filter: filter,
          callback: (_) => unawaited(_checkOffer()),
        )
        .subscribe();
  }

  void _subscribeJob(String jobId) {
    _jobChannel?.unsubscribe();
    _jobChannel = ref
        .read(supabaseProvider)
        .channel('driver-job-$jobId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (_) => unawaited(_refreshActiveJob(jobId)),
        )
        .subscribe();
  }

  Future<void> _refreshActiveJob(String jobId) async {
    if (state.isSubmitting) return;
    final statusAtRequest = state.driverStatus;
    try {
      final active = await _repo.activeJob();
      if (!ref.mounted ||
          _activeJobId != jobId ||
          state.isSubmitting ||
          state.driverStatus != statusAtRequest) {
        return;
      }
      if (active == null) {
        final message = await _outcomeMessage(jobId);
        if (!ref.mounted || _activeJobId != jobId) return;
        _activeJobId = null;
        _jobChannel?.unsubscribe();
        _jobChannel = null;
        // The trip finished; make sure the server and the GPS feed are both
        // ready for the next offer.
        _lastNotifiedOfferId = null;
        try {
          await _repo.setAvailability(true);
        } catch (_) {
          // The completion trigger also frees the driver; this is a backstop.
        }
        state = state.copyWith(
          driverStatus: DriverStatus.onlineSearching,
          clearActive: true,
          notice: message,
        );
        unawaited(_startLocationUpdates());
        await _checkOffer();
        return;
      }
      state = state.copyWith(
        activeJob: active,
        driverStatus: _statusFor(active.status),
      );
      _syncPickupWait(active);
    } catch (_) {
      // Realtime failures are non-fatal.
    }
  }

  /// Explains a job that left this driver's screen without them finishing it.
  Future<String?> _outcomeMessage(String jobId) async {
    try {
      final outcome = await _repo.jobOutcome(jobId);
      final reason = outcome.reason?.trim();
      return switch (outcome.outcome) {
        'cancelled' =>
          reason == null || reason.isEmpty
              ? 'This job was cancelled.'
              : 'This job was cancelled: $reason',
        'released' =>
          reason == null || reason.isEmpty
              ? 'This job was given to another driver.'
              : 'This job was given to another driver. Reason: $reason',
        'assigned' => null,
        _ => 'This job is no longer assigned to you.',
      };
    } catch (_) {
      return 'This job is no longer assigned to you.';
    }
  }

  String? _pickupWaitFor;

  void _syncPickupWait(DriverJob job) {
    if (job.status == 'arrived') {
      if (_pickupWaitFor == job.id) return;
      _pickupWaitFor = job.id;
      unawaited(() async {
        try {
          final endsAt = await _repo.pickupFreeWaitEndsAt(job.id);
          if (!ref.mounted || _activeJobId != job.id) return;
          state = state.copyWith(
            pickupFreeWaitEndsAt: endsAt,
            clearPickupWait: endsAt == null,
          );
        } catch (_) {
          _pickupWaitFor = null;
        }
      }());
    } else if (_pickupWaitFor != null || state.pickupFreeWaitEndsAt != null) {
      _pickupWaitFor = null;
      state = state.copyWith(clearPickupWait: true);
    }
  }

  /// Ends the driver's part in the active job (release, no-show, cargo
  /// mismatch) and returns them to searching.
  Future<bool> _leaveActiveJob(
    Future<void> Function(String jobId) action,
    String doneMessage,
  ) async {
    final job = state.activeJob;
    if (job == null || state.isSubmitting || _isMock) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await action(job.id);
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        notice: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
    if (!ref.mounted) return false;
    _activeJobId = null;
    _pickupWaitFor = null;
    _jobChannel?.unsubscribe();
    _jobChannel = null;
    _lastNotifiedOfferId = null;
    state = state.copyWith(
      isSubmitting: false,
      driverStatus: DriverStatus.onlineSearching,
      clearActive: true,
      notice: doneMessage,
    );
    unawaited(_startLocationUpdates());
    await _checkOffer();
    return true;
  }

  /// "I can't do this job": hands it back so another driver can take it.
  Future<bool> releaseActiveJob(String reason) => _leaveActiveJob(
    (jobId) => _repo.releaseJob(jobId, reason),
    'Job released. We are finding the customer another driver.',
  );

  Future<bool> reportCustomerNoShow() => _leaveActiveJob(
    _repo.reportCustomerNoShow,
    'Recorded as a customer no-show. You are free for new jobs.',
  );

  Future<bool> reportCargoMismatch(String reason) => _leaveActiveJob(
    (jobId) => _repo.reportCargoMismatch(jobId, reason),
    'Cargo refused and the job was cancelled. You are free for new jobs.',
  );

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_checkOffer());
      final activeJobId = _activeJobId;
      if (activeJobId != null) {
        unawaited(_refreshActiveJob(activeJobId));
      }
    });
  }

  /// Streams GPS fixes while the driver is online or on a trip.
  ///
  /// Like the big ride-hailing apps, the rate depends on what the driver is
  /// doing. On a job the stream runs every ~3 s and each accepted fix is
  /// broadcast live to the customer over the job's private Realtime channel
  /// (no database write). Idle, it runs every ~20 s. In both cases a point is
  /// stored in `driver_locations` at most every 30 s, which keeps dispatch,
  /// the watchdog and the history fed without a write per fix.
  ///
  /// On Android the stream runs behind a foreground-service notification so
  /// the OS keeps delivering updates in the background.
  Future<String?> _startLocationUpdates({String? jobId}) async {
    if (_isMock) return null;
    _locationTimer?.cancel();
    _locationTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _gpsFilter.reset();
    _attachBroadcaster(jobId);
    _watchServiceStatus();

    final issue = await _locationIssue();
    if (!ref.mounted) return null;
    if (issue != null) {
      state = state.copyWith(locationIssue: issue);
      return locationIssueMessage(issue);
    }
    if (state.locationIssue != null) {
      state = state.copyWith(clearLocationIssue: true);
    }

    // Publish a fix right away so the driver becomes dispatchable without
    // waiting for the first stream event.
    final failure = await _pushLocation(jobId);

    try {
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: _locationSettings(onJob: jobId != null),
          ).listen(
            (position) => unawaited(_onPosition(position, jobId)),
            onError: (_) {
              // A single bad fix is not fatal; the stream keeps running.
            },
          );
    } catch (error, stack) {
      debugPrint(
        'Position stream unavailable: '
        '${ErrorHandler.map(error, stackTrace: stack).message}',
      );
    }

    // Safety net for ROMs that stop the stream: store a fresh fix if none
    // was stored recently.
    _locationTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      final last = _lastPersistedAt;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(seconds: 40)) {
        unawaited(_pushLocation(jobId));
      }
    });
    return failure;
  }

  final GpsFilter _gpsFilter = GpsFilter();
  LiveLocationBroadcaster? _broadcaster;

  /// Opens (or closes, with null) the live channel for the job in progress.
  void _attachBroadcaster(String? jobId) {
    if (jobId == null) {
      _broadcaster?.detach();
      return;
    }
    (_broadcaster ??= LiveLocationBroadcaster(
      ref.read(supabaseProvider),
    )).attach(jobId);
  }

  DateTime? _lastPersistedAt;
  static const _persistEvery = Duration(seconds: 30);

  static LiveFix _fixFrom(Position position) {
    // Sensor heading is noise below walking pace.
    final moving = position.speed.isFinite && position.speed >= 1.5;
    return LiveFix(
      lat: position.latitude,
      lng: position.longitude,
      at: position.timestamp,
      heading: moving && position.heading.isFinite && position.heading >= 0
          ? position.heading % 360
          : null,
      speedKmh: position.speed.isFinite && position.speed >= 0
          ? position.speed * 3.6
          : null,
      accuracyM: position.accuracy.isFinite ? position.accuracy : null,
    );
  }

  Future<void> _onPosition(Position position, String? jobId) async {
    final fix = _gpsFilter.accept(_fixFrom(position));
    if (fix == null || !ref.mounted) return;
    state = state.copyWith(
      driverLat: fix.lat,
      driverLng: fix.lng,
      driverHeading: fix.heading,
      driverSpeedKmh: fix.speedKmh,
    );
    if (jobId != null) unawaited(_broadcaster?.send(fix));
    final last = _lastPersistedAt;
    if (last == null || DateTime.now().difference(last) >= _persistEvery) {
      await _persist(fix, jobId);
    }
  }

  Future<void> _persist(LiveFix fix, String? jobId) async {
    _lastPersistedAt = DateTime.now();
    try {
      await _repo.updateLocation(
        latitude: fix.lat,
        longitude: fix.lng,
        jobId: jobId,
        heading: fix.heading,
        speedKmh: fix.speedKmh,
        accuracyM: fix.accuracyM,
      );
    } catch (_) {
      // Retry on the next fix rather than waiting another 30 s.
      _lastPersistedAt = null;
    }
  }

  /// Android-specific settings so location keeps flowing in the background.
  ///
  /// iOS/desktop keep the plain settings; on Android the foreground service
  /// notification is what prevents the OS from freezing updates once the app
  /// leaves the foreground. The plugin starts and stops that service with the
  /// stream, so it does not leak after [_cancelAll].
  LocationSettings _locationSettings({required bool onJob}) {
    const accuracy = LocationAccuracy.high;
    final distanceFilter = onJob ? 5 : 25;
    final interval = onJob
        ? const Duration(seconds: 3)
        : const Duration(seconds: 20);
    if (defaultTargetPlatform != TargetPlatform.android) {
      return LocationSettings(
        accuracy: onJob ? LocationAccuracy.bestForNavigation : accuracy,
        distanceFilter: distanceFilter,
      );
    }
    return AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      intervalDuration: interval,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: onJob
            ? 'SafeShift Driver is on a trip'
            : 'SafeShift Driver is online',
        notificationText: onJob
            ? 'Sharing your live location with the customer.'
            : 'Sharing your location so nearby customers can find you.',
        notificationChannelName: 'Driver location',
        notificationIcon: const AndroidResource(name: 'ic_launcher'),
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  /// Publishes the driver's GPS fix.
  ///
  /// Returns null on success, or a short reason the fix could not be
  /// published. A driver whose location never lands is invisible to dispatch,
  /// so the reason is surfaced instead of being swallowed: going "online"
  /// without a published location looks identical to going offline.
  Future<String?> _pushLocation(String? jobId) async {
    if (_isMock) return null;
    try {
      // No prompt here: _startLocationUpdates already asked, and this also
      // runs from timers and app resume where a dialog would be unexpected.
      final issue = await _locationIssue(request: false);
      if (issue != null) {
        if (ref.mounted) state = state.copyWith(locationIssue: issue);
        return locationIssueMessage(issue);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Never hang on a fix the device cannot get (indoors, bad GPS).
          timeLimit: Duration(seconds: 20),
        ),
      );
      final fix = _fixFrom(position);
      if (ref.mounted) {
        state = state.copyWith(
          driverLat: fix.lat,
          driverLng: fix.lng,
          driverHeading: fix.heading,
          driverSpeedKmh: fix.speedKmh,
        );
      }
      if (jobId != null) unawaited(_broadcaster?.send(fix));
      _lastPersistedAt = DateTime.now();
      await _repo.updateLocation(
        latitude: fix.lat,
        longitude: fix.lng,
        jobId: jobId,
        heading: fix.heading,
        speedKmh: fix.speedKmh,
        accuracyM: fix.accuracyM,
      );
      return null;
    } catch (error, stack) {
      _lastPersistedAt = null;
      return ErrorHandler.map(error, stackTrace: stack).message;
    }
  }

  void _mockGoOnline() {
    state = state.copyWith(
      driverStatus: DriverStatus.onlineIdle,
      clearIncoming: true,
      clearActive: true,
      clearError: true,
      driverLat: -6.79,
      driverLng: 39.25,
    );
    _idleTimer = Timer(HomeDelays.idleToSearching, () {
      if (!ref.mounted) return;
      state = state.copyWith(driverStatus: DriverStatus.onlineSearching);
      _startIncomingJobSimulation();
    });
  }

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

  void _completeMockTrip() {
    final fare = state.activeJob?.estimatedFareTzs ?? 0;
    state = state.copyWith(
      driverStatus: DriverStatus.tripCompleted,
      todayEarnings: state.todayEarnings + fare,
      completedToday: state.completedToday + 1,
    );
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Location availability
  // ---------------------------------------------------------------------------

  /// Returns why location is unusable, or null when it is ready. Shows the
  /// system permission prompt only when [request] is true.
  Future<LocationIssue?> _locationIssue({bool request = true}) async {
    if (_isMock) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationIssue.serviceOff;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      return switch (permission) {
        LocationPermission.denied => LocationIssue.permissionDenied,
        LocationPermission.deniedForever ||
        LocationPermission.unableToDetermine => LocationIssue.permissionBlocked,
        LocationPermission.whileInUse || LocationPermission.always => null,
      };
    } catch (_) {
      // Plugin unavailable: let the fix attempt surface its own error.
      return null;
    }
  }

  /// Reacts to the driver switching device location off or on while online
  /// or on a job, so dispatch and live tracking never fail silently.
  void _watchServiceStatus() {
    if (_serviceStatusSubscription != null) return;
    try {
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
        status,
      ) {
        if (!ref.mounted || state.driverStatus == DriverStatus.offline) {
          return;
        }
        if (status == ServiceStatus.disabled) {
          state = state.copyWith(locationIssue: LocationIssue.serviceOff);
        } else if (state.locationIssue == LocationIssue.serviceOff) {
          unawaited(_onLocationRestored());
        }
      }, onError: (_) {});
    } catch (_) {
      // Not supported on this platform; resume checks still cover it.
    }
  }

  Future<void> _recheckLocationOnResume() async {
    if (!ref.mounted) return;
    final hadIssue = state.locationIssue != null;
    if (!hadIssue) {
      if (state.driverStatus != DriverStatus.offline) {
        unawaited(_pushLocation(_activeJobId));
      }
      return;
    }
    final issue = await _locationIssue(request: false);
    if (!ref.mounted) return;
    if (issue == null) {
      await _onLocationRestored();
    } else if (issue != state.locationIssue) {
      state = state.copyWith(locationIssue: issue);
    }
  }

  /// Location works again: clear the banner and resume what was interrupted.
  Future<void> _onLocationRestored() async {
    if (!ref.mounted) return;
    state = state.copyWith(clearLocationIssue: true);
    if (state.driverStatus == DriverStatus.offline) {
      final blockedAt = _onlineBlockedAt;
      _onlineBlockedAt = null;
      // The driver tried to go online moments ago; finish that for them.
      if (blockedAt != null &&
          DateTime.now().difference(blockedAt) < const Duration(minutes: 10)) {
        await goOnline();
      }
      return;
    }
    await _startLocationUpdates(jobId: _activeJobId);
  }

  /// The banner's action: open location settings, show the permission
  /// prompt again, or open the app's settings when permission is blocked.
  Future<void> fixLocation() async {
    switch (state.locationIssue) {
      case null:
        return;
      case LocationIssue.serviceOff:
        await Geolocator.openLocationSettings();
      case LocationIssue.permissionBlocked:
        await Geolocator.openAppSettings();
      case LocationIssue.permissionDenied:
        final permission = await Geolocator.requestPermission();
        if (!ref.mounted) return;
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          await _onLocationRestored();
        } else if (permission == LocationPermission.deniedForever) {
          state = state.copyWith(
            locationIssue: LocationIssue.permissionBlocked,
          );
        }
    }
    // Returning from settings is handled by the resume check.
  }

  /// Hides the offline banner when the driver does not want to go online.
  void dismissLocationIssue() {
    if (state.driverStatus != DriverStatus.offline) return;
    _onlineBlockedAt = null;
    state = state.copyWith(clearLocationIssue: true);
  }

  void _cancelAll() {
    _idleTimer?.cancel();
    _incomingTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    _offersChannel?.unsubscribe();
    _jobChannel?.unsubscribe();
    _idleTimer = null;
    _incomingTimer = null;
    _countdownTimer = null;
    _pollTimer = null;
    _locationTimer = null;
    _positionSubscription = null;
    _offersChannel = null;
    _jobChannel = null;
    _activeJobId = null;
    _broadcaster?.detach();
  }
}

/// Reads the authenticated user id without making HomeNotifier depend on the
/// full auth state object.
final authProviderUserId = Provider<String?>((ref) {
  return ref.watch(authProvider).currentUser?.id;
});

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

/// Short reason used where a location problem is reported as text.
String locationIssueMessage(LocationIssue issue) => switch (issue) {
  LocationIssue.serviceOff =>
    'Turn on location so customers can find you nearby.',
  LocationIssue.permissionDenied =>
    'Allow location access so customers can find you nearby.',
  LocationIssue.permissionBlocked =>
    'Location access is blocked. Enable it in Settings.',
};
