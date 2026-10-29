// Driver home state machine. Everything from the offer inbox through trip
// completion stays on the single /home route. In real mode the state is driven
// by Supabase RPCs, realtime offers and a slow poll fallback. Mock mode remains
// available through --dart-define=MOCK_MODE=true for design work and tests.
import 'dart:async';

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
  RealtimeChannel? _offersChannel;
  RealtimeChannel? _jobChannel;
  String? _activeJobId;

  DriverRepository get _repo => DriverRepository(ref.read(supabaseProvider));

  bool get _isMock => ref.read(mockEnabledProvider);

  @override
  HomeState build() {
    ref.onDispose(_cancelAll);
    final mock = ref.read(mockEnabledProvider);
    if (mock) {
      return const HomeState(
        todayEarnings: MockEarnings.todayTzs,
        completedToday: MockEarnings.todayTrips,
        acceptanceRate: 0.94,
        isMockMode: true,
      );
    }
    unawaited(_bootstrap());
    return const HomeState();
  }

  Future<void> _bootstrap() async {
    final user = ref.read(authProviderUserId);
    if (user == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final earnings = await _repo.earnings();
      final active = await _repo.activeJob();
      if (active == null) {
        state = state.copyWith(
          isLoading: false,
          todayEarnings: earnings.todayAmount,
          completedToday: earnings.todayTrips,
        );
        return;
      }
      _activeJobId = active.id;
      state = state.copyWith(
        isLoading: false,
        activeJob: active,
        driverStatus: _statusFor(active.status),
        todayEarnings: earnings.todayAmount,
        completedToday: earnings.todayTrips,
      );
      _subscribeJob(active.id);
      _startLocationUpdates(jobId: active.id);
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
    'loading' => DriverStatus.loading,
    'in_transit' => DriverStatus.inTransit,
    'delivered' => DriverStatus.arrivedAtDestination,
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
    try {
      await _repo.setAvailability(true);
      state = state.copyWith(
        driverStatus: DriverStatus.onlineSearching,
        isLoading: false,
      );
      _subscribeOffers();
      _startPolling();
      await _startLocationUpdates();
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
    if (job == null || state.driverStatus != DriverStatus.incomingJob) return;
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
      final active = await _repo.activeJob();
      if (active == null) {
        throw StateError('The job could not be loaded after acceptance.');
      }
      _activeJobId = active.id;
      state = state.copyWith(
        driverStatus: DriverStatus.headingToPickup,
        activeJob: active,
        isSubmitting: false,
        clearIncoming: true,
      );
      _subscribeJob(active.id);
      _startLocationUpdates(jobId: active.id);
      await _repo.advanceJob(active.id, 'heading_to_pickup');
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        driverStatus: DriverStatus.onlineSearching,
        clearIncoming: true,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      await _checkOffer();
    }
  }

  Future<void> declineJob() async {
    if (state.driverStatus != DriverStatus.incomingJob) return;
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
    final next = switch (state.driverStatus) {
      DriverStatus.headingToPickup => DriverStatus.arrivedAtPickup,
      DriverStatus.arrivedAtPickup => DriverStatus.loading,
      DriverStatus.loading => DriverStatus.inTransit,
      DriverStatus.inTransit => DriverStatus.arrivedAtDestination,
      DriverStatus.arrivedAtDestination =>
        _isMock ? DriverStatus.tripCompleted : null,
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
    if (job == null) return;
    final backendStatus = switch (next) {
      DriverStatus.arrivedAtPickup => 'arrived',
      DriverStatus.loading => 'loading',
      DriverStatus.inTransit => 'in_transit',
      _ => null,
    };
    state = state.copyWith(
      driverStatus: next,
      isSubmitting: true,
      clearError: true,
    );
    try {
      if (backendStatus != null) {
        await _repo.advanceJob(job.id, backendStatus);
      }
      state = state.copyWith(isSubmitting: false);
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Called by the arrived-at-destination sheet. The driver asks the customer
  /// for the 6-digit code shown in the customer app. Only a successful verify
  /// completes the trip and moves money/receipts forward.
  Future<bool> verifyDeliveryOtp(String code) async {
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
      await _completeRealTrip(job);
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  Future<void> _completeRealTrip(DriverJob job) async {
    try {
      await _repo.advanceJob(job.id, 'completed');
    } catch (_) {
      // OTP verification already moved the job to delivered. A retry can still
      // complete it, so keep the UI in the delivered state and show the error.
      state = state.copyWith(
        driverStatus: DriverStatus.arrivedAtDestination,
        isSubmitting: false,
        errorMessage: 'Delivery verified. Completing the trip will retry.',
      );
      return;
    }
    final earnings = await _repo.earnings();
    state = state.copyWith(
      driverStatus: DriverStatus.tripCompleted,
      isSubmitting: false,
      todayEarnings: earnings.todayAmount,
      completedToday: earnings.todayTrips,
    );
    _cancelAll();
  }

  Future<void> goBackOnline() async {
    _cancelAll();
    if (_isMock) {
      _mockGoOnline();
      return;
    }
    try {
      final earnings = await _repo.earnings();
      state = state.copyWith(
        driverStatus: DriverStatus.onlineSearching,
        todayEarnings: earnings.todayAmount,
        completedToday: earnings.todayTrips,
        clearIncoming: true,
        clearActive: true,
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
    await _checkOffer();
  }

  Future<void> _checkOffer() async {
    if (_isMock || !ref.mounted) return;
    if (state.driverStatus != DriverStatus.onlineSearching &&
        state.driverStatus != DriverStatus.onlineIdle) {
      return;
    }
    try {
      final offer = await _repo.nextOffer();
      if (offer == null || !ref.mounted) return;
      if (state.driverStatus != DriverStatus.onlineSearching &&
          state.driverStatus != DriverStatus.onlineIdle) {
        return;
      }
      final seconds = offer.expiresAt == null
          ? HomeDelays.countdownSeconds
          : offer.expiresAt!.difference(DateTime.now()).inSeconds;
      state = state.copyWith(
        driverStatus: DriverStatus.incomingJob,
        incomingJob: offer,
        countdownSeconds: seconds.clamp(1, 300),
        clearError: true,
      );
      _startCountdown();
    } catch (_) {
      // Poll failures are non-fatal; the next tick retries.
    }
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
    _offersChannel = ref
        .read(supabaseProvider)
        .channel('driver-offers-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'job_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: userId,
          ),
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
    try {
      final active = await _repo.activeJob();
      if (!ref.mounted || _activeJobId != jobId) return;
      if (active == null) {
        _activeJobId = null;
        state = state.copyWith(
          driverStatus: DriverStatus.onlineSearching,
          clearActive: true,
        );
        await _checkOffer();
        return;
      }
      state = state.copyWith(activeJob: active);
    } catch (_) {
      // Realtime failures are non-fatal.
    }
  }

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

  Future<void> _startLocationUpdates({String? jobId}) async {
    _locationTimer?.cancel();
    await _pushLocation(jobId);
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_pushLocation(jobId)),
    );
  }

  Future<void> _pushLocation(String? jobId) async {
    if (_isMock) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _repo.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        jobId: jobId,
      );
    } catch (_) {
      // Location is best-effort; never block dispatch on it.
    }
  }

  void _mockGoOnline() {
    state = state.copyWith(
      driverStatus: DriverStatus.onlineIdle,
      clearIncoming: true,
      clearActive: true,
      clearError: true,
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

  void _cancelAll() {
    _idleTimer?.cancel();
    _incomingTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    _offersChannel?.unsubscribe();
    _jobChannel?.unsubscribe();
    _idleTimer = null;
    _incomingTimer = null;
    _countdownTimer = null;
    _pollTimer = null;
    _locationTimer = null;
    _offersChannel = null;
    _jobChannel = null;
    _activeJobId = null;
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
