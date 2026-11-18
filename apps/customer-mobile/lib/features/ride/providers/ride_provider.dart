import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/mock/mock_payment_methods.dart';
import '../../../shared/models/ride_place.dart';
import '../../../shared/providers/places_provider.dart';
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
    this.scheduledAt,
    this.driver,
    this.etaMin = 7,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.parcelDescription,
    this.parcelWeightKg,
    this.parcelValueTzs,
    this.parcelPhotoPaths = const <String>[],
    this.cargoPhotoPaths = const <String>[],
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
    this.acceptedAt,
    this.cancellationReason,
    this.cancellationFee,
    this.dispatchAttempts = 0,
    this.driverLocationFresh = false,
    this.driverLocationUpdatedAt,
    this.isQuoting = false,
    this.isSubmitting = false,
    this.isRouting = false,
    this.isUploadingPhotos = false,
    this.routePoints = const <LatLng>[],
    this.driverLatitude,
    this.driverLongitude,
  }) : paymentMethod = paymentMethod ?? mockPaymentMethods.first;

  final RideStage stage;
  final RidePlace? pickup;
  final RidePlace? destination;
  final VehicleTypeOption? vehicleClass;
  final CargoTypeOption? cargo;

  /// Requested pickup time. `null` means "now".
  final DateTime? scheduledAt;

  final Driver? driver;
  final int etaMin;
  final double distanceKm;
  final int durationMin;
  // Parcel details (filled via dialog, stays on the single screen).
  final String? parcelDescription;
  final double? parcelWeightKg;
  final int? parcelValueTzs;

  /// Local filesystem paths chosen in the parcel dialog.
  final List<String> parcelPhotoPaths;

  /// Object paths inside `job-evidence` after the photos are uploaded.
  final List<String> cargoPhotoPaths;

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

  final DateTime? acceptedAt;
  final String? cancellationReason;
  final double? cancellationFee;
  final int dispatchAttempts;

  /// Whether the driver's last GPS fix is recent enough to trust.
  final bool driverLocationFresh;
  final DateTime? driverLocationUpdatedAt;

  final bool isQuoting;
  final bool isSubmitting;
  final bool isUploadingPhotos;

  /// True while a road route is being calculated for the current endpoints.
  final bool isRouting;

  /// Decoded road-following polyline between pickup and destination.
  final List<LatLng> routePoints;
  final double? driverLatitude;
  final double? driverLongitude;

  bool get hasRoute => pickup != null && destination != null;
  bool get isScheduled => scheduledAt != null;
  bool get hasParcelDetails =>
      (parcelDescription?.trim().isNotEmpty ?? false) ||
      parcelWeightKg != null ||
      parcelValueTzs != null ||
      parcelPhotoPaths.isNotEmpty;

  /// True only when the parcel details the driver needs (value + photo) are
  /// complete. Vehicles and quotes must not be shown before this.
  bool get hasRequiredParcelDetails =>
      parcelValueTzs != null &&
      parcelValueTzs! > 0 &&
      parcelPhotoPaths.isNotEmpty;

  /// Human label for the schedule pill. "Now" until a time is chosen.
  String get scheduledLabel {
    final at = scheduledAt;
    if (at == null) return 'Now';
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = day.difference(today).inDays;
    final time = DateFormat('h:mm a').format(local);
    if (days == 0) return 'Today $time';
    if (days == 1) return 'Tomorrow $time';
    return DateFormat('EEE d MMM, h:mm a').format(local);
  }

  RideState copyWith({
    RideStage? stage,
    RidePlace? pickup,
    RidePlace? destination,
    VehicleTypeOption? vehicleClass,
    CargoTypeOption? cargo,
    DateTime? scheduledAt,
    Driver? driver,
    int? etaMin,
    double? distanceKm,
    int? durationMin,
    String? parcelDescription,
    double? parcelWeightKg,
    int? parcelValueTzs,
    List<String>? parcelPhotoPaths,
    List<String>? cargoPhotoPaths,
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
    DateTime? acceptedAt,
    String? cancellationReason,
    double? cancellationFee,
    int? dispatchAttempts,
    bool? driverLocationFresh,
    DateTime? driverLocationUpdatedAt,
    bool? isQuoting,
    bool? isSubmitting,
    bool? isUploadingPhotos,
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
    bool clearSchedule = false,
    bool clearVehicle = false,
  }) {
    return RideState(
      stage: stage ?? this.stage,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      vehicleClass: clearVehicle ? null : (vehicleClass ?? this.vehicleClass),
      cargo: clearCargo ? null : (cargo ?? this.cargo),
      scheduledAt: clearSchedule ? null : (scheduledAt ?? this.scheduledAt),
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
      cargoPhotoPaths: clearParcel
          ? const <String>[]
          : (cargoPhotoPaths ?? this.cargoPhotoPaths),
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
      acceptedAt: clearJob ? null : (acceptedAt ?? this.acceptedAt),
      cancellationReason: clearJob
          ? null
          : (cancellationReason ?? this.cancellationReason),
      cancellationFee: clearJob
          ? null
          : (cancellationFee ?? this.cancellationFee),
      dispatchAttempts: clearJob
          ? 0
          : (dispatchAttempts ?? this.dispatchAttempts),
      driverLocationFresh: clearDriver
          ? false
          : (driverLocationFresh ?? this.driverLocationFresh),
      driverLocationUpdatedAt: clearDriver
          ? null
          : (driverLocationUpdatedAt ?? this.driverLocationUpdatedAt),
      isQuoting: isQuoting ?? this.isQuoting,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingPhotos: isUploadingPhotos ?? this.isUploadingPhotos,
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

final _tzs = NumberFormat('#,##0');

class RideNotifier extends Notifier<RideState> {
  int _quoteGen = 0;
  int _routeGen = 0;
  Timer? _routeTimer;
  RealtimeChannel? _channel;
  Timer? _poll;
  String? _otpIssuedFor;
  DateTime? _lastAutoDispatch;

  static const Duration _autoDispatchCooldown = Duration(seconds: 50);

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
      // Price the real road route rather than the straight-line estimate.
      if (state.vehicleClass != null) {
        unawaited(refreshQuote());
      }
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
    final currentVehicle = state.vehicleClass;
    final weight = state.parcelWeightKg;
    final clearVehicle = currentVehicle != null &&
        !canVehicleCarryCargo(currentVehicle, cargo, weight);
    state = state.copyWith(
      cargo: cargo,
      clearVehicle: clearVehicle,
      clearQuote: true,
      clearError: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  /// Sets (or clears, with `null`) the requested pickup time.
  ///
  /// Any schedule change invalidates the quote because time-of-day pricing and
  /// the scheduled-at field are part of it.
  void setScheduledAt(DateTime? at) {
    state = state.copyWith(
      scheduledAt: at,
      clearSchedule: at == null,
      clearQuote: true,
      clearError: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
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
    final newWeight = weightKg ?? state.parcelWeightKg;
    final currentVehicle = state.vehicleClass;
    final cargo = state.cargo;
    final clearVehicle = currentVehicle != null &&
        !canVehicleCarryCargo(currentVehicle, cargo, newWeight);
    state = state.copyWith(
      parcelDescription: description ?? state.parcelDescription,
      parcelWeightKg: weightKg ?? state.parcelWeightKg,
      parcelValueTzs: valueTzs ?? state.parcelValueTzs,
      parcelPhotoPaths: photoPaths ?? state.parcelPhotoPaths,
      clearVehicle: clearVehicle,
      clearQuote: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  void clearParcelDetails() {
    state = state.copyWith(clearParcel: true, clearQuote: true);
    if (state.hasRoute) unawaited(refreshQuote());
  }

  /// Client-side mirror of the quote engine's load checks.
  ///
  /// The server remains authoritative, but failing here keeps the customer on
  /// the sheet with actionable copy instead of a rounded request error.
  String? _validateLoad(VehicleTypeOption vehicle) {
    final description = state.parcelDescription?.trim();
    if (description != null && description.length > 1000) {
      return 'Keep the parcel description under 1000 characters.';
    }

    final weight = state.parcelWeightKg;
    if (weight != null) {
      if (weight <= 0) return 'Enter a parcel weight greater than zero.';
      if (vehicle.capacityKgMax > 0 && weight > vehicle.capacityKgMax) {
        return 'This load weighs ${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg '
            'but a ${vehicle.name} carries at most '
            '${vehicle.capacityKgMax.round()} kg. Choose a larger vehicle.';
      }
    }

    final cargo = state.cargo;
    if (cargo != null) {
      if (cargo.allowedVehicleTypeCodes.isNotEmpty &&
          !cargo.allowedVehicleTypeCodes.contains(vehicle.code)) {
        return '${cargo.name} cannot travel in a ${vehicle.name}. '
            'Choose an allowed vehicle.';
      }
      if (cargo.prohibitedVehicleTypeCodes.contains(vehicle.code)) {
        return '${cargo.name} cannot travel in a ${vehicle.name}. '
            'Choose another vehicle.';
      }
      final maxValue = cargo.maxValueTzs;
      if (maxValue != null &&
          state.parcelValueTzs != null &&
          state.parcelValueTzs! > maxValue) {
        return 'The declared value is above the TZS '
            '${_tzs.format(maxValue)} limit for ${cargo.name}. '
            'Split the load or contact support.';
      }
    }

    if (state.parcelValueTzs == null || state.parcelValueTzs! <= 0) {
      return 'Add an approximate value for your parcel so the driver can '
          'handle it correctly.';
    }
    if (state.parcelPhotoPaths.isEmpty) {
      return 'Add at least one photo of the parcel.';
    }

    final scheduled = state.scheduledAt;
    if (scheduled != null) {
      final now = DateTime.now();
      if (scheduled.isBefore(now.subtract(const Duration(minutes: 1)))) {
        return 'Choose a pickup time in the future.';
      }
      if (scheduled.isAfter(now.add(const Duration(days: 60)))) {
        return 'Moves can be scheduled at most 60 days ahead.';
      }
    }

    if (state.distanceKm > 1000) {
      return 'This route is too long for a single move.';
    }
    return null;
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

    final validationError = _validateLoad(vehicle);
    if (validationError != null) {
      _quoteGen++;
      state = state.copyWith(
        isQuoting: false,
        clearQuote: true,
        errorMessage: validationError,
      );
      return;
    }

    final gen = ++_quoteGen;
    state = state.copyWith(isQuoting: true, clearError: true);
    try {
      final quote = await _repo.requestQuote(
        pickup: pickup,
        destination: destination,
        vehicle: vehicle,
        cargo: state.cargo,
        weightKg: state.parcelWeightKg,
        valueTzs: state.parcelValueTzs,
        scheduledAt: state.scheduledAt,
        cargoDescription: state.parcelDescription,
      );
      if (gen != _quoteGen) return;
      state = state.copyWith(
        quoteId: quote.quoteId,
        quoteTotal: quote.total,
        quoteSubtotal: quote.subtotal,
        quoteVat: quote.vat,
        distanceKm: quote.distanceKm,
        durationMin: quote.durationMin,
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

    final vehicle = state.vehicleClass;
    if (vehicle == null) {
      state = state.copyWith(errorMessage: 'Choose a vehicle first.');
      return;
    }
    final validationError = _validateLoad(vehicle);
    if (validationError != null) {
      state = state.copyWith(
        stage: RideStage.confirm,
        errorMessage: validationError,
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

      final job = await _createJobWithFreshQuote(
        paymentMethod: state.paymentMethod.id,
      );
      state = state.copyWith(jobId: job.id, jobStatus: job.status);
      _subscribe(job.id);
      _startPolling(job.id);

      // Parcel photos are uploaded after the job exists so they land under the
      // path the storage policy expects. A failure here must not lose the
      // move: the customer can still complete it, and support can see the job.
      await _attachParcelPhotos(job.id);

      final dispatch = await _repo.dispatch(job.id);
      _lastAutoDispatch = DateTime.now();
      if (dispatch.count == 0) {
        final message = _noDriverMessage(dispatch);
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: message,
          clearError: message == null,
        );
        return;
      }
      state = state.copyWith(isSubmitting: false, clearError: true);
    } catch (error, stack) {
      state = state.copyWith(
        stage: state.jobId == null ? RideStage.confirm : RideStage.searching,
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  Future<void> _attachParcelPhotos(String jobId) async {
    final paths = state.parcelPhotoPaths;
    if (paths.isEmpty) return;
    state = state.copyWith(isUploadingPhotos: true);
    try {
      final uploaded = await _repo.uploadParcelPhotos(
        jobId: jobId,
        localPaths: paths,
      );
      if (state.jobId == jobId) {
        state = state.copyWith(
          cargoPhotoPaths: uploaded,
          isUploadingPhotos: false,
        );
      }
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isUploadingPhotos: false,
        errorMessage:
            'Your move is still active, but the parcel photos could not be '
            'uploaded. ${ErrorHandler.map(error, stackTrace: stack).message}',
      );
    }
  }

  /// Creates the job, re-quoting once if the quote expired.
  ///
  /// A quote is valid for 15 minutes. If the customer leaves the confirmation
  /// sheet open for longer, the job insert is rejected with SQLSTATE 22023
  /// ("quote ... has expired"). Re-quote and try again rather than failing.
  Future<CustomerJobSnapshot> _createJobWithFreshQuote({
    String? paymentMethod,
  }) async {
    final quoteId = state.quoteId;
    if (quoteId == null) {
      throw StateError('Cannot create a job without a quote.');
    }
    try {
      return await _repo.createJob(quoteId, paymentMethod: paymentMethod);
    } on PostgrestException catch (error) {
      if (error.code != '22023') rethrow;
      await refreshQuote();
      final freshQuoteId = state.quoteId;
      if (freshQuoteId == null) rethrow;
      return _repo.createJob(freshQuoteId, paymentMethod: paymentMethod);
    }
  }

  /// Explains why dispatch found nobody.
  ///
  /// The server reports the step that emptied the result, so the customer
  /// sees the actual cause instead of a generic "no drivers nearby". Returns
  /// null for states that are normal (a live offer is out, or a scheduled move
  /// is deliberately waiting), so the searching view stays calm.
  String? _noDriverMessage(DispatchResult dispatch) {
    final reason = dispatch.reason?.trim();
    if (reason == null || reason.isEmpty) {
      return 'No verified drivers are nearby right now. We will keep looking.';
    }
    switch (reason) {
      case 'waiting for a driver to respond':
        return null;
      case 'job is scheduled for later':
        return 'Your move is scheduled for ${state.scheduledLabel}. '
            'We will start looking for a driver 45 minutes before pickup.';
      case 'job is no longer dispatchable':
        return 'This move can no longer be offered to new drivers.';
      case 'no verified drivers are available right now':
        return 'No verified drivers are online right now. We will keep looking.';
      case 'drivers are online but have not shared a recent location':
        return 'Drivers are online but have not shared a recent location yet. '
            'We will keep looking.';
      case 'drivers have no verified vehicle attached':
        return 'The drivers online are still waiting for a vehicle to be '
            'verified. We will keep looking.';
      case 'no online driver has a vehicle of the requested class':
        return 'No online driver has a vehicle of the class you selected. '
            'Try a different vehicle, or wait for one to come online.';
      case 'every matching driver is already on a job':
        return 'Every matching driver is already on a move. We will keep '
            'looking for a free driver.';
      case 'no matching driver is within the search radius':
        return 'No matching driver is close enough yet. We are widening the '
            'search.';
      case 'no matching driver is free right now':
        return 'No matching driver is free right now. We will keep looking.';
      default:
        return 'No verified drivers are nearby right now. We will keep looking.';
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
      _lastAutoDispatch = DateTime.now();
      final message = result.count == 0 ? _noDriverMessage(result) : null;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: message,
        clearError: message == null,
      );
      _startPolling(jobId);
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
    _lastAutoDispatch = null;
    _otpIssuedFor = null;
    state = RideState(stage: RideStage.searching, jobId: jobId);
    try {
      final job = await _repo.getJob(jobId);
      if (job == null) {
        state = state.copyWith(errorMessage: 'That move could not be found.');
        return;
      }
      _applyJob(job);
      // A resumed job only carries its endpoints, not the road geometry, so
      // rebuild the route once for the map. The guarded call is a no-op when
      // the customer was already mid-flow with a route on screen.
      if (state.routePoints.isEmpty &&
          state.pickup != null &&
          state.destination != null) {
        unawaited(_computeRoute(++_routeGen));
      }
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

  /// Restores an in-flight move when the app starts on the home screen.
  ///
  /// Only runs from a pristine idle state so it never replaces a route the
  /// customer is already editing.
  Future<void> resumeActiveJob() async {
    if (state.stage != RideStage.idle || state.jobId != null) return;
    try {
      final job = await _repo.getActiveJob();
      if (job == null || !ref.mounted) return;
      if (state.stage != RideStage.idle || state.jobId != null) return;
      await loadJob(job.id);
    } catch (_) {
      // Resume is best-effort; a failure leaves the customer on the form.
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
      if (job != null && state.jobId == jobId) {
        _applyJob(job);
        _maybeAutoRedispatch(job);
      }
    } catch (_) {
      // Realtime/poll failures are non-fatal; the next tick retries.
    }
  }

  /// Rebuilds a map endpoint from stored job coordinates, or returns
  /// [current] when it already points at the same place.
  ///
  /// Jobs only persist an address and a coordinate, not the provider metadata
  /// (place id, structured address). Reusing [current] while it matches keeps
  /// that metadata and avoids refitting the map on every poll.
  RidePlace? _restoredPlace({
    required RidePlace? current,
    required String jobId,
    required String suffix,
    required String fallbackName,
    required String address,
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude == null || longitude == null) return current;
    if (current != null &&
        (current.latitude - latitude).abs() <= 1e-6 &&
        (current.longitude - longitude).abs() <= 1e-6) {
      return current;
    }
    final trimmed = address.trim();
    return RidePlace(
      id: 'job-$jobId-$suffix',
      name: trimmed.isNotEmpty ? trimmed : fallbackName,
      district: '',
      latitude: latitude,
      longitude: longitude,
      formattedAddress: trimmed.isNotEmpty ? trimmed : null,
      source: current?.source ?? RidePlaceSource.map,
    );
  }

  void _applyJob(CustomerJobSnapshot job) {
    final status = job.status;
    if (status == 'cancelled') {
      _cleanup();
      state = state.copyWith(
        stage: RideStage.confirm,
        jobStatus: status,
        cancellationReason: job.cancellationReason,
        cancellationFee: job.cancellationFee,
        errorMessage: job.cancellationReason?.trim().isNotEmpty == true
            ? 'This move was cancelled: ${job.cancellationReason!.trim()}'
            : 'This move was cancelled.',
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

    final completed = job.isDelivered && status == 'completed';
    final scheduledLater =
        driver == null &&
        job.scheduledAt != null &&
        job.scheduledAt!.isAfter(
          DateTime.now().add(const Duration(minutes: 45)),
        );

    final RideStage stage;
    if (completed) {
      stage = RideStage.done;
    } else if (driver != null) {
      stage = RideStage.tracking;
    } else {
      stage = RideStage.searching;
    }

    String? message = state.errorMessage;
    if (driver != null || completed) {
      message = null;
    } else if (scheduledLater) {
      message =
          'Your move is scheduled for ${_formatSchedule(job.scheduledAt!)}. '
          'We will start looking for a driver 45 minutes before pickup.';
    }

    // Restore the map endpoints when opening an existing job (cold start or a
    // deep link). Keep the richer place the customer already picked while it
    // still matches the job, so a polling refresh does not reset the camera.
    final pickupPlace = _restoredPlace(
      current: state.pickup,
      jobId: job.id,
      suffix: 'pickup',
      fallbackName: 'Pickup',
      address: job.pickupAddress,
      latitude: job.pickupLat,
      longitude: job.pickupLng,
    );
    final destinationPlace = _restoredPlace(
      current: state.destination,
      jobId: job.id,
      suffix: 'dropoff',
      fallbackName: 'Drop-off',
      address: job.destinationAddress,
      latitude: job.destinationLat,
      longitude: job.destinationLng,
    );

    state = state.copyWith(
      stage: stage,
      jobStatus: status,
      pickup: pickupPlace,
      destination: destinationPlace,
      pickupAddress: job.pickupAddress,
      destinationAddress: job.destinationAddress,
      scheduledAt: job.scheduledAt,
      clearSchedule: job.scheduledAt == null,
      acceptedAt: job.acceptedAt,
      dispatchAttempts: job.dispatchAttempts,
      parcelDescription: job.cargoDescription,
      parcelWeightKg: job.cargoWeightKg,
      parcelValueTzs: job.declaredValueTzs?.round(),
      cargoPhotoPaths: job.cargoPhotoPaths,
      driver: driver,
      clearDriver: driver == null,
      distanceKm: job.distanceKm > 0 ? job.distanceKm : null,
      quoteTotal: job.amount > 0 ? job.amount : null,
      driverLatitude: job.driverLat,
      driverLongitude: job.driverLng,
      driverLocationFresh: job.driverLocationFresh,
      driverLocationUpdatedAt: job.driverLocationUpdatedAt,
      errorMessage: message,
      clearError: message == null,
    );

    if (driver != null &&
        !completed &&
        state.deliveryOtp == null &&
        _otpIssuedFor != job.id) {
      _otpIssuedFor = job.id;
      unawaited(_issueOtp(job.id));
    }
    if (completed) _cleanup();
  }

  /// Runs the client-side dispatch fallback while the customer is searching.
  ///
  /// The database worker is the primary re-dispatch loop; this exists so a
  /// missing or paused pg_cron does not strand a move. It respects the
  /// server's `last_dispatched_at` cadence and the six-attempt cap so it never
  /// races the worker or burns the customer's search.
  void _maybeAutoRedispatch(CustomerJobSnapshot job) {
    if (state.stage != RideStage.searching) return;
    if (state.jobId == null || state.jobId != job.id) return;
    if (job.driverId != null || job.isTerminal || job.isDelivered) return;
    if (job.dispatchAttempts >= 6) return;
    final scheduled = job.scheduledAt;
    if (scheduled != null &&
        scheduled.isAfter(DateTime.now().add(const Duration(minutes: 45)))) {
      return;
    }
    final now = DateTime.now();
    final last = [?_lastAutoDispatch, ?job.lastDispatchedAt].fold<DateTime?>(
      null,
      (latest, value) {
        if (latest == null || value.isAfter(latest)) return value;
        return latest;
      },
    );
    if (last != null && now.difference(last) < _autoDispatchCooldown) return;
    _lastAutoDispatch = now;
    unawaited(_autoDispatch(job.id));
  }

  Future<void> _autoDispatch(String jobId) async {
    if (!ref.mounted || state.jobId != jobId) return;
    if (state.stage != RideStage.searching) return;
    try {
      final result = await _repo.dispatch(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      final message = result.count == 0 ? _noDriverMessage(result) : null;
      state = state.copyWith(
        errorMessage: message,
        clearError: message == null,
      );
    } catch (_) {
      // Silent retry; the next poll tick tries again.
    }
  }

  static String _formatSchedule(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = day.difference(today).inDays;
    final time = DateFormat('h:mm a').format(local);
    if (days == 0) return 'today at $time';
    if (days == 1) return 'tomorrow at $time';
    return '${DateFormat('EEE d MMM').format(local)} at $time';
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

/// Whether [vehicle] can carry [cargo] with the optional [weightKg].
///
/// Cargo compatibility comes from the catalogue (`allowed`/`prohibited`
/// vehicle type codes); capacity is checked only when a weight is known.
bool canVehicleCarryCargo(
  VehicleTypeOption vehicle,
  CargoTypeOption? cargo,
  double? weightKg,
) {
  if (cargo != null) {
    if (cargo.allowedVehicleTypeCodes.isNotEmpty &&
        !cargo.allowedVehicleTypeCodes.contains(vehicle.code)) {
      return false;
    }
    if (cargo.prohibitedVehicleTypeCodes.contains(vehicle.code)) {
      return false;
    }
  }
  if (weightKg != null &&
      weightKg > 0 &&
      vehicle.capacityKgMax > 0 &&
      weightKg > vehicle.capacityKgMax) {
    return false;
  }
  return true;
}
