import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/mock/mock_payment_methods.dart';
import '../../../shared/models/catalog_option.dart';
import '../../../shared/models/ride_place.dart';
import '../../../shared/providers/places_provider.dart';
import '../../../shared/repositories/catalog_repository.dart';
import '../../../shared/utils/polyline.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tracking/domain/entities/driver.dart';
import '../data/ride_repository.dart';
import '../data/route_service.dart';

/// Single-screen Bolt-style flow. Everything happens on RideScreen,
/// the bottom sheet just morphs through these stages.
enum RideStage {
  /// Map + "Where to?" + saved places.
  idle,

  /// Pickup + destination chosen, route preview on map.
  route,

  /// Vehicle carousel visible.
  vehicle,

  /// Quote + confirm visible.
  confirm,

  /// Searching for driver (radar).
  searching,

  /// Driver assigned + live tracking.
  tracking,

  /// Delivered / receipt.
  done,
}

class RideState {
  RideState({
    this.stage = RideStage.idle,
    this.pickup,
    this.destination,
    this.vehicleClass,
    this.cargo,
    this.scheduledLabel = 'Now',
    this.driver,
    this.etaMin = 7,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.parcelDescription,
    this.parcelWeightKg,
    this.parcelValueTzs,
    this.parcelPhotoPaths = const <String>[],
    MockPaymentMethod? paymentMethod,
    this.quoteId,
    this.jobId,
    this.jobStatus,
    this.pickupAddress,
    this.destinationAddress,
    this.quoteTotal,
    this.quoteSubtotal,
    this.quoteVat,
    this.deliveryOtp,
    this.errorMessage,
    this.routeError,
    this.isQuoting = false,
    this.isSubmitting = false,
    this.isRouting = false,
    this.routePoints = const <LatLng>[],
    this.driverLatitude,
    this.driverLongitude,
  }) : paymentMethod = paymentMethod ?? mockPaymentMethods.first;

  final RideStage stage;
  final RidePlace? pickup;
  final RidePlace? destination;
  final VehicleTypeOption? vehicleClass;
  final CargoTypeOption? cargo;
  final String scheduledLabel;
  final Driver? driver;
  final int etaMin;
  final double distanceKm;
  final int durationMin;
  // Parcel details (filled via dialog, stays on the single screen).
  final String? parcelDescription;
  final double? parcelWeightKg;
  final int? parcelValueTzs;
  final List<String> parcelPhotoPaths;
  final MockPaymentMethod paymentMethod;

  // Backend identifiers and live values.
  final String? quoteId;
  final String? jobId;
  final String? jobStatus;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? quoteTotal;
  final double? quoteSubtotal;
  final double? quoteVat;
  final String? deliveryOtp;
  final String? errorMessage;
  /// User-facing message when road-route calculation fails.
  final String? routeError;
  final bool isQuoting;
  final bool isSubmitting;
  /// True while a road route is being calculated for the current endpoints.
  final bool isRouting;
  /// Decoded road-following polyline between pickup and destination.
  final List<LatLng> routePoints;
  final double? driverLatitude;
  final double? driverLongitude;

  bool get hasRoute => pickup != null && destination != null;
  bool get hasParcelDetails =>
      (parcelDescription?.trim().isNotEmpty ?? false) ||
      parcelWeightKg != null ||
      parcelValueTzs != null ||
      parcelPhotoPaths.isNotEmpty;

