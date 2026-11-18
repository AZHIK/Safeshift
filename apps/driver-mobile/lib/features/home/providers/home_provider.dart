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
          if (state.driverStatus == DriverStatus.offline) return;
          unawaited(_pushLocation(_activeJobId));
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
      // Dispatch matches on drivers.current_vehicle_id. Without it the driver
      // is invisible to every job, so make sure it is set before going online.
      if (!await _repo.ensureCurrentVehicle()) {
        state = state.copyWith(
          driverStatus: DriverStatus.offline,
          isLoading: false,
          errorMessage:
              'Add a vehicle and wait for it to be verified before going online.',
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
      if (!await _repo.ensureCurrentVehicle()) {
        state = state.copyWith(
          driverStatus: DriverStatus.offline,
          clearIncoming: true,
          clearActive: true,
          errorMessage:
              'Add a vehicle and wait for it to be verified before going online.',
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
    if (_isMock || !ref.mounted) return;
    final searching =
        state.driverStatus == DriverStatus.onlineSearching ||
        state.driverStatus == DriverStatus.onlineIdle;
    final incoming = state.driverStatus == DriverStatus.incomingJob;
    if (!searching && !incoming) return;
    try {
      final offer = await _repo.nextOffer();
      if (!ref.mounted) return;

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
    try {
      final active = await _repo.activeJob();
      if (!ref.mounted || _activeJobId != jobId) return;
      if (active == null) {
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
        );
        unawaited(_startLocationUpdates());
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

  /// Streams GPS fixes while the driver is online or on a trip.
  ///
  /// A one-shot `getCurrentPosition` every 30 s wakes the radio only to drop
  /// the lock immediately, which on Android often returns a cached fix and
  /// makes dispatch believe the driver never moves. A position stream keeps
  /// the fused provider warm and, on Android, runs behind a foreground-service
  /// notification so the OS keeps delivering updates while the app is in the
  /// background.
  Future<String?> _startLocationUpdates({String? jobId}) async {
    if (_isMock) return null;
    _locationTimer?.cancel();
    _locationTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on location services so customers can find you nearby.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Allow location access so customers can find you nearby.';
      }
    } catch (error, stack) {
      return ErrorHandler.map(error, stackTrace: stack).message;
    }

    // Publish a fix right away so the driver becomes dispatchable without
    // waiting for the first stream event.
    final failure = await _pushLocation(jobId);

    var lastPushed = DateTime.now();
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(
        (position) {
          final now = DateTime.now();
          // The fused stream can be chatty; the server only needs a fix a few
          // times a minute.
          if (now.difference(lastPushed) < const Duration(seconds: 15)) return;
          lastPushed = now;
          unawaited(_pushPosition(position, jobId));
        },
        onError: (_) {
          // A single bad fix is not fatal; the stream keeps running.
        },
      );
    } catch (error, stack) {
      // Fall back to the periodic safety push below.
      debugPrint('Position stream unavailable: '
          '${ErrorHandler.map(error, stackTrace: stack).message}');
    }

    // Safety net for ROMs/configs that stop the stream: re-assert a fix
    // periodically even if no stream event has arrived.
    _locationTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_pushLocation(jobId)),
    );
    return failure;
  }

  /// Android-specific settings so location keeps flowing in the background.
  ///
  /// iOS/desktop keep the plain settings; on Android the foreground service
  /// notification is what prevents the OS from freezing updates once the app
  /// leaves the foreground. The plugin starts and stops that service with the
  /// stream, so it does not leak after [_cancelAll].
  LocationSettings _locationSettings() {
    const accuracy = LocationAccuracy.high;
    const distanceFilter = 15;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    }
    return AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      intervalDuration: const Duration(seconds: 15),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'SafeShift Driver is online',
        notificationText:
            'Sharing your location so nearby customers can find you.',
        notificationChannelName: 'Driver location',
        notificationIcon: AndroidResource(name: 'ic_launcher'),
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  Future<void> _pushPosition(Position position, String? jobId) async {
    if (_isMock) return;
    try {
      await _repo.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        jobId: jobId,
      );
    } catch (_) {
      // The periodic safety push retries.
    }
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
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on location services so customers can find you nearby.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Allow location access so customers can find you nearby.';
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
      return null;
    } catch (error, stack) {
      return ErrorHandler.map(error, stackTrace: stack).message;
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
    _positionSubscription?.cancel();
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