  RideState copyWith({
    RideStage? stage,
    RidePlace? pickup,
    RidePlace? destination,
    VehicleTypeOption? vehicleClass,
    CargoTypeOption? cargo,
    String? scheduledLabel,
    Driver? driver,
    int? etaMin,
    double? distanceKm,
    int? durationMin,
    String? parcelDescription,
    double? parcelWeightKg,
    int? parcelValueTzs,
    List<String>? parcelPhotoPaths,
    MockPaymentMethod? paymentMethod,
    String? quoteId,
    String? jobId,
    String? jobStatus,
    String? pickupAddress,
    String? destinationAddress,
    double? quoteTotal,
    double? quoteSubtotal,
    double? quoteVat,
    String? deliveryOtp,
    String? errorMessage,
    String? routeError,
    bool? isQuoting,
    bool? isSubmitting,
    bool? isRouting,
    double? driverLatitude,
    double? driverLongitude,
    List<LatLng>? routePoints,
    bool clearDriver = false,
    bool clearParcel = false,
    bool clearQuote = false,
    bool clearJob = false,
    bool clearOtp = false,
    bool clearError = false,
    bool clearRouteError = false,
    bool clearCargo = false,
  }) {
    return RideState(
      stage: stage ?? this.stage,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      cargo: clearCargo ? null : (cargo ?? this.cargo),
      scheduledLabel: scheduledLabel ?? this.scheduledLabel,
      driver: clearDriver ? null : (driver ?? this.driver),
      etaMin: etaMin ?? this.etaMin,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      parcelDescription: clearParcel
          ? null
          : (parcelDescription ?? this.parcelDescription),
      parcelWeightKg: clearParcel
          ? null
          : (parcelWeightKg ?? this.parcelWeightKg),
      parcelValueTzs: clearParcel
          ? null
          : (parcelValueTzs ?? this.parcelValueTzs),
      parcelPhotoPaths: clearParcel
          ? const <String>[]
          : (parcelPhotoPaths ?? this.parcelPhotoPaths),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      quoteId: clearQuote ? null : (quoteId ?? this.quoteId),
      jobId: clearJob ? null : (jobId ?? this.jobId),
      jobStatus: clearJob ? null : (jobStatus ?? this.jobStatus),
      pickupAddress: clearJob ? null : (pickupAddress ?? this.pickupAddress),
      destinationAddress: clearJob
          ? null
          : (destinationAddress ?? this.destinationAddress),
      quoteTotal: clearQuote ? null : (quoteTotal ?? this.quoteTotal),
      quoteSubtotal: clearQuote ? null : (quoteSubtotal ?? this.quoteSubtotal),
      quoteVat: clearQuote ? null : (quoteVat ?? this.quoteVat),
      deliveryOtp: clearOtp ? null : (deliveryOtp ?? this.deliveryOtp),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      routeError: clearRouteError ? null : (routeError ?? this.routeError),
      isQuoting: isQuoting ?? this.isQuoting,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRouting: isRouting ?? this.isRouting,
      routePoints: routePoints ?? this.routePoints,
      driverLatitude: clearDriver
          ? null
          : (driverLatitude ?? this.driverLatitude),
      driverLongitude: clearDriver
          ? null
          : (driverLongitude ?? this.driverLongitude),
    );
  }
}

class RideNotifier extends Notifier<RideState> {
  int _quoteGen = 0;
  int _routeGen = 0;
  Timer? _routeTimer;
  RealtimeChannel? _channel;
  Timer? _poll;
  String? _otpIssuedFor;

  RideRepository get _repo => RideRepository(ref.read(supabaseProvider));
  RouteService get _routeService => ref.read(routeServiceProvider);

  @override
  RideState build() {
    ref.onDispose(_cleanup);
    return RideState();
  }

  void ensureVehicleSelected(List<VehicleTypeOption> vehicles) {
    if (state.vehicleClass != null || vehicles.isEmpty) return;
    final preferred = vehicles.length > 1 ? vehicles[1] : vehicles.first;
    state = state.copyWith(vehicleClass: preferred);
  }

  void setPickup(RidePlace location) {
    state = state.copyWith(
      pickup: location,
      clearQuote: true,
      clearError: true,
      clearRouteError: true,
      routePoints: const <LatLng>[],
    );
    if (state.hasRoute) {
      state = state.copyWith(stage: RideStage.vehicle);
      unawaited(refreshQuote());
      _scheduleRouteCalculation();
    }
  }

  void setDestination(RidePlace location) {
    state = state.copyWith(
      destination: location,
      clearQuote: true,
      clearError: true,
      clearRouteError: true,
      routePoints: const <LatLng>[],
    );
    if (state.hasRoute) {
      state = state.copyWith(stage: RideStage.vehicle);
      unawaited(refreshQuote());
      _scheduleRouteCalculation();
    }
  }

  void swap() {
    final p = state.pickup;
    final d = state.destination;
    if (p == null || d == null) return;
    state = state.copyWith(
      pickup: d,
      destination: p,
      clearQuote: true,
      clearError: true,
      clearRouteError: true,
      routePoints: const <LatLng>[],
    );
    unawaited(refreshQuote());
    _scheduleRouteCalculation();
  }

  /// Debounces route recalculation so rapid endpoint changes do not fire a
  /// request on every keystroke or pin drag.
  void _scheduleRouteCalculation() {
    _routeTimer?.cancel();
    final gen = ++_routeGen;
    _routeTimer = Timer(const Duration(milliseconds: 400), () async {
      if (gen != _routeGen) return;
      await _computeRoute(gen);
    });
  }

  /// Calculates the road route for the current endpoints and stores the decoded
  /// polyline, distance, and duration. Stale results are discarded when a
  /// newer calculation supersedes them.
  Future<void> _computeRoute(int generation) async {
    final pickup = state.pickup;
    final destination = state.destination;
    if (pickup == null ||
        destination == null ||
        !pickup.hasCoordinates ||
        !destination.hasCoordinates) {
      return;
    }

    state = state.copyWith(isRouting: true, clearRouteError: true);
    try {
      final result = await _routeService.computeRoute(
        originLat: pickup.latitude,
        originLng: pickup.longitude,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
      );
      // Ignore results from superseded requests.
      if (generation != _routeGen || !ref.mounted) return;
      final points = decodePolyline(result.encodedPolyline);
      state = state.copyWith(
        isRouting: false,
        routePoints: points,
        distanceKm: result.distanceKm,
        durationMin: result.durationMin,
        clearRouteError: true,
      );
    } on RouteException catch (error) {
      if (generation != _routeGen || !ref.mounted) return;
      state = state.copyWith(
        isRouting: false,
        routePoints: const <LatLng>[],
        routeError: error.message,
      );
    } catch (error, stack) {
      if (generation != _routeGen || !ref.mounted) return;
      state = state.copyWith(
        isRouting: false,
        routePoints: const <LatLng>[],
        routeError: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  void selectVehicle(VehicleTypeOption vehicle) {
    state = state.copyWith(
      vehicleClass: vehicle,
      stage: RideStage.confirm,
      clearQuote: true,
      clearError: true,
    );
    unawaited(refreshQuote());
  }

  void selectCargo(CargoTypeOption cargo) {
    state = state.copyWith(cargo: cargo, clearQuote: true, clearError: true);
    if (state.hasRoute) unawaited(refreshQuote());
  }

  void setSchedule(String label) {
    state = state.copyWith(scheduledLabel: label);
  }

  /// Payment selection is displayed immediately. Phase 5 settlement remains
  /// server-owned; the client never marks a job paid.
  void selectPaymentMethod(MockPaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setParcelDetails({
    String? description,
    double? weightKg,
    int? valueTzs,
    List<String>? photoPaths,
  }) {
    state = state.copyWith(
      parcelDescription: description ?? state.parcelDescription,
      parcelWeightKg: weightKg ?? state.parcelWeightKg,
      parcelValueTzs: valueTzs ?? state.parcelValueTzs,
      parcelPhotoPaths: photoPaths ?? state.parcelPhotoPaths,
      clearQuote: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  void clearParcelDetails() {
    state = state.copyWith(clearParcel: true, clearQuote: true);
    if (state.hasRoute) unawaited(refreshQuote());
  }

  Future<void> refreshQuote() async {
    final pickup = state.pickup;
    final destination = state.destination;
    final vehicle = state.vehicleClass;
    final user = ref.read(authProvider).currentUser;
    if (pickup == null ||
        destination == null ||
        vehicle == null ||
        user == null) {
      return;
    }

    final gen = ++_quoteGen;
    state = state.copyWith(isQuoting: true, clearError: true);
    try {
      final quote = await _repo.requestQuote(
        customerId: user.id,
        pickup: pickup,
        destination: destination,
        vehicle: vehicle,
        cargo: state.cargo,
        weightKg: state.parcelWeightKg,
        valueTzs: state.parcelValueTzs,
      );
      if (gen != _quoteGen) return;
      // The quote is priced on the straight-line distance. Once a road route
      // has been computed, keep the real road distance and duration so the
      // sheet does not flip back to the estimate.
      final hasRoadRoute = state.routePoints.isNotEmpty;
      state = state.copyWith(
        quoteId: quote.quoteId,
        quoteTotal: quote.total,
        quoteSubtotal: quote.subtotal,
        quoteVat: quote.vat,
        distanceKm: hasRoadRoute ? null : quote.distanceKm,
        durationMin: hasRoadRoute ? null : quote.durationMin,
        isQuoting: false,
      );
    } catch (error, stack) {
      if (gen != _quoteGen) return;
      state = state.copyWith(
        isQuoting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Creates the job from the persisted quote and starts dispatch. The search
  /// stays on the same screen and updates through realtime plus a slow poll
  /// fallback for unreliable mobile networks.
  Future<void> confirmAndFindDriver() async {
    if (!state.hasRoute || state.isSubmitting) return;
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Your session expired. Please sign in again.',
      );
      return;
    }

    state = state.copyWith(
      stage: RideStage.searching,
      isSubmitting: true,
      clearDriver: true,
      clearJob: true,
      clearOtp: true,
      clearError: true,
    );

    try {
      if (state.quoteId == null) {
        await refreshQuote();
        if (state.quoteId == null) {
          state = state.copyWith(
            stage: RideStage.confirm,
            isSubmitting: false,
            errorMessage: state.errorMessage ?? 'Could not price this move.',
          );
          return;
        }
      }

      final job = await _repo.createJob(state.quoteId!);
      state = state.copyWith(jobId: job.id, jobStatus: job.status);
      _subscribe(job.id);
      final dispatch = await _repo.dispatch(job.id);
      if (dispatch.count == 0) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'No verified drivers are nearby right now. Try again in a moment.',
        );
        return;
      }
      state = state.copyWith(isSubmitting: false);
      _startPolling(job.id);
    } catch (error, stack) {
      state = state.copyWith(
        stage: state.jobId == null ? RideStage.confirm : RideStage.searching,
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  Future<void> retryDispatch() async {
    final jobId = state.jobId;
    if (jobId == null) {
      await confirmAndFindDriver();
      return;
    }
    state = state.copyWith(
      stage: RideStage.searching,
      isSubmitting: true,
      clearError: true,
    );
    try {
      final result = await _repo.dispatch(jobId);
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: result.count == 0
            ? 'Still no verified drivers nearby. Please try again shortly.'
            : null,
      );
      if (result.count > 0) _startPolling(jobId);
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Used by deep links and history detail to jump straight into a job.
  Future<void> loadJob(String jobId) async {
    _cleanup();
    state = RideState(stage: RideStage.searching, jobId: jobId);
    try {
      final job = await _repo.getJob(jobId);
      if (job == null) {
        state = state.copyWith(errorMessage: 'That move could not be found.');
        return;
      }
      _applyJob(job);
      if (!job.isTerminal && !job.isDelivered) {
        _subscribe(jobId);
        _startPolling(jobId);
      }
    } catch (error, stack) {
      state = state.copyWith(
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Uploads pickup/delivery evidence for the current job.
  Future<bool> uploadEvidence({
    required String evidenceType,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(
        errorMessage: 'No active move to attach proof to.',
      );
      return false;
    }
    try {
      await _repo.uploadJobEvidence(
        jobId: jobId,
        evidenceType: evidenceType,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  /// Sends a photo/file to the driver through the job chat.
  Future<bool> sendChatAttachment({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    String? caption,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(errorMessage: 'No active move to chat about.');
      return false;
    }
    try {
      await _repo.sendChatAttachment(
        jobId: jobId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        caption: caption,
      );
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  Future<void> cancelSearch() async {
    if (state.isSubmitting) return;
    final jobId = state.jobId;
    final userId = ref.read(authProvider).currentUser?.id;
    if (jobId != null && userId != null) {
      state = state.copyWith(isSubmitting: true, clearError: true);
      try {
        await _repo.cancelJob(jobId, userId);
      } catch (error, stack) {
        if (!ref.mounted) return;
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
        );
        return;
      }
    }
    _cleanup();
    state = state.copyWith(
      stage: RideStage.vehicle,
      isSubmitting: false,
      clearDriver: true,
      clearJob: true,
      clearOtp: true,
      clearError: true,
    );
  }

  void complete() {
    _cleanup();
    state = state.copyWith(stage: RideStage.done);
  }

  void reset() {
    _cleanup();
    _quoteGen++;
    state = RideState();
  }

  void backToRoute() {
    _cleanup();
    _quoteGen++;
    state = state.copyWith(
      stage: RideStage.vehicle,
      clearDriver: true,
      clearJob: true,
      clearOtp: true,
      clearError: true,
    );
  }

  void driverFound(Driver driver) {
    state = state.copyWith(stage: RideStage.tracking, driver: driver);
  }

  void _subscribe(String jobId) {
    _channel?.unsubscribe();
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('customer-job-$jobId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (_) => unawaited(_refreshJob(jobId)),
        )
        .subscribe();
  }

  void _startPolling(String jobId) {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_refreshJob(jobId)),
    );
  }

  Future<void> _refreshJob(String jobId) async {
    if (state.jobId != jobId) return;
    try {
      final job = await _repo.getJob(jobId);
      if (job != null && state.jobId == jobId) _applyJob(job);
    } catch (_) {
      // Realtime/poll failures are non-fatal; the next tick retries.
    }
  }

  void _applyJob(CustomerJobSnapshot job) {
    final status = job.status;
    if (status == 'cancelled') {
      _cleanup();
      state = state.copyWith(
        stage: RideStage.confirm,
        jobStatus: status,
        errorMessage: 'This move was cancelled.',
        clearDriver: true,
      );
      return;
    }

    Driver? driver;
    if (job.driverId != null) {
      driver = Driver(
        id: job.driverId!,
        name: job.driverName ?? 'SafeShift driver',
        vehicleClass: job.vehicleType ?? state.vehicleClass?.name ?? 'Vehicle',
        rating: job.driverRating,
        phone: job.driverPhone ?? '',
        completedTrips: 0,
        verified: job.driverVerified,
      );
    }

    final delivered = job.isDelivered;
    final tracking = driver != null && !delivered;
    state = state.copyWith(
      stage: delivered
          ? RideStage.done
          : tracking
          ? RideStage.tracking
          : state.stage,
      jobStatus: status,
      pickupAddress: job.pickupAddress,
      destinationAddress: job.destinationAddress,
      driver: driver,
      clearDriver: driver == null,
      distanceKm: job.distanceKm > 0 ? job.distanceKm : state.distanceKm,
      quoteTotal: job.amount > 0 ? job.amount : state.quoteTotal,
      driverLatitude: job.driverLat,
      driverLongitude: job.driverLng,
      clearError: true,
    );

    if (driver != null &&
        !delivered &&
        state.deliveryOtp == null &&
        _otpIssuedFor != job.id) {
      _otpIssuedFor = job.id;
      unawaited(_issueOtp(job.id));
    }
    if (delivered) _cleanup();
  }

  Future<void> _issueOtp(String jobId) async {
    try {
      final code = await _repo.issueDeliveryOtp(jobId);
      if (state.jobId == jobId) {
        state = state.copyWith(deliveryOtp: code);
      }
    } catch (_) {
      _otpIssuedFor = null;
    }
  }

  void _cleanup() {
    _routeTimer?.cancel();
    _routeTimer = null;
    _poll?.cancel();
    _poll = null;
    _channel?.unsubscribe();
    _channel = null;
  }
}

final rideProvider = NotifierProvider<RideNotifier, RideState>(
  RideNotifier.new,
);

final rideVehicleTypesProvider = FutureProvider<List<VehicleTypeOption>>((ref) {
  return CatalogRepository(ref.watch(supabaseProvider)).getVehicleTypes();
});

final rideCargoTypesProvider = FutureProvider<List<CargoTypeOption>>((ref) {
  return CatalogRepository(ref.watch(supabaseProvider)).getCargoTypes();
});

final rideSavedPlacesProvider = FutureProvider<List<RidePlace>>((ref) async {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return const <RidePlace>[];
  return ref.watch(placesRepositoryProvider).getSavedPlaces(user.id);
});
